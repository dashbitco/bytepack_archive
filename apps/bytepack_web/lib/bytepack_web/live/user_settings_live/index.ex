defmodule BytepackWeb.UserSettingsLive.Index do
  use BytepackWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    socket = MountHelpers.assign_defaults(socket, params, session, [:user, :write])
    {:ok, assign(socket, :page_title, "User Settings")}
  end

  @impl true
  def handle_info({:flash, key, message}, socket) do
    {:noreply, put_flash(socket, key, message)}
  end
end
