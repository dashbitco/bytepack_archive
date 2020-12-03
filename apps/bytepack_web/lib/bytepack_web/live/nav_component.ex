defmodule BytepackWeb.NavComponent do
  use BytepackWeb, :live_component
  alias Bytepack.Orgs

  @impl true
  def update(%{current_user: current_user, current_org: current_org} = assigns, socket) do
    orgs = current_user |> Orgs.list_orgs() |> remove_current_org(current_org)
    {:ok, socket |> assign(assigns) |> assign(:orgs, orgs)}
  end

  defp remove_current_org(orgs, nil), do: orgs
  defp remove_current_org(orgs, %{id: id}), do: Enum.reject(orgs, &(&1.id == id))

  defp nav_item(assigns) do
    ~L"""
    <%= if @show_if_acl == :always or Bytepack.AccessControl.can?(@show_if_acl, @current_membership) do %>
    <li class="nav-item <%= if List.starts_with?(@acl, @active_if_acl), do: "active", else: "" %>">
      <%= live_redirect to: @url, class: "nav-link" do %>
        <i class="<%= @icon %> mr-1"></i><%= @title %>
      <% end %>
    </li>
    <% end %>
    """
  end
end
