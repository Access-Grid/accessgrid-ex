defmodule AccessGrid.AccessPassesTest do
  use ExUnit.Case, async: true
  use Test.HttpClientMocking

  alias AccessGrid.AccessPass
  alias AccessGrid.AccessPasses
  alias AccessGrid.Client

  @client Client.new(
            account_id: "acct_123",
            api_secret: "test_secret",
            api_host: "https://api.accessgrid.com"
          )

  describe "issue/2" do
    test "returns {:ok, Card} on success" do
      response_body = %{
        "id" => "card_abc123",
        "state" => "issued",
        "install_url" => "https://example.com/install",
        "full_name" => "John Doe",
        "card_template_id" => "tmpl_123"
      }

      expect(mock_http_client(), :post, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/key-cards"
        assert opts[:body] == %{card_template_id: "tmpl_123", full_name: "John Doe"}
        {:ok, %HttpResponse{status: 201, body_decoded: response_body}}
      end)

      assert {:ok, %AccessPass{} = card} =
               AccessPasses.issue(
                 %{card_template_id: "tmpl_123", full_name: "John Doe"},
                 client: @client
               )

      assert card.id == "card_abc123"
      assert card.state == "issued"
      assert card.full_name == "John Doe"
    end

    test "returns {:error, :validation_failed, failure} on 422" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 422,
           reason: :unprocessable_entity,
           body_decoded: %{"message" => "Invalid card_template_id"}
         }}
      end)

      assert {:error, :validation_failed, %HttpFailure{} = failure} =
               AccessPasses.issue(%{card_template_id: "invalid"}, client: @client)

      assert failure.status == 422
    end

    test "returns {:error, :unauthorized, failure} on 401" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error, %HttpFailure{status: 401, reason: :unauthorized}}
      end)

      assert {:error, :unauthorized, %HttpFailure{}} =
               AccessPasses.issue(%{card_template_id: "tmpl_123"}, client: @client)
    end
  end

  describe "get/2" do
    test "returns {:ok, Card} on success" do
      response_body = %{
        "id" => "card_abc123",
        "state" => "active",
        "full_name" => "Jane Doe"
      }

      expect(mock_http_client(), :get, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/key-cards/card_abc123"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %AccessPass{} = card} = AccessPasses.get("card_abc123", client: @client)

      assert card.id == "card_abc123"
      assert card.state == "active"
    end

    test "returns {:error, :not_found, failure} on 404" do
      expect(mock_http_client(), :get, fn _url, _opts ->
        {:error, %HttpFailure{status: 404, reason: :not_found}}
      end)

      assert {:error, :not_found, %HttpFailure{}} =
               AccessPasses.get("nonexistent", client: @client)
    end
  end

  describe "list/2" do
    test "returns {:ok, [Card]} on success" do
      response_body = %{
        "keys" => [
          %{"id" => "card_1", "state" => "active"},
          %{"id" => "card_2", "state" => "suspended"}
        ]
      }

      expect(mock_http_client(), :get, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/key-cards"
        assert opts[:params]["template_id"] == "tmpl_123"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, cards} = AccessPasses.list("tmpl_123", client: @client)

      assert length(cards) == 2
      assert [%AccessPass{id: "card_1"}, %AccessPass{id: "card_2"}] = cards
    end

    test "passes state filter when provided" do
      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:params]["template_id"] == "tmpl_123"
        assert opts[:params]["state"] == "active"
        {:ok, %HttpResponse{status: 200, body_decoded: %{"keys" => []}}}
      end)

      assert {:ok, []} = AccessPasses.list("tmpl_123", client: @client, state: "active")
    end
  end

  describe "update/3" do
    test "returns {:ok, Card} on success" do
      response_body = %{
        "id" => "card_abc123",
        "state" => "active",
        "full_name" => "Updated Name"
      }

      expect(mock_http_client(), :patch, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/key-cards/card_abc123"
        assert opts[:body] == %{full_name: "Updated Name"}
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %AccessPass{} = card} =
               AccessPasses.update("card_abc123", %{full_name: "Updated Name"}, client: @client)

      assert card.full_name == "Updated Name"
    end
  end

  describe "suspend/2" do
    test "returns {:ok, Card} on success" do
      response_body = %{"id" => "card_abc123", "state" => "suspended"}

      expect(mock_http_client(), :post, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/key-cards/card_abc123/suspend"
        # Manage actions POST with no body, so Rails verifies the signature
        # against the `sig_payload` query param. Lock in that the SDK actually
        # sends it — without this, requests 401 at runtime even though the
        # client-layer signature value is correct.
        assert opts[:params]["sig_payload"] == ~s({"id":"card_abc123"})
        assert opts[:body] == nil
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %AccessPass{state: "suspended"}} =
               AccessPasses.suspend("card_abc123", client: @client)
    end
  end

  describe "resume/2" do
    test "returns {:ok, Card} on success" do
      response_body = %{"id" => "card_abc123", "state" => "active"}

      expect(mock_http_client(), :post, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/key-cards/card_abc123/resume"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %AccessPass{state: "active"}} =
               AccessPasses.resume("card_abc123", client: @client)
    end
  end

  describe "unlink/2" do
    test "returns {:ok, Card} on success" do
      response_body = %{"id" => "card_abc123", "state" => "unlinked"}

      expect(mock_http_client(), :post, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/key-cards/card_abc123/unlink"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %AccessPass{state: "unlinked"}} =
               AccessPasses.unlink("card_abc123", client: @client)
    end
  end

  describe "delete/2" do
    test "returns {:ok, Card} on success" do
      response_body = %{"id" => "card_abc123", "state" => "deleted"}

      expect(mock_http_client(), :post, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/key-cards/card_abc123/delete"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %AccessPass{state: "deleted"}} =
               AccessPasses.delete("card_abc123", client: @client)
    end
  end

  describe "client resolution" do
    test "uses client from opts when provided" do
      custom_client =
        Client.new(
          account_id: "custom_acct",
          api_secret: "custom_secret",
          api_host: "https://custom.api.com"
        )

      expect(mock_http_client(), :get, fn url, opts ->
        assert url == "https://custom.api.com/v1/key-cards/card_123"
        assert opts[:headers]["X-ACCT-ID"] == "custom_acct"
        {:ok, %HttpResponse{status: 200, body_decoded: %{"id" => "card_123"}}}
      end)

      AccessPasses.get("card_123", client: custom_client)
    end

    test "falls back to config when no client provided" do
      Gestalt.replace_config(:accessgrid, :account_id, "config_acct", self())
      Gestalt.replace_config(:accessgrid, :api_secret, "config_secret", self())
      Gestalt.replace_config(:accessgrid, :api_host, "https://config.api.com", self())

      expect(mock_http_client(), :get, fn url, opts ->
        assert url == "https://config.api.com/v1/key-cards/card_123"
        assert opts[:headers]["X-ACCT-ID"] == "config_acct"
        {:ok, %HttpResponse{status: 200, body_decoded: %{"id" => "card_123"}}}
      end)

      AccessPasses.get("card_123")
    end
  end

  describe "local required-field validation" do
    # Short-circuits before HTTP — no mock needed.

    test "issue requires card_template_id" do
      assert {:error, :missing_required, [:card_template_id]} =
               AccessPasses.issue(%{}, client: @client)

      assert {:error, :missing_required, [:card_template_id]} =
               AccessPasses.issue(%{card_template_id: ""}, client: @client)
    end

    test "get requires card_id" do
      assert {:error, :missing_required, [:card_id]} = AccessPasses.get(nil, client: @client)
      assert {:error, :missing_required, [:card_id]} = AccessPasses.get("", client: @client)
    end

    test "update requires card_id" do
      assert {:error, :missing_required, [:card_id]} =
               AccessPasses.update(nil, %{full_name: "X"}, client: @client)
    end

    test "list requires template_id" do
      assert {:error, :missing_required, [:template_id]} = AccessPasses.list(nil, client: @client)
    end

    test "manage actions (suspend/resume/unlink/delete) require card_id" do
      assert {:error, :missing_required, [:card_id]} = AccessPasses.suspend(nil, client: @client)
      assert {:error, :missing_required, [:card_id]} = AccessPasses.resume(nil, client: @client)
      assert {:error, :missing_required, [:card_id]} = AccessPasses.unlink(nil, client: @client)
      assert {:error, :missing_required, [:card_id]} = AccessPasses.delete(nil, client: @client)
    end
  end
end
