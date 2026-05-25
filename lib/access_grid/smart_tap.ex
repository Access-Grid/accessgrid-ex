defmodule AccessGrid.SmartTap do
  @moduledoc false

  # Internal crypto helpers for the SmartTap reveal flow. Driven by
  # `AccessGrid.Console.reveal_smart_tap/2`; not part of the public API.

  # Must match the server-side encryption parameters.
  @hkdf_info "accessgrid-smart-tap-reveal-v1"
  @curve :secp256r1

  @type ec_private_key :: tuple()
  @type envelope :: %{optional(String.t()) => String.t()}

  @doc false
  @spec generate_keypair() :: {ec_private_key(), binary()}
  def generate_keypair do
    ec_priv = :public_key.generate_key({:namedCurve, @curve})
    {:ECPrivateKey, _v, _scalar, params, pub_point, _attrs} = ec_priv

    pub_pem =
      :public_key.pem_encode([
        :public_key.pem_entry_encode(:SubjectPublicKeyInfo, {{:ECPoint, pub_point}, params})
      ])

    {ec_priv, pub_pem}
  end

  @doc false
  @spec decrypt_envelope(envelope(), ec_private_key()) ::
          {:ok, binary()} | {:error, :decrypt_failed | :invalid_envelope}
  def decrypt_envelope(envelope, ec_priv) when is_map(envelope) and is_tuple(ec_priv) do
    with {:ok, server_point} <- parse_ephemeral_pubkey(envelope),
         {:ok, iv} <- decode64(envelope, "iv"),
         {:ok, ciphertext} <- decode64(envelope, "ciphertext"),
         {:ok, tag} <- decode64(envelope, "tag"),
         {:ok, my_priv_scalar} <- extract_private_scalar(ec_priv) do
      shared_secret = :crypto.compute_key(:ecdh, server_point, my_priv_scalar, @curve)
      aes_key = derive_aes_key(shared_secret)

      case :crypto.crypto_one_time_aead(:aes_256_gcm, aes_key, iv, ciphertext, "", tag, false) do
        plaintext when is_binary(plaintext) -> {:ok, plaintext}
        :error -> {:error, :decrypt_failed}
      end
    end
  end

  def decrypt_envelope(_envelope, _ec_priv), do: {:error, :invalid_envelope}

  defp parse_ephemeral_pubkey(envelope) do
    with pem when is_binary(pem) <- Map.get(envelope, "ephemeral_public_key"),
         [entry | _] <- safe_pem_decode(pem),
         {{:ECPoint, point}, _params} <- safe_pem_entry_decode(entry) do
      {:ok, point}
    else
      _ -> {:error, :invalid_envelope}
    end
  end

  defp safe_pem_decode(pem) do
    :public_key.pem_decode(pem)
  rescue
    _ -> []
  end

  defp safe_pem_entry_decode(entry) do
    :public_key.pem_entry_decode(entry)
  rescue
    _ -> :error
  end

  defp decode64(envelope, key) do
    case Map.get(envelope, key) do
      val when is_binary(val) ->
        case Base.decode64(val) do
          {:ok, bin} -> {:ok, bin}
          :error -> {:error, :invalid_envelope}
        end

      _ ->
        {:error, :invalid_envelope}
    end
  end

  defp extract_private_scalar({:ECPrivateKey, _v, scalar, _params, _pub, _attrs})
       when is_binary(scalar),
       do: {:ok, scalar}

  defp extract_private_scalar(_), do: {:error, :invalid_envelope}

  # HKDF-SHA256: empty salt, single-block expand (32-byte output = one SHA-256 block);
  # must match the server-side derivation.
  defp derive_aes_key(shared_secret) do
    prk = :crypto.mac(:hmac, :sha256, "", shared_secret)
    :crypto.mac(:hmac, :sha256, prk, @hkdf_info <> <<1>>)
  end
end
