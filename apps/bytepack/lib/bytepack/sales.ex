defmodule Bytepack.Sales do
  alias Bytepack.AuditLog
  alias Bytepack.Repo
  alias Bytepack.Sales.{Product, Sale, Seller}
  alias Bytepack.Accounts.UserNotifier
  alias Ecto.Multi

  import Ecto.Query

  ## Products

  def create_product(audit_context, org, attrs, deps_map) do
    product_changeset = change_product(%Product{seller_id: org.id}, attrs, deps_map)

    Multi.new()
    |> Multi.insert(:product, product_changeset)
    |> AuditLog.multi(audit_context, "sales.create_product", %{
      name: product_changeset.changes[:name]
    })
    |> Repo.transaction()
    |> case do
      {:ok, %{product: product}} -> {:ok, product}
      {:error, :product, changeset, _} -> {:error, changeset}
    end
  end

  def update_product(audit_context, product, attrs, deps_map) do
    product_changeset = change_product(product, attrs, deps_map)

    Multi.new()
    |> Multi.update(:product, product_changeset)
    |> AuditLog.multi(audit_context, "sales.update_product", %{
      product_id: product.id,
      original_name: product.name,
      new_name: product_changeset.changes[:name]
    })
    |> Repo.transaction()
    |> case do
      {:ok, %{product: product}} -> {:ok, product}
      {:error, :product, changeset, _} -> {:error, changeset}
    end
  end

  def change_product(product, attrs, deps_map) do
    Product.changeset(product, attrs, deps_map)
  end

  def get_product!(seller, id) do
    Product
    |> Repo.get_by!(seller_id: seller.id, id: id)
    |> Repo.preload(:packages)
  end

  def list_products(seller) do
    from(Product, where: [seller_id: ^seller.id], order_by: :name)
    |> Repo.all()
    |> Repo.preload(:packages)
  end

  def list_products_by_seller_ids(seller_ids) do
    from(p in Product, where: p.seller_id in ^seller_ids, order_by: :name)
    |> Repo.all()
    |> Repo.preload(:packages)
  end

  @doc """
  Returns if a given product can have its packages removed.
  """
  def can_remove_packages?(%Product{} = product) do
    is_nil(product.id) or not has_sales?(product.id)
  end

  defp has_sales?(product_id) do
    Sale
    |> where(product_id: ^product_id)
    |> Repo.exists?()
  end

  ## Sales

  def list_sales(seller) do
    seller
    |> Sale.for_seller()
    |> Repo.all()
    |> Repo.preload([:product, :buyer])
  end

  def create_sale(audit_context, seller, attrs) do
    sale_changeset = Sale.insert_changeset(%Sale{}, attrs)

    Multi.new()
    |> Multi.insert(:sale, sale_changeset)
    |> Multi.run(:product, fn _, %{sale: sale} ->
      get_product_from_seller(sale, seller)
    end)
    |> AuditLog.multi(
      audit_context,
      "sales.create_sale",
      fn audit_context, %{sale: sale} ->
        %{
          audit_context
          | params: %{
              sale_id: sale.id,
              product_id: sale.product_id,
              email: sale.email,
              external_id: sale.external_id
            }
        }
      end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{sale: sale, product: product}} ->
        {:ok, %{sale | product: product}}

      {:error, :sale, changeset, _} ->
        {:error, changeset}

      {:error, :product, error, _} ->
        {:error, Ecto.Changeset.add_error(sale_changeset, :product_id, error)}
    end
  end

  defp get_product_from_seller(%Sale{} = sale, %Seller{} = seller) do
    case Repo.get_by(Product, id: sale.product_id, seller_id: seller.id) do
      %Product{} = product ->
        {:ok, product}

      nil ->
        {:error, "does not belong to organization"}
    end
  end

  def update_sale(audit_context, sale, attrs) do
    sale_changeset = Sale.update_changeset(sale, attrs)

    Multi.new()
    |> Multi.update(:sale, sale_changeset)
    |> AuditLog.multi(audit_context, "sales.update_sale", fn audit_context, %{sale: sale} ->
      %{
        audit_context
        | params: %{
            external_id: sale.external_id,
            sale_id: sale.id,
            product_id: sale.product_id
          }
      }
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{sale: sale}} ->
        {:ok, sale}

      {:error, :sale, changeset, _} ->
        {:error, changeset}
    end
  end

  def get_sale!(seller, id) do
    seller
    |> Sale.for_seller()
    |> Repo.get_by!(id: id)
    |> Repo.preload([:product, :buyer])
  end

  def get_sale_by_external_id!(seller, external_id) do
    seller
    |> Sale.for_seller()
    |> from(where: [external_id: ^external_id])
    |> Repo.one!()
  end

  def get_sale_by_id_and_token(id, encoded_token) do
    query = from(s in Sale, where: s.id == ^id and is_nil(s.revoked_at))

    with {:ok, token} <- Base.url_decode64(encoded_token, padding: false),
         %Sale{} = sale <- Repo.one(query),
         true <- Plug.Crypto.secure_compare(sale.token, token) do
      Repo.preload(sale, :product)
    else
      _ -> nil
    end
  end

  @doc """
  It marks a sale as revoked by putting the timestamp of revocation.

  This will keep the original state.
  """
  def revoke_sale(audit_context, sale, params) do
    if Sale.state(sale) == :revoked do
      {:ok, sale}
    else
      sale_changeset = Sale.revoke_changeset(sale, params)

      audit_params =
        sale_changeset.changes
        |> Map.put_new(:sale_id, sale.id)
        |> Map.put_new(:external_id, sale.external_id)

      Multi.new()
      |> Multi.update(:sale, sale_changeset)
      |> AuditLog.multi(audit_context, "sales.revoke_sale", audit_params)
      |> Repo.transaction()
      |> case do
        {:ok, %{sale: sale}} ->
          {:ok, sale}

        {:error, :sale, changeset, _} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Complete a sale by assigning it to a buyer.

  This sale cannot be deleted after completion.
  """
  def complete_sale!(audit_context, sale, buyer, completed_at \\ DateTime.utc_now()) do
    sale_changeset = Sale.complete_changeset(sale, buyer, completed_at)

    {:ok, updated_sale} =
      Repo.transaction(fn ->
        AuditLog.audit!(%{audit_context | org: buyer}, "sales.complete_sale", %{
          sale_id: sale.id,
          buyer_id: buyer.id,
          external_id: sale.external_id
        })

        user =
          Bytepack.Accounts.get_user_by_email(sale.email) ||
            raise "the email associated with this sale does not have a correspondent user"

        unless user.confirmed_at do
          Bytepack.Accounts.confirm_user!(user)
        end

        Repo.update!(sale_changeset)
      end)

    updated_sale
  end

  def change_sale(sale, attrs \\ %{}) do
    if sale.id do
      Sale.update_changeset(sale, attrs)
    else
      Sale.insert_changeset(sale, attrs)
    end
  end

  def change_revoke_sale(sale, attrs \\ %{}) do
    Sale.revoke_changeset(sale, attrs)
  end

  @doc """
  Deletes a pending sale.
  """
  def delete_sale(audit_context, sale) do
    sale_changeset = Sale.delete_changeset(sale)

    audit_params =
      sale
      |> Map.from_struct()
      |> Map.take([:email, :buyer_id, :product_id, :external_id])
      |> Map.put_new(:sale_id, sale.id)

    Repo.transaction(fn ->
      AuditLog.audit!(
        audit_context,
        "sales.delete_sale",
        audit_params
      )

      Repo.delete!(sale_changeset)
    end)
  end

  @doc """
  Activate a sale that was revoked.
  """
  def activate_sale(audit_context, sale) do
    Repo.transaction(fn ->
      AuditLog.audit!(audit_context, "sales.activate_sale", %{
        sale_id: sale.id,
        external_id: sale.external_id
      })

      sale
      |> Sale.activate_changeset()
      |> Repo.update!()
    end)
  end

  def sale_state(%Sale{} = sale), do: Sale.state(sale)

  def can_be_revoked?(%Sale{} = sale) do
    sale_state(sale) in [:pending, :active]
  end

  def can_be_deleted?(%Sale{} = sale) do
    is_nil(sale.buyer_id) && sale_state(sale) in [:pending, :revoked]
  end

  def can_be_activated?(%Sale{} = sale) do
    sale_state(sale) == :revoked
  end

  def deliver_create_sale_email(sale, url_fun) do
    token = Base.url_encode64(sale.token, padding: false)
    UserNotifier.deliver_create_sale_email(sale, url_fun.(token))
  end

  ## Seller

  def get_seller!(%Bytepack.Orgs.Org{id: id} = org) do
    seller = Repo.get_by!(Seller, id: id, is_seller: true)
    %{seller | org: org}
  end

  @doc """
  Update seller attributes only.
  """
  def update_seller(audit_context, seller, attrs) do
    Multi.new()
    |> Multi.update(:seller, Seller.changeset(seller, attrs))
    |> AuditLog.multi(audit_context, "sales.update_seller", fn audit_context, %{seller: seller} ->
      %{
        audit_context
        | params: %{seller_id: seller.id, legal_name: seller.legal_name}
      }
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{seller: seller}} -> {:ok, seller}
      {:error, :seller, changeset, _} -> {:error, changeset}
    end
  end

  def change_seller(seller, attrs \\ %{}) do
    Seller.changeset(seller, attrs)
  end

  @doc """
  Activate an `Org` that is not `Seller` yet and update it.

  This version is intended to be used by the Admins of the system,
  so we don't keep an audit log.
  """
  def activate_seller(
        %Bytepack.Orgs.Org{id: id} = org,
        %Seller{id: id} = seller,
        attrs
      ) do
    Multi.new()
    |> Multi.run(:enable_seller, fn _, _ -> Bytepack.Orgs.enable_as_seller(org) end)
    |> Multi.update(:update_seller, Seller.changeset(seller, attrs))
    |> Repo.transaction()
    |> case do
      {:ok, %{update_seller: seller}} ->
        {:ok, seller}

      {:error, :update_seller, %Ecto.Changeset{} = changeset, _} ->
        {:error, changeset}
    end
  end

  def encode_http_signature_secret(%Seller{webhook_http_signature_secret: secret})
      when is_binary(secret) do
    "wh_sig_#{Base.url_encode64(secret)}"
  end
end
