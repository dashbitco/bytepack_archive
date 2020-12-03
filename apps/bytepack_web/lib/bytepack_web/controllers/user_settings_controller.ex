defmodule BytepackWeb.UserSettingsController do
  use BytepackWeb, :controller

  alias Bytepack.Accounts
  alias Bytepack.Orgs
  alias BytepackWeb.UserAuth

  def confirm_email(conn, %{"token" => token}) do
    audit_context = conn.assigns.audit_context
    user = conn.assigns.current_user

    case Orgs.update_user_email(audit_context, user, token) do
      :ok ->
        conn
        |> put_flash(:info, "E-mail changed successfully.")
        |> redirect(to: Routes.user_settings_path(conn, :index))

      :error ->
        conn
        |> put_flash(:error, "Email change token is invalid or it has expired.")
        |> redirect(to: Routes.user_settings_path(conn, :index))
    end
  end

  def update_password(conn, %{"current_password" => password, "user" => user_params}) do
    audit_context = conn.assigns.audit_context
    user = conn.assigns.current_user

    case Accounts.update_user_password(audit_context, user, password, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> UserAuth.login_user(user)
        |> redirect(to: Routes.user_settings_path(conn, :index))

      _ ->
        conn
        |> put_flash(:error, "We were unable to update your password. Please try again.")
        |> redirect(to: Routes.user_settings_path(conn, :index))
    end
  end
end
