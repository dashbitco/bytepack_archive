defmodule BytepackWeb.TeamLive.InviteFormComponent do
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
        Send an invitation to the following e-mail address to join your organization.
        They will be able to accept it by logging in to their Bytepack dashboard.
      </p>

      <%= f = form_for @changeset, "#",
                id: "form-invite",
                phx_target: @myself,
                phx_change: "validate",
                phx_submit: "invite" %>
        <%= input f, :email, phx_debounce: "blur" %>
        <%= live_submit() %>
      </form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = Orgs.Invitation.changeset(%Orgs.Invitation{}, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"invitation" => params}, socket) do
    changeset =
      socket.assigns.current_org
      |> Orgs.build_invitation(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("invite", %{"invitation" => params}, socket) do
    org = socket.assigns.current_org
    invitation_url = Routes.dashboard_index_url(socket, :index)

    case Orgs.create_invitation(socket.assigns.audit_context, org, params, invitation_url) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
