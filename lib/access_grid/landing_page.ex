defmodule AccessGrid.LandingPage do
  @moduledoc """
  Account-scoped landing page where pass holders are directed before installing
  a pass. Returned by `AccessGrid.Console.list_landing_pages/1`,
  `AccessGrid.Console.create_landing_page/2`, and
  `AccessGrid.Console.update_landing_page/3`.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          created_at: String.t() | nil,
          kind: String.t() | nil,
          password_protected: boolean() | nil,
          logo_url: String.t() | nil
        }

  defstruct [
    :id,
    :name,
    :created_at,
    :kind,
    :password_protected,
    :logo_url
  ]

  @doc """
  Creates a LandingPage struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      created_at: data["created_at"],
      kind: data["kind"],
      password_protected: data["password_protected"],
      logo_url: data["logo_url"]
    }
  end
end
