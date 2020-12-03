defmodule Bytepack.Packages.PackageTest do
  use Bytepack.DataCase, async: true

  alias Bytepack.Packages.Package

  test "add_deps/2" do
    deps_map = %{
      2 => MapSet.new([1]),
      3 => MapSet.new([2])
    }

    assert Package.add_deps([1], deps_map) == [1]
    assert Package.add_deps([2], deps_map) == [1, 2]
    assert Package.add_deps([1, 2], deps_map) == [1, 2]
    assert Package.add_deps([3], deps_map) == [1, 2, 3]
    assert Package.add_deps([2, 3], deps_map) == [1, 2, 3]
    assert Package.add_deps([1, 3], deps_map) == [1, 2, 3]
    assert Package.add_deps([1, 2, 3], deps_map) == [1, 2, 3]
  end
end
