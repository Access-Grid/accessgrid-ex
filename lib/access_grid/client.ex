defmodule AccessGrid.Client do
  @moduledoc """
  Holds configuration for AccessGrid API authentication.

  A client can be created explicitly with `new/1` or loaded from application config with `from_config/0`.

  ## Examples

      # Explicit credentials
      client = AccessGrid.Client.new(
        account_id: "acct_123",
        api_secret: "secret_456"
      )

      # From application config (uses Gestalt for process isolation)
      client = AccessGrid.Client.from_config()

  """

  @type t :: %__MODULE__{
          account_id: String.t(),
          api_secret: String.t(),
          api_host: String.t()
        }

  @default_host "https://api.accessgrid.com"

  @enforce_keys [:account_id, :api_secret]
  defstruct [:account_id, :api_secret, api_host: @default_host]

  @doc """
  Creates a new client with explicit credentials.

  ## Options

    * `:account_id` - Required. The AccessGrid account ID.
    * `:api_secret` - Required. The API secret for signing requests.
    * `:api_host` - Optional. API host URL. Defaults to `#{@default_host}`.

  ## Examples

      iex> AccessGrid.Client.new(account_id: "acct_123", api_secret: "secret_456")
      %AccessGrid.Client{account_id: "acct_123", api_secret: "secret_456", api_host: "https://api.accessgrid.com"}

  """
  @spec new(keyword()) :: t()
  def new(opts) do
    account_id = Keyword.get(opts, :account_id)
    api_secret = Keyword.get(opts, :api_secret)
    api_host = Keyword.get(opts, :api_host, @default_host)

    validate_required!(:account_id, account_id)
    validate_required!(:api_secret, api_secret)

    %__MODULE__{
      account_id: account_id,
      api_secret: api_secret,
      api_host: api_host
    }
  end

  @doc """
  Creates a client from application configuration.

  Uses Gestalt for process-specific config overrides, enabling async test isolation.

  ## Configuration

      config :accessgrid,
        account_id: "acct_123",
        api_secret: "secret_456",
        api_host: "https://api.accessgrid.com"  # optional

  """
  @spec from_config() :: t()
  def from_config do
    pid = self()

    account_id = Gestalt.get_config(:accessgrid, :account_id, pid)
    api_secret = Gestalt.get_config(:accessgrid, :api_secret, pid)
    api_host = Gestalt.get_config(:accessgrid, :api_host, pid) || @default_host

    :ok = validate_required!(:account_id, account_id)
    :ok = validate_required!(:api_secret, api_secret)

    %__MODULE__{
      account_id: account_id,
      api_secret: api_secret,
      api_host: api_host
    }
  end

  @type method :: :get | :post | :put | :patch | :delete | :head

  @doc """
  Makes an authenticated request to the AccessGrid API.

  Handles URL construction, payload signing, and header generation.

  ## Options

    * `:body` - Request body (map). Will be JSON encoded for POST/PUT/PATCH.
    * `:params` - Query parameters (map).
    * `:headers` - Additional headers (map).

  ## Examples

      client = AccessGrid.Client.new(account_id: "acct_123", api_secret: "secret")

      # POST with body
      Client.request(client, :post, "/v1/key-cards", body: %{name: "Test"})

      # GET with params
      Client.request(client, :get, "/v1/key-cards", params: %{"page" => "2"})

      # Using config (pass nil for client)
      Client.request(nil, :get, "/v1/key-cards/card_123")

  """
  @spec request(t() | nil, method(), String.t(), keyword()) ::
          {:ok, AccessGrid.HttpResponse.t()} | {:error, AccessGrid.HttpFailure.t()}
  def request(client, method, path, opts \\ [])

  def request(nil, method, path, opts) do
    request(from_config(), method, path, opts)
  end

  def request(%__MODULE__{} = client, method, path, opts) do
    body = Keyword.get(opts, :body)
    params = Keyword.get(opts, :params, %{})
    custom_headers = Keyword.get(opts, :headers, %{})

    payload = compute_payload(method, path, body)
    signature = sign(client.api_secret, payload)

    headers =
      auth_headers(client.account_id, signature)
      |> Map.merge(custom_headers)

    params =
      if body_empty?(body) do
        Map.put(params, "sig_payload", payload)
      else
        params
      end

    url = build_url(client.api_host, path)

    request_opts = %{headers: headers, params: params, body: body}

    apply(AccessGrid.HttpClient, method, [url, request_opts])
  end

  # --- Private helpers ---

  @action_segments ~w(suspend resume unlink delete publish)

  defp compute_payload(:get, path, _body), do: id_payload(path)
  defp compute_payload(:delete, path, _body), do: id_payload(path)
  defp compute_payload(:post, path, nil), do: id_payload(path)
  defp compute_payload(:post, path, body) when body == %{}, do: id_payload(path)
  defp compute_payload(_method, _path, body) when is_map(body), do: Jason.encode!(body)
  defp compute_payload(_method, _path, nil), do: "{}"

  defp id_payload(path) do
    case extract_resource_id(path) do
      nil -> "{}"
      id -> ~s({"id":"#{id}"})
    end
  end

  defp extract_resource_id(path) do
    parts =
      path
      |> String.trim()
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))

    case parts do
      [] ->
        nil

      [_single] ->
        nil

      parts ->
        last = List.last(parts)
        second_to_last = Enum.at(parts, -2)

        if last in @action_segments do
          second_to_last
        else
          last
        end
    end
  end

  defp sign(secret, payload) do
    encoded_payload = Base.encode64(payload)

    :crypto.mac(:hmac, :sha256, secret, encoded_payload)
    |> Base.encode16(case: :lower)
  end

  defp auth_headers(account_id, signature) do
    %{
      "X-ACCT-ID" => account_id,
      "X-PAYLOAD-SIG" => signature,
      "Content-Type" => "application/json",
      "User-Agent" => "accessgrid-ex/#{version()}"
    }
  end

  defp version do
    Application.spec(:accessgrid, :vsn) |> to_string()
  end

  defp build_url(host, path) do
    host = String.trim_trailing(host, "/")
    path = if String.starts_with?(path, "/"), do: path, else: "/" <> path
    host <> path
  end

  # Whether the HTTP body is effectively empty for signature-verification purposes.
  # When true, the server falls back to verifying `sig_payload` from the query string
  # (see `Api::ApiController#valid_payload_signature?`), so the client must
  # include `sig_payload` in the request params. Covers GET (no body), DELETE
  # (no body), and POST/PUT/PATCH with nil or empty-map bodies.
  defp body_empty?(nil), do: true
  defp body_empty?(body) when body == %{}, do: true
  defp body_empty?(_), do: false

  defp validate_required!(key, nil) do
    raise ArgumentError, "#{key} is required"
  end

  defp validate_required!(_key, _value), do: :ok
end
