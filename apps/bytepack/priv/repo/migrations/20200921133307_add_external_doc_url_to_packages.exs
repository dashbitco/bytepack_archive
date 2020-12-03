defmodule Bytepack.Repo.Migrations.AddExternalDocToPackages do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add :external_doc_url, :string
    end
  end
end
