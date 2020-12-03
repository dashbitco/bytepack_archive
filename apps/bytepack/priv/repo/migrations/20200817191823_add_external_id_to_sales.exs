defmodule Bytepack.Repo.Migrations.AddExternalIdToSales do
  use Ecto.Migration

  def change do
    alter table(:sales) do
      add :external_id, :string
    end

    create unique_index(:sales, [:product_id, :external_id])
  end
end
