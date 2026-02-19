defmodule AccessGrid.HttpClient.ReqTest do
  use ExUnit.Case, async: true

  alias AccessGrid.HttpClient.Req, as: ReqClient
  alias AccessGrid.HttpFailure
  alias AccessGrid.HttpResponse

  # Each test stubs the Req transport via Req.Test, registered against the
  # ReqClient module name. The `:req_plug` config in config/test.exs makes
  # ReqClient route every Req request through the stub. The URL passed to
  # ReqClient.get/post/etc. is opaque — Req.Test intercepts before any HTTP
  # call, so the URL just needs to be valid syntax.

  describe "get/2" do
    test "returns HttpResponse on 2xx" do
      Req.Test.stub(ReqClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"id": "123"}))
      end)

      assert {:ok, %HttpResponse{} = response} = ReqClient.get("http://test/test")

      assert response.status == 200
      assert response.body_decoded == %{"id" => "123"}
      assert response.body_raw == ~s({"id": "123"})
      assert response.content_type =~ "application/json"
    end

    test "includes query params when provided" do
      Req.Test.stub(ReqClient, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["foo"] == "bar"
        assert conn.query_params["baz"] == "qux"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({}))
      end)

      opts = %{params: %{"foo" => "bar", "baz" => "qux"}}
      assert {:ok, _response} = ReqClient.get("http://test/test", opts)
    end

    test "includes headers when provided" do
      Req.Test.stub(ReqClient, fn conn ->
        assert Plug.Conn.get_req_header(conn, "x-custom-header") == ["custom-value"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({}))
      end)

      opts = %{headers: [{"x-custom-header", "custom-value"}]}
      assert {:ok, _response} = ReqClient.get("http://test/test", opts)
    end

    test "returns HttpFailure with :not_found on 404" do
      Req.Test.stub(ReqClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, ~s({"error": "not found"}))
      end)

      assert {:error, %HttpFailure{} = failure} = ReqClient.get("http://test/test/missing")

      assert failure.status == 404
      assert failure.reason == :not_found
      assert failure.body_decoded == %{"error" => "not found"}
      assert failure.body_raw == ~s({"error": "not found"})
    end

    test "returns HttpFailure with :unauthorized on 401" do
      Req.Test.stub(ReqClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(401, ~s({"error": "unauthorized"}))
      end)

      assert {:error, %HttpFailure{} = failure} = ReqClient.get("http://test/test")

      assert failure.status == 401
      assert failure.reason == :unauthorized
    end

    test "returns HttpFailure with :forbidden on 403" do
      Req.Test.stub(ReqClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(403, ~s({"error": "forbidden"}))
      end)

      assert {:error, %HttpFailure{} = failure} = ReqClient.get("http://test/test")

      assert failure.status == 403
      assert failure.reason == :forbidden
    end

    test "returns HttpFailure with :unprocessable_entity on 422" do
      Req.Test.stub(ReqClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(422, ~s({"errors": ["invalid"]}))
      end)

      assert {:error, %HttpFailure{} = failure} = ReqClient.get("http://test/test")

      assert failure.status == 422
      assert failure.reason == :unprocessable_entity
    end

    test "returns HttpFailure with :client_error on other 4xx" do
      Req.Test.stub(ReqClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(418, ~s({"error": "teapot"}))
      end)

      assert {:error, %HttpFailure{} = failure} = ReqClient.get("http://test/test")

      assert failure.status == 418
      assert failure.reason == :client_error
    end

    test "returns HttpFailure with :internal_server_error on 500" do
      Req.Test.stub(ReqClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(500, ~s({"error": "internal"}))
      end)

      assert {:error, %HttpFailure{} = failure} =
               ReqClient.get("http://test/test", %{retry: false})

      assert failure.status == 500
      assert failure.reason == :internal_server_error
    end

    test "returns HttpFailure with :service_unavailable on 503" do
      Req.Test.stub(ReqClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(503, ~s({"error": "unavailable"}))
      end)

      assert {:error, %HttpFailure{} = failure} =
               ReqClient.get("http://test/test", %{retry: false})

      assert failure.status == 503
      assert failure.reason == :service_unavailable
    end

    test "returns HttpFailure with :server_error on other 5xx" do
      Req.Test.stub(ReqClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(502, ~s({"error": "bad gateway"}))
      end)

      assert {:error, %HttpFailure{} = failure} =
               ReqClient.get("http://test/test", %{retry: false})

      assert failure.status == 502
      assert failure.reason == :bad_gateway
    end

    test "returns HttpFailure on connection error" do
      # Simulate a transport-level failure (e.g. econnrefused). Req.Test
      # supports this via transport_error/2 — the stub raises a TransportError
      # which ReqClient maps to %HttpFailure{reason: :econnrefused}.
      Req.Test.stub(ReqClient, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %HttpFailure{} = failure} =
               ReqClient.get("http://test/test", %{retry: false})

      assert failure.reason == :econnrefused
      assert failure.status == nil
    end

    test "returns HttpFailure with :redirect on 3xx" do
      Req.Test.stub(ReqClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "/other")
        |> Plug.Conn.resp(302, "")
      end)

      # Disable redirect following
      opts = %{redirect: false}

      assert {:error, %HttpFailure{} = failure} = ReqClient.get("http://test/test", opts)

      assert failure.status == 302
      assert failure.reason == :redirect
    end
  end

  describe "post/2" do
    test "sends JSON body by default" do
      Req.Test.stub(ReqClient, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"name" => "test"}
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, ~s({"id": "456"}))
      end)

      opts = %{body: %{"name" => "test"}}

      assert {:ok, %HttpResponse{} = response} = ReqClient.post("http://test/test", opts)

      assert response.status == 201
      assert response.body_decoded == %{"id" => "456"}
    end

    test "sends raw body when body_format is :raw" do
      Req.Test.stub(ReqClient, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == "raw content"

        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.resp(200, "ok")
      end)

      opts = %{body: "raw content", body_format: :raw}

      assert {:ok, %HttpResponse{} = response} = ReqClient.post("http://test/test", opts)

      assert response.status == 200
    end
  end

  describe "put/2" do
    test "sends JSON body" do
      Req.Test.stub(ReqClient, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"name" => "updated"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"id": "123", "name": "updated"}))
      end)

      opts = %{body: %{"name" => "updated"}}

      assert {:ok, %HttpResponse{} = response} = ReqClient.put("http://test/test/123", opts)

      assert response.status == 200
    end
  end

  describe "patch/2" do
    test "sends JSON body" do
      Req.Test.stub(ReqClient, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"name" => "patched"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"id": "123", "name": "patched"}))
      end)

      opts = %{body: %{"name" => "patched"}}

      assert {:ok, %HttpResponse{} = response} = ReqClient.patch("http://test/test/123", opts)

      assert response.status == 200
      assert response.body_decoded == %{"id" => "123", "name" => "patched"}
    end
  end

  describe "delete/2" do
    test "returns HttpResponse on success" do
      Req.Test.stub(ReqClient, fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, %HttpResponse{} = response} = ReqClient.delete("http://test/test/123")

      assert response.status == 204
    end
  end

  describe "head/2" do
    test "returns HttpResponse with headers" do
      Req.Test.stub(ReqClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-total-count", "42")
        |> Plug.Conn.resp(200, "")
      end)

      assert {:ok, %HttpResponse{} = response} = ReqClient.head("http://test/test")

      assert response.status == 200
      assert {"x-total-count", "42"} in response.headers
    end
  end
end
