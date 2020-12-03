defmodule Bytepack.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  def change do
    create table(:orgs_invitations) do
      add :email, :string, null: false
      add :org_id, references(:orgs, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all)
      timestamps()
    end

    create unique_index(:orgs_invitations, [:email, :org_id])
    create index(:orgs_invitations, [:user_id])
  end
end
