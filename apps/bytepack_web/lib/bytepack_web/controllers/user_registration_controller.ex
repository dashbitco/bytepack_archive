defmodule BytepackWeb.UserRegistrationController do
  use BytepackWeb, :controller

  alias Bytepack.Accounts
  alias Bytepack.Accounts.User
  alias BytepackWeb.UserAuth

  plug :put_layout, "authentication.html"

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(conn.assigns.audit_context, user_params) do
      {:ok, user} ->
        _ =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &Routes.user_confirmation_url(conn, :confirm, &1)
          )

        conn
        |> put_flash(:info, "User created successfully.")
        |> UserAuth.login_user(user)
        |> UserAuth.redirect_user_after_login_with_remember_me()

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
