defmodule Bytepack.Packages.Package do
  use Bytepack.Schema
  import Ecto.Changeset

  @types ~w(hex npm)

  schema "packages" do
    field :name, :string
    field :type, :string
    field :description, :string
    field :external_doc_url, :string
    field :org_id, :id

    has_many :releases, Bytepack.Packages.Release
    timestamps()
  end

  @doc false
  def changeset(package, attrs) do
    package
    |> cast(attrs, [:name, :type, :description])
    |> validate_required([:name, :type, :description])
    |> validate_inclusion(:type, @types)
    |> validate_length(:name, min: 2)
    |> validate_format(:name, ~r"^[a-z]\w*$")
    |> unique_constraint([:name, :type])
  end

  def update_changeset(package, attrs) do
    package
    |> cast(attrs, [:description, :external_doc_url])
    |> validate_required([:description])
    |> Bytepack.Extensions.Ecto.Validations.normalize_and_validate_url(:external_doc_url)
  end

  @doc """
  Update the given `package_ids` with corresponding ones from `deps_map`.
  """
  def add_deps(package_ids, deps_map) do
    MapSet.new()
    |> add_deps(package_ids, deps_map)
    |> MapSet.to_list()
  end

  defp add_deps(acc, [id | rest], deps_map) do
    acc
    |> MapSet.put(id)
    |> add_deps(rest, deps_map)
    |> add_deps(Enum.to_list(Map.get(deps_map, id, [])), deps_map)
  end

  defp add_deps(acc, [], _deps_map) do
    acc
  end
end
