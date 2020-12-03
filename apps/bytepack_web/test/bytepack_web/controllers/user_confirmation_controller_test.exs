defmodule BytepackWeb.UserConfirmationControllerTest do
  use BytepackWeb.ConnCase, async: true

  alias Bytepack.Accounts
  alias Bytepack.Repo
  import Bytepack.AccountsFixtures

  setup do
    %{user: user_fixture(confirmed: false)}
  end

  describe "GET /users/confirm" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, Routes.user_confirmation_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h4>Resend confirmation instructions</h4>"
    end
  end

  describe "POST /users/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.user_confirmation_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :info) =~ "If your e-mail is in our system"
      assert Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "confirm"
    end

    test "does not send confirmation token if account is confirmed", %{conn: conn, user: user} do
      Repo.update!(Accounts.User.confirm_changeset(user))

      conn =
        post(conn, Routes.user_confirmation_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :info) =~ "If your e-mail is in our system"
      refute Repo.get_by(Accounts.UserToken, user_id: user.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.user_confirmation_path(conn, :create), %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :info) =~ "If your e-mail is in our system"
      assert Repo.all(Accounts.UserToken) == []
    end
  end

  describe "GET /users/confirm/:token" do
    test "confirms the given token once", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      conn = get(conn, Routes.user_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :info) =~ "Account confirmed successfully"
      assert Accounts.get_user!(user.id).confirmed_at
      refute get_session(conn, :user_token)
      assert Repo.all(Accounts.UserToken) == []

      # When not logged in
      conn = get(conn, Routes.user_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :error) =~ "Account confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> login_user(user)
        |> get(Routes.user_confirmation_path(conn, :confirm, token))

      assert redirected_to(conn) == Routes.dashboard_index_path(conn, :index)
      refute get_flash(conn, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_confirmation_path(conn, :confirm, "oops"))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :error) =~ "Account confirmation link is invalid or it has expired"
      refute Accounts.get_user!(user.id).confirmed_at
    end
  end
end
