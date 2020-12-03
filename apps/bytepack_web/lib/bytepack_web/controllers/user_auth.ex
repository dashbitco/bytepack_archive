defmodule BytepackWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias Bytepack.Accounts
  alias BytepackWeb.Router.Helpers, as: Routes

  defmodule NotStaffError do
    defexception plug_status: 404, message: "staff status is required to access this page"
  end

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.
  """
  def login_user(conn, user) do
    token = Accounts.generate_user_session_token(user)

    conn
    |> renew_session()
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, user_session_topic(token))
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after login/logout,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     def renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> put_session(:user_return_to, user_return_to)
  end

  @doc """
  Returns to or redirects home and potentially set remember_me token.
  """
  def redirect_user_after_login_with_remember_me(conn, params \\ %{}) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> maybe_remember_user(params)
    |> delete_session(:user_return_to)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_remember_user(conn, %{"remember_me" => "true"}) do
    token = get_session(conn, :user_token)
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_remember_user(conn, _params) do
    conn
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def logout_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      BytepackWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: Routes.user_session_path(conn, :new))
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)
    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if user_token = get_session(conn, :user_token) do
      {user_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if user_token = conn.cookies[@remember_me_cookie] do
        {user_token, put_session(conn, :user_token, user_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Used for routes that requires the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that requires the user to be authenticated.

  If you want to enforce the user e-mail is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    cond do
      is_nil(conn.assigns[:current_user]) ->
        conn
        |> put_flash(:error, "You must log in to access this page.")
        |> maybe_store_user_return_to()
        |> redirect(to: Routes.user_session_path(conn, :new))
        |> halt()

      get_session(conn, :user_totp_pending) && conn.path_info != ["users", "totp"] &&
          conn.path_info != ["users", "logout"] ->
        conn
        |> redirect(to: Routes.user_totp_path(conn, :new))
        |> halt()

      true ->
        conn
    end
  end

  @doc """
  Only staff members can access.
  """
  def require_staff(conn, _opts) do
    if conn.assigns.current_user.is_staff do
      conn
    else
      raise NotStaffError
    end
  end

  defp signed_in_path(conn), do: Routes.dashboard_index_path(conn, :index)

  @doc """
  Stores return to in the session as long as it is a GET request
  and the user is not authenticated.
  """
  def maybe_store_user_return_to(conn, _opts) do
    maybe_store_user_return_to(conn)
  end

  defp maybe_store_user_return_to(%{assigns: %{current_user: %{}}} = conn), do: conn

  defp maybe_store_user_return_to(%{method: "GET"} = conn) do
    %{request_path: request_path, query_string: query_string} = conn
    return_to = if query_string == "", do: request_path, else: request_path <> "?" <> query_string
    put_session(conn, :user_return_to, return_to)
  end

  defp maybe_store_user_return_to(conn), do: conn

  ## PubSub helpers

  @doc """
  Reconnects all sessions for the given user.

  This is typically invoked when permissions are removed from a user,
  such as they no longer belong to an organization.
  """
  def reconnect_user_sessions(id) do
    for user_token <- Accounts.list_user_session_tokens(id) do
      reconnect_user_session(user_token.token)
    end

    :ok
  end

  defp user_session_topic(token), do: "user_sessions:" <> token

  # Even tough the function is called "disconnect", the effect in
  # a LiveView app is to cause reconnection.
  defp reconnect_user_session(token) do
    BytepackWeb.Endpoint.broadcast(user_session_topic(token), "disconnect", %{})
  end
end
