defmodule AccessGrid.HttpClient.Behaviour do
  @moduledoc """
  Behaviour for HTTP clients.

  Implementations must normalize responses to `AccessGrid.HttpResponse` and
  errors to `AccessGrid.HttpFailure`.
  """

  alias AccessGrid.HttpFailure
  alias AccessGrid.HttpResponse

  @type url :: String.t()

  @type request_opts :: %{
          optional(:headers) => [{String.t(), String.t()}],
          optional(:params) => %{optional(String.t()) => String.t()},
          optional(:timeout) => integer(),
          optional(:body) => term()
        }

  @doc """
  Performs an HTTP DELETE request.
  """
  @callback delete(url(), request_opts()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}

  @doc """
  Performs an HTTP GET request.
  """
  @callback get(url(), request_opts()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}

  @doc """
  Performs an HTTP HEAD request.
  """
  @callback head(url(), request_opts()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}

  @doc """
  Performs an HTTP PATCH request.
  """
  @callback patch(url(), request_opts()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}

  @doc """
  Performs an HTTP POST request.
  """
  @callback post(url(), request_opts()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}

  @doc """
  Performs an HTTP PUT request.
  """
  @callback put(url(), request_opts()) :: {:ok, HttpResponse.t()} | {:error, HttpFailure.t()}
end
