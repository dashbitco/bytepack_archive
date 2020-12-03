defmodule BytepackWeb.MountHelpers do
  import Phoenix.LiveView
  alias Bytepack.Accounts
  alias Bytepack.Orgs
  alias BytepackWeb.Router.Helpers, as: Routes
  alias BytepackWeb.RequestContext

  @doc """
  Assign default values on the socket.
  """
  def assign_defaults(socket, params, session, acl) do
    socket
    |> assign_current_user(session)
    |> assign_current_membership(params)
    |> assign_current_org()
    |> assign(:navbar, :org)
    |> RequestContext.put_audit_context()
    |> RequestContext.put_sentry_context()
    |> ensure_access(acl)
  end

  @doc """
  Assign default values for users that may or may not be logged in.
  """
  def assign_maybe_logged_in_defaults(socket, user_token) do
    socket
    |> assign_new(:current_user, fn ->
      user_token && Accounts.get_user_by_session_token(user_token)
    end)
    |> RequestContext.put_audit_context()
    |> RequestContext.put_sentry_context()
  end

  @doc """
  Assign admin default values on the socket.
  """
  def assign_admin(socket, _params, session) do
    socket = assign_current_user(socket, session)

    if socket.assigns.current_user.is_staff do
      socket
      |> assign(:navbar, :admin)
      |> RequestContext.put_audit_context()
      |> RequestContext.put_sentry_context()
    else
      raise BytepackWeb.UserAuth.NotStaffError
    end
  end

  defp assign_current_user(socket, session) do
    assign_new(socket, :current_user, fn ->
      Accounts.get_user_by_session_token!(session["user_token"])
    end)
  end

  defp assign_current_membership(socket, params) do
    assign_new(socket, :current_membership, fn ->
      params["org_slug"] && Orgs.get_membership!(socket.assigns.current_user, params["org_slug"])
    end)
  end

  defp assign_current_org(socket) do
    assign_new(socket, :current_org, fn ->
      membership = socket.assigns.current_membership
      membership && membership.org
    end)
  end

  defp ensure_access(socket, [:user, _] = acl) do
    assign(socket, :acl, acl)
  end

  defp ensure_access(socket, acl) do
    cond do
      is_nil(socket.assigns.current_user.confirmed_at) ->
        socket
        |> put_flash(:error, "You need to confirm your account to access this page")
        |> push_redirect(to: Routes.dashboard_index_path(socket, :index))

      not Bytepack.AccessControl.can?(acl, socket.assigns.current_membership) ->
        socket
        |> put_flash(:error, "Access denied")
        |> push_redirect(to: Routes.dashboard_index_path(socket, :index))

      true ->
        assign(socket, :acl, acl)
    end
  end
end
