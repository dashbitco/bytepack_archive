defmodule BytepackWeb.UserSessionController do
  use BytepackWeb, :controller

  alias Bytepack.{Accounts, AuditLog}
  alias BytepackWeb.UserAuth

  plug :put_layout, "authentication.html"

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      audit_context = %{conn.assigns.audit_context | user: user}
      AuditLog.audit!(audit_context, "accounts.login", %{email: email})
      conn = UserAuth.login_user(conn, user)

      if Accounts.get_user_totp(user) do
        totp_params = Map.take(user_params, ["remember_me"])

        conn
        |> put_session(:user_totp_pending, true)
        |> redirect(to: Routes.user_totp_path(conn, :new, user: totp_params))
      else
        UserAuth.redirect_user_after_login_with_remember_me(conn, user_params)
      end
    else
      render(conn, "new.html", error_message: "Invalid e-mail or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.logout_user()
  end
end
