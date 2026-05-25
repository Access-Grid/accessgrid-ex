defmodule AccessGrid.SmartTapTest do
  use ExUnit.Case, async: true

  alias AccessGrid.SmartTap

  # Captured test vector: a real envelope produced by the server against a
  # sentinel `smart_tap_key` value. Lets us verify the SDK's decrypt is
  # wire-compatible with the server without reproducing the server's encrypt
  # in test code.
  #
  # The caller_private_key is ephemeral and single-use by design (the server
  # rejects reuse on pubkey fingerprint), so committing it carries no
  # credential risk.
  @fixture_caller_private_key_pem """
  -----BEGIN EC PRIVATE KEY-----
  MHcCAQEEIIou+Kk08kWAjhi0WyIx+L2GrgStGBCPODlwKYKd5BydoAoGCCqGSM49
  AwEHoUQDQgAE+gnDxXJt1SBaCK8roKH8QvOa/ItdQUe85JIsUc6RvhD/udLaFtHY
  m+MnOmeSdVaKTPWudH0+iGbleB3kS7lYxQ==
  -----END EC PRIVATE KEY-----
  """

  @fixture_envelope %{
    "alg" => "ECDH-ES+A256GCM",
    "ciphertext" => "ckYyA3FdRYjOFI/FKz/QeR5Yf9nZZFzo73kDXKZSB/EgbQ==",
    "ephemeral_public_key" =>
      "-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE7mg6i99GcIVutMPr/PXSBSQVlbLM\ntnJO10ZBjk9ZTfw6wwAVNBnDBiqY7VrdOG1JdFOYoac+NkAlyMRGYk2tVQ==\n-----END PUBLIC KEY-----\n",
    "iv" => "5X2OCht+kLB/xQmX",
    "tag" => "0vwkjVaCwi5zl37xvJPxeg=="
  }

  @fixture_expected_plaintext "FIXTURE-PLAINTEXT-NOT-A-CREDENTIAL"

  defp fixture_caller_private_key do
    [pem_entry] = :public_key.pem_decode(@fixture_caller_private_key_pem)
    :public_key.pem_entry_decode(pem_entry)
  end

  describe "decrypt_envelope/2" do
    test "decrypts the captured server-produced envelope" do
      assert {:ok, plaintext} =
               SmartTap.decrypt_envelope(@fixture_envelope, fixture_caller_private_key())

      assert plaintext == @fixture_expected_plaintext
    end

    test "{:error, :decrypt_failed} when the auth tag is tampered" do
      <<first, rest::binary>> = Base.decode64!(@fixture_envelope["tag"])
      tampered_tag = Base.encode64(<<Bitwise.bxor(first, 1)>> <> rest)
      tampered = Map.put(@fixture_envelope, "tag", tampered_tag)

      assert {:error, :decrypt_failed} =
               SmartTap.decrypt_envelope(tampered, fixture_caller_private_key())
    end

    test "{:error, :decrypt_failed} when a different private key is used" do
      wrong_priv = :public_key.generate_key({:namedCurve, :secp256r1})

      assert {:error, :decrypt_failed} =
               SmartTap.decrypt_envelope(@fixture_envelope, wrong_priv)
    end

    test "{:error, :invalid_envelope} when ephemeral_public_key is missing" do
      bad = Map.delete(@fixture_envelope, "ephemeral_public_key")

      assert {:error, :invalid_envelope} =
               SmartTap.decrypt_envelope(bad, fixture_caller_private_key())
    end

    test "{:error, :invalid_envelope} when iv is not base64" do
      bad = Map.put(@fixture_envelope, "iv", "not!base64!")

      assert {:error, :invalid_envelope} =
               SmartTap.decrypt_envelope(bad, fixture_caller_private_key())
    end

    test "{:error, :invalid_envelope} when envelope is not a map" do
      assert {:error, :invalid_envelope} =
               SmartTap.decrypt_envelope(:nope, fixture_caller_private_key())
    end
  end

  describe "generate_keypair/0" do
    test "returns an ECPrivateKey record and a SubjectPublicKeyInfo PEM" do
      {ec_priv, pub_pem} = SmartTap.generate_keypair()

      assert match?({:ECPrivateKey, _, _, _, _, _}, ec_priv)
      assert pub_pem =~ "-----BEGIN PUBLIC KEY-----"
      assert pub_pem =~ "-----END PUBLIC KEY-----"
    end

    test "each call returns a distinct keypair" do
      {priv_a, pub_a} = SmartTap.generate_keypair()
      {priv_b, pub_b} = SmartTap.generate_keypair()

      refute priv_a == priv_b
      refute pub_a == pub_b
    end
  end
end
