defmodule BytepackWeb.UserSessionControllerTest do
  use BytepackWeb.ConnCase, async: true

  import Bytepack.AccountsFixtures
  alias Bytepack.AuditLog

  setup do
    %{user: user_fixture()}
  end

  describe "GET /users/login" do
    test "renders login page", %{conn: conn} do
      conn = get(conn, Routes.user_session_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h4>Log in</h4>"
      assert response =~ "Register new account</a>"
    end

    test "does not render password from url", %{conn: conn} do
      conn =
        get(conn, Routes.user_session_path(conn, :new), user: [password: "thisisaurlpassword"])

      response = html_response(conn, 200)
      refute response =~ "thisisaurlpassword"
    end

    test "redirects if already logged in", %{conn: conn, user: user} do
      conn = conn |> login_user(user) |> get(Routes.user_session_path(conn, :new))
      assert redirected_to(conn) == Routes.dashboard_index_path(conn, :index)
    end
  end

  describe "POST /users/login" do
    test "logs the user in", %{conn: conn, user: user} do
      conn =
        conn
        |> put_req_header("user-agent", "foo/1.0")
        |> put_req_header("x-forwarded-for", "9.9.9.9")
        |> post(Routes.user_session_path(conn, :create), %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == Routes.dashboard_index_path(conn, :index)

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/dashboard")
      response = html_response(conn, 200)
      assert response =~ user.email
      assert response =~ ~r"Settings\s*</a>"
      assert response =~ ~r"Logout\s*</a>"

      [audit_log] = AuditLog.list_by_user(user, action: "accounts.login")
      assert audit_log.ip_address == {9, 9, 9, 9}
      assert audit_log.user_agent == "foo/1.0"
      assert audit_log.user_email == user.email
      refute audit_log.org_id
      assert audit_log.params == %{"email" => user.email}
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(Routes.user_session_path(conn, :create), %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert redirected_to(conn) == "/foo/bar"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.user_session_path(conn, :create), %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["user_remember_me"]
      assert redirected_to(conn) == Routes.dashboard_index_path(conn, :index)
    end

    test "logs the user but marks totp as pending", %{conn: conn, user: user} do
      _ = user_totp_fixture(user)

      conn =
        post(conn, Routes.user_session_path(conn, :create), %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      refute conn.resp_cookies["user_remember_me"]
      assert get_session(conn, :user_totp_pending)
      assert redirected_to(conn) == Routes.user_totp_path(conn, :new, user: [remember_me: true])

      # Accesing any page does not work
      conn = get(conn, "/dashboard")
      assert redirected_to(conn) == Routes.user_totp_path(conn, :new)
    end

    test "emits error message with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.user_session_path(conn, :create), %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h4>Log in</h4>"
      assert response =~ "Invalid e-mail or password"
    end
  end

  describe "DELETE /users/logout" do
    test "redirects if not logged in", %{conn: conn} do
      conn = delete(conn, Routes.user_session_path(conn, :delete))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
    end

    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> login_user(user) |> delete(Routes.user_session_path(conn, :delete))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      refute get_session(conn, :user_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end
  end
end
