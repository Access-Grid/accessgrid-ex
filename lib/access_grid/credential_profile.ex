defmodule AccessGrid.CredentialProfile do
  @moduledoc """
  Credential profile bound to a specific reader app (e.g. `"KEY-ID-main"`).
  Returned by `AccessGrid.Console.list_credential_profiles/1` and
  `AccessGrid.Console.create_credential_profile/2`.

  `keys` and `files` are kept as raw lists of maps with string keys, matching
  the SDK convention for embedded config blocks (see `Template.support_settings`).
  Each `keys` entry: `{ex_id, label, keys_diversified, source_key_index}`. Each
  `files` entry: `{ex_id, file_type, file_size, communication_settings,
  read_rights, write_rights, read_write_rights, change_rights}`.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          aid: String.t() | nil,
          name: String.t() | nil,
          apple_id: String.t() | nil,
          created_at: String.t() | nil,
          card_storage: String.t() | nil,
          keys: list(map()),
          files: list(map())
        }

  defstruct [
    :id,
    :aid,
    :name,
    :apple_id,
    :created_at,
    :card_storage,
    keys: [],
    files: []
  ]

  @doc """
  Creates a CredentialProfile struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      aid: data["aid"],
      name: data["name"],
      apple_id: data["apple_id"],
      created_at: data["created_at"],
      card_storage: data["card_storage"],
      keys: data["keys"] || [],
      files: data["files"] || []
    }
  end
end
