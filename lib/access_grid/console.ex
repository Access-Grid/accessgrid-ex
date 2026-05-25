defmodule AccessGrid.Console do
  @moduledoc """
  Manages enterprise template and logging operations.

  This module provides functions for card template management (create, update, read),
  retrieving activity logs, and listing template pairs. These are enterprise-only
  features requiring special account permissions.

  ## Examples

      # Create a new template
      {:ok, result} = AccessGrid.Console.create_template(%{
        name: "Employee Badge",
        platform: "apple",
        use_case: "employee_badge",
        protocol: "desfire"
      })

      # Read full template details
      {:ok, template} = AccessGrid.Console.read_template(result.id)

      # Get activity logs
      {:ok, logs, pagination} = AccessGrid.Console.get_logs(template.id)

  """

  alias AccessGrid.CardTemplate
  alias AccessGrid.CardTemplatePair
  alias AccessGrid.Client
  alias AccessGrid.CredentialProfile
  alias AccessGrid.Event
  alias AccessGrid.HidOrg
  alias AccessGrid.HttpFailure
  alias AccessGrid.HttpResponse
  alias AccessGrid.IosPreflight
  alias AccessGrid.LandingPage
  alias AccessGrid.LedgerItem
  alias AccessGrid.Params
  alias AccessGrid.SmartTap
  alias AccessGrid.SmartTapReveal
  alias AccessGrid.Types
  alias AccessGrid.Webhook

  @base_path "/v1/console"

  @type result :: {:ok, CardTemplate.Result.t()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type template_result ::
          {:ok, CardTemplate.t() | CardTemplatePair.t()}
          | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type logs_result ::
          {:ok, [Event.t()], map()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type pairs_result ::
          {:ok, [CardTemplatePair.Summary.t()], map()}
          | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type pair_summary_result ::
          {:ok, CardTemplatePair.Summary.t()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type ios_preflight_result ::
          {:ok, IosPreflight.t()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type landing_pages_result ::
          {:ok, [LandingPage.t()]} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type landing_page_result ::
          {:ok, LandingPage.t()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type credential_profiles_result ::
          {:ok, [CredentialProfile.t()]} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type credential_profile_result ::
          {:ok, CredentialProfile.t()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type webhooks_result ::
          {:ok, [Webhook.t()], map()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type webhook_result ::
          {:ok, Webhook.t()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type webhook_delete_result :: :ok | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type hid_orgs_result ::
          {:ok, [HidOrg.t()]} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type hid_org_result ::
          {:ok, HidOrg.t()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type ledger_items_result ::
          {:ok, [LedgerItem.t()], map()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type publish_result ::
          {:ok, CardTemplate.PublishResult.t()}
          | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}
  @type smart_tap_reveal_result ::
          {:ok, SmartTapReveal.t()} | {:error, Types.api_error_reason(), HttpFailure.t() | [atom(), ...]}

  @doc """
  Creates a new card template.

  Params are passed straight through to Rails — pass top-level keys using the
  exact wire names (no nested `design:` / `support_info:` wrappers). Image fields
  (`background`, `logo`, `icon`) accept base64-encoded strings; see
  `AccessGrid.Utils.base64_file/1` for a helper.

  ## Parameters

    * `params` - Template configuration:
      * `:name` - Display name for the template (required)
      * `:platform` - `"apple"` or `"android"` (required)
      * `:use_case` - e.g. `"employee_badge"` (required)
      * `:protocol` - `"desfire"` (Apple), `"seos"`, or `"smart_tap"` (Android)
      * `:allow_on_multiple_devices`, `:watch_count`, `:iphone_count` - Device limits
      * `:background_color`, `:label_color`, `:label_secondary_color` - Style settings
      * `:background`, `:logo`, `:icon` - Base64-encoded PNG/JPEG images (max 10MB decoded)
      * `:support_url`, `:support_phone_number`, `:support_email` - Support contact info
      * `:privacy_policy_url`, `:terms_and_conditions_url` - Legal URLs
      * `:credential_profiles` - List of credential-profile ex_id strings to attach
      * `:landing_pages` - List of landing-page ex_id strings to attach
      * `:metadata` - Custom metadata map

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %CardTemplate.Result{}}` - Template created successfully
    * `{:error, reason, %HttpFailure{}}` - Creation failed

  """
  @spec create_template(map(), keyword()) :: result()
  def create_template(params, opts \\ []) do
    with :ok <- Params.require(params, [:name, :platform, :use_case, :protocol]) do
      opts[:client]
      |> Client.request(:post, "#{@base_path}/card-templates", body: params)
      |> handle_result_response()
    end
  end

  @doc """
  Updates an existing card template.

  ## Parameters

    * `template_id` - The template ID to update
    * `params` - Fields to update (same options as create_template)
    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %CardTemplate.Result{}}` - Template updated successfully
    * `{:error, reason, %HttpFailure{}}` - Update failed

  """
  @spec update_template(String.t(), map(), keyword()) :: result()
  def update_template(template_id, params, opts \\ []) do
    with :ok <- Params.require_present(template_id, :template_id) do
      opts[:client]
      |> Client.request(:put, "#{@base_path}/card-templates/#{template_id}", body: params)
      |> handle_result_response()
    end
  end

  @doc """
  Retrieves a card template or card template pair by id.

  The `/v1/console/card-templates/:id` endpoint serves both shapes: a single
  template, or a pair containing two member templates. Match on the returned
  struct to tell them apart.

  ## Parameters

    * `template_id` - The template (or pair) id to retrieve
    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %CardTemplate{}}` - Single template
    * `{:ok, %CardTemplatePair{}}` - Pair, with member templates under `:templates`
    * `{:error, reason, %HttpFailure{}}` - Retrieval failed

  """
  @spec read_template(String.t(), keyword()) :: template_result()
  def read_template(template_id, opts \\ []) do
    with :ok <- Params.require_present(template_id, :template_id) do
      opts[:client]
      |> Client.request(:get, "#{@base_path}/card-templates/#{template_id}")
      |> handle_template_response()
    end
  end

  @doc """
  Retrieves activity logs for a card template.

  ## Parameters

    * `template_id` - The template ID to get logs for
    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)
      * `:page` - Page number (default: 1)
      * `:per_page` - Results per page (default: 50, max: 100)
      * `:filters` - Map with optional filters:
        * `:device` - "mobile" or "watch"
        * `:start_date` - ISO8601 timestamp
        * `:end_date` - ISO8601 timestamp
        * `:event_type` - Event type string

  ## Returns

    * `{:ok, [%Event{}], pagination}` - List of events and pagination info
    * `{:error, reason, %HttpFailure{}}` - Retrieval failed

  """
  @spec get_logs(String.t(), keyword()) :: logs_result()
  def get_logs(template_id, opts \\ []) do
    with :ok <- Params.require_present(template_id, :template_id) do
      params =
        %{}
        |> maybe_add_param(:page, opts[:page])
        |> maybe_add_param(:per_page, opts[:per_page])
        |> maybe_add_param(:filters, opts[:filters])

      opts[:client]
      |> Client.request(:get, "#{@base_path}/card-templates/#{template_id}/logs", params: params)
      |> handle_logs_response()
    end
  end

  @doc """
  Runs Apple Wallet In-App Provisioning preflight for an access pass.

  Returns the identifiers needed to drive the iOS provisioning flow. Note that
  Rails returns these keys in camelCase (Apple convention); the resulting struct
  uses snake_case Elixir-idiomatic field names.

  ## Parameters

    * `template_id` - The card template ID containing the access pass
    * `params` - Map with:
      * `:access_pass_ex_id` - ex_id of the access pass to preflight (required)
    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %IosPreflight{}}` - Preflight identifiers
    * `{:error, reason, %HttpFailure{}}` - Preflight failed (404 if template or access pass missing)

  """
  @spec ios_preflight(String.t(), map(), keyword()) :: ios_preflight_result()
  def ios_preflight(template_id, params, opts \\ []) do
    with :ok <- Params.require_present(template_id, :template_id),
         :ok <- Params.require(params, [:access_pass_ex_id]) do
      opts[:client]
      |> Client.request(:post, "#{@base_path}/card-templates/#{template_id}/ios_preflight", body: params)
      |> handle_ios_preflight_response()
    end
  end

  @doc """
  Lists all pass template pairs for the account.

  Template pairs combine an iOS and Android template for cross-platform pass issuance.

  ## Parameters

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)
      * `:page` - Page number (default: 1)
      * `:per_page` - Results per page (default: 50, max: 100)

  ## Returns

    * `{:ok, [%CardTemplatePair.Summary{}], pagination}` - List of pairs and pagination info
    * `{:error, reason, %HttpFailure{}}` - Retrieval failed

  """
  @spec list_card_template_pairs(keyword()) :: pairs_result()
  def list_card_template_pairs(opts \\ []) do
    params =
      %{}
      |> maybe_add_param(:page, opts[:page])
      |> maybe_add_param(:per_page, opts[:per_page])

    opts[:client]
    |> Client.request(:get, "#{@base_path}/card-template-pairs", params: params)
    |> handle_pairs_response()
  end

  @doc """
  Creates a card template pair from an existing Apple and Google template.

  The Rails API enforces several validations before the pair is created:

    * Both referenced templates must belong to the current account (404 otherwise).
    * Apple template must have `platform == "apple"` and Google template `platform == "android"` (422).
    * Protocol combination must be either both SEOS, or Apple DESFire + Google Smart Tap (422).
    * Both templates must be in `status == "ready"` (i.e. published) (422).

  ## Parameters

    * `params` - Map with:
      * `:name` - Name for the new pair (required)
      * `:apple_card_template_id` - ex_id of the published Apple template
      * `:google_card_template_id` - ex_id of the published Google template

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %CardTemplatePair.Summary{}}` - Pair created. Same shape as items returned by
      `list_card_template_pairs/1`.
    * `{:error, reason, %HttpFailure{}}` - Creation failed.

  """
  @spec create_card_template_pair(map(), keyword()) :: pair_summary_result()
  def create_card_template_pair(params, opts \\ []) do
    with :ok <-
           Params.require(params, [
             :name,
             :apple_card_template_id,
             :google_card_template_id
           ]) do
      opts[:client]
      |> Client.request(:post, "#{@base_path}/card-template-pairs", body: params)
      |> handle_pair_summary_response()
    end
  end

  @doc """
  Lists all landing pages for the account.

  Rails returns a flat JSON array — there is no `landing_pages` wrapper and no
  pagination, so the result is `{:ok, list}` rather than `{:ok, list, pagination}`.

  ## Parameters

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, [%LandingPage{}]}` - List of landing pages (may be empty)
    * `{:error, reason, %HttpFailure{}}` - Retrieval failed

  """
  @spec list_landing_pages(keyword()) :: landing_pages_result()
  def list_landing_pages(opts \\ []) do
    opts[:client]
    |> Client.request(:get, "#{@base_path}/landing-pages")
    |> handle_landing_pages_list_response()
  end

  @doc """
  Creates a new landing page.

  ## Parameters

    * `params` - Map with:
      * `:name` - Display name (required)
      * `:kind` - Landing page kind (required; immutable after creation)
      * `:additional_text`, `:bg_color`, `:allow_immediate_download`,
        `:password`, `:is_2fa_enabled` - Optional fields
      * `:logo` - Base64-encoded PNG or JPEG image (optional)

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %LandingPage{}}` - Created
    * `{:error, reason, %HttpFailure{}}` - Creation failed

  """
  @spec create_landing_page(map(), keyword()) :: landing_page_result()
  def create_landing_page(params, opts \\ []) do
    with :ok <- Params.require(params, [:name, :kind]) do
      opts[:client]
      |> Client.request(:post, "#{@base_path}/landing-pages", body: params)
      |> handle_landing_page_response()
    end
  end

  @doc """
  Updates an existing landing page.

  The `:kind` field is immutable after creation. Sending a different value
  returns 422.

  ## Parameters

    * `landing_page_id` - The landing page ID to update
    * `params` - Same fields as `create_landing_page/2` except `:kind`
    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %LandingPage{}}` - Updated
    * `{:error, reason, %HttpFailure{}}` - 404 if id missing, 422 on validation

  """
  @spec update_landing_page(String.t(), map(), keyword()) :: landing_page_result()
  def update_landing_page(landing_page_id, params, opts \\ []) do
    with :ok <- Params.require_present(landing_page_id, :landing_page_id) do
      opts[:client]
      |> Client.request(:put, "#{@base_path}/landing-pages/#{landing_page_id}", body: params)
      |> handle_landing_page_response()
    end
  end

  @doc """
  Lists all credential profiles for the account.

  Rails returns a flat JSON array — no wrapper, no pagination — so the result
  is `{:ok, list}` rather than `{:ok, list, pagination}`.

  ## Parameters

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, [%CredentialProfile{}]}` - List of credential profiles (may be empty)
    * `{:error, reason, %HttpFailure{}}` - Retrieval failed

  """
  @spec list_credential_profiles(keyword()) :: credential_profiles_result()
  def list_credential_profiles(opts \\ []) do
    opts[:client]
    |> Client.request(:get, "#{@base_path}/credential-profiles")
    |> handle_credential_profiles_list_response()
  end

  @doc """
  Creates a new credential profile.

  ## Parameters

    * `params` - Map with:
      * `:name` - Display name (required)
      * `:app_name` - Reader app name (optional, defaults to `"KEY-ID-main"`)
      * `:keys` - List of `%{value, keys_diversified?, source_key_index?}` maps;
        length must match the app's required key count
      * `:file_id` - Hex file id string (optional, defaults to `"00"`)

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %CredentialProfile{}}` - Created
    * `{:error, reason, %HttpFailure{}}` - 422 on invalid `app_name`, wrong key count, or validation failure

  """
  @spec create_credential_profile(map(), keyword()) :: credential_profile_result()
  def create_credential_profile(params, opts \\ []) do
    with :ok <- Params.require(params, [:name, :keys]) do
      opts[:client]
      |> Client.request(:post, "#{@base_path}/credential-profiles", body: params)
      |> handle_credential_profile_response()
    end
  end

  @doc """
  Lists webhook subscriptions for the account.

  ## Parameters

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)
      * `:page` - Page number (default: 1)
      * `:per_page` - Results per page (default: 50, max: 100)

  ## Returns

    * `{:ok, [%Webhook{}], pagination}` - List + pagination map
    * `{:error, reason, %HttpFailure{}}` - Retrieval failed

  """
  @spec list_webhooks(keyword()) :: webhooks_result()
  def list_webhooks(opts \\ []) do
    params =
      %{}
      |> maybe_add_param(:page, opts[:page])
      |> maybe_add_param(:per_page, opts[:per_page])

    opts[:client]
    |> Client.request(:get, "#{@base_path}/webhooks", params: params)
    |> handle_webhooks_list_response()
  end

  @doc """
  Creates a new webhook subscription.

  ## Parameters

    * `params` - Map with:
      * `:name` - Display name
      * `:url` - HTTPS endpoint to receive events
      * `:subscribed_events` - List of event names (e.g. `["ag.access_pass.issued"]`)
      * `:auth_method` - `"bearer_token"` (default) or `"mtls"`

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %Webhook{}}` - Created. For `bearer_token`, the struct includes
      `private_key` (sensitive — store on receipt, Rails does not return it
      again). For `mtls`, the struct includes `client_cert` and `cert_expires_at`.
    * `{:error, reason, %HttpFailure{}}` - 422 on empty or invalid `subscribed_events`.

  """
  @spec create_webhook(map(), keyword()) :: webhook_result()
  def create_webhook(params, opts \\ []) do
    with :ok <- Params.require(params, [:name, :url, :subscribed_events]) do
      opts[:client]
      |> Client.request(:post, "#{@base_path}/webhooks", body: params)
      |> handle_webhook_response()
    end
  end

  @doc """
  Deletes a webhook subscription.

  ## Parameters

    * `webhook_id` - The webhook ID to delete
    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `:ok` - Deleted (Rails returns 204 No Content; there is no body)
    * `{:error, reason, %HttpFailure{}}` - 404 if id missing

  """
  @spec delete_webhook(String.t(), keyword()) :: webhook_delete_result()
  def delete_webhook(webhook_id, opts \\ []) do
    with :ok <- Params.require_present(webhook_id, :webhook_id) do
      opts[:client]
      |> Client.request(:delete, "#{@base_path}/webhooks/#{webhook_id}")
      |> handle_webhook_delete_response()
    end
  end

  @doc """
  Lists HID Origo organizations registered to the account.

  Rails returns a flat JSON array — no wrapper, no pagination.

  ## Parameters

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, [%HidOrg{}]}` - List of HID orgs (may be empty)
    * `{:error, reason, %HttpFailure{}}` - Retrieval failed

  """
  @spec list_hid_orgs(keyword()) :: hid_orgs_result()
  def list_hid_orgs(opts \\ []) do
    opts[:client]
    |> Client.request(:get, "#{@base_path}/hid/orgs")
    |> handle_hid_orgs_list_response()
  end

  @doc """
  Registers a new HID Origo organization for the account.

  Idempotent on `name` → `slug`: if an org with the derived slug already exists,
  Rails returns the existing record with status 200 instead of creating a new one.

  ## Parameters

    * `params` - Map with:
      * `:name` - Display name (required)
      * `:full_address` - Full mailing address
      * `:phone` - Contact phone number
      * `:first_name` - Primary contact first name
      * `:last_name` - Primary contact last name

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %HidOrg{}}` - Created (201) or existing (200)
    * `{:error, reason, %HttpFailure{}}` - 422 on validation failure

  """
  @spec create_hid_org(map(), keyword()) :: hid_org_result()
  def create_hid_org(params, opts \\ []) do
    with :ok <-
           Params.require(params, [:name, :full_address, :phone, :first_name, :last_name]) do
      opts[:client]
      |> Client.request(:post, "#{@base_path}/hid/orgs", body: params)
      |> handle_hid_org_response()
    end
  end

  @doc """
  Completes registration for an HID Origo organization (activate).

  Rails may return extra fields on the response (`already_completed: true` when
  the org is already activated, `job_queued: true` when a registration job is
  in flight). Those flags are not surfaced on the returned struct — inspect
  `org.status` to determine activation state.

  ## Parameters

    * `params` - Map with:
      * `:email` - Email used to register the org
      * `:password` - HID portal password

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %HidOrg{}}` - 200 OK (fresh, already-complete, or no-op)
    * `{:error, reason, %HttpFailure{}}` - 404 if no org matches the email

  """
  @spec activate_hid_org(map(), keyword()) :: hid_org_result()
  def activate_hid_org(params, opts \\ []) do
    with :ok <- Params.require(params, [:email, :password]) do
      opts[:client]
      |> Client.request(:post, "#{@base_path}/hid/orgs/activate", body: params)
      |> handle_hid_org_response()
    end
  end

  @doc """
  Lists ledger items for the account, paginated and optionally date-filtered.

  ## Parameters

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)
      * `:page` - Page number (default: 1)
      * `:per_page` - Results per page (default: 50, max: 100)
      * `:start_date` - ISO8601 timestamp; filters items created on/after
      * `:end_date` - ISO8601 timestamp; filters items created on/before

  ## Returns

    * `{:ok, [%LedgerItem{}], pagination}` - List + pagination map
    * `{:error, reason, %HttpFailure{}}` - 422 on bad date format

  """
  @spec list_ledger_items(keyword()) :: ledger_items_result()
  def list_ledger_items(opts \\ []) do
    params =
      %{}
      |> maybe_add_param(:page, opts[:page])
      |> maybe_add_param(:per_page, opts[:per_page])
      |> maybe_add_param(:start_date, opts[:start_date])
      |> maybe_add_param(:end_date, opts[:end_date])

    opts[:client]
    |> Client.request(:get, "#{@base_path}/ledger-items", params: params)
    |> handle_ledger_items_list_response()
  end

  @doc """
  Publishes a card template, moving it out of `draft` toward `ready` or `in-review`.

  For Android+SEOS templates, Rails also syncs the template to the HID portal as
  part of publish. If that sync fails, the template is rolled back to `draft`
  and this call returns `{:error, :validation_failed, failure}` with a
  field-tagged error message in `failure.body_decoded["message"]`.

  ## Parameters

    * `template_id` - The card template id to publish
    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %CardTemplate.PublishResult{}}` - 200 OK with `{id, status}`. `status` is
      `"publishing"` (already in flight), `"in-review"` (Apple queued), or `"ready"`
      (Android, immediate).
    * `{:error, reason, %HttpFailure{}}` - 404 if template missing, 422 on validation
      failure or HID-sync failure (for Android+SEOS).

  """
  @spec publish_template(String.t(), keyword()) :: publish_result()
  def publish_template(template_id, opts \\ []) do
    with :ok <- Params.require_present(template_id, :template_id) do
      opts[:client]
      |> Client.request(:post, "#{@base_path}/card-templates/#{template_id}/publish")
      |> handle_publish_response()
    end
  end

  @doc """
  Reveals the SmartTap private key for a card template.

  The SDK generates a fresh ephemeral P-256 keypair per call, submits the
  public half, and decrypts the server's response client-side. The returned
  `%SmartTapReveal{}` carries the decrypted PEM in `:private_key` (the value
  callers normally want). The original `:encrypted_private_key` envelope is
  also preserved on the struct as an escape hatch.

  Each call uses a fresh keypair internally, so the server's single-use
  enforcement on pubkey fingerprint is satisfied automatically.

  ## Parameters

    * `template_id` - The card template id (must be SmartTap protocol with a
      `smart_tap_key`)

    * `opts` - Options:
      * `:client` - Client struct (optional, defaults to config)

  ## Returns

    * `{:ok, %SmartTapReveal{}}` - Reveal succeeded; `:private_key` holds the
      plaintext SmartTap PEM
    * `{:error, :decrypt_failed, body}` - HTTP succeeded but the returned
      envelope didn't decrypt against the SDK-generated keypair (server-side
      crypto drift or SDK bug)
    * `{:error, :not_found, %HttpFailure{}}` - Template missing, not SmartTap,
      or no `smart_tap_key`
    * `{:error, :validation_failed, %HttpFailure{}}` - Server-side validation
      failure

  """
  @spec reveal_smart_tap(String.t(), keyword()) :: smart_tap_reveal_result()
  def reveal_smart_tap(template_id, opts \\ []) do
    with :ok <- Params.require_present(template_id, :template_id) do
      {ec_priv, pub_pem} = Keyword.get_lazy(opts, :keypair, &SmartTap.generate_keypair/0)

      opts[:client]
      |> Client.request(
        :post,
        "#{@base_path}/card-templates/#{template_id}/smart-tap/reveal",
        body: %{client_public_key: pub_pem}
      )
      |> handle_smart_tap_reveal_response(ec_priv)
    end
  end

  # --- Private Helpers ---

  defp handle_result_response({:ok, %HttpResponse{body_decoded: body}}) do
    {:ok, CardTemplate.Result.from_response(body)}
  end

  defp handle_result_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_template_response({:ok, %HttpResponse{body_decoded: %{"is_pair" => true} = body}}) do
    {:ok, CardTemplatePair.from_response(body)}
  end

  defp handle_template_response({:ok, %HttpResponse{body_decoded: body}}) do
    {:ok, CardTemplate.from_response(body)}
  end

  defp handle_template_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_logs_response({:ok, %HttpResponse{body_decoded: body}}) do
    events =
      body
      |> Map.get("logs", [])
      |> Enum.map(&Event.from_response/1)

    pagination = Map.get(body, "pagination", %{})

    {:ok, events, pagination}
  end

  defp handle_logs_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_pairs_response({:ok, %HttpResponse{body_decoded: body}}) do
    pairs =
      body
      |> Map.get("card_template_pairs", [])
      |> Enum.map(&CardTemplatePair.Summary.from_response/1)

    pagination = Map.get(body, "pagination", %{})

    {:ok, pairs, pagination}
  end

  defp handle_pairs_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_pair_summary_response({:ok, %HttpResponse{body_decoded: body}}) do
    {:ok, CardTemplatePair.Summary.from_response(body)}
  end

  defp handle_pair_summary_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_ios_preflight_response({:ok, %HttpResponse{body_decoded: body}}) do
    {:ok, IosPreflight.from_response(body)}
  end

  defp handle_ios_preflight_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_landing_pages_list_response({:ok, %HttpResponse{body_decoded: pages}})
       when is_list(pages) do
    {:ok, Enum.map(pages, &LandingPage.from_response/1)}
  end

  defp handle_landing_pages_list_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_landing_page_response({:ok, %HttpResponse{body_decoded: body}}) do
    {:ok, LandingPage.from_response(body)}
  end

  defp handle_landing_page_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_credential_profiles_list_response({:ok, %HttpResponse{body_decoded: profiles}})
       when is_list(profiles) do
    {:ok, Enum.map(profiles, &CredentialProfile.from_response/1)}
  end

  defp handle_credential_profiles_list_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_credential_profile_response({:ok, %HttpResponse{body_decoded: body}}) do
    {:ok, CredentialProfile.from_response(body)}
  end

  defp handle_credential_profile_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_webhooks_list_response({:ok, %HttpResponse{body_decoded: body}}) do
    webhooks =
      body
      |> Map.get("webhooks", [])
      |> Enum.map(&Webhook.from_response/1)

    pagination = Map.get(body, "pagination", %{})

    {:ok, webhooks, pagination}
  end

  defp handle_webhooks_list_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_webhook_response({:ok, %HttpResponse{body_decoded: body}}) do
    {:ok, Webhook.from_response(body)}
  end

  defp handle_webhook_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_webhook_delete_response({:ok, %HttpResponse{}}), do: :ok

  defp handle_webhook_delete_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_hid_orgs_list_response({:ok, %HttpResponse{body_decoded: orgs}})
       when is_list(orgs) do
    {:ok, Enum.map(orgs, &HidOrg.from_response/1)}
  end

  defp handle_hid_orgs_list_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_hid_org_response({:ok, %HttpResponse{body_decoded: body}}) do
    {:ok, HidOrg.from_response(body)}
  end

  defp handle_hid_org_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_ledger_items_list_response({:ok, %HttpResponse{body_decoded: body}}) do
    items =
      body
      |> Map.get("ledger_items", [])
      |> Enum.map(&LedgerItem.from_response/1)

    pagination = Map.get(body, "pagination", %{})

    {:ok, items, pagination}
  end

  defp handle_ledger_items_list_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_publish_response({:ok, %HttpResponse{body_decoded: body}}) do
    {:ok, CardTemplate.PublishResult.from_response(body)}
  end

  defp handle_publish_response({:error, %HttpFailure{} = failure}) do
    {:error, reason_from_failure(failure), failure}
  end

  defp handle_smart_tap_reveal_response({:ok, %HttpResponse{body_decoded: body}}, ec_priv) do
    reveal = SmartTapReveal.from_response(body)

    case SmartTap.decrypt_envelope(reveal.encrypted_private_key, ec_priv) do
      {:ok, plaintext} -> {:ok, %{reveal | private_key: plaintext}}
      {:error, reason} -> {:error, reason, body}
    end
  end

  defp handle_smart_tap_reveal_response({:error, %HttpFailure{} = failure}, _ec_priv) do
    {:error, reason_from_failure(failure), failure}
  end

  defp reason_from_failure(%HttpFailure{reason: :unauthorized}), do: :unauthorized
  defp reason_from_failure(%HttpFailure{reason: :forbidden}), do: :forbidden
  defp reason_from_failure(%HttpFailure{reason: :not_found}), do: :not_found
  defp reason_from_failure(%HttpFailure{reason: :conflict}), do: :conflict
  defp reason_from_failure(%HttpFailure{reason: :unprocessable_entity}), do: :validation_failed
  defp reason_from_failure(%HttpFailure{reason: :too_many_requests}), do: :rate_limited
  defp reason_from_failure(%HttpFailure{reason: :timeout}), do: :timeout

  defp reason_from_failure(%HttpFailure{reason: reason})
       when reason in [:internal_server_error, :bad_gateway, :service_unavailable, :gateway_timeout, :server_error],
       do: :server_error

  defp reason_from_failure(%HttpFailure{}), do: :request_failed

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: Map.put(params, key, value)
end
