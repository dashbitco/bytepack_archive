defmodule Bytepack.Sales.Sale do
  use Bytepack.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "sales" do
    field :email, :string
    field :external_id, :string
    field :token, :binary
    field :completed_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    field :revoke_reason, :string

    belongs_to :product, Bytepack.Sales.Product
    belongs_to :buyer, Bytepack.Orgs.Org

    timestamps()
  end

  def state(%__MODULE__{} = sale) do
    cond do
      sale.revoked_at ->
        :revoked

      sale.buyer_id ->
        :active

      true ->
        :pending
    end
  end

  def for_seller(seller) do
    from(s in __MODULE__,
      join: p in assoc(s, :product),
      order_by: [desc: :inserted_at],
      where: p.seller_id == ^seller.id
    )
  end

  def insert_changeset(sale, attrs) do
    sale
    |> cast(attrs, [:product_id, :email, :external_id])
    |> validate_required([:email, :product_id])
    |> Bytepack.Extensions.Ecto.Validations.validate_email(:email)
    |> unique_constraint(:external_id, name: "sales_product_id_external_id_index")
    |> foreign_key_constraint(:product_id)
    |> put_change(:token, :crypto.strong_rand_bytes(32))
  end

  def update_changeset(sale, attrs) do
    sale
    |> cast(attrs, [:product_id, :external_id])
    |> validate_required([:product_id])
    |> foreign_key_constraint(:product_id)
    |> unique_constraint(:external_id, name: "sales_product_id_external_id_index")
  end

  def revoke_changeset(sale, attrs) do
    sale
    |> cast(attrs, [:revoke_reason])
    |> validate_required([:revoke_reason])
    |> validate_length(:revoke_reason, max: 50)
    |> put_change(:revoked_at, DateTime.utc_now())
  end

  def complete_changeset(sale, buyer, completed_at) do
    sale
    |> change(buyer_id: buyer.id, completed_at: completed_at)
    |> validate_change(:completed_at, fn :completed_at, _completed_at ->
      if state(sale) == :revoked do
        [completed_at: "cannot complete a sale that was revoked"]
      else
        []
      end
    end)
  end

  def delete_changeset(sale) do
    sale
    |> change()
    |> validate_deletion()
  end

  def activate_changeset(sale) do
    change(sale, revoked_at: nil)
  end

  defp validate_deletion(changeset) do
    if get_field(changeset, :buyer_id) do
      add_error(changeset, :buyer_id, "cannot be deleted because it is completed")
    else
      changeset
    end
  end
end
