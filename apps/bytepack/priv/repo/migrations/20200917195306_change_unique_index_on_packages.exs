defmodule Bytepack.Repo.Migrations.ChangeUniqueIndexOnPackages do
  use Ecto.Migration

  def change do
    drop index(:packages, [:name, :org_id], unique: true)
    create index(:packages, [:name, :type], unique: true)
  end
end
