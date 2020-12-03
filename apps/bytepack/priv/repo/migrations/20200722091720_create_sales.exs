defmodule Bytepack.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    alter table(:orgs) do
      add :is_seller, :boolean, default: false, null: false
    end

    create table(:products) do
      add :name, :string, null: false
      add :description, :string, null: false
      add :seller_id, references(:orgs, on_delete: :delete_all), null: false
      timestamps()
    end

    create table(:products_packages) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :package_id, references(:packages, on_delete: :delete_all), null: false
    end

    create unique_index(:products_packages, [:product_id, :package_id])

    create table(:sales) do
      add :product_id, references(:products), null: false
      add :email, :string, null: false
      add :buyer_id, references(:orgs), null: true
      timestamps()
    end
  end
end
