defmodule Bytepack.Repo.Migrations.AddWebhookHTTPSignatureSecretToSellers do
  use Ecto.Migration

  def change do
    alter table(:orgs) do
      add :webhook_http_signature_secret, :binary
    end

    create unique_index(:orgs, [:webhook_http_signature_secret], where: "is_seller = true")
  end
end
