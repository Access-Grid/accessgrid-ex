defmodule AccessGrid.SmartTapReveal do
  @moduledoc """
  Response from `AccessGrid.Console.reveal_smart_tap/2` — the SmartTap
  credentials for a card template.

  `private_key` is the plaintext PEM, decrypted client-side by the SDK.
  `key_version`, `collector_id`, and `fingerprint` are the server's response
  metadata (template id, Google Wallet SmartTap merchant id, SHA-256 of the
  caller's pubkey).
  """

  @type t :: %__MODULE__{
          key_version: String.t() | nil,
          collector_id: String.t() | nil,
          fingerprint: String.t() | nil,
          private_key: binary() | nil
        }

  defstruct [
    :key_version,
    :collector_id,
    :fingerprint,
    :private_key
  ]

  @doc """
  Builds a SmartTapReveal struct from the metadata fields of an API response.
  `private_key` is left `nil` and filled in by
  `AccessGrid.Console.reveal_smart_tap/2` after the envelope is decrypted.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      key_version: data["key_version"],
      collector_id: data["collector_id"],
      fingerprint: data["fingerprint"]
    }
  end
end
