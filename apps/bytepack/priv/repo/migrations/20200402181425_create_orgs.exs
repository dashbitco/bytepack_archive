defmodule Bytepack.Repo.Migrations.CreateOrgs do
  use Ecto.Migration

  def change do
    create table(:orgs) do
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:orgs, [:name])
  end
end
