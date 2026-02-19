defmodule AccessGrid.Event do
  @moduledoc """
  Represents a template activity log event.

  Events are returned by `AccessGrid.Console.get_logs/2` and capture
  actions taken on templates and access passes.
  """

  @type t :: %__MODULE__{
          id: String.t() | integer() | nil,
          event: String.t() | nil,
          created_at: String.t() | nil,
          ip_address: String.t() | nil,
          user_agent: String.t() | nil,
          metadata: map()
        }

  defstruct [
    :id,
    :event,
    :created_at,
    :ip_address,
    :user_agent,
    metadata: %{}
  ]

  @doc """
  Creates an Event struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      event: data["event"],
      created_at: data["created_at"],
      ip_address: data["ip_address"],
      user_agent: data["user_agent"],
      metadata: data["metadata"] || %{}
    }
  end
end
