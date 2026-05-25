defmodule AccessGrid.LedgerItem do
  @moduledoc """
  A line item from the account's billing ledger. Returned by
  `AccessGrid.Console.list_ledger_items/1`.

  `access_pass` is populated when the ledger item is tied to a specific access
  pass — typically credit/debit lines for issuance, renewals, etc. It is `nil`
  for line items that aren't pass-scoped.

  The API returns both `id` and `ex_id` for ledger items (same value); `ex_id`
  is deprecated. This struct reads from `id`.
  """

  alias AccessGrid.LedgerItem.AccessPass

  @type t :: %__MODULE__{
          id: String.t() | nil,
          created_at: String.t() | nil,
          amount: number() | nil,
          kind: String.t() | nil,
          event: String.t() | nil,
          metadata: map(),
          access_pass: AccessPass.t() | nil
        }

  defstruct [
    :id,
    :created_at,
    :amount,
    :kind,
    :event,
    :access_pass,
    metadata: %{}
  ]

  @doc """
  Creates a LedgerItem struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      created_at: data["created_at"],
      amount: data["amount"],
      kind: data["kind"],
      event: data["event"],
      metadata: data["metadata"] || %{},
      access_pass: AccessPass.from_response(data["access_pass"])
    }
  end
end

defmodule AccessGrid.LedgerItem.AccessPass do
  @moduledoc """
  Narrow access-pass representation embedded in `AccessGrid.LedgerItem`. Returned
  with just enough fields to identify the pass behind a ledger line; for the full
  access-pass shape, use `AccessGrid.AccessPasses.get/2`.

  The field is named `pass_template` here (matching the wire key the server returns)
  but its value is a `%AccessGrid.LedgerItem.CardTemplate{}`.
  """

  alias AccessGrid.LedgerItem.CardTemplate

  @type t :: %__MODULE__{
          id: String.t() | nil,
          full_name: String.t() | nil,
          state: String.t() | nil,
          metadata: map(),
          unified_access_pass_id: String.t() | nil,
          pass_template: CardTemplate.t() | nil
        }

  defstruct [
    :id,
    :full_name,
    :state,
    :unified_access_pass_id,
    :pass_template,
    metadata: %{}
  ]

  @doc """
  Creates a LedgerItem.AccessPass struct from an API response map.
  """
  @spec from_response(map() | nil) :: t() | nil
  def from_response(nil), do: nil

  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      full_name: data["full_name"],
      state: data["state"],
      metadata: data["metadata"] || %{},
      unified_access_pass_id: data["unified_access_pass_id"],
      pass_template: CardTemplate.from_response(data["pass_template"])
    }
  end
end

defmodule AccessGrid.LedgerItem.CardTemplate do
  @moduledoc """
  Narrow card-template representation embedded in
  `AccessGrid.LedgerItem.AccessPass`. Returned with just enough fields to identify
  the template behind a ledger line; for the full template shape, use
  `AccessGrid.Console.read_template/2`.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          protocol: String.t() | nil,
          platform: String.t() | nil,
          use_case: String.t() | nil
        }

  defstruct [:id, :name, :protocol, :platform, :use_case]

  @doc """
  Creates a LedgerItem.CardTemplate struct from an API response map.
  """
  @spec from_response(map() | nil) :: t() | nil
  def from_response(nil), do: nil

  def from_response(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      protocol: data["protocol"],
      platform: data["platform"],
      use_case: data["use_case"]
    }
  end
end
