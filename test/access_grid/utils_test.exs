defmodule AccessGrid.UtilsTest do
  use ExUnit.Case, async: true

  alias AccessGrid.Utils

  setup do
    path = Path.join(System.tmp_dir!(), "ag_utils_test_#{System.unique_integer([:positive])}.bin")
    File.write!(path, "hello, accessgrid")
    on_exit(fn -> File.rm(path) end)

    %{path: path}
  end

  describe "base64_file/1" do
    test "returns {:ok, encoded} for an existing file", %{path: path} do
      assert {:ok, encoded} = Utils.base64_file(path)
      assert encoded == Base.encode64("hello, accessgrid")
    end

    test "returns {:error, :enoent} when the file is missing" do
      assert {:error, :enoent} = Utils.base64_file("/tmp/does-not-exist-#{System.unique_integer([:positive])}")
    end
  end

  describe "base64_file!/1" do
    test "returns the encoded string for an existing file", %{path: path} do
      assert Utils.base64_file!(path) == Base.encode64("hello, accessgrid")
    end

    test "raises File.Error when the file is missing" do
      missing = "/tmp/does-not-exist-#{System.unique_integer([:positive])}"

      assert_raise File.Error, fn ->
        Utils.base64_file!(missing)
      end
    end
  end
end
