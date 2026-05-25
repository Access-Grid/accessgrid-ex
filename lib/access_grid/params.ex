defmodule AccessGrid.Params do
  @moduledoc """
  Helpers for composing SDK request params. Currently just `require/2` for
  client-side required-field presence checks — used internally by `Console`
  and `AccessPasses` create/action functions to surface "you forgot X" without
  a round-trip to the API.
  """

  @doc """
  Returns `:ok` if every atom key in `required_keys` has a non-blank value
  in `params`. Returns `{:error, :missing_required, missing}` where `missing`
  is the non-empty list of every missing/blank key (in input order —
  deterministic).

  "Blank" means `nil`, key absent, an empty string `""`, or a whitespace-only
  string (`"   "`, `"\\t\\n"`, etc.). Empty lists, maps, and other values pass
  through — the server validates whether an empty collection is acceptable
  for a given field (e.g. the server rejects `subscribed_events: []` with its own
  clear 422 message).

  Atom-keyed maps only; mirrors the SDK's input convention.

  ## Examples

      iex> AccessGrid.Params.require(%{name: "X", protocol: "desfire"}, [:name, :protocol])
      :ok

      iex> AccessGrid.Params.require(%{name: "X"}, [:name, :protocol])
      {:error, :missing_required, [:protocol]}

      iex> AccessGrid.Params.require(%{}, [:name, :platform, :protocol])
      {:error, :missing_required, [:name, :platform, :protocol]}

      iex> AccessGrid.Params.require(%{name: "  "}, [:name])
      {:error, :missing_required, [:name]}

  """
  @spec require(map(), [atom()]) ::
          :ok | {:error, :missing_required, [atom(), ...]}
  def require(params, required_keys) when is_map(params) and is_list(required_keys) do
    case Enum.filter(required_keys, &blank?(Map.get(params, &1))) do
      [] -> :ok
      missing -> {:error, :missing_required, missing}
    end
  end

  @doc """
  Returns `:ok` if `value` is non-blank. Returns
  `{:error, :missing_required, [name]}` otherwise (single-element list for
  shape consistency with `require/2`). Used to validate positional arguments
  (path-segment IDs like `template_id`, `card_id`, etc.) where the SDK
  function takes a positional string rather than a key in a params map.

  ## Examples

      iex> AccessGrid.Params.require_present("tpl_abc", :template_id)
      :ok

      iex> AccessGrid.Params.require_present(nil, :template_id)
      {:error, :missing_required, [:template_id]}

      iex> AccessGrid.Params.require_present("  ", :template_id)
      {:error, :missing_required, [:template_id]}

  """
  @spec require_present(any(), atom()) ::
          :ok | {:error, :missing_required, [atom(), ...]}
  def require_present(value, name) when is_atom(name) do
    if blank?(value), do: {:error, :missing_required, [name]}, else: :ok
  end

  defp blank?(nil), do: true
  defp blank?(val) when is_binary(val), do: String.trim(val) == ""
  defp blank?(_), do: false
end
