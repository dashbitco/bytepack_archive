defmodule Bytepack.Repo.Migrations.AddStateToSales do
  use Ecto.Migration

  def change do
    alter table(:sales) do
      add :completed_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec
    end

    create index(:sales, [:completed_at])
    create index(:sales, [:revoked_at])
  end
end
