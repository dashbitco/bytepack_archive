defmodule BytepackWeb.ModalComponent do
  use BytepackWeb, :live_component

  @impl true
  def render(assigns) do
    ~L"""
    <div class="live-modal" tabindex="-1"
      phx-capture-click="close"
      phx-window-keydown="close"
      phx-key="escape"
      phx-target="<%= @myself %>"
      phx-page-loading>

      <div class="modal-dialog modal-lg"  role="document">
        <div class="modal-content">
          <%= live_patch raw("&times;"), to: @return_to, class: "close" %>
          <%= live_component @socket, @component, @opts %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("close", _, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.return_to)}
  end
end
