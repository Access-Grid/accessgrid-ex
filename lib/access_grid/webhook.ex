defmodule AccessGrid.Webhook do
  @moduledoc """
  Webhook subscription that receives event notifications. Returned by
  `AccessGrid.Console.list_webhooks/1` and `AccessGrid.Console.create_webhook/2`.

  Auth-method-specific fields appear only when applicable:

    * `private_key` is returned ONLY on `auth_method: "bearer_token"` creation
      (sensitive; store on receipt — Rails does not return it again).
    * `client_cert` and `cert_expires_at` are returned on `auth_method: "mtls"`.

  Unused fields are `nil` on the struct.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          url: String.t() | nil,
          auth_method: String.t() | nil,
          created_at: String.t() | nil,
          subscribed_events: [String.t()],
          private_key: String.t() | nil,
          client_cert: String.t() | nil,
          cert_expires_at: String.t() | nil
        }

  defstruct [
    :id,
    :name,
    :url,
    :auth_method,
    :created_at,
    :private_key,
    :client_cert,
    :cert_expires_at,
    subscribed_events: []
  ]

  @doc """
  Creates a Webhook struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      url: data["url"],
      auth_method: data["auth_method"],
      created_at: data["created_at"],
      subscribed_events: data["subscribed_events"] || [],
      private_key: data["private_key"],
      client_cert: data["client_cert"],
      cert_expires_at: data["cert_expires_at"]
    }
  end
end
