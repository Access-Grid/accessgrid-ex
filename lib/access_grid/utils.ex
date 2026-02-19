defmodule AccessGrid.Utils do
  @moduledoc """
  Utility helpers for composing API request params.

  These functions are intentionally not invoked automatically by the Console /
  AccessPasses functions — they're building blocks. Callers compose the params they
  want and pass them through.
  """

  @doc """
  Reads `path` and returns its contents Base64-encoded.

  Pairs with image-accepting endpoints (`Console.create_template/2`,
  `Console.update_template/3`, `Console.create_landing_page/2`,
  `Console.update_landing_page/3`, `AccessPasses.issue/2`, `AccessPasses.update/3`) —
  Rails decodes the base64 string server-side and attaches the resulting image.

  Returns `{:ok, encoded}` on success or `{:error, reason}` on failure, where
  `reason` is the posix atom from `File.read/1` (`:enoent`, `:eacces`, etc.).

  ## Examples

      {:ok, b64} = AccessGrid.Utils.base64_file("badge.png")

      AccessGrid.Console.create_template(
        %{
          name: "Employee Badge",
          platform: "apple",
          background: b64
        },
        client: client
      )

  """
  @spec base64_file(Path.t()) :: {:ok, String.t()} | {:error, File.posix()}
  def base64_file(path) do
    case File.read(path) do
      {:ok, bytes} -> {:ok, Base.encode64(bytes)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Same as `base64_file/1` but raises `File.Error` on failure.

  Use when the file is known to exist and an unrecoverable error is appropriate.

  ## Examples

      b64 = AccessGrid.Utils.base64_file!("badge.png")

  """
  @spec base64_file!(Path.t()) :: String.t()
  def base64_file!(path) do
    path |> File.read!() |> Base.encode64()
  end
end
