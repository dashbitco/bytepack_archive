defmodule Bytepack.Repo.Migrations.AddDepsToHexReleases do
  use Ecto.Migration

  def change do
    alter table(:hex_releases) do
      add :deps, :jsonb, null: false, default: "[]"
    end
  end
end
