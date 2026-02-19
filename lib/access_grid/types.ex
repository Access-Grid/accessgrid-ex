defmodule AccessGrid.Types do
  @moduledoc """
  Shared type definitions for the AccessGrid client.

  This module contains types used across multiple modules to avoid
  circular dependencies.
  """

  @typedoc """
  Error reasons returned from API operations.

  - `:unauthorized` - Invalid or missing credentials (401)
  - `:forbidden` - Access denied (403)
  - `:not_found` - Resource not found (404)
  - `:conflict` - Request conflicts with current state (409)
  - `:validation_failed` - Invalid request parameters (422)
  - `:rate_limited` - Too many requests (429)
  - `:timeout` - Request timed out
  - `:server_error` - Server-side error (5xx)
  - `:request_failed` - Other/unknown failures
  - `:missing_required` - A required field was nil or blank before the request was
    sent. The third tuple element is the offending field name as an atom (no
    `HttpFailure` is produced — the SDK short-circuits before any HTTP call).
  """
  @type api_error_reason ::
          :unauthorized
          | :forbidden
          | :not_found
          | :conflict
          | :validation_failed
          | :rate_limited
          | :timeout
          | :server_error
          | :request_failed
          | :missing_required
end
