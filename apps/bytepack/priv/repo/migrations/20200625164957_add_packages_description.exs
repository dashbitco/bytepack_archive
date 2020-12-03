defmodule Bytepack.Repo.Migrations.AddPackagesDescription do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add :description, :string
    end

    execute "update packages set description = ''"

    alter table(:packages) do
      modify :description, :string, null: false
    end
  end
end
