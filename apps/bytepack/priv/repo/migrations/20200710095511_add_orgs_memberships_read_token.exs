defmodule Bytepack.Repo.Migrations.AddOrgsMembershipsReadToken do
  use Ecto.Migration

  def change do
    alter table(:orgs_memberships) do
      add :read_token, :binary, null: false
    end

    create unique_index(:orgs_memberships, :read_token)
  end
end
