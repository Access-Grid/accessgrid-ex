defmodule Test.HttpClientMocking do
  @moduledoc """
  Test helper for HTTP client mocking.

  ## Usage

      # Default - uses mock HTTP client
      use Test.HttpClientMocking

      # Live mode - uses real Req client for e2e tests
      use Test.HttpClientMocking, live: true

  Then use `mock_http_client/0` to get the mock module for setting expectations:

      expect(mock_http_client(), :get, fn _url, _opts ->
        {:ok, %HttpResponse{status: 200, body: %{"id" => "abc"}}}
      end)
  """

  defmacro __using__(opts) do
    quote do
      import Mox
      import Test.HttpClientMocking

      alias AccessGrid.HttpClient
      alias AccessGrid.HttpFailure
      alias AccessGrid.HttpResponse

      setup :verify_on_exit!

      setup do
        if unquote(opts[:live]) == true do
          Mox.stub_with(AccessGrid.HttpClient.Mock, AccessGrid.HttpClient.Req)
        end

        :ok
      end
    end
  end

  def mock_http_client, do: AccessGrid.HttpClient.Mock
end
