defmodule AccessGrid.AccessPass do
  @moduledoc """
  Represents an access pass — the credential issued to an end user. Returned
  by `AccessGrid.AccessPasses` operations (issue, get, update, list, suspend,
  resume, unlink, delete).
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          state: String.t() | nil,
          install_url: String.t() | nil,
          direct_install_url: String.t() | nil,
          full_name: String.t() | nil,
          expiration_date: String.t() | nil,
          card_template_id: String.t() | nil,
          card_number: String.t() | nil,
          site_code: String.t() | nil,
          file_data: map() | nil,
          devices: list(),
          metadata: map()
        }

  defstruct [
    :id,
    :state,
    :install_url,
    :direct_install_url,
    :full_name,
    :expiration_date,
    :card_template_id,
    :card_number,
    :site_code,
    :file_data,
    devices: [],
    metadata: %{}
  ]

  @doc """
  Creates an AccessPass struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      state: data["state"],
      install_url: data["install_url"],
      direct_install_url: data["direct_install_url"],
      full_name: data["full_name"],
      expiration_date: data["expiration_date"],
      card_template_id: data["card_template_id"],
      card_number: data["card_number"],
      site_code: data["site_code"],
      file_data: data["file_data"],
      devices: data["devices"] || [],
      metadata: data["metadata"] || %{}
    }
  end
end
