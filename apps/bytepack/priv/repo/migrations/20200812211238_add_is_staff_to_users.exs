defmodule Bytepack.Repo.Migrations.AddIsStaffToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_staff, :boolean, null: false, default: false
    end
  end
end
