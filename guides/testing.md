# Testing

This guide covers how to test code that uses the AccessGrid SDK.

## Mocking with Mox

The SDK uses a behaviour-based HTTP client, making it easy to mock with [Mox](https://hex.pm/packages/mox).

### Setup

Add Mox to your test dependencies:

```elixir
# mix.exs
defp deps do
  [
    {:mox, "~> 1.0", only: :test}
  ]
end
```

Define a mock in your `test/test_helper.exs`:

```elixir
Mox.defmock(AccessGrid.HttpClient.Mock, for: AccessGrid.HttpClient.Behaviour)
Application.put_env(:accessgrid, :http_client, AccessGrid.HttpClient.Mock)
```

### Basic Example

```elixir
defmodule MyApp.CardServiceTest do
  use ExUnit.Case, async: true

  import Mox

  alias AccessGrid.HttpResponse

  # Verify mocks are called
  setup :verify_on_exit!

  test "issues a card successfully" do
    expect(AccessGrid.HttpClient.Mock, :post, fn _url, _opts ->
      {:ok, %HttpResponse{
        status: 201,
        body_decoded: %{
          "id" => "card_123",
          "state" => "active",
          "install_url" => "https://install.example.com/card_123"
        }
      }}
    end)

    assert {:ok, card} = AccessGrid.AccessCards.issue(%{
      card_template_id: "tmpl_123",
      full_name: "Test User"
    })

    assert card.id == "card_123"
    assert card.state == "active"
  end
end
```

### Testing Error Handling

```elixir
test "handles not found errors" do
  expect(AccessGrid.HttpClient.Mock, :get, fn _url, _opts ->
    {:error, %AccessGrid.HttpFailure{
      status: 404,
      reason: :not_found,
      body_decoded: %{"error" => "Card not found"}
    }}
  end)

  assert {:error, :not_found, failure} = AccessGrid.AccessCards.get("invalid_id")
  assert failure.status == 404
end

test "handles validation errors" do
  expect(AccessGrid.HttpClient.Mock, :post, fn _url, _opts ->
    {:error, %AccessGrid.HttpFailure{
      status: 422,
      reason: :unprocessable_entity,
      body_decoded: %{"errors" => ["card_template_id is required"]}
    }}
  end)

  assert {:error, :validation_failed, failure} = AccessGrid.AccessCards.issue(%{})
  assert failure.status == 422
end
```

## Using Explicit Clients

For more control in tests, pass an explicit client instead of relying on config:

```elixir
setup do
  client = AccessGrid.Client.new(
    account_id: "test_account",
    api_secret: "test_secret"
  )

  {:ok, client: client}
end

test "uses explicit client", %{client: client} do
  expect(AccessGrid.HttpClient.Mock, :get, fn url, opts ->
    # Verify the client credentials were used
    assert opts[:headers]["X-ACCT-ID"] == "test_account"
    {:ok, %HttpResponse{status: 200, body_decoded: %{"id" => "card_123"}}}
  end)

  AccessGrid.AccessCards.get("card_123", client: client)
end
```

## Using Gestalt for Config Isolation

For async tests that need different config values, use [Gestalt](https://hex.pm/packages/gestalt):

```elixir
setup do
  # Override config for this test process only
  Gestalt.replace_config(:accessgrid, :account_id, "test_account", self())
  Gestalt.replace_config(:accessgrid, :api_secret, "test_secret", self())
  :ok
end
```

This allows async tests to run with different configurations without interfering with each other.

## Creating a Test Helper

For cleaner tests, create a helper module with a `__using__` macro:

```elixir
# test/support/accessgrid_testing.ex
defmodule MyApp.AccessGridTesting do
  @moduledoc """
  Test helper for AccessGrid mocking.

  ## Usage

      # Default - uses mock HTTP client
      use MyApp.AccessGridTesting

      # Live mode - uses real HTTP client for integration tests
      use MyApp.AccessGridTesting, live: true

  Then use `mock_http_client/0` to set expectations:

      expect(mock_http_client(), :get, fn _url, _opts ->
        {:ok, %HttpResponse{status: 200, body_decoded: %{"id" => "abc"}}}
      end)
  """

  defmacro __using__(opts) do
    quote do
      import Mox
      import MyApp.AccessGridTesting

      alias AccessGrid.HttpFailure
      alias AccessGrid.HttpResponse

      setup :verify_on_exit!

      setup do
        if unquote(opts[:live]) == true do
          # Use real HTTP client for integration tests
          # `AccessGrid.HttpClient.Req` is the default http client
          Mox.stub_with(AccessGrid.HttpClient.Mock, AccessGrid.HttpClient.Req)
        end

        :ok
      end
    end
  end

  def mock_http_client, do: AccessGrid.HttpClient.Mock

  # Convenience helpers for common responses

  def mock_card_response(attrs \\ %{}) do
    Map.merge(
      %{
        "id" => "card_#{System.unique_integer([:positive])}",
        "state" => "active",
        "install_url" => "https://install.example.com",
        "full_name" => "Test User"
      },
      attrs
    )
  end

  def expect_card_issue(response_attrs \\ %{}) do
    expect(mock_http_client(), :post, fn _url, _opts ->
      {:ok, %HttpResponse{status: 201, body_decoded: mock_card_response(response_attrs)}}
    end)
  end

  def expect_card_get(card_id, response_attrs \\ %{}) do
    expect(mock_http_client(), :get, fn url, _opts ->
      assert url =~ card_id
      {:ok, %HttpResponse{status: 200, body_decoded: mock_card_response(response_attrs)}}
    end)
  end

  def expect_not_found do
    expect(mock_http_client(), :get, fn _url, _opts ->
      {:error, %HttpFailure{status: 404, reason: :not_found}}
    end)
  end
end
```

Usage with mocked HTTP (default):

```elixir
defmodule MyApp.CardServiceTest do
  use ExUnit.Case, async: true
  use MyApp.AccessGridTesting

  test "issues a card" do
    expect_card_issue(%{"full_name" => "Jane Doe"})

    {:ok, card} = AccessGrid.AccessCards.issue(%{card_template_id: "tmpl_123"})
    assert card.full_name == "Jane Doe"
  end

  test "handles not found" do
    expect_not_found()

    assert {:error, :not_found, _} = AccessGrid.AccessCards.get("invalid")
  end
end
```

Usage with live HTTP (integration tests):

```elixir
defmodule MyApp.CardServiceIntegrationTest do
  use ExUnit.Case, async: false
  use MyApp.AccessGridTesting, live: true

  # These tests hit the real AccessGrid API
  # Make sure you have valid credentials configured

  @tag :integration
  test "actually issues a card" do
    {:ok, card} = AccessGrid.AccessCards.issue(%{
      card_template_id: "real_template_id",
      full_name: "Integration Test"
    })

    assert card.id
  end
end
```

Run integration tests separately:

```bash
# Skip integration tests (default)
mix test --exclude integration

# Run only integration tests
mix test --only integration
```
