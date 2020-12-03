defmodule Bytepack.Sales.Seller do
  use Bytepack.Schema

  import Ecto.Changeset

  alias Bytepack.Orgs.Country

  @http_signature_size 32

  schema "orgs" do
    field :slug
    field :email, :string
    field :is_seller, :boolean
    field :stripe_user_id, :string
    field :webhook_http_signature_secret, :binary

    field :legal_name, :string
    field :address_city, :string
    field :address_country, :string
    field :address_line1, :string
    field :address_line2, :string
    field :address_postal_code, :string
    field :address_state, :string

    belongs_to :org, Bytepack.Orgs.Org, references: :id, define_field: false

    timestamps()
  end

  def changeset(%__MODULE__{} = seller, attrs \\ %{}) do
    fields = [
      :legal_name,
      :address_city,
      :address_country,
      :address_line1,
      :address_line2,
      :address_postal_code,
      :address_state
    ]

    seller
    |> cast(attrs, fields)
    |> validate_required([
      :legal_name,
      :address_city,
      :address_country,
      :address_line1
    ])
    |> validate_inclusion(:address_country, Country.codes())
    |> maybe_put_secret(:webhook_http_signature_secret)
  end

  defp maybe_put_secret(changeset, field) do
    if get_field(changeset, field) do
      changeset
    else
      put_change(changeset, field, :crypto.strong_rand_bytes(@http_signature_size))
    end
  end
end
