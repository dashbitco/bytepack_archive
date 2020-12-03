defmodule Bytepack.Repo.Migrations.AddUsersTotps do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :totp_secret, :binary
    end

    create table(:users_totps) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :secret, :binary
      add :backup_codes, :map
      timestamps()
    end

    create unique_index(:users_totps, [:user_id])
  end
end
