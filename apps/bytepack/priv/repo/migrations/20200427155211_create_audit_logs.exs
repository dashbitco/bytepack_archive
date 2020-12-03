defmodule Bytepack.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add :action, :string, null: false
      add :ip_address, :inet
      add :user_agent, :string
      add :user_email, :string
      add :params, :map, null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :org_id, references(:orgs, on_delete: :delete_all)
      timestamps(updated_at: false)
    end

    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:org_id])
  end
end
