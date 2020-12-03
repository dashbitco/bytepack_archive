defmodule Bytepack.Repo.Migrations.AddOrgsEmail do
  use Ecto.Migration

  def change do
    alter table(:orgs) do
      add :email, :string, null: false
    end
  end
end
