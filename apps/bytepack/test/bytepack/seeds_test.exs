defmodule Bytepack.SeedsTest do
  # Do not use async: true as the seeds use unique names
  # instead of random names. This helps avoid deadlocks.
  use Bytepack.DataCase

  test "seeds" do
    assert [] = Bytepack.Repo.all(Bytepack.Orgs.Org)

    Code.require_file(Application.app_dir(:bytepack, "priv/repo/seeds.exs"))

    assert [_ | _] = Bytepack.Repo.all(Bytepack.Orgs.Org)
  end
end
