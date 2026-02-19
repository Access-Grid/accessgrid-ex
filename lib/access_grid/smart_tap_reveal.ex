defmodule AccessGrid.SmartTapReveal do
  @moduledoc """
  Response from `AccessGrid.Console.reveal_smart_tap/3` — the Smart Tap
  credentials for a card template, encrypted with the caller's ephemeral public
  key.

  The caller decrypts `encrypted_private_key` using their corresponding private
  key (out-of-scope for this SDK — Smart Tap decryption is the caller's
  responsibility).

  `encrypted_private_key` is exposed as a raw map (string keys) — it's an
  encryption envelope, not a first-class entity. Expected keys:

    * `"alg"` — encryption algorithm identifier
    * `"ephemeral_public_key"` — server-side ephemeral key for ECDH
    * `"iv"` — initialization vector
    * `"ciphertext"` — encrypted Smart Tap private key
    * `"tag"` — authentication tag
  """

  @type t :: %__MODULE__{
          key_version: String.t() | nil,
          collector_id: String.t() | nil,
          fingerprint: String.t() | nil,
          encrypted_private_key: map() | nil
        }

  defstruct [
    :key_version,
    :collector_id,
    :fingerprint,
    :encrypted_private_key
  ]

  @doc """
  Creates a SmartTapReveal struct from an API response map.
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
