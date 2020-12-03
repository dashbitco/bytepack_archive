defmodule Bytepack.Repo.Migrations.AddStripeFieldsToOrgs do
  use Ecto.Migration

  def change do
    alter table(:orgs) do
      add :slug, :citext, null: false
      add :legal_name, :string
      add :address_city, :string
      add :address_country, :string, size: 2
      add :address_line1, :string
      add :address_line2, :string
      add :address_postal_code, :string
      add :address_state, :string
    end

    drop unique_index(:orgs, [:name])

    create unique_index(:orgs, [:slug])
  end
end
