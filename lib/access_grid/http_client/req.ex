defmodule AccessGrid.HttpClient.Req do
  @moduledoc """
  HTTP client implementation using Req.
  """

  @behaviour AccessGrid.HttpClient.Behaviour

  alias AccessGrid.HttpFailure
  alias AccessGrid.HttpResponse

  @default_receive_timeout 30_000

  @doc """
  Callback implementation for `c:AccessGrid.HttpClient.Behaviour.delete/2`
  """
  @impl true
  def delete(url, opts \\ %{}) do
    url
    |> build_request(opts)
    |> Req.delete()
    |> handle_response()
  end

  @doc """
  Callback implementation for `c:AccessGrid.HttpClient.Behaviour.get/2`
  """
  @impl true
  def get(url, opts \\ %{}) do
    url
    |> build_request(opts)
    |> Req.get()
    |> handle_response()
  end

  @doc """
  Callback implementation for `c:AccessGrid.HttpClient.Behaviour.head/2`
  """
  @impl true
  def head(url, opts \\ %{}) do
    url
    |> build_request(opts)
    |> Req.head()
    |> handle_response()
  end

  @doc """
  Callback implementation for `c:AccessGrid.HttpClient.Behaviour.patch/2`
  """
  @impl true
  def patch(url, opts \\ %{}) do
    url
    |> build_request(opts)
    |> Req.patch()
    |> handle_response()
  end

  @doc """
  Callback implementation for `c:AccessGrid.HttpClient.Behaviour.post/2`
  """
  @impl true
  def post(url, opts \\ %{}) do
    url
    |> build_request(opts)
    |> Req.post()
    |> handle_response()
  end

  @doc """
  Callback implementation for `c:AccessGrid.HttpClient.Behaviour.put/2`
  """
  @impl true
  def put(url, opts \\ %{}) do
    url
    |> build_request(opts)
    |> Req.put()
    |> handle_response()
  end

  # # #

  defp build_request(url, opts) do
    req_opts =
      [url: url, decode_body: false, receive_timeout: @default_receive_timeout]
      |> maybe_add(:headers, opts[:headers])
      |> maybe_add(:params, opts[:params])
      |> maybe_add(:receive_timeout, opts[:timeout])
      |> maybe_add(:retry, opts[:retry])
      |> maybe_add(:redirect, opts[:redirect])
      |> add_body(opts[:body], opts[:body_format])
      |> maybe_add_test_plug()

    Req.new(req_opts)
  end

  defp maybe_add(req_opts, _key, nil), do: req_opts
  defp maybe_add(req_opts, key, value), do: Keyword.put(req_opts, key, value)

  # Hook for Req.Test (test env only). The :req_plug config is unset in dev/prod
  # so this is a no-op outside of tests. See config/test.exs.
  defp maybe_add_test_plug(req_opts) do
    case Application.get_env(:accessgrid, :req_plug) do
      nil -> req_opts
      plug -> Keyword.put(req_opts, :plug, plug)
    end
  end

  defp add_body(req_opts, nil, _format), do: req_opts
  defp add_body(req_opts, body, :raw), do: Keyword.put(req_opts, :body, body)
  defp add_body(req_opts, body, _format), do: Keyword.put(req_opts, :json, body)

  # # #

  defp handle_response({:ok, %Req.Response{status: status} = response})
       when status >= 200 and status < 300 do
    {:ok, build_http_response(response)}
  end

  defp handle_response({:ok, %Req.Response{} = response}) do
    {:error, build_http_failure_from_response(response)}
  end

  defp handle_response({:error, %Req.TransportError{reason: reason} = error}) do
    {:error,
     %HttpFailure{
       reason: reason,
       message: Exception.message(error),
       original: error
     }}
  end

  defp handle_response({:error, error}) do
    {:error,
     %HttpFailure{
       reason: :unknown,
       message: inspect(error),
       original: error
     }}
  end

  # # #

  defp build_http_response(%Req.Response{} = response) do
    %HttpResponse{
      body_decoded: decode_body(response.body, get_content_type(response)),
      body_raw: response.body,
      content_type: get_content_type(response),
      headers: normalize_headers(response.headers),
      status: response.status
    }
  end

  defp build_http_failure_from_response(%Req.Response{} = response) do
    content_type = get_content_type(response)

    %HttpFailure{
      body_decoded: decode_body(response.body, content_type),
      body_raw: response.body,
      content_type: content_type,
      message: nil,
      original: response,
      reason: status_to_reason(response.status),
      status: response.status
    }
  end

  # # #

  defp get_content_type(%Req.Response{headers: headers}) do
    case Map.get(headers, "content-type") do
      [content_type | _] -> content_type
      _ -> nil
    end
  end

  defp decode_body(body, content_type) when is_binary(body) do
    if json_content_type?(content_type) do
      case Jason.decode(body) do
        {:ok, decoded} -> decoded
        {:error, _} -> body
      end
    else
      body
    end
  end

  defp decode_body(body, _content_type), do: body

  defp json_content_type?(nil), do: false
  defp json_content_type?(content_type), do: String.contains?(content_type, "json")

  defp normalize_headers(headers) do
    Enum.flat_map(headers, fn {key, values} ->
      values
      |> List.wrap()
      |> Enum.map(&{key, &1})
    end)
  end

  # # #

  defp status_to_reason(301), do: :redirect
  defp status_to_reason(302), do: :redirect
  defp status_to_reason(303), do: :redirect
  defp status_to_reason(304), do: :not_modified
  defp status_to_reason(307), do: :redirect
  defp status_to_reason(308), do: :redirect
  defp status_to_reason(status) when status >= 300 and status < 400, do: :redirect

  defp status_to_reason(400), do: :bad_request
  defp status_to_reason(401), do: :unauthorized
  defp status_to_reason(403), do: :forbidden
  defp status_to_reason(404), do: :not_found
  defp status_to_reason(408), do: :request_timeout
  defp status_to_reason(409), do: :conflict
  defp status_to_reason(422), do: :unprocessable_entity
  defp status_to_reason(429), do: :too_many_requests
  defp status_to_reason(status) when status >= 400 and status < 500, do: :client_error

  defp status_to_reason(500), do: :internal_server_error
  defp status_to_reason(502), do: :bad_gateway
  defp status_to_reason(503), do: :service_unavailable
  defp status_to_reason(504), do: :gateway_timeout
  defp status_to_reason(status) when status >= 500 and status < 600, do: :server_error

  defp status_to_reason(_status), do: :unexpected_status
end
