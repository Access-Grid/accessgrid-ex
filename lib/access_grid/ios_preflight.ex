defmodule AccessGrid.IosPreflight do
  @moduledoc """
  Response from `AccessGrid.Console.ios_preflight/3` — the identifiers needed
  to drive Apple Wallet In-App Provisioning for a specific access pass.

  Rails returns these keys in camelCase (Apple convention, not the usual
  snake_case AccessGrid wire shape). This struct maps them to snake_case
  Elixir fields via `from_response/1`.
  """

  @type t :: %__MODULE__{
          provisioning_credential_identifier: String.t() | nil,
          sharing_instance_identifier: String.t() | nil,
          card_template_identifier: String.t() | nil,
          environment_identifier: String.t() | nil
        }

  defstruct [
    :provisioning_credential_identifier,
    :sharing_instance_identifier,
    :card_template_identifier,
    :environment_identifier
  ]

  @doc """
  Creates an IosPreflight struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      provisioning_credential_identifier: data["provisioningCredentialIdentifier"],
      sharing_instance_identifier: data["sharingInstanceIdentifier"],
      card_template_identifier: data["cardTemplateIdentifier"],
      environment_identifier: data["environmentIdentifier"]
    }
  end
end
