defmodule AccessGrid.HttpFailure do
  @moduledoc """
  Represents an HTTP request failure.

  This covers both transport-level failures (connection refused, timeout) and
  HTTP error responses (4xx, 5xx status codes).

  This is a struct, not an exception. All HTTP client implementations must
  normalize their errors to this struct.
  """

  @type t :: %__MODULE__{
          body_decoded: term() | nil,
          body_raw: binary() | nil,
          content_type: String.t() | nil,
          message: String.t() | nil,
          original: term(),
          reason: atom(),
          status: integer() | nil
        }

  defstruct [:body_decoded, :body_raw, :content_type, :message, :original, :reason, :status]
end
