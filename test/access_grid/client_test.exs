defmodule AccessGrid.ClientTest do
  use ExUnit.Case, async: true
  use Test.HttpClientMocking

  alias AccessGrid.Client

  @default_host "https://api.accessgrid.com"

  @client Client.new(
            account_id: "acct_123",
            api_secret: "test_secret",
            api_host: "https://api.accessgrid.com"
          )

  describe "new/1" do
    test "creates client with explicit credentials" do
      client = Client.new(account_id: "acct_123", api_secret: "secret_456")

      assert client.account_id == "acct_123"
      assert client.api_secret == "secret_456"
      assert client.api_host == @default_host
    end

    test "allows overriding api_host" do
      client =
        Client.new(
          account_id: "acct_123",
          api_secret: "secret_456",
          api_host: "https://staging.accessgrid.com"
        )

      assert client.api_host == "https://staging.accessgrid.com"
    end

    test "raises when account_id is missing" do
      assert_raise ArgumentError, ~r/account_id/, fn ->
        Client.new(api_secret: "secret_456")
      end
    end

    test "raises when api_secret is missing" do
      assert_raise ArgumentError, ~r/api_secret/, fn ->
        Client.new(account_id: "acct_123")
      end
    end
  end

  describe "from_config/0" do
    test "creates client from application config" do
      # Use Gestalt to set process-specific config for this test
      Gestalt.replace_config(:accessgrid, :account_id, "config_acct", self())
      Gestalt.replace_config(:accessgrid, :api_secret, "config_secret", self())

      client = Client.from_config()

      assert client.account_id == "config_acct"
      assert client.api_secret == "config_secret"
      assert client.api_host == @default_host
    end

    test "uses api_host from config when provided" do
      Gestalt.replace_config(:accessgrid, :account_id, "config_acct", self())
      Gestalt.replace_config(:accessgrid, :api_secret, "config_secret", self())
      Gestalt.replace_config(:accessgrid, :api_host, "https://custom.accessgrid.com", self())

      client = Client.from_config()

      assert client.api_host == "https://custom.accessgrid.com"
    end

    test "raises when account_id not configured" do
      Gestalt.replace_config(:accessgrid, :account_id, nil, self())
      Gestalt.replace_config(:accessgrid, :api_secret, "config_secret", self())

      assert_raise ArgumentError, ~r/account_id/, fn ->
        Client.from_config()
      end
    end

    test "raises when api_secret not configured" do
      Gestalt.replace_config(:accessgrid, :account_id, "config_acct", self())
      Gestalt.replace_config(:accessgrid, :api_secret, nil, self())

      assert_raise ArgumentError, ~r/api_secret/, fn ->
        Client.from_config()
      end
    end
  end

  describe "request/4" do
    test "builds correct URL from host and path" do
      expect(mock_http_client(), :post, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/key-cards"
        {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
      end)

      Client.request(@client, :post, "/v1/key-cards", body: %{name: "Test"})
    end

    test "includes auth headers" do
      expect(mock_http_client(), :get, fn _url, opts ->
        headers = opts[:headers]
        assert headers["X-ACCT-ID"] == "acct_123"
        assert is_binary(headers["X-PAYLOAD-SIG"])
        assert headers["Content-Type"] == "application/json"
        version = Application.spec(:accessgrid, :vsn) |> to_string()
        assert headers["User-Agent"] == "accessgrid-ex/#{version}"
        {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
      end)

      Client.request(@client, :get, "/v1/key-cards")
    end

    test "passes body for POST requests" do
      body = %{card_template_id: "tmpl_123", full_name: "John Doe"}

      expect(mock_http_client(), :post, fn _url, opts ->
        assert opts[:body] == body
        {:ok, %HttpResponse{status: 201, body_decoded: %{"id" => "card_123"}}}
      end)

      Client.request(@client, :post, "/v1/key-cards", body: body)
    end

    test "adds sig_payload param for GET requests" do
      expect(mock_http_client(), :get, fn _url, opts ->
        assert Map.has_key?(opts[:params], "sig_payload")
        {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
      end)

      Client.request(@client, :get, "/v1/key-cards/card_123")
    end

    test "returns HttpResponse on success" do
      expect(mock_http_client(), :get, fn _url, _opts ->
        {:ok, %HttpResponse{status: 200, body_decoded: %{"id" => "card_123"}}}
      end)

      assert {:ok, %HttpResponse{status: 200}} =
               Client.request(@client, :get, "/v1/key-cards/card_123")
    end

    test "returns HttpFailure on error" do
      expect(mock_http_client(), :get, fn _url, _opts ->
        {:error, %AccessGrid.HttpFailure{reason: :timeout}}
      end)

      assert {:error, %AccessGrid.HttpFailure{reason: :timeout}} =
               Client.request(@client, :get, "/v1/key-cards/card_123")
    end

    test "resolves client from config when nil" do
      Gestalt.replace_config(:accessgrid, :account_id, "config_acct", self())
      Gestalt.replace_config(:accessgrid, :api_secret, "config_secret", self())

      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:headers]["X-ACCT-ID"] == "config_acct"
        {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
      end)

      Client.request(nil, :get, "/v1/key-cards")
    end

    test "merges custom params with sig_payload" do
      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:params]["page"] == "2"
        assert opts[:params]["state"] == "active"
        assert Map.has_key?(opts[:params], "sig_payload")
        {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
      end)

      Client.request(@client, :get, "/v1/key-cards", params: %{"page" => "2", "state" => "active"})
    end

    test "supports all HTTP methods" do
      # Methods defined in HttpClient.Behaviour
      for method <- [:get, :post, :put, :patch, :delete, :head] do
        expect(mock_http_client(), method, fn _url, _opts ->
          {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
        end)

        assert {:ok, _} = Client.request(@client, method, "/v1/test")
      end
    end
  end

  describe "request/4 signature computation" do
    # Test vectors generated from another SDK implementation to verify compatibility:
    #   secret = "test_secret"
    #   payload = '{"id":"card_123"}'
    #   encoded = Base64.strict_encode64(payload)  # => "eyJpZCI6ImNhcmRfMTIzIn0="
    #   signature = OpenSSL::HMAC.hexdigest('sha256', secret, encoded)
    #   # => "0b1918a2ba398bbd851ba5ab8bbcfe3a3fdbee5857f64e49439d97a717f76d51"

    test "POST with body uses JSON body as payload with correct signature" do
      # payload = {"name":"test"} (JSON encoded body)
      # verified: signature = "0e492e35e3858140c7e4a6678ca96a2dc553e81cc3bd97b5cf4a8576107b868e"
      expected_sig = "0e492e35e3858140c7e4a6678ca96a2dc553e81cc3bd97b5cf4a8576107b868e"

      expect(mock_http_client(), :post, fn _url, opts ->
        assert opts[:headers]["X-PAYLOAD-SIG"] == expected_sig
        assert opts[:body] == %{name: "test"}
        {:ok, %HttpResponse{status: 201, body_decoded: %{}}}
      end)

      Client.request(@client, :post, "/v1/key-cards", body: %{name: "test"})
    end

    test "GET uses resource ID payload with correct signature" do
      # /v1/key-cards/card_123 -> payload = {"id":"card_123"}
      # verified: signature = "0b1918a2ba398bbd851ba5ab8bbcfe3a3fdbee5857f64e49439d97a717f76d51"
      expected_sig = "0b1918a2ba398bbd851ba5ab8bbcfe3a3fdbee5857f64e49439d97a717f76d51"
      expected_payload = ~s({"id":"card_123"})

      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:headers]["X-PAYLOAD-SIG"] == expected_sig
        assert opts[:params]["sig_payload"] == expected_payload
        {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
      end)

      Client.request(@client, :get, "/v1/key-cards/card_123")
    end

    test "DELETE uses resource ID payload + sends sig_payload in query" do
      # Rails verifies signature against the request body OR `sig_payload` query
      # when body is blank. For DELETE we have no body, so we must send the
      # payload in the query — same pattern as GET. Reuses the GET test vector.
      expected_sig = "0b1918a2ba398bbd851ba5ab8bbcfe3a3fdbee5857f64e49439d97a717f76d51"
      expected_payload = ~s({"id":"card_123"})

      expect(mock_http_client(), :delete, fn _url, opts ->
        assert opts[:headers]["X-PAYLOAD-SIG"] == expected_sig
        assert opts[:params]["sig_payload"] == expected_payload
        assert opts[:body] == nil
        {:ok, %HttpResponse{status: 204, body_decoded: nil}}
      end)

      Client.request(@client, :delete, "/v1/key-cards/card_123")
    end

    test "POST without body uses resource ID payload + sends sig_payload in query" do
      # /v1/key-cards/card_123/suspend -> payload = {"id":"card_123"}
      # Rails falls back to `sig_payload` query when body is blank, so the
      # client must include it for the signature to match.
      expected_sig = "0b1918a2ba398bbd851ba5ab8bbcfe3a3fdbee5857f64e49439d97a717f76d51"
      expected_payload = ~s({"id":"card_123"})

      expect(mock_http_client(), :post, fn _url, opts ->
        assert opts[:headers]["X-PAYLOAD-SIG"] == expected_sig
        assert opts[:params]["sig_payload"] == expected_payload
        assert opts[:body] == nil
        {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
      end)

      Client.request(@client, :post, "/v1/key-cards/card_123/suspend")
    end

    test "empty payload uses correct signature" do
      # payload = "{}" -> signature verified
      expected_sig = "bb98f7d7e577e826235bd51f99cfb30542e74f0f992624fd3bb61d7cf053f737"
      expected_payload = "{}"

      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:headers]["X-PAYLOAD-SIG"] == expected_sig
        assert opts[:params]["sig_payload"] == expected_payload
        {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
      end)

      # Root path produces empty payload
      Client.request(@client, :get, "/v1")
    end

    test "action paths extract ID from second-to-last segment" do
      # All actions should use {"id":"card_123"} -> same signature
      expected_sig = "0b1918a2ba398bbd851ba5ab8bbcfe3a3fdbee5857f64e49439d97a717f76d51"

      for action <- ~w(suspend resume unlink delete) do
        expect(mock_http_client(), :post, fn _url, opts ->
          assert opts[:headers]["X-PAYLOAD-SIG"] == expected_sig
          {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
        end)

        Client.request(@client, :post, "/v1/key-cards/card_123/#{action}")
      end
    end

    test "collection path uses last segment as ID" do
      # /v1/key-cards -> {"id":"key-cards"}
      expected_payload = ~s({"id":"key-cards"})

      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:params]["sig_payload"] == expected_payload
        # Signature is computed from {"id":"key-cards"}
        {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
      end)

      Client.request(@client, :get, "/v1/key-cards")
    end
  end
end
