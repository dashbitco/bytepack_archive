defmodule BytepackWeb.TeamLive.MembershipFormComponent do
  use BytepackWeb, :live_component
  alias Bytepack.Orgs

  @impl true
  def render(assigns) do
    ~L"""
    <div class="modal-header">
      <h4 class="modal-title"><%= @title %></h4>
    </div>
    <div class="modal-body">
      <p>
      Edit "<%= @membership.member.email %>" membership.
      </p>

      <%= f = form_for @changeset, "#",
                id: "form-membership",
                phx_target: @myself,
                phx_change: "validate",
                phx_submit: "save" %>
        <%= input f, :role, label: "Role", using: :select, options: @roles %>

        <%= if @membership.member_id == @current_membership.member_id do %>
          <div class="alert alert-warning" role="alert">
            <strong>Be careful</strong>: by removing yourself from admins you won't be able to regain access.
          </div>
        <% end %>

        <%= live_submit() %>
      </form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = Orgs.change_membership(assigns.membership)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:roles, Orgs.membership_roles())
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"membership" => params}, socket) do
    changeset =
      socket.assigns.membership
      |> Orgs.change_membership(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"membership" => params}, socket) do
    case Orgs.update_membership(socket.assigns.audit_context, socket.assigns.membership, params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Membership updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
