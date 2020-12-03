defmodule Bytepack.AccountsFixtures do
  @totp_secret Base.decode32!("PTEPUGZ7DUWTBGMW4WLKB6U63MGKKMCA")

  def valid_totp_secret, do: @totp_secret
  def valid_user_password, do: "hello world!"
  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  def user_fixture(attrs \\ %{}) do
    {confirmed, attrs} = attrs |> Map.new() |> Map.pop(:confirmed, true)

    user_params =
      Enum.into(attrs, %{
        email: unique_user_email(),
        password: valid_user_password(),
        terms_of_service: true
      })

    {:ok, user} = Bytepack.Accounts.register_user(Bytepack.AuditLog.system(), user_params)

    if confirmed do
      confirm(user)
    else
      user
    end
  end

  def staff_fixture(attrs \\ %{}) do
    attrs
    |> user_fixture()
    |> Ecto.Changeset.change(%{is_staff: true})
    |> Bytepack.Repo.update!()
  end

  def user_totp_fixture(user) do
    %Bytepack.Accounts.UserTOTP{}
    |> Ecto.Changeset.change(user_id: user.id, secret: valid_totp_secret())
    |> Bytepack.Accounts.UserTOTP.ensure_backup_codes()
    |> Bytepack.Repo.insert!()
  end

  defp confirm(user) do
    token =
      extract_user_token(fn url ->
        Bytepack.Accounts.deliver_user_confirmation_instructions(user, url)
      end)

    {:ok, user} = Bytepack.Orgs.confirm_and_invite_user_by_token(token)
    user
  end

  def extract_user_token(fun) do
    {:ok, email_data} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(email_data.text_body, "[TOKEN]")
    token
  end
end
