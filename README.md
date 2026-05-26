# ![AccessGrid Logo](https://github.com/Access-Grid/accessgrid-ex/raw/main/accessgrid.png)

AccessGrid is an Elixir SDK for interacting with the [AccessGrid.com](https://www.accessgrid.com) API. This SDK provides a simple interface for managing NFC key cards, card templates, landing pages, credential profiles, webhooks, HID Origo organizations, and ledger items. Full docs at https://www.accessgrid.com/docs.

## Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [Access passes](#access-passes)
  - [Card templates](#card-templates)
  - [Card template pairs](#card-template-pairs)
  - [Landing pages](#landing-pages)
  - [Credential profiles](#credential-profiles)
  - [Webhooks](#webhooks)
  - [HID orgs](#hid-orgs)
  - [Ledger items](#ledger-items)
- [Utilities](#utilities)
- [Error Handling](#error-handling)
- [Testing](#testing)
- [Security](#security)
- [Contributing](#contributing)
- [Development](#development)
- [License](#license)

## Installation

Add `accessgrid` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:accessgrid, "~> 0.1.0"}
  ]
end
```

## Configuration

The SDK reads credentials from your application config. Add them in `config/runtime.exs` so environment variables are picked up at boot:

```elixir
# config/runtime.exs
import Config

config :accessgrid,
  account_id: System.get_env("ACCESSGRID_ACCOUNT_ID"),
  api_secret: System.get_env("ACCESSGRID_API_SECRET")
```

For static values (set at compile time) use `config/config.exs` instead. Either file works — the SDK doesn't care where the config came from.

With credentials in config, every SDK call resolves them automatically:

```elixir
{:ok, card} = AccessGrid.AccessPasses.get("card_id")
```

This is the default path for single-tenant apps.

### Using a custom client

For multi-tenant scenarios, testing, or scripted operations against multiple accounts, pass credentials explicitly via `AccessGrid.Client.new/1`:

```elixir
client = AccessGrid.Client.new(
  account_id: "your_account_id",
  api_secret: "your_api_secret"
)

{:ok, card} = AccessGrid.AccessPasses.get("card_id", client: client)
```

Every SDK function accepts `client:` as an option; when omitted, it falls back to the project config.

## Quick Start

```elixir
# Issue a new card
{:ok, card} = AccessGrid.AccessPasses.issue(%{
  card_template_id: "template_id",
  full_name: "Employee Name",
  email: "employee@company.com"
})

IO.puts("Install URL: #{card.install_url}")
```

## API Reference

### Access passes

#### Issue a new card

```elixir
{:ok, card} = AccessGrid.AccessPasses.issue(%{
  card_template_id: "template_id",
  employee_id: "123456789",
  card_number: "16187",
  site_code: "100",
  full_name: "Employee Name",
  email: "employee@yourwebsite.com",
  phone_number: "+19547212241",
  classification: "full_time",
  start_date: "2025-01-31T22:46:25.601Z",
  expiration_date: "2025-04-30T22:46:25.601Z",
  employee_photo: AccessGrid.Utils.base64_file!("path/to/photo.png"),
  metadata: %{department: "Engineering"}
})

IO.puts("Install URL: #{card.install_url}")
```

#### Get a card

```elixir
{:ok, card} = AccessGrid.AccessPasses.get("card_id")

IO.puts("Card ID: #{card.id}")
IO.puts("State: #{card.state}")
IO.puts("Full Name: #{card.full_name}")
IO.puts("Install URL: #{card.install_url}")
IO.puts("Expiration Date: #{card.expiration_date}")
IO.puts("Card Number: #{card.card_number}")
IO.puts("Site Code: #{card.site_code}")
IO.puts("Devices: #{length(card.devices)}")
IO.puts("Metadata: #{inspect(card.metadata)}")
```

#### Update a card

```elixir
{:ok, card} = AccessGrid.AccessPasses.update("card_id", %{
  employee_id: "987654321",
  full_name: "Updated Employee Name",
  classification: "contractor",
  expiration_date: "2025-02-22T21:04:03.664Z"
})
```

#### List cards

```elixir
# List all cards for a template
{:ok, cards} = AccessGrid.AccessPasses.list("template_id")

# List cards filtered by state
{:ok, active_cards} = AccessGrid.AccessPasses.list("template_id", state: "active")
```

#### Manage card states

```elixir
# Suspend a card
{:ok, card} = AccessGrid.AccessPasses.suspend("card_id")

# Resume a card
{:ok, card} = AccessGrid.AccessPasses.resume("card_id")

# Unlink a card
{:ok, card} = AccessGrid.AccessPasses.unlink("card_id")

# Delete a card
{:ok, card} = AccessGrid.AccessPasses.delete("card_id")
```

### Card templates

#### Create a template

All template fields are flat — no `design:` or `support_info:` wrappers. Pair image params with [`AccessGrid.Utils.base64_file!/1`](#encode-an-image-as-base64).

```elixir
{:ok, result} = AccessGrid.Console.create_template(%{
  name: "Employee NFC key",
  platform: "apple",
  use_case: "corporate_id",
  protocol: "desfire",
  allow_on_multiple_devices: true,
  watch_count: 2,
  iphone_count: 3,
  background_color: "#FFFFFF",
  label_color: "#000000",
  label_secondary_color: "#333333",
  background: AccessGrid.Utils.base64_file!("path/to/background.png"),
  logo: AccessGrid.Utils.base64_file!("path/to/logo.png"),
  icon: AccessGrid.Utils.base64_file!("path/to/icon.png"),
  support_url: "https://help.yourcompany.com",
  support_phone_number: "+1-555-123-4567",
  support_email: "support@yourcompany.com",
  privacy_policy_url: "https://yourcompany.com/privacy",
  terms_and_conditions_url: "https://yourcompany.com/terms",
  credential_profiles: ["cp_ex_id_1"],
  landing_pages: ["lp_ex_id_1"],
  metadata: %{version: "1.0"}
})

IO.puts("Template ID: #{result.id}")
IO.puts("Estimated Publishing: #{result.estimated_publishing_date}")
```

#### Update a template

```elixir
{:ok, result} = AccessGrid.Console.update_template("template_id", %{
  name: "Updated Employee NFC key",
  watch_count: 3,
  support_url: "https://help.yourcompany.com",
  support_email: "newsupport@yourcompany.com"
})
```

#### Read a template

The same endpoint serves both single templates and template pairs. Pattern match on the returned struct to tell them apart.

```elixir
case AccessGrid.Console.read_template("template_id") do
  {:ok, %AccessGrid.CardTemplate{} = template} ->
    IO.puts("Name: #{template.name}")
    IO.puts("Platform: #{template.platform}")
    IO.puts("Background color: #{template.background_color}")
    IO.puts("Support email: #{template.support_email}")
    IO.puts("Watch count: #{template.watch_count}")
    IO.puts("Allow on multiple devices: #{template.allow_on_multiple_devices}")
    IO.puts("Issued keys: #{template.issued_keys_count}")
    IO.puts("Active keys: #{template.active_keys_count}")
    IO.puts("Credential profiles: #{inspect(template.credential_profiles)}")
    IO.puts("Landing pages: #{inspect(template.landing_pages)}")

  {:ok, %AccessGrid.CardTemplatePair{} = pair} ->
    IO.puts("Pair: #{pair.name}")
    Enum.each(pair.templates, fn t -> IO.puts(" - #{t.platform}: #{t.id}") end)
end
```

#### Get event logs

```elixir
{:ok, events, pagination} = AccessGrid.Console.get_logs("template_id",
  page: 1,
  per_page: 50,
  filters: %{
    device: "mobile",
    start_date: "2025-01-01T00:00:00Z",
    end_date: "2025-01-31T23:59:59Z",
    event_type: "access_pass.installed"
  }
)

Enum.each(events, fn event ->
  IO.puts("#{event.created_at}: #{event.event}")
end)

IO.puts("Page #{pagination["current_page"]} of #{pagination["total_pages"]}")
```

#### iOS preflight

Returns the Apple In-App Provisioning preflight bundle for an access pass.

```elixir
{:ok, preflight} = AccessGrid.Console.ios_preflight(
  "template_id",
  %{access_pass_ex_id: "ap_abc123"}
)

IO.puts("Provisioning credential: #{preflight.provisioning_credential_identifier}")
IO.puts("Sharing instance: #{preflight.sharing_instance_identifier}")
IO.puts("Card template: #{preflight.card_template_identifier}")
IO.puts("Environment: #{preflight.environment_identifier}")
```

#### Publish a template

For Android+SEOS templates, the server also syncs the template to the HID portal. If the sync fails the template rolls back to `draft` and the call returns `{:error, :validation_failed, _}`.

```elixir
{:ok, result} = AccessGrid.Console.publish_template("template_id")

IO.puts("Template #{result.id} status: #{result.status}")
# status is one of: "publishing" (already in flight), "in-review" (Apple
# queued), or "ready" (Android immediate)
```

#### Reveal SmartTap credentials

Fetches the template's SmartTap private key, decrypted client-side. The SDK generates a fresh ephemeral keypair internally, submits the public half, and decrypts the server's response — you get the plaintext PEM back without touching any crypto.

```elixir
{:ok, reveal} = AccessGrid.Console.reveal_smart_tap("template_id")

IO.puts("Key version:  #{reveal.key_version}")
IO.puts("Collector ID: #{reveal.collector_id}")
IO.puts("Fingerprint:  #{reveal.fingerprint}")
IO.puts(reveal.private_key)  # PEM — store in your reader/collector key vault
```

The server enforces single-use on pubkey fingerprint and rate-limits to 1 per minute per account. Retrying within the rate-limit window returns `{:error, :rate_limited, _}`.

### Card template pairs

#### List template pairs

```elixir
{:ok, pairs, pagination} = AccessGrid.Console.list_card_template_pairs(
  page: 1,
  per_page: 25
)

Enum.each(pairs, fn pair ->
  IO.puts("#{pair.name}: iOS=#{pair.ios_template.id}, Android=#{pair.android_template.id}")
end)
```

#### Create a template pair

Pairs two existing card templates (one Apple, one Android) for cross-platform issuance. Both templates must be `status: "ready"` and use a compatible protocol combination (both SEOS, or Apple-DESFire + Android-SmartTap).

```elixir
{:ok, pair} = AccessGrid.Console.create_card_template_pair(%{
  name: "Cross-Platform Employee Badge",
  apple_card_template_id: "tpl_apple_xyz",
  google_card_template_id: "tpl_android_xyz"
})

IO.puts("Pair ID: #{pair.id}")
```

### Landing pages

#### List landing pages

```elixir
{:ok, pages} = AccessGrid.Console.list_landing_pages()

Enum.each(pages, fn page -> IO.puts("#{page.id}: #{page.name} (#{page.kind})") end)
```

#### Create a landing page

```elixir
{:ok, page} = AccessGrid.Console.create_landing_page(%{
  name: "Lobby Access",
  kind: "universal",
  additional_text: "Welcome — install your pass on your phone",
  bg_color: "#1a1a1a",
  allow_immediate_download: true,
  logo: AccessGrid.Utils.base64_file!("path/to/logo.png")
})

IO.puts("Landing page ID: #{page.id}")
IO.puts("Logo URL: #{page.logo_url}")
```

#### Update a landing page

`kind` is immutable after creation — passing a different value yields a `{:error, :validation_failed, _}`. Other fields can be updated freely.

```elixir
{:ok, page} = AccessGrid.Console.update_landing_page("lp_ex_id_1", %{
  name: "Lobby Access (renamed)",
  password: "letmein",
  is_2fa_enabled: true
})
```

### Credential profiles

#### List credential profiles

```elixir
{:ok, profiles} = AccessGrid.Console.list_credential_profiles()

Enum.each(profiles, fn p -> IO.puts("#{p.id}: #{p.name} (aid=#{p.aid})") end)
```

#### Create a credential profile

Each app has a fixed required key count: `KEY-ID-main` and `KEY-ID-alt` need 2 keys, `ag_main` needs 3. Passing the wrong number yields `{:error, :validation_failed, _}`.

```elixir
{:ok, profile} = AccessGrid.Console.create_credential_profile(%{
  name: "Office Reader",
  app_name: "KEY-ID-main",
  keys: [
    %{value: "00112233445566778899AABBCCDDEEFF"},
    %{value: "FFEEDDCCBBAA99887766554433221100", keys_diversified: true}
  ]
})

IO.puts("Profile ID: #{profile.id}")
IO.puts("AID: #{profile.aid}")
IO.inspect(profile.keys, label: "keys")
IO.inspect(profile.files, label: "files")
```

### Webhooks

#### List webhooks

```elixir
{:ok, webhooks, pagination} = AccessGrid.Console.list_webhooks(page: 1, per_page: 50)

Enum.each(webhooks, fn wh ->
  IO.puts("#{wh.id}: #{wh.name} (#{wh.auth_method}) → #{wh.url}")
end)
```

#### Create a webhook

`auth_method` is either `"bearer_token"` (default) or `"mtls"`. Sensitive fields appear on the create response **only once**:

- **bearer_token:** `private_key` is returned — store it immediately, it cannot be retrieved later.
- **mtls:** `client_cert` (PEM) and `cert_expires_at` are returned.

```elixir
{:ok, webhook} = AccessGrid.Console.create_webhook(%{
  name: "Production",
  url: "https://example.com/hooks",
  subscribed_events: ["ag.access_pass.issued", "ag.card_template.created"],
  auth_method: "bearer_token"
})

IO.puts("Webhook ID: #{webhook.id}")
IO.puts("Private key (store now — not retrievable later): #{webhook.private_key}")
```

#### Delete a webhook

Returns `:ok` (flat, not `{:ok, _}`) on success since the server returns 204 No Content.

```elixir
:ok = AccessGrid.Console.delete_webhook("webhook_id")
```

### HID orgs

#### List HID orgs

```elixir
{:ok, orgs} = AccessGrid.Console.list_hid_orgs()

Enum.each(orgs, fn org -> IO.puts("#{org.id}: #{org.name} (status=#{org.status})") end)
```

#### Create a HID org

Idempotent on the derived `slug` — if an org with the same slug already exists, the server returns the existing record with 200 instead of creating a new one.

```elixir
{:ok, org} = AccessGrid.Console.create_hid_org(%{
  name: "Acme Corp",
  full_address: "1 Acme Plaza, NY 10001",
  phone: "+1-555-0100",
  first_name: "Wile E.",
  last_name: "Coyote"
})

IO.puts("HID org ID: #{org.id}")
IO.puts("Slug: #{org.slug}")
```

#### Activate a HID org

Completes registration with the HID portal using the org's registered email and the customer's HID portal password.

```elixir
{:ok, org} = AccessGrid.Console.activate_hid_org(%{
  email: "admin@acme.com",
  password: "hid-portal-password"
})

IO.puts("Status: #{org.status}")
```

The server may return extra fields (`already_completed: true` if the org is already activated, `job_queued: true` if a registration job is in flight) — these aren't surfaced on the struct. Inspect `org.status` for the current state.

### Ledger items

#### List ledger items

```elixir
{:ok, items, pagination} = AccessGrid.Console.list_ledger_items(
  page: 1,
  per_page: 50,
  start_date: "2026-01-01T00:00:00Z",
  end_date: "2026-12-31T23:59:59Z"
)

Enum.each(items, fn item ->
  IO.puts("#{item.created_at}: #{item.kind} $#{item.amount}")
  if item.access_pass, do: IO.puts("  pass: #{item.access_pass.full_name}")
end)
```

## Utilities

### Encode an image as base64

`AccessGrid.Utils.base64_file!/1` reads a file from the local filesystem and returns its contents Base64-encoded as a string — suitable for any of the SDK's image-accepting params (`background`, `logo`, `icon` on `create_template`; `logo` on `create_landing_page`; `employee_photo` on `AccessPasses.issue`).

```elixir
# Bang variant — raises File.Error if the path doesn't exist
b64 = AccessGrid.Utils.base64_file!("path/to/badge.png")

# Tuple variant — returns {:ok, encoded} or {:error, posix_reason}
case AccessGrid.Utils.base64_file("path/to/badge.png") do
  {:ok, b64} -> # ...
  {:error, :enoent} -> # file missing
end
```

The helper does not validate the file's contents — the server enforces format and size limits (PNG/JPEG, 10MB max) and returns clear errors. No URL support: if you have an image at a URL, fetch it with your own HTTP client and `Base.encode64/1` the bytes.

## Error Handling

All functions return `{:ok, result}` (or `{:ok, list, pagination}` for paginated lists, or `:ok` for `delete_webhook`) on success, or `{:error, reason, failure}` on failure:

```elixir
case AccessGrid.AccessPasses.get("card_id") do
  {:ok, card} ->
    IO.puts("Found card: #{card.full_name}")

  {:error, :not_found, _failure} ->
    IO.puts("Card not found")

  {:error, :unauthorized, _failure} ->
    IO.puts("Invalid credentials")

  {:error, :validation_failed, failure} ->
    IO.puts("Validation error: #{inspect(failure.body_decoded)}")

  {:error, reason, _failure} ->
    IO.puts("Request failed: #{reason}")
end
```

Error reasons include:
- `:unauthorized` - Invalid credentials (401)
- `:forbidden` - Access denied (403)
- `:not_found` - Resource not found (404)
- `:conflict` - Conflict with current resource state (409) — e.g. `reveal_smart_tap` retried with a pubkey that's already been used
- `:validation_failed` - Invalid parameters (422)
- `:rate_limited` - Too many requests (429)
- `:timeout` - Request timeout
- `:server_error` - Server error (5xx)
- `:request_failed` - Other failures
- `:missing_required` - Local validation caught a missing/blank required field before any HTTP call. The third element is a non-empty list of atom field names (e.g. `[:template_id, :access_pass_ex_id]`) — not an `HttpFailure`. See `AccessGrid.Params`.

The third element (`failure`) is an `AccessGrid.HttpFailure` struct with additional context like status code and response body, except for `:missing_required` (see above — that variant carries a list of field-name atoms instead).

## Testing

See the [Testing Guide](guides/testing.md) for detailed examples of how to mock AccessGrid in your tests.

## Security

The SDK automatically handles:
- Request signing using HMAC-SHA256
- Secure payload encoding
- Authentication headers
- HTTPS communication

Never expose your `api_secret` in client-side code. Always use environment variables or a secure configuration management system.

## Contributing

Bug reports and pull requests are welcome on GitHub.

## Development

### Requirements

- Elixir 1.17 or higher
- OTP 26 or higher

> Note: A `.tool-versions` file exists. `asdf` users can install these requirements with `asdf install` from the project root.

### Initial setup

After checking out the repo, run the doctor script to verify your environment:

```bash
bin/dev/doctor
```

Run tests:

```bash
mix test
```

Run all checks (format, credo, dialyzer):

```bash
bin/dev/audit
```

## License

The package is available as open source under the terms of the [MIT License](LICENSE).
