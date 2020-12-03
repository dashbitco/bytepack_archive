defmodule BytepackWeb.PackageLive.Index do
  use BytepackWeb, :live_view
  alias Bytepack.Packages

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:package, :read])
      |> assign_packages()
      |> assign(:page_title, "Packages")

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"type" => type, "name" => name}, _path, socket) do
    package =
      Packages.get_available_package_by!(socket.assigns.current_org, type: type, name: name)

    {:noreply, assign(socket, :package, package)}
  end

  def handle_params(_params, _path, socket) do
    {:noreply, assign(socket, :package, %Packages.Package{})}
  end

  def latest_version(package), do: hd(package.releases).version

  defp assign_packages(socket) do
    packages =
      Packages.list_available_packages(socket.assigns.current_org) |> Packages.preload_releases()

    assign(socket, :packages, packages)
  end
end
