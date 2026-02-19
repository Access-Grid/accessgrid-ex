defmodule AccessGrid.AccessPasses do
  @moduledoc """
  Manages access-pass lifecycle operations against `/v1/key-cards`.

  All functions accept an optional `:client` in opts. If not provided,
  credentials are loaded from application config via Gestalt.

  ## Examples

      # Using explicit client
      client = AccessGrid.Client.new(account_id: "...", api_secret: "...")
      AccessGrid.AccessPasses.issue(%{card_template_id: "tmpl_123"}, client: client)

      # Using config (client resolved automatically)
      AccessGrid.AccessPasses.get("card_abc123")

  """

  alias AccessGrid.AccessPass
  alias AccessGrid.Client
  alias AccessGrid.HttpFailure
  alias AccessGrid.HttpResponse
  alias AccessGrid.Params
  alias AccessGrid.Types

  @base_path "/v1/key-cards"

  @type result :: {:ok, AccessPass.t()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type list_result :: {:ok, [AccessPass.t()]} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}

  @doc """
  Issues a new key card.

  ## Parameters

    * `params` - Map with card parameters (card_template_id, full_name, etc.)
    * `opts` - Options including `:client`

  ## Examples

      AccessGrid.AccessPasses.issue(%{
        card_template_id: "tmpl_123",
        full_name: "John Doe"
      })

  """
  @spec issue(map(), keyword()) :: result()
  def issue(params, opts \\ []) do
    with :ok <- Params.require(params, [:card_template_id]) do
      opts[:client]
      |> Client.request(:post, @base_path, body: params)
      |> handle_response()
    end
  end

  @doc """
  Retrieves a key card by ID.

  ## Examples

      AccessGrid.AccessPasses.get("card_abc123")

  """
  @spec get(String.t(), keyword()) :: result()
  def get(card_id, opts \\ []) do
    with :ok <- Params.require_present(card_id, :card_id) do
      opts[:client]
      |> Client.request(:get, "#{@base_path}/#{card_id}")
      |> handle_response()
    end
  end

  @doc """
  Updates a key card.

  ## Examples

      AccessGrid.AccessPasses.update("card_abc123", %{full_name: "New Name"})

  """
  @spec update(String.t(), map(), keyword()) :: result()
  def update(card_id, params, opts \\ []) do
    with :ok <- Params.require_present(card_id, :card_id) do
      opts[:client]
      |> Client.request(:patch, "#{@base_path}/#{card_id}", body: params)
      |> handle_response()
    end
  end

  @doc """
  Lists key cards for a template.

  ## Options

    * `:state` - Filter by card state (e.g., "active", "suspended")
    * `:client` - Client for authentication

  ## Examples

      AccessGrid.AccessPasses.list("tmpl_123")
      AccessGrid.AccessPasses.list("tmpl_123", state: "active")

  """
  @spec list(String.t(), keyword()) :: list_result()
  def list(template_id, opts \\ []) do
    with :ok <- Params.require_present(template_id, :template_id) do
      params =
        %{"template_id" => template_id}
        |> maybe_add_param("state", opts[:state])

      opts[:client]
      |> Client.request(:get, @base_path, params: params)
      |> handle_list_response()
    end
  end

  @doc """
  Suspends a key card.

  ## Examples

      AccessGrid.AccessPasses.suspend("card_abc123")

  """
  @spec suspend(String.t(), keyword()) :: result()
  def suspend(card_id, opts \\ []), do: manage_state(card_id, "suspend", opts)

  @doc """
  Resumes a suspended key card.

  ## Examples

      AccessGrid.AccessPasses.resume("card_abc123")

  """
  @spec resume(String.t(), keyword()) :: result()
  def resume(card_id, opts \\ []), do: manage_state(card_id, "resume", opts)

  @doc """
  Unlinks a key card from its device.

  ## Examples

      AccessGrid.AccessPasses.unlink("card_abc123")

  """
  @spec unlink(String.t(), keyword()) :: result()
  def unlink(card_id, opts \\ []), do: manage_state(card_id, "unlink", opts)

  @doc """
  Deletes a key card.

  ## Examples

      AccessGrid.AccessPasses.delete("card_abc123")

  """
  @spec delete(String.t(), keyword()) :: result()
  def delete(card_id, opts \\ []), do: manage_state(card_id, "delete", opts)

  # --- Private helpers ---

  defp manage_state(card_id, action, opts) do
    with :ok <- Params.require_present(card_id, :card_id) do
      opts[:client]
      |> Client.request(:post, "#{@base_path}/#{card_id}/#{action}")
      |> handle_response()
    end
  end

  defp handle_response({:ok, %HttpResponse{body_decoded: body}}) do
    {:ok, AccessPass.from_response(body)}
  end

  defp handle_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_list_response({:ok, %HttpResponse{body_decoded: body}}) do
    cards =
      body
      |> Map.get("keys", [])
      |> Enum.map(&AccessPass.from_response/1)

    {:ok, cards}
  end

  defp handle_list_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp reason_from_failure(%HttpFailure{reason: :unauthorized}), do: :unauthorized
  defp reason_from_failure(%HttpFailure{reason: :forbidden}), do: :forbidden
  defp reason_from_failure(%HttpFailure{reason: :not_found}), do: :not_found
  defp reason_from_failure(%HttpFailure{reason: :unprocessable_entity}), do: :validation_failed
  defp reason_from_failure(%HttpFailure{reason: :too_many_requests}), do: :rate_limited
  defp reason_from_failure(%HttpFailure{reason: :timeout}), do: :timeout

  defp reason_from_failure(%HttpFailure{reason: reason})
       when reason in [:internal_server_error, :bad_gateway, :service_unavailable, :gateway_timeout, :server_error],
       do: :server_error

  defp reason_from_failure(%HttpFailure{}), do: :request_failed

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: Map.put(params, key, value)
end
