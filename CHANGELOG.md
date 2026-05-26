# Changelog

## 0.2.0 — 2026-05-25

### Changed (breaking)

- **`AccessGrid.Console.reveal_smart_tap/3` → `/2`.** The function now generates the ephemeral P-256 keypair internally, submits the public half, decrypts the server's envelope, and returns the plaintext SmartTap key on `%SmartTapReveal{private_key: pem}`. Callers no longer pass `%{client_public_key: pem}` — the second arg is now just `opts`. Reveal-and-decrypt is a single line.
- **`%AccessGrid.SmartTapReveal{}` reshaped** to `{key_version, collector_id, fingerprint, private_key}`. `:private_key` is the decrypted PEM (what callers want); the encrypted envelope is consumed internally and no longer exposed. Matches the C# SDK's `RevealTemplatePrivateKeyResponse` shape.
- `AccessGrid.SmartTap` module is internal (`@moduledoc false`) — crypto driven by `Console.reveal_smart_tap/2`, not part of the public API. Erlang stdlib (`:public_key` + `:crypto`) only; no new runtime dependencies.

Migration:

```elixir
# Before (0.1.0)
{ec_priv, pub_pem} = generate_keypair_somehow()
{:ok, reveal} = AccessGrid.Console.reveal_smart_tap(id, %{client_public_key: pub_pem})
# caller decrypts reveal.encrypted_private_key themselves

# After (0.2.0)
{:ok, reveal} = AccessGrid.Console.reveal_smart_tap(id)
reveal.private_key  # plaintext PEM
```

### Fixed

- `AccessGrid.Console.create_template/2` docstring and module example used `use_case: "employee_badge"`, which is not a valid enum value and returned 422 from the API. Replaced with `"corporate_id"` and enumerated the supported values.
- README reveal example shelled out to `openssl ec -in priv.pem -pubout` against a `priv.pem` that callers had to produce out-of-band, then waved at decryption with "Decrypt with your matching private key." Replaced with the single-line `Console.reveal_smart_tap/2` that returns the decrypted PEM directly.

## 0.1.0 — 2026-05-20

Initial release.

### Modules

- `AccessGrid.Client` — HMAC-SHA256 request signing, Gestalt-based config, configurable `:api_host`. Empty-body methods (GET, DELETE, POST/PUT/PATCH with nil or `%{}` body) automatically send `sig_payload` in the query so the server can verify the signature.
- `AccessGrid.AccessPasses` — operations against `/v1/key-cards`: `issue`, `get`, `update`, `list`, `suspend`, `resume`, `unlink`, `delete`. Returns `%AccessGrid.AccessPass{}`.
- `AccessGrid.Console` — operations against `/v1/console/*`:
  - card templates: `create_template`, `update_template`, `read_template` (returns `%CardTemplate{}` for singles and `%CardTemplatePair{}` for pairs via `is_pair` discriminator), `get_logs`, `ios_preflight`, `publish_template`, `reveal_smart_tap`
  - card template pairs: `list_card_template_pairs`, `create_card_template_pair`
  - landing pages: `list_landing_pages`, `create_landing_page`, `update_landing_page`
  - credential profiles: `list_credential_profiles`, `create_credential_profile`
  - webhooks: `list_webhooks`, `create_webhook`, `delete_webhook`
  - HID orgs: `list_hid_orgs`, `create_hid_org`, `activate_hid_org`
  - ledger items: `list_ledger_items`
- HTTP client abstraction with pluggable implementations (`AccessGrid.HttpClient.Req`).
- Structured error handling with semantic reason atoms (`:unauthorized`, `:not_found`, `:validation_failed`, `:rate_limited`, `:timeout`, `:server_error`, `:request_failed`).

### Structs

- `AccessGrid.AccessPass` — credential issued to an end user
- `AccessGrid.CardTemplate` (+ `.Result`, `.Summary`) — card template configuration
- `AccessGrid.CardTemplatePair` (+ `.Summary`) — paired iOS+Android template
- `AccessGrid.LedgerItem` (+ `.AccessPass`, `.CardTemplate`) — billing ledger line
- `AccessGrid.SmartTapReveal` — encrypted SmartTap credential envelope
- `AccessGrid.CredentialProfile`, `AccessGrid.LandingPage`, `AccessGrid.Webhook`, `AccessGrid.HidOrg`, `AccessGrid.IosPreflight`, `AccessGrid.Event`
