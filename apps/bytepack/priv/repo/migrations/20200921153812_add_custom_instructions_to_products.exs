defmodule Bytepack.Repo.Migrations.AddCustomInstructionsToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :custom_instructions, :text
    end
  end
end
