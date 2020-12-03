defmodule BytepackWeb.OrgLive.New do
  use BytepackWeb, :live_view

  alias Bytepack.Orgs.Org

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:org, :new])
      |> assign(:page_title, "New Organization")
      |> assign(:org, %Org{})

    {:ok, socket}
  end
end
