defmodule Bytepack.Purchases.BuyerRegistration do
  use Bytepack.Schema

  import Ecto.Changeset

  embedded_schema do
    field :user_email, :string
    field :user_password, :string
    field :organization_name, :string
    field :organization_slug, :string
    field :organization_email, :string
    field :terms_of_service, :boolean
  end

  @fields ~w(user_email user_password organization_name organization_email organization_slug terms_of_service)a

  def changeset(struct, attrs) do
    cast(struct, attrs, @fields)
  end
end
