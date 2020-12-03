defmodule BytepackWeb.PackageLive.Show do
  use BytepackWeb, :live_view
  alias Bytepack.Packages

  @impl true
  def mount(%{"name" => name, "type" => type} = params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:package, :read])
      |> assign(:page_title, "Packages")
      |> assign_package(name: name, type: type)
      |> assign_selected_release_version(params)

    if connected?(socket) do
      user = socket.assigns.current_user
      package = socket.assigns.package
      Phoenix.PubSub.subscribe(Bytepack.PubSub, "user:#{user.id}:package:#{package.id}")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = assign_selected_release_version(socket, params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("choose_package_version", %{"version" => version}, socket) do
    %{current_org: current_org, package: package} = socket.assigns

    url =
      Routes.package_show_path(
        socket,
        :show,
        current_org.slug,
        package.type,
        package.name,
        version
      )

    {:noreply, push_patch(socket, to: url)}
  end

  defp assign_package(socket, params) do
    package = Packages.get_available_package_by!(socket.assigns.current_org, params)
    assign(socket, package: package)
  end

  defp assign_selected_release_version(socket, params) do
    with %{"release_version" => release_version} <- params do
      package = socket.assigns.package
      selected_release = Bytepack.Hex.get_hex_release!(package, release_version)
      assign(socket, :selected_release, selected_release)
    else
      _ -> assign(socket, :selected_release, Bytepack.Hex.latest_release(socket.assigns.package))
    end
  end

  @impl true
  def handle_info({:published, data}, socket) do
    socket =
      socket
      |> assign_package(id: data.package_id)
      |> put_flash(:info, "#{data.package_name} v#{data.version} was published successfully!")

    {:noreply, socket}
  end
end
