defmodule BytepackWeb.TeamLive.Index do
  use BytepackWeb, :live_view
  alias Bytepack.Orgs

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:team, :read])
      |> assign(:page_title, "Team")
      |> assign_memberships()
      |> assign_invitations()

    {:ok, socket, temporary_assigns: [members: nil, invitations: nil]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Team")
  end

  defp apply_action(socket, :invite, _params) do
    socket
    |> assign(:page_title, "Invite")
  end

  defp apply_action(socket, :edit_membership, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit member")
    |> assign(:membership, Orgs.get_membership!(id))
  end

  @impl true
  def handle_event("delete_member", %{"id" => id}, socket) do
    org = socket.assigns.current_org
    %{membership: membership} = Orgs.delete_member!(socket.assigns.audit_context, org, id)

    if membership.member_id == socket.assigns.current_user.id do
      {:noreply,
       socket
       |> put_flash(:info, "You have left #{org.name}")
       |> push_redirect(to: Routes.dashboard_index_path(socket, :index))}
    else
      # Cause all users sessions to reconnect. In theory this will
      # affect even users currently not looking at the current
      # organization page but this is uncommon to matter in practive.
      BytepackWeb.UserAuth.reconnect_user_sessions(membership.member_id)

      {:noreply,
       socket
       |> put_flash(:info, "Member deleted successfully")
       |> assign_memberships()}
    end
  end

  @impl true
  def handle_event("delete_invitation", %{"id" => id}, socket) do
    org = socket.assigns.current_org
    invitation = Orgs.get_invitation_by_org!(org, id)
    Orgs.delete_invitation!(socket.assigns.audit_context, invitation)

    {:noreply,
     socket
     |> put_flash(:info, "Invitation deleted successfully")
     |> assign_invitations()}
  end

  # TODO: change the role to remove the last member and count Admins
  defp delete_member_button(member, members_count, current_user, current_org) do
    {icon, confirmation_text, button_text} =
      if current_user.id == member.id do
        {"icon-minus-circle", "Are you sure you want to leave #{current_org.name}?",
         "Leave #{current_org.name}"}
      else
        {"icon-user-minus",
         "Are you sure you want remove #{member.email} from #{current_org.name}?", "Remove user"}
      end

    ~E"""
    <%= button data: [confirm: confirmation_text],
      tooltip: members_count == 1 && "Cannot remove last member of the organization",
      disabled: members_count == 1,
      class: "btn-outline-danger btn-sm",
      phx_click: "delete_member",
      phx_value_id: member.id do %>
      <i class="feather-icon <%= icon %> mr-1"></i>
      <%= button_text %>
    <% end %>
    """
  end

  defp assign_memberships(socket) do
    memberships = Orgs.list_memberships_by_org(socket.assigns.current_org)
    assign(socket, memberships: memberships, members_count: length(memberships))
  end

  defp assign_invitations(socket) do
    invitations = Orgs.list_invitations_by_org(socket.assigns.current_org)
    assign(socket, :invitations, invitations)
  end
end
