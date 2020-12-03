defmodule Bytepack.Repo.Migrations.AddStripeUserIdToOrgs do
  use Ecto.Migration

  def change do
    alter table(:orgs) do
      add :stripe_user_id, :string
    end
  end
end
