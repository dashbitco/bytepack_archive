defmodule BytepackWeb.PackageLive.New do
  use BytepackWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:package, :write])
      |> assign(:page_title, "New package")

    if connected?(socket) do
      user = socket.assigns.current_user
      Phoenix.PubSub.subscribe(Bytepack.PubSub, "user:#{user.id}:package:new")
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:published, data}, socket) do
    socket =
      socket
      |> put_flash(:info, "#{data.package_name} v#{data.version} was published successfully!")
      |> push_redirect(
        to:
          Routes.package_show_path(
            socket,
            :show,
            socket.assigns.current_org,
            data.package_type,
            data.package_name
          )
      )

    {:noreply, socket}
  end

  defp hex_step1_snippet(assigns) do
    code_snippet(
      ~L"""
      def project() do
        [
          app: :my_package,
          hex: [api_url: <%= inspect Routes.hex_api_url(@socket, :api_index, @current_org) %>],
          # ... configure your project and package as usual ...
        ]
      end
      """,
      id: "hex_step1"
    )
  end

  defp hex_step2_snippet(assigns) do
    code_snippet(
      ~L"""
      HEX_API_KEY="<%= Bytepack.Orgs.Membership.encode_write_token(@current_membership) %>" mix hex.publish package
      """,
      id: "hex_step2"
    )
  end
end
