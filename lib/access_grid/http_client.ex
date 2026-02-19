defmodule AccessGrid.HttpClient do
  @moduledoc """
  HTTP client dispatcher.

  Delegates to the configured HTTP client implementation (default: `AccessGrid.HttpClient.Req`).
  The implementation can be configured via application config or overridden per-process
  using Gestalt for testing.
  """

  alias AccessGrid.HttpFailure
  alias AccessGrid.HttpResponse

  @doc """
  Performs an HTTP DELETE request.
  """
  @spec delete(String.t(), map()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}
  def delete(url, opts \\ %{}), do: client().delete(url, opts)

  @doc """
  Performs an HTTP GET request.
  """
  @spec get(String.t(), map()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}
  def get(url, opts \\ %{}), do: client().get(url, opts)

  @doc """
  Performs an HTTP HEAD request.
  """
  @spec head(String.t(), map()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}
  def head(url, opts \\ %{}), do: client().head(url, opts)

  @doc """
  Performs an HTTP PATCH request.
  """
  @spec patch(String.t(), map()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}
  def patch(url, opts \\ %{}), do: client().patch(url, opts)

  @doc """
  Performs an HTTP POST request.
  """
  @spec post(String.t(), map()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}
  def post(url, opts \\ %{}), do: client().post(url, opts)

  @doc """
  Performs an HTTP PUT request.
  """
  @spec put(String.t(), map()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}
  def put(url, opts \\ %{}), do: client().put(url, opts)

  defp client do
    Gestalt.get_config(:accessgrid, :http_client, self())
  end
end
