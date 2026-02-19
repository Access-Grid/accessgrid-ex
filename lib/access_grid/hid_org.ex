defmodule AccessGrid.HidOrg do
  @moduledoc """
  HID Origo organization registered to the account. Returned by
  `AccessGrid.Console.list_hid_orgs/1`, `AccessGrid.Console.create_hid_org/2`,
  and `AccessGrid.Console.activate_hid_org/2`.

  The activate endpoint (`activate_hid_org/2`) may return extra fields like
  `already_completed: true` or `job_queued: true` to indicate state — those are
  not surfaced on this struct. Use `org.status` to determine activation state.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          slug: String.t() | nil,
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          phone: String.t() | nil,
          full_address: String.t() | nil,
          status: String.t() | nil,
          created_at: String.t() | nil
        }

  defstruct [
    :id,
    :name,
    :slug,
    :first_name,
    :last_name,
    :phone,
    :full_address,
    :status,
    :created_at
  ]

  @doc """
  Creates a HidOrg struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      slug: data["slug"],
      first_name: data["first_name"],
      last_name: data["last_name"],
      phone: data["phone"],
      full_address: data["full_address"],
      status: data["status"],
      created_at: data["created_at"]
    }
  end
end
