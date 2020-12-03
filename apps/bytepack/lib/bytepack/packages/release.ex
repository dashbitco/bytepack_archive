defmodule Bytepack.Packages.Release do
  use Bytepack.Schema
  import Ecto.Changeset
  alias Bytepack.Packages.Package

  schema "releases" do
    field :version, :string
    field :size_in_bytes, :integer

    belongs_to :package, Package

    timestamps()
  end

  def changeset(release, attrs) do
    release
    |> cast(attrs, [:version])
    |> validate_required([:version])
    |> validate_version(:version)
  end

  defp validate_version(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      case Version.parse(value) do
        {:ok, _} ->
          []

        :error ->
          [{field, "does not follow the Semantic Versioning 2.0 schema"}]
      end
    end)
  end
end
