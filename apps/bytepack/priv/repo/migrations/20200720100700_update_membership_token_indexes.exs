defmodule Bytepack.Repo.Migrations.UpdateMembershipTokenIndexes do
  use Ecto.Migration

  def change do
    drop index(:orgs_memberships, [:write_token])
    drop index(:orgs_memberships, [:read_token])

    create unique_index(:orgs_memberships, [:org_id, :write_token])
    create unique_index(:orgs_memberships, [:org_id, :read_token])
  end
end
