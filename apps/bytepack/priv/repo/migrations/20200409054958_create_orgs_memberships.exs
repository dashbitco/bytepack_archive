defmodule Bytepack.Repo.Migrations.CreateOrgsMemberships do
  use Ecto.Migration

  def change do
    create table(:orgs_memberships) do
      add :org_id, references(:orgs, on_delete: :delete_all), null: false
      add :member_id, references(:users, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:orgs_memberships, [:org_id, :member_id])
  end
end
