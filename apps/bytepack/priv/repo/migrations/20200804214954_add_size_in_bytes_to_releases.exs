defmodule Bytepack.Repo.Migrations.AddSizeInBytesToReleases do
  use Ecto.Migration

  def change do
    alter table(:releases) do
      add :size_in_bytes, :integer, null: false
    end
  end
end
