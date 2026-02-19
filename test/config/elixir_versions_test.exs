defmodule Config.ElixirVersionsTest do
  use ExUnit.Case, async: true

  # ══════════════════════════════════════════════════════════════════════════════
  # TARGET VERSIONS - Update these when upgrading Elixir/Erlang
  # ══════════════════════════════════════════════════════════════════════════════
  @target_elixir "1.19.5"
  @target_otp "28.5"

  describe ".tool-versions" do
    test "elixir version matches target" do
      assert tool_versions()["elixir"] |> elixir_version() == @target_elixir
    end

    test "erlang version matches target" do
      assert tool_versions()["erlang"] == @target_otp
    end

    test "elixir otp suffix matches target otp major" do
      assert tool_versions()["elixir"] |> otp_suffix() == otp_major(@target_otp)
    end
  end

  describe "CI workflow" do
    test "at least one matrix entry matches target elixir major.minor" do
      target_major_minor = major_minor(@target_elixir)
      matrix_elixirs = ci_matrix_pairs() |> Enum.map(& &1.elixir) |> Enum.uniq()

      assert target_major_minor in matrix_elixirs,
             "CI matrix should include elixir #{target_major_minor}, found: #{inspect(matrix_elixirs)}"
    end

    test "at least one matrix entry matches target otp major" do
      target_major = otp_major(@target_otp)
      matrix_otps = ci_matrix_pairs() |> Enum.map(& &1.otp) |> Enum.uniq()

      assert target_major in matrix_otps,
             "CI matrix should include otp #{target_major}, found: #{inspect(matrix_otps)}"
    end

    test "at least one matrix entry matches both target elixir and otp" do
      target_elixir_mm = major_minor(@target_elixir)
      target_otp_major = otp_major(@target_otp)

      matching_pair =
        ci_matrix_pairs()
        |> Enum.find(fn pair ->
          pair.elixir == target_elixir_mm and pair.otp == target_otp_major
        end)

      assert matching_pair != nil,
             "CI matrix should include pair {elixir: #{target_elixir_mm}, otp: #{target_otp_major}}"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # Helpers
  # ══════════════════════════════════════════════════════════════════════════════

  defp tool_versions do
    ".tool-versions"
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Map.new(fn line ->
      [tool, version] = String.split(line, " ", parts: 2)
      {tool, version}
    end)
  end

  defp ci_matrix_pairs do
    content = File.read!(".github/workflows/tests.yml")

    # Find all matrix pair definitions like:
    #   - pair:
    #       elixir: 1.19
    #       otp: 28
    Regex.scan(~r/elixir:\s*(\d+\.\d+)\s*\n\s*otp:\s*(\d+)/, content)
    |> Enum.map(fn [_match, elixir, otp] ->
      %{elixir: elixir, otp: otp}
    end)
    |> Enum.uniq()
  end

  # Extract elixir version from tool-versions format (e.g., "1.19.5-otp-28" -> "1.19.5")
  defp elixir_version(tool_version_string) do
    tool_version_string |> String.split("-otp-") |> List.first()
  end

  # Extract otp suffix from tool-versions format (e.g., "1.19.5-otp-28" -> "28")
  defp otp_suffix(tool_version_string) do
    tool_version_string |> String.split("-otp-") |> List.last()
  end

  # Extract major version (e.g., "28.3.1" -> "28")
  defp otp_major(version) do
    version |> String.split(".") |> List.first()
  end

  # Extract major.minor version (e.g., "1.19.5" -> "1.19")
  defp major_minor(version) do
    version
    |> String.split(".")
    |> Enum.take(2)
    |> Enum.join(".")
  end
end
