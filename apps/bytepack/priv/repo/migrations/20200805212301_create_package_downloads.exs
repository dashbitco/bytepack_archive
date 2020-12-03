defmodule Bytepack.Repo.Migrations.CreatePackageDownloads do
  use Ecto.Migration

  def change do
    create table(:package_downloads, primary_key: false) do
      add :org_id, references(:orgs), null: false, primary_key: true
      add :user_id, references(:users), null: false, primary_key: true
      add :release_id, references(:releases), null: false, primary_key: true

      add :size, :integer,
        null: false,
        primary_key: true,
        comment: "size in bytes of the package"

      add :date, :date, null: false, primary_key: true

      add :counter, :integer, null: false, default: 0
    end

    create unique_index(:package_downloads, [:org_id, :user_id, :release_id, :size, :date])
  end
end
