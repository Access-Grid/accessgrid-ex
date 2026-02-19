defmodule Config.DocsTest do
  use ExUnit.Case, async: true

  @moduletag :docs

  describe "mix docs" do
    test "generates without errors" do
      {output, exit_code} =
        System.cmd("mix", ["docs", "--warnings-as-errors"], stderr_to_stdout: true, env: [{"MIX_ENV", "dev"}])

      assert exit_code == 0,
             "mix docs failed with exit code #{exit_code}:\n#{output}"
    end
  end
end
