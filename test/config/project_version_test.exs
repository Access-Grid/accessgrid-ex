defmodule Config.ProjectVersionTest do
  use ExUnit.Case, async: true

  @version AccessGrid.MixProject.project()[:version]

  describe "project version consistency" do
    test "README.md version matches mix.exs" do
      readme = File.read!("README.md")

      assert readme =~ ~r/{:accessgrid,\s*"~>\s*#{Regex.escape(@version)}"/,
             "README.md should reference version ~> #{@version}"
    end
  end
end
