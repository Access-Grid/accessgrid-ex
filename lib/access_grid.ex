defmodule AccessGrid do
  @external_resource "README.md"
  # README is rendered as this module's moduledoc. ExDoc auto-prefixes section
  # IDs with `module-` (e.g. `## Installation` becomes `id="module-installation"`),
  # so the README's GitHub-style TOC links (`#installation`) need the same
  # prefix added when seen by ExDoc. The actual README file stays unchanged.
  @moduledoc File.read!("README.md")
             |> String.replace(~r/# !\[AccessGrid Logo\]\(.*\)/, "", global: false)
             |> String.replace(~r/\]\(#([\w-]+)\)/, "](#module-\\1)")
end
