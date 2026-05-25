defmodule AccessGrid.SmartTapReveal do
  @moduledoc """
  Response from `AccessGrid.Console.reveal_smart_tap/2` — the SmartTap
  credentials for a card template.

  `private_key` is the plaintext PEM, decrypted client-side by the SDK; this
  is what callers normally need. `encrypted_private_key` is the raw envelope
  the server returned, exposed as an escape hatch for callers who want to
  verify decryption themselves or re-decrypt later.
  """

  @type t :: %__MODULE__{
          key_version: String.t() | nil,
          collector_id: String.t() | nil,
          fingerprint: String.t() | nil,
          encrypted_private_key: map() | nil,
          private_key: binary() | nil
        }

  defstruct [
    :key_version,
    :collector_id,
    :fingerprint,
    :encrypted_private_key,
    :private_key
  ]

  @doc """
  Creates a SmartTapReveal struct from an API response map. `private_key`
  is left `nil` and filled in by `AccessGrid.Console.reveal_smart_tap/2`
  after the envelope is decrypted.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      key_version: data["key_version"],
      collector_id: data["collector_id"],
      fingerprint: data["fingerprint"],
      encrypted_private_key: data["encrypted_private_key"]
    }
  end
end
