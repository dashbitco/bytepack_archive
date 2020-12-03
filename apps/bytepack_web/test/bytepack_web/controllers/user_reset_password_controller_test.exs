defmodule BytepackWeb.UserResetPasswordControllerTest do
  use BytepackWeb.ConnCase, async: true

  alias Bytepack.{Accounts, AuditLog}
  alias Bytepack.Repo
  import Bytepack.AccountsFixtures

  setup do
    %{user: user_fixture(confirmed: false)}
  end

  describe "GET /users/reset_password" do
    test "renders the reset password page", %{conn: conn} do
      conn = get(conn, Routes.user_reset_password_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h4>Forgot your password?</h4>"
    end
  end

  describe "POST /users/reset_password" do
    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.user_reset_password_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :info) =~ "If your e-mail is in our system"
      assert Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.user_reset_password_path(conn, :create), %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :info) =~ "If your e-mail is in our system"
      assert Repo.all(Accounts.UserToken) == []
    end
  end

  describe "GET /users/reset_password/:token" do
    setup %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(AuditLog.system(), user, url)
        end)

      %{token: token}
    end

    test "renders reset password", %{conn: conn, token: token} do
      conn = get(conn, Routes.user_reset_password_path(conn, :edit, token))
      assert html_response(conn, 200) =~ "<h4>Reset password</h4>"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      conn = get(conn, Routes.user_reset_password_path(conn, :edit, "oops"))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :error) =~ "Reset password token is invalid or it has expired"
    end
  end

  describe "PUT /users/reset_password/:token" do
    setup %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(AuditLog.system(), user, url)
        end)

      %{token: token}
    end

    test "resets password once", %{conn: conn, user: user, token: token} do
      conn =
        put(conn, Routes.user_reset_password_path(conn, :update, token), %{
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      refute get_session(conn, :user_token)
      assert get_flash(conn, :info) =~ "Password reset successfully"
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")

      [audit_log] = AuditLog.list_by_user(user, action: "accounts.reset_password.finish")
      assert audit_log.user_email == user.email
      assert audit_log.user_id == user.id
      refute audit_log.org_id
      assert audit_log.params == %{"user_id" => user.id}
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      conn =
        put(conn, Routes.user_reset_password_path(conn, :update, token), %{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(conn, 200)
      assert response =~ "<h4>Reset password</h4>"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match confirmation"
    end

    test "does not reset password with invalid token", %{conn: conn} do
      conn = put(conn, Routes.user_reset_password_path(conn, :update, "oops"))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :error) =~ "Reset password token is invalid or it has expired"
    end
  end
end
