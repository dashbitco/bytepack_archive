defmodule BytepackWeb.UserSettingsLiveTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Bytepack.AccountsFixtures
  import Bytepack.SwooshHelpers

  setup :register_and_login_user

  describe "Index" do
    test "update email", %{conn: conn} do
      {:ok, settings_live, html} = live(conn, Routes.user_settings_path(conn, :index))

      assert html =~ "Change e-mail"

      change_with_errors =
        settings_live
        |> form("#form-update-email", user: [email: "bad"])
        |> render_change()

      assert change_with_errors =~ "must have the @ sign and no spaces"

      change_with_errors =
        settings_live
        |> form("#form-update-email", user: [email: unique_user_email()], current_password: "bad")
        |> render_change()

      assert change_with_errors =~ "is not valid"

      email = unique_user_email()

      settings_live
      |> form("#form-update-email",
        user: [email: email],
        current_password: valid_user_password()
      )
      |> render_submit()

      assert_received_email(to: email, subject: "Update e-mail instructions")

      assert render(settings_live) =~
               "A link to confirm your e-mail change has been sent to the new address."
    end

    test "update password", %{conn: conn} do
      {:ok, settings_live, html} = live(conn, Routes.user_settings_path(conn, :index))

      assert html =~ "Change password"

      change_with_errors =
        settings_live
        |> form("#form-update-password",
          user: [password: "bad", password_confirmation: valid_user_password()]
        )
        |> render_change()

      assert change_with_errors =~ "does not match confirmation"
      assert change_with_errors =~ "should be at least 12 character(s)"

      change_with_errors =
        settings_live
        |> form("#form-update-password",
          current_password: "bad",
          user: [password: valid_user_password(), password_confirmation: valid_user_password()]
        )
        |> render_change()

      assert change_with_errors =~ "is not valid"

      submitted_form =
        settings_live
        |> form("#form-update-password",
          current_password: valid_user_password(),
          user: [password: valid_user_password(), password_confirmation: valid_user_password()]
        )
        |> render_submit()

      refute submitted_form =~ "invalid_feedback"
    end
  end

  describe "Index (2FA)" do
    @backup_codes_message "Keep these backup codes safe"
    @enter_your_current_password_to_enable "Enter your current password to enable"
    @enter_your_current_password_to_change "Enter your current password to change"

    test "requires password to enable 2FA", %{conn: conn} do
      {:ok, settings_live, html} = live(conn, Routes.user_settings_path(conn, :index))

      assert html =~ "Two-factor authentication"
      assert html =~ @enter_your_current_password_to_enable

      html =
        settings_live
        |> form("#form-submit-totp", current_password: "bad")
        |> render_submit()

      assert html =~ "is not valid"

      html =
        settings_live
        |> form("#form-submit-totp", current_password: valid_user_password())
        |> render_submit()

      assert html =~ "Authentication code"
      refute html =~ @enter_your_current_password_to_enable

      assert settings_live |> element("#btn-cancel-totp", "Cancel") |> render_click() =~
               @enter_your_current_password_to_enable

      refute settings_live |> element("#current_password_for_totp") |> render() =~ "value="
    end

    test "enables totp secret", %{conn: conn} do
      {:ok, settings_live, _html} = live(conn, Routes.user_settings_path(conn, :index))

      settings_live
      |> form("#form-submit-totp", current_password: valid_user_password())
      |> render_submit()

      assert settings_live
             |> form("#form-update-totp", user_totp: [code: "123"])
             |> render_submit() =~ "should be a 6 digit number"

      refute settings_live |> element("#totp_secret") |> has_element?()

      settings_live
      |> element("#btn-manual-secret", "enter your secret")
      |> render_click()

      html =
        settings_live
        |> form("#form-update-totp", user_totp: [code: get_otp(settings_live)])
        |> render_submit()

      # Now we show all backup codes
      assert html =~ @backup_codes_message

      html =
        settings_live
        |> element("#btn-hide-backup", "Close")
        |> render_click()

      # Until we close the modal and see the whole page
      refute html =~ @backup_codes_message
      assert html =~ ~S(<i class="feather-icon icon-check font-weight-bold mr-1"></i> Enabled)
      assert html =~ @enter_your_current_password_to_change

      # Finally, check there is no lingering password on the initial form
      refute settings_live |> element("#current_password_for_totp") |> render() =~ "value="
    end

    test "disables 2FA password", %{conn: conn, user: user} do
      totp = user_totp_fixture(user)

      {:ok, settings_live, html} = live(conn, Routes.user_settings_path(conn, :index))
      assert html =~ @enter_your_current_password_to_change

      assert settings_live
             |> form("#form-submit-totp", current_password: valid_user_password())
             |> render_submit() =~
               "Authentication code"

      assert settings_live |> element("#btn-disable-totp", "disable") |> render_click() =~
               @enter_your_current_password_to_enable

      refute Bytepack.Repo.get(Bytepack.Accounts.UserTOTP, totp.id)
    end

    test "changes totp secret", %{conn: conn, user: user} do
      totp = user_totp_fixture(user)
      {:ok, settings_live, _html} = live(conn, Routes.user_settings_path(conn, :index))

      settings_live
      |> form("#form-submit-totp", current_password: valid_user_password())
      |> render_submit()

      settings_live
      |> element("#btn-manual-secret", "enter your secret")
      |> render_click()

      html =
        settings_live
        |> form("#form-update-totp", user_totp: [code: get_otp(settings_live)])
        |> render_submit()

      assert html =~ ~S(<i class="feather-icon icon-check font-weight-bold mr-1"></i> Enabled)
      assert html =~ @enter_your_current_password_to_change

      refute settings_live |> element("#current_password_for_totp") |> render() =~ "value="

      assert Bytepack.Repo.get!(Bytepack.Accounts.UserTOTP, totp.id).secret !=
               valid_totp_secret()
    end

    test "regenerates backup codes", %{conn: conn, user: user} do
      %{backup_codes: [backup_code | backup_codes]} = totp = user_totp_fixture(user)
      used_code = Ecto.Changeset.change(backup_code, used_at: DateTime.utc_now())

      totp
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_embed(:backup_codes, [used_code | backup_codes])
      |> Bytepack.Repo.update!()

      {:ok, settings_live, _html} = live(conn, Routes.user_settings_path(conn, :index))

      settings_live
      |> form("#form-submit-totp", current_password: valid_user_password())
      |> render_submit()

      settings_live
      |> element("#btn-manual-secret", "enter your secret")
      |> render_click()

      otp_secret = get_otp(settings_live)

      html =
        settings_live
        |> element("#btn-show-backup", "see your available backup codes")
        |> render_click()

      # We can now see all backup codes and one of them is marked as del
      assert html =~ @backup_codes_message
      assert settings_live |> element("del", backup_code.code) |> has_element?()

      html =
        settings_live
        |> element("#btn-regenerate-backup", "Regenerate backup codes")
        |> render_click()

      # We are on the same page, with the same secret, but we got new tokens
      assert html =~ @backup_codes_message
      refute html =~ backup_code.code
      assert get_otp(settings_live) == otp_secret

      # Also make sure the changes were reflected in the database
      updated_totp = Bytepack.Repo.get!(Bytepack.Accounts.UserTOTP, totp.id)
      assert updated_totp.secret == totp.secret
      assert Enum.all?(updated_totp.backup_codes, &is_nil(&1.used_at))
      assert Enum.all?(updated_totp.backup_codes, &(html =~ &1.code))

      # Now we close and reopen to find the same token
      settings_live
      |> element("#btn-hide-backup", "Close")
      |> render_click()

      html =
        settings_live
        |> element("#btn-show-backup", "see your available backup codes")
        |> render_click()

      assert Enum.all?(updated_totp.backup_codes, &(html =~ &1.code))
    end

    defp get_otp(live) do
      live
      |> element("#totp-secret")
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.text()
      |> String.replace(~r/\s/, "")
      |> Base.decode32!()
      |> NimbleTOTP.verification_code()
    end
  end
end
