defmodule Bytepack.Repo.Migrations.AddProductUrl do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :url, :string, null: false
    end
  end
end
