defmodule AccessGrid.CardTemplate do
  @moduledoc """
  Represents a full card template configuration.

  This struct contains all template data as returned by `AccessGrid.Console.read_template/2`.

  For minimal representations, see:
  - `AccessGrid.CardTemplate.Result` - returned from create/update operations
  - `AccessGrid.CardTemplate.Summary` - embedded in `AccessGrid.CardTemplatePair.Summary`
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          platform: String.t() | nil,
          protocol: String.t() | nil,
          use_case: String.t() | nil,
          created_at: String.t() | nil,
          last_published_at: String.t() | nil,
          issued_keys_count: integer() | nil,
          active_keys_count: integer() | nil,
          allow_on_multiple_devices: boolean() | nil,
          watch_count: integer() | nil,
          iphone_count: integer() | nil,
          support_url: String.t() | nil,
          support_phone_number: String.t() | nil,
          support_email: String.t() | nil,
          privacy_policy_url: String.t() | nil,
          terms_and_conditions_url: String.t() | nil,
          background_color: String.t() | nil,
          label_color: String.t() | nil,
          label_secondary_color: String.t() | nil,
          credential_profiles: [String.t()],
          landing_pages: [String.t()],
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    :platform,
    :protocol,
    :use_case,
    :created_at,
    :last_published_at,
    :issued_keys_count,
    :active_keys_count,
    :allow_on_multiple_devices,
    :watch_count,
    :iphone_count,
    :support_url,
    :support_phone_number,
    :support_email,
    :privacy_policy_url,
    :terms_and_conditions_url,
    :background_color,
    :label_color,
    :label_secondary_color,
    credential_profiles: [],
    landing_pages: [],
    metadata: %{}
  ]

  @doc """
  Creates a CardTemplate struct from an API response map.

  Rails groups some fields under nested objects (`allowed_device_counts`,
  `support_settings`, `terms_settings`, `style_settings`) and renames a few
  along the way (e.g. wire `support_settings.url` → struct `:support_url`).
  This function does the flatten + rename so the struct's field names match
  the request param names. Symmetric: write `background_color: "..."` on
  create, read `template.background_color` on get.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    device = data["allowed_device_counts"] || %{}
    support = data["support_settings"] || %{}
    terms = data["terms_settings"] || %{}
    style = data["style_settings"] || %{}

    %__MODULE__{
      id: data["id"],
      name: data["name"],
      platform: data["platform"],
      protocol: data["protocol"],
      use_case: data["use_case"],
      created_at: data["created_at"],
      last_published_at: data["last_published_at"],
      issued_keys_count: data["issued_keys_count"],
      active_keys_count: data["active_keys_count"],
      allow_on_multiple_devices: device["allow_on_multiple_devices"],
      watch_count: device["watch"],
      iphone_count: device["iphone"],
      support_url: support["url"],
      support_phone_number: support["phone"],
      support_email: support["email"],
      privacy_policy_url: terms["privacy_policy_url"],
      terms_and_conditions_url: terms["terms_and_conditions_url"],
      background_color: style["background_color"],
      label_color: style["label_color"],
      label_secondary_color: style["label_secondary_color"],
      credential_profiles: data["credential_profiles"] || [],
      landing_pages: data["landing_pages"] || [],
      metadata: data["metadata"] || %{}
    }
  end
end

defmodule AccessGrid.CardTemplate.Result do
  @moduledoc """
  Represents the response from template create/update operations.

  This is a minimal acknowledgment containing only the template ID,
  estimated publishing date, and metadata. For full template data,
  use `AccessGrid.Console.read_template/2` which returns `AccessGrid.CardTemplate`.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          estimated_publishing_date: String.t() | nil,
          metadata: map()
        }

  defstruct [
    :id,
    :estimated_publishing_date,
    metadata: %{}
  ]

  @doc """
  Creates a Result struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      estimated_publishing_date: data["estimated_publishing_date"],
      metadata: data["metadata"] || %{}
    }
  end
end

defmodule AccessGrid.CardTemplate.PublishResult do
  @moduledoc """
  Response from publishing a card template via
  `AccessGrid.Console.publish_template/2`. Contains the template id and the
  resulting publish status:

    * `"publishing"` — already in flight from a prior call
    * `"in-review"` — Apple-side review queued (typical for Apple templates)
    * `"ready"` — published immediately (typical for Android templates)
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          status: String.t() | nil
        }

  defstruct [:id, :status]

  @doc """
  Creates a PublishResult struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      status: data["status"]
    }
  end
end

defmodule AccessGrid.CardTemplate.Summary do
  @moduledoc """
  Represents a minimal template reference embedded in `AccessGrid.CardTemplatePair.Summary`.

  Contains only the essential identifying information: id, name, and platform.
  For full template data, use `AccessGrid.Console.read_template/2`.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          platform: String.t() | nil
        }

  defstruct [:id, :name, :platform]

  @doc """
  Creates a Summary struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(nil), do: nil

  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      platform: data["platform"]
    }
  end
end
