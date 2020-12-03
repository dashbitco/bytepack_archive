defmodule Bytepack.Sales.Product do
  use Bytepack.Schema
  import Ecto.Query
  import Ecto.Changeset
  alias Bytepack.Packages.Package

  schema "products" do
    field :name, :string
    field :description, :string
    field :url, :string
    field :custom_instructions, :string
    field :package_ids, {:array, :id}, virtual: true

    belongs_to :seller, Bytepack.Orgs.Org
    has_many :sales, Bytepack.Sales.Sale
    many_to_many :packages, Package, join_through: "products_packages", on_replace: :delete

    timestamps()
  end

  def changeset(struct, params, deps_map) do
    cast(struct, params, ~w(name description url package_ids custom_instructions)a)
    |> validate_required(~w(name description url package_ids)a)
    |> validate_length(:package_ids, min: 1)
    |> Bytepack.Extensions.Ecto.Validations.normalize_and_validate_url(:url)
    |> update_change(:package_ids, &Package.add_deps(&1, deps_map))
    |> prepare_changes(&maybe_keep_existing_package_ids/1)
    |> prepare_changes(&put_packages/1)
  end

  defp maybe_keep_existing_package_ids(changeset) do
    if Bytepack.Sales.can_remove_packages?(changeset.data) do
      changeset
    else
      ids = Enum.uniq(get_change(changeset, :package_ids, []) ++ changeset.data.package_ids)
      force_change(changeset, :package_ids, ids)
    end
  end

  defp put_packages(changeset) do
    if package_ids = get_change(changeset, :package_ids) do
      seller_id = fetch_field!(changeset, :seller_id)

      packages =
        from(p in Package, where: p.org_id == ^seller_id and p.id in ^package_ids)
        |> changeset.repo.all()

      put_assoc(changeset, :packages, packages)
    else
      changeset
    end
  end
end
