defmodule Bytepack.Repo.Migrations.CreatePackages do
  use Ecto.Migration

  def change do
    create table(:packages) do
      add :name, :citext, null: false
      add :type, :string, null: false
      add :org_id, references(:orgs), null: false
      timestamps()
    end

    create unique_index(:packages, [:name, :org_id])

    create table(:releases) do
      add :version, :string, null: false
      add :package_id, references(:packages, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:releases, [:version, :package_id])

    create table(:hex_registries) do
      add :public_key, :text, null: false
      add :private_key, :text, null: false
      add :org_id, references(:orgs), null: false
      timestamps()
    end

    create unique_index(:hex_registries, [:org_id])

    create table(:hex_releases) do
      add :inner_checksum, :binary, null: false
      add :outer_checksum, :binary, null: false
      add :release_id, references(:releases, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:hex_releases, [:release_id])
  end
end
