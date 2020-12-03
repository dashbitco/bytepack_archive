defmodule Bytepack.Repo.Migrations.AddSalesToken do
  use Ecto.Migration

  def change do
    alter table(:sales) do
      add :token, :binary, null: false
    end
  end
end
