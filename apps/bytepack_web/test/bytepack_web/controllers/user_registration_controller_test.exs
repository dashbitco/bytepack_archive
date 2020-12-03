defmodule BytepackWeb.UserRegistrationControllerTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Bytepack.AccountsFixtures

  describe "GET /users/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, Routes.user_registration_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h4>Register</h4>"
      assert response =~ "Log in</a>"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> login_user(user_fixture()) |> get(Routes.user_registration_path(conn, :new))
      assert redirected_to(conn) == Routes.dashboard_index_path(conn, :index)
    end
  end

  describe "POST /users/register" do
    @tag :capture_log
    test "creates account and logs the user in", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, Routes.user_registration_path(conn, :create), %{
          "user" => %{
            "email" => email,
            "password" => valid_user_password(),
            "terms_of_service" => "true"
          }
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == Routes.dashboard_index_path(conn, :index)

      # Now do a logged in request and assert on the menu
      conn = get(conn, Routes.dashboard_index_path(conn, :index))
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ ~r"Settings\s*</a>"
      assert response =~ ~r"Logout\s*</a>"

      # New users can always access their settings page
      {:ok, _, html} = live(conn, Routes.user_settings_path(conn, :index))
      assert html =~ "Change e-mail"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, Routes.user_registration_path(conn, :create), %{
          "user" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h4>Register</h4>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
