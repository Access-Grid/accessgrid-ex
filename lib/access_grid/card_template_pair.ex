defmodule AccessGrid.CardTemplatePair do
  @moduledoc """
  Full representation of a template pair, as returned by
  `AccessGrid.Console.read_template/2` when the resolved id belongs to a pair.

  The same `card-templates/:id` endpoint serves both single templates and pairs;
  the server marks pairs with `is_pair: true` and embeds the full member templates
  under `templates`. For the lightweight list-view shape, see
  `AccessGrid.CardTemplatePair.Summary`.
  """

  alias AccessGrid.CardTemplate

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          templates: [CardTemplate.t()]
        }

  defstruct [
    :id,
    :name,
    templates: []
  ]

  @doc """
  Creates a CardTemplatePair struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      templates: Enum.map(data["templates"] || [], &CardTemplate.from_response/1)
    }
  end
end

defmodule AccessGrid.CardTemplatePair.Summary do
  @moduledoc """
  Minimal representation of a template pair, as returned by
  `AccessGrid.Console.list_card_template_pairs/1`.

  Holds the pair's identity plus platform-keyed summaries of its member templates.
  For the full pair representation (returned from `AccessGrid.Console.read_template/2`
  when the resolved id belongs to a pair), see `AccessGrid.CardTemplatePair`.
  """

  alias AccessGrid.CardTemplate

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          created_at: String.t() | nil,
          android_template: CardTemplate.Summary.t() | nil,
          ios_template: CardTemplate.Summary.t() | nil
        }

  defstruct [
    :id,
    :name,
    :created_at,
    :android_template,
    :ios_template
  ]

  @doc """
  Creates a CardTemplatePair.Summary struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      created_at: data["created_at"],
      android_template: CardTemplate.Summary.from_response(data["android_template"]),
      ios_template: CardTemplate.Summary.from_response(data["ios_template"])
    }
  end
end
