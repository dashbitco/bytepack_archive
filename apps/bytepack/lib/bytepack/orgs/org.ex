defmodule Bytepack.Orgs.Org do
  use Bytepack.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Bytepack.Accounts.User
  alias Bytepack.Orgs.Membership

  schema "orgs" do
    field :name, :string
    field :slug, :string
    field :email, :string
    field :is_seller, :boolean

    has_many :memberships, Membership
    timestamps()
  end

  def by_user(%User{} = user) do
    from(o in __MODULE__,
      join: ms in assoc(o, :memberships),
      on: [member_id: ^user.id]
    )
  end

  def insert_changeset(attrs) do
    %__MODULE__{}
    |> update_changeset(attrs)
    |> cast(attrs, [:slug])
    |> validate_required([:slug])
    |> validate_format(:slug, ~r/^[a-z\d\-]+$/,
      message: "should only contain lower case ASCII letters (from a to z), digits and -"
    )
    |> unique_constraint(:slug)
    |> unsafe_validate_unique(:slug, Bytepack.Repo)
  end

  def update_changeset(org, attrs) do
    org
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> Bytepack.Extensions.Ecto.Validations.validate_email(:email)
  end
end
