defmodule Bytepack.Purchases do
  alias Bytepack.Repo
  alias Bytepack.Packages.Package
  alias Bytepack.Sales
  alias Bytepack.Sales.Sale
  alias Bytepack.Accounts
  alias Bytepack.Orgs
  alias Bytepack.Purchases.BuyerRegistration
  import Ecto.Query

  ## Purchases

  def list_all_purchases(org, preload \\ []) do
    from(Sale,
      where: [buyer_id: ^org.id],
      order_by: [desc: :inserted_at, desc_nulls_first: :revoked_at]
    )
    |> Repo.all()
    |> Repo.preload(preload)
  end

  def list_available_purchases_by_buyer_ids(buyer_ids, preload \\ []) do
    from(p in Sale,
      where: p.buyer_id in ^buyer_ids and is_nil(p.revoked_at),
      order_by: [desc: :inserted_at, desc_nulls_first: :revoked_at]
    )
    |> Repo.all()
    |> Repo.preload(preload)
  end

  def list_pending_purchases_by_email(email) do
    from(p in Sale,
      where: p.email == ^email and is_nil(p.revoked_at) and is_nil(p.buyer_id),
      preload: [:product],
      order_by: [desc: :inserted_at]
    )
    |> Repo.all()
  end

  def get_any_purchase_with_releases!(org, id) do
    Sale
    |> Repo.get_by!(buyer_id: org.id, id: id)
    |> Repo.preload(product: [:seller, packages: :releases])
    |> sort_releases()
  end

  @doc """
  Claims a purchase.

  Returns `{:ok, %Sale{}}`, {:already_claimed, %Sale{}}, or `{:error, message}`.
  """
  def claim_purchase(user, orgs, id, token) do
    sale = Sales.get_sale_by_id_and_token(id, token)
    org_ids = orgs && Enum.map(orgs, & &1.id)

    cond do
      !sale ->
        {:error, "Purchase not found"}

      user && sale.buyer_id in org_ids ->
        sale = Repo.preload(sale, :buyer)
        {:already_claimed, sale}

      Sale.state(sale) != :pending ->
        {:error, "Purchase has already been linked to another account"}

      user && user.email != sale.email ->
        {:error,
         "The purchase was made with a different e-mail address than the one used by this account"}

      true ->
        {:ok, sale}
    end
  end

  def purchase_token(purchase) do
    Base.url_encode64(purchase.token, padding: false)
  end

  ## Packages

  def list_available_packages(org, clauses \\ []) do
    available_packages_query(org)
    |> where(^clauses)
    |> Repo.all()
  end

  def get_available_package_by!(org, clauses) do
    available_packages_query(org)
    |> Repo.get_by!(clauses)
  end

  defp available_packages_query(org) do
    from(Package,
      join: s in "sales",
      on: s.buyer_id == ^org.id,
      on: is_nil(s.revoked_at),
      join: p in "products",
      on: p.id == s.product_id,
      join: pp in "products_packages",
      on: pp.product_id == p.id,
      where: [id: pp.package_id],
      order_by: :name
    )
  end

  defp sort_releases(%Sale{} = sale) do
    update_in(sale.product.packages, fn packages ->
      Enum.map(packages, &sort_releases/1)
    end)
  end

  defp sort_releases(sales) when is_list(sales) do
    Enum.map(sales, &sort_releases/1)
  end

  defp sort_releases(%Package{} = package) do
    Map.update!(package, :releases, fn releases ->
      Enum.sort_by(releases, & &1.version, {:desc, Version})
    end)
  end

  ## Buyer Registration

  @user_mapping %{
    user_email: :email,
    user_password: :password,
    terms_of_service: :terms_of_service
  }

  @org_mapping %{
    organization_name: :name,
    organization_slug: :slug,
    organization_email: :email
  }

  def change_buyer_registration(buyer_registration, attrs) do
    buyer_registration
    |> BuyerRegistration.changeset(attrs)
    |> with_mapping(@user_mapping, fn params ->
      Accounts.change_user_registration(%Accounts.User{}, params)
    end)
    |> with_mapping(@org_mapping, fn params ->
      Orgs.change_org(%Orgs.Org{}, params)
    end)
  end

  def register_buyer(audit_context, sale, attrs) do
    changeset =
      %BuyerRegistration{}
      |> Ecto.Changeset.change(user_email: sale.email)
      |> BuyerRegistration.changeset(attrs)
      |> Map.replace!(:action, :insert)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:user, fn _repo, _ ->
        with_mapping(changeset, @user_mapping, fn params ->
          Accounts.register_user(audit_context, params)
        end)
      end)
      |> Ecto.Multi.run(:confirm_user, fn _repo, %{user: user} ->
        {:ok, Orgs.confirm_and_invite_user!(user)}
      end)
      |> Ecto.Multi.run(:org, fn _repo, %{confirm_user: user} ->
        with_mapping(changeset, @org_mapping, fn params ->
          Orgs.create_org(audit_context, user, params)
        end)
      end)
      |> Ecto.Multi.run(:complete_sale, fn _repo, %{org: org} ->
        {:ok, Sales.complete_sale!(audit_context, sale, org)}
      end)

    case Repo.transaction(multi) do
      {:ok, %{confirm_user: user, org: org, complete_sale: sale}} ->
        {:ok, %{user: user, org: org, sale: sale}}

      {:error, :user, changeset, _} ->
        {:error, changeset}

      {:error, :org, changeset, _} ->
        {:error, changeset}
    end
  end

  defp with_mapping(changeset, mapping, fun) do
    params =
      for {from_key, to_key} <- mapping, into: %{} do
        {to_key, changeset.changes[from_key]}
      end

    case fun.(params) do
      {:ok, struct} ->
        {:ok, struct}

      {:error, to_changeset} ->
        {:error, do_mapping(changeset, to_changeset, mapping)}

      %Ecto.Changeset{} = to_changeset ->
        do_mapping(changeset, to_changeset, mapping)
    end
  end

  defp do_mapping(from_changeset, to_changeset, mapping) do
    reverse_mapping = for {from_key, to_key} <- mapping, into: %{}, do: {to_key, from_key}

    Enum.reduce(to_changeset.errors, from_changeset, fn {to_key, {message, meta}}, acc ->
      Ecto.Changeset.add_error(acc, Map.fetch!(reverse_mapping, to_key), message, meta)
    end)
  end
end
