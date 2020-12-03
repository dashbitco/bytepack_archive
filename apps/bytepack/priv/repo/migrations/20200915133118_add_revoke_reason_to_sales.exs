defmodule Bytepack.Repo.Migrations.AddRevokeReasonToSales do
  use Ecto.Migration

  def change do
    alter table(:sales) do
      add :revoke_reason, :string
    end
  end
end
