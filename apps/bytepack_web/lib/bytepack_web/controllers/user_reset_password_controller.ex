defmodule BytepackWeb.UserResetPasswordController do
  use BytepackWeb, :controller

  alias Bytepack.Accounts

  plug :get_user_by_reset_password_token when action in [:edit, :update]
  plug :put_layout, "authentication.html"

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      _ =
        Accounts.deliver_user_reset_password_instructions(
          conn.assigns.audit_context,
          user,
          &Routes.user_reset_password_url(conn, :edit, &1)
        )
    end

    # Regardless of the outcome, show an impartial success/error message.
    conn
    |> put_flash(
      :info,
      "If your e-mail is in our system, you receive instructions to reset your password shortly."
    )
    |> redirect(to: Routes.user_session_path(conn, :new))
  end

  def edit(conn, _params) do
    render(conn, "edit.html", changeset: Accounts.change_user_password(conn.assigns.user))
  end

  # Do not login the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def update(conn, %{"user" => user_params}) do
    case Accounts.reset_user_password(conn.assigns.audit_context, conn.assigns.user, user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: Routes.user_session_path(conn, :new))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp get_user_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if user = Accounts.get_user_by_reset_password_token(token) do
      conn
      |> assign(:user, user)
      |> assign(:token, token)
      |> assign(:audit_context, %{conn.assigns.audit_context | user: user})
    else
      conn
      |> put_flash(:error, "Reset password token is invalid or it has expired.")
      |> redirect(to: Routes.user_session_path(conn, :new))
      |> halt()
    end
  end
end
