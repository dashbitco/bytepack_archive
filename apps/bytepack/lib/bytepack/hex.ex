defmodule Bytepack.Hex do
  import Ecto.Changeset
  import Ecto.Query
  alias Bytepack.Packages.{Package, Release, Store}
  alias Bytepack.{AuditLog, Hex, Repo}

  @doc """
  Returns Hex registry for the given `org`.
  """
  def get_registry_by_org!(org) do
    registry = Repo.get_by!(Hex.Registry, org_id: org.id)
    %{registry | org: org}
  end

  def latest_release(%Package{releases: [latest | _]}) do
    latest
    |> Hex.Release.by_release()
    |> Repo.one!()
    |> Map.replace!(:release, latest)
  end

  @doc """
  Returns a map of top-level internal dependencies for the given `packages`.

  The map keys are package ids and the values are sets of their dependency ids.
  """
  def deps_map(packages) do
    ids = Enum.map(packages, & &1.id)
    names_to_ids = Map.new(packages, &{&1.name, &1.id})

    package_id_to_deps =
      Repo.all(
        from(hr in Hex.Release,
          join: r in assoc(hr, :release),
          where: r.package_id in ^ids,
          select: {r.package_id, hr.deps}
        )
      )

    for {package_id, deps} <- package_id_to_deps,
        %{repository: nil, package: dep_name} <- deps,
        reduce: %{} do
      acc ->
        dep_id = Map.fetch!(names_to_ids, dep_name)
        Map.update(acc, package_id, MapSet.new([dep_id]), &MapSet.put(&1, dep_id))
    end
  end

  @doc """
  Publish a tarball into registry.

  ## Options

    * `:replace` - if `true`, allows already published release to be overriden,
      defaults to `false`
  """
  def publish(audit_context, org, tarball, opts \\ []) do
    ensure_registry!(org)

    with {:ok, result} <- :hex_tarball.unpack(tarball, :memory),
         {:ok, operations} <- do_publish(audit_context, org, result, byte_size(tarball), opts) do
      name = operations.package.name
      version = operations.hex_release.release.version

      Store.put!(tarball_path(org.id, name, version), tarball)
      {:ok, operations}
    else
      {:error, _, changeset, _} ->
        {:error, changeset}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a Hex registry for `org`.
  """
  def create_registry!(org) do
    {private_key, public_key} = generate_random_keys()
    Repo.insert!(%Hex.Registry{org: org, private_key: private_key, public_key: public_key})
  end

  @doc """
  Ensures the `org` has a Hex registry.
  """
  def ensure_registry!(org) do
    {:ok, registry} =
      Repo.transaction(fn ->
        case Repo.get_by(Hex.Registry, org_id: org.id) do
          %Hex.Registry{} = registry ->
            %{registry | org: org}

          nil ->
            create_registry!(org)
        end
      end)

    registry
  end

  defp do_publish(audit_context, org, result, size, opts) do
    %{"name" => name, "version" => version} = result.metadata
    repo_name = org.slug

    on_conflict =
      if opts[:replace] do
        {:replace_all_except, [:id]}
      else
        :nothing
      end

    Ecto.Multi.new()
    |> Ecto.Multi.run(:get_package, fn repo, %{} ->
      {:ok, repo.get_by(Package, org_id: org.id, name: name)}
    end)
    |> Ecto.Multi.insert_or_update(:package, fn %{get_package: package} ->
      if package do
        change(package)
      else
        params = %{type: "hex", name: name, description: result.metadata["description"]}
        Package.changeset(%Package{org_id: org.id}, params)
      end
    end)
    |> Ecto.Multi.insert(
      :release,
      fn %{package: package} ->
        Release.changeset(%Release{package: package, size_in_bytes: size}, %{version: version})
      end,
      on_conflict: on_conflict,
      conflict_target: [:version, :package_id]
    )
    |> Ecto.Multi.insert(
      :hex_release,
      fn %{release: release} ->
        deps =
          for {package, map} <- Map.get(result.metadata, "requirements", []) do
            %Bytepack.Hex.Release.Dep{
              package: package,
              app: Map.fetch!(map, "app"),
              optional: Map.fetch!(map, "optional"),
              repository: normalize_dep_repository(Map.fetch!(map, "repository"), repo_name),
              requirement: Map.fetch!(map, "requirement")
            }
          end

        changeset =
          change(%Hex.Release{release: release}, %{
            inner_checksum: result.inner_checksum,
            outer_checksum: result.outer_checksum,
            deps: deps
          })

        if release.id do
          changeset
        else
          add_error(
            changeset,
            :inserted_at,
            "must include `--replace` flag on `mix hex.publish` to update an existing release. The flag is available from Hex v0.20.6+."
          )
        end
      end,
      on_conflict: on_conflict,
      conflict_target: :release_id
    )
    |> AuditLog.multi(audit_context, "packages.publish_package", fn
      audit_context, %{package: package} ->
        %{
          audit_context
          | params: %{
              package_id: package.id,
              release_version: version
            }
        }
    end)
    |> Repo.transaction()
  end

  defp normalize_dep_repository("hexpm", _repo) do
    "hexpm"
  end

  # when dependency repo is the same as the repo, it's an internal dependency
  defp normalize_dep_repository(repo, repo) do
    nil
  end

  defp normalize_dep_repository(dep_repo, _repo) do
    raise ArgumentError, "#{inspect(dep_repo)} is external and thus not supported"
  end

  @doc false
  def tarball_path(org_id, package_name, version) do
    Path.join(["pkg", to_string(org_id), "hex", "tarballs", "#{package_name}-#{version}.tar"])
  end

  @doc """
  Gets tarball from the registry based on `Org` and `basename`.
  """
  @spec get_tarball_request(%Bytepack.Packages.Package{}, binary()) :: Finch.Request.t()
  def get_tarball_request(package, version) do
    Store.get_request(tarball_path(package.org_id, package.name, version))
  end

  @doc """
  Gets a `Hex.Release` for a given `package` and `version`.
  """
  @spec get_hex_release!(%Package{}, binary()) :: %Hex.Release{}
  def get_hex_release!(package, version) do
    release = Bytepack.Packages.get_release_by_version!(package, version)

    release
    |> Hex.Release.by_release()
    |> Repo.one!()
    |> Map.replace!(:release, release)
  end

  @doc """
  Builds the /names resource.
  """
  def build_names(registry, packages) do
    packages =
      for package <- packages do
        %{name: package.name}
      end

    %{repository: registry.org.slug, packages: packages}
    |> :hex_registry.encode_names()
    |> sign_and_gzip(registry.private_key)
  end

  @doc """
  Builds the /versions resource.
  """
  def build_versions(registry, packages) do
    packages =
      for package <- packages do
        versions = Enum.map(package.releases, & &1.version)
        %{name: package.name, versions: versions}
      end

    %{repository: registry.org.slug, packages: packages}
    |> :hex_registry.encode_versions()
    |> sign_and_gzip(registry.private_key)
  end

  @doc """
  Builds the /package/:name resource.
  """
  def build_package(registry, package) do
    hex_releases =
      package
      |> Hex.Release.by_package()
      |> Repo.all()
      |> Enum.sort_by(& &1.release.version, Version)

    releases =
      for hex_release <- hex_releases do
        dependencies =
          for dep <- hex_release.deps do
            dep = Map.drop(dep, [:__struct__])

            # internal dependency has no :repository key in the protobuf resource
            if dep.repository == nil do
              Map.delete(dep, :repository)
            else
              dep
            end
          end

        %{
          version: hex_release.release.version,
          inner_checksum: hex_release.inner_checksum,
          outer_checksum: hex_release.outer_checksum,
          dependencies: dependencies
        }
      end

    %{repository: registry.org.slug, name: package.name, releases: releases}
    |> :hex_registry.encode_package()
    |> sign_and_gzip(registry.private_key)
  end

  ## Registry Utilities

  defp sign_and_gzip(protobuf, private_key) do
    protobuf
    |> :hex_registry.sign_protobuf(private_key)
    |> :zlib.gzip()
  end

  ## Keys Utilities

  defp generate_random_keys() do
    {:ok, private_key} = generate_rsa_key(2048, 65537)
    public_key = extract_public_key(private_key)
    {pem_encode(:RSAPrivateKey, private_key), pem_encode(:RSAPublicKey, public_key)}
  end

  require Record

  Record.defrecordp(
    :rsa_private_key,
    :RSAPrivateKey,
    Record.extract(:RSAPrivateKey, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  Record.defrecordp(
    :rsa_public_key,
    :RSAPublicKey,
    Record.extract(:RSAPublicKey, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  defp pem_encode(type, key) do
    :public_key.pem_encode([:public_key.pem_entry_encode(type, key)])
  end

  defp generate_rsa_key(keysize, e) do
    private_key = :public_key.generate_key({:rsa, keysize, e})
    {:ok, private_key}
  end

  defp extract_public_key(rsa_private_key(modulus: m, publicExponent: e)) do
    rsa_public_key(modulus: m, publicExponent: e)
  end
end
