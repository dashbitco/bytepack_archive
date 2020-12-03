defmodule Bytepack.Repo.Migrations.AddOrgsMembershipsWriteToken do
  use Ecto.Migration

  def change do
    alter table(:orgs_memberships) do
      add :write_token, :binary, null: false
    end

    create unique_index(:orgs_memberships, :write_token)
  end
end
