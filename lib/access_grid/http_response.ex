defmodule AccessGrid.HttpResponse do
  @moduledoc """
  Represents a successful HTTP response (2xx status codes).

  All HTTP client implementations must normalize their responses to this struct.
  """

  @type t :: %__MODULE__{
          body_decoded: term(),
          body_raw: binary(),
          content_type: String.t() | nil,
          headers: [{String.t(), String.t()}],
          status: integer()
        }

  defstruct [:body_decoded, :body_raw, :content_type, :headers, :status]
end
