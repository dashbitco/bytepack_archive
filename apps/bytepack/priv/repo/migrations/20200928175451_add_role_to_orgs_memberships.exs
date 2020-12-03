defmodule Bytepack.Repo.Migrations.AddRoleToOrgsMemberships do
  use Ecto.Migration

  def change do
    alter table(:orgs_memberships) do
      add :role, :string, default: "member", null: false
    end
  end
end
