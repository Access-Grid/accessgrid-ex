defmodule AccessGrid.ParamsTest do
  use ExUnit.Case, async: true

  alias AccessGrid.Params

  describe "require/2" do
    test "returns :ok when all required keys are present and non-blank" do
      assert :ok = Params.require(%{name: "X", platform: "apple"}, [:name, :platform])
    end

    test "returns {:error, :missing_required, [key]} when a key is absent from the map" do
      assert {:error, :missing_required, [:name]} =
               Params.require(%{platform: "apple"}, [:name, :platform])
    end

    test "returns {:error, :missing_required, [key]} when a key is explicitly nil" do
      assert {:error, :missing_required, [:name]} =
               Params.require(%{name: nil, platform: "apple"}, [:name, :platform])
    end

    test "treats empty string as missing" do
      assert {:error, :missing_required, [:name]} = Params.require(%{name: ""}, [:name])
    end

    test "treats whitespace-only string as missing" do
      assert {:error, :missing_required, [:name]} = Params.require(%{name: "   "}, [:name])
      assert {:error, :missing_required, [:name]} = Params.require(%{name: "\t\n"}, [:name])
    end

    test "passes padded strings through (preserves caller intent)" do
      assert :ok = Params.require(%{name: " X "}, [:name])
    end

    test "passes empty lists through (server validates collection-emptiness rules)" do
      assert :ok = Params.require(%{keys: []}, [:keys])
    end

    test "passes empty maps through" do
      assert :ok = Params.require(%{metadata: %{}}, [:metadata])
    end

    test "returns every missing key in input order (not just the first)" do
      assert {:error, :missing_required, [:name, :platform, :protocol]} =
               Params.require(%{}, [:name, :platform, :protocol])

      assert {:error, :missing_required, [:a, :c]} =
               Params.require(%{b: "ok"}, [:a, :b, :c])
    end

    test "passes integer 0 through" do
      assert :ok = Params.require(%{count: 0}, [:count])
    end

    test "passes boolean false through" do
      assert :ok = Params.require(%{enabled: false}, [:enabled])
    end
  end

  describe "require_present/2" do
    test "returns :ok for a non-blank value" do
      assert :ok = Params.require_present("tpl_abc", :template_id)
      assert :ok = Params.require_present(" X ", :name)
    end

    test "returns {:error, :missing_required, [name]} for nil" do
      assert {:error, :missing_required, [:template_id]} =
               Params.require_present(nil, :template_id)
    end

    test "returns {:error, :missing_required, [name]} for empty string" do
      assert {:error, :missing_required, [:template_id]} =
               Params.require_present("", :template_id)
    end

    test "returns {:error, :missing_required, [name]} for whitespace-only string" do
      assert {:error, :missing_required, [:template_id]} =
               Params.require_present("   ", :template_id)

      assert {:error, :missing_required, [:template_id]} =
               Params.require_present("\t\n", :template_id)
    end

    test "passes integer 0 through (valid scalar)" do
      assert :ok = Params.require_present(0, :count)
    end

    test "passes boolean false through" do
      assert :ok = Params.require_present(false, :enabled)
    end
  end
end
