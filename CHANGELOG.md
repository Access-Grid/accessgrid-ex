# Changelog

## 0.1.0 — 2026-05-20

Initial release.

### Modules

- `AccessGrid.Client` — HMAC-SHA256 request signing, Gestalt-based config, configurable `:api_host`. Empty-body methods (GET, DELETE, POST/PUT/PATCH with nil or `%{}` body) automatically send `sig_payload` in the query so Rails can verify the signature.
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
