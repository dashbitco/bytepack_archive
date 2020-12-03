defmodule Bytepack.Packages do
  import Ecto.Query
  alias Bytepack.Repo
  alias Bytepack.AuditLog
  alias Bytepack.Orgs.{Org, Membership}
  alias Bytepack.Packages.{Package, Release, PackageDownload}

  def list_available_packages(%Org{} = org, clauses \\ []) do
    from(Package, where: [org_id: ^org.id], where: ^clauses, order_by: [asc: :name])
    |> Repo.all()
  end

  def get_available_package_by!(%Org{} = org, clauses) do
    Repo.get_by!(Package, [org_id: org.id] ++ clauses)
    |> preload_releases()
  end

  def get_release_by_version!(%Package{} = package, version) do
    Repo.get_by!(Release, package_id: package.id, version: version)
  end

  def create_package(%Org{} = org, attrs \\ %{}) do
    %Package{org_id: org.id}
    |> Package.changeset(attrs)
    |> Repo.insert()
  end

  def update_package(audit_context, %Package{} = package, attrs \\ %{}) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:package, Package.update_changeset(package, attrs))
    |> AuditLog.multi(audit_context, "packages.update_package", fn
      audit_context, %{package: package} ->
        %{
          audit_context
          | params: %{
              package_id: package.id,
              description: package.description,
              external_doc_url: package.external_doc_url
            }
        }
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{package: package}} -> {:ok, package}
      {:error, :package, changeset, _} -> {:error, changeset}
    end
  end

  def change_package(package, attrs \\ %{}) do
    Package.update_changeset(package, attrs)
  end

  def preload_releases(%Package{} = package) do
    package
    |> Repo.preload(:releases)
    |> Map.update!(:releases, fn releases ->
      Enum.sort_by(releases, & &1.version, {:desc, Version})
    end)
  end

  def preload_releases(packages) when is_list(packages) do
    packages
    |> Repo.preload(:releases)
    |> Enum.map(&preload_releases/1)
  end

  def create_release(%Package{} = package, size_in_bytes, attrs \\ %{}) do
    %Release{package: package, size_in_bytes: size_in_bytes}
    |> Release.changeset(attrs)
    |> Repo.insert()
  end

  def broadcast_published(user_id, package, release, new_package?) do
    topic =
      if new_package? do
        "user:#{user_id}:package:new"
      else
        "user:#{user_id}:package:#{package.id}"
      end

    Phoenix.PubSub.broadcast(
      Bytepack.PubSub,
      topic,
      {:published,
       %{
         package_id: package.id,
         package_name: package.name,
         package_type: package.type,
         version: release.version
       }}
    )
  end

  @doc """
  It increments the download counter of a given release.

  It will track based on date, user and org.
  """
  def increment_download_counter!(
        %Release{} = release,
        %Membership{} = membership,
        date \\ Date.utc_today()
      ) do
    query = from(m in PackageDownload, update: [inc: [counter: 1]])

    Repo.insert!(
      %PackageDownload{
        release_id: release.id,
        org_id: membership.org_id,
        user_id: membership.member_id,
        date: date,
        size: release.size_in_bytes,
        counter: 1
      },
      on_conflict: query,
      conflict_target: [:org_id, :user_id, :release_id, :size, :date]
    )
  end
end
