defmodule BytepackWeb.UserSettingsControllerTest do
  use BytepackWeb.ConnCase, async: true

  alias Bytepack.{Accounts, AuditLog}
  import Bytepack.AccountsFixtures

  setup :register_and_login_user

  describe "GET /users/settings" do
    test "renders settings page", %{conn: conn} do
      conn = get(conn, Routes.user_settings_path(conn, :index))
      response = html_response(conn, 200)
      assert response =~ ~s|<h4 class="page-title">Settings</h4>|
    end

    test "redirects if user is not logged in" do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :index))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
    end
  end

  describe "PUT /users/settings/update_password" do
    test "updates the user password and resets tokens", %{conn: conn, user: user} do
      new_password_conn =
        put(conn, Routes.user_settings_path(conn, :update_password), %{
          "current_password" => valid_user_password(),
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == "/users/settings"
      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)
      assert get_flash(new_password_conn, :info) =~ "Password updated successfully"
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "redirects back to settings on invalid data", %{conn: conn} do
      failed_change_conn =
        put(conn, Routes.user_settings_path(conn, :update_password), %{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert redirected_to(failed_change_conn) == "/users/settings"

      assert get_flash(failed_change_conn, :error) =~
               "We were unable to update your password. Please try again."

      assert get_session(failed_change_conn, :user_token) == get_session(conn, :user_token)
    end
  end

  describe "GET /users/settings/confirm_email/:token" do
    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_user_email_instructions(
            AuditLog.system(),
            %{user | email: email},
            user.email,
            url
          )
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :index)
      assert get_flash(conn, :info) =~ "E-mail changed successfully"
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :index)
      assert get_flash(conn, :error) =~ "Email change token is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, "oops"))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :index)
      assert get_flash(conn, :error) =~ "Email change token is invalid or it has expired"
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
    end
  end
end
