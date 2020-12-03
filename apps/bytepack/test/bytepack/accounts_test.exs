defmodule Bytepack.AccountsTest do
  use Bytepack.DataCase, async: true

  import Bytepack.AccountsFixtures
  alias Bytepack.{Accounts, AuditLog}
  alias Bytepack.Accounts.{User, UserToken, UserTOTP}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(123)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/2" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_user(system(), %{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} =
        Accounts.register_user(system(), %{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for e-mail and password for security" do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.register_user(system(), %{email: too_long, password: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates e-mail uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(system(), %{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upcase e-mail too
      {:error, changeset} = Accounts.register_user(system(), %{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates that terms of service are accepted" do
      {:error, changeset} =
        Accounts.register_user(system(), %{
          email: unique_user_email(),
          password: valid_user_password()
        })

      assert "You must agree before continuing" in errors_on(changeset).terms_of_service
    end

    test "registers users with a hashed password" do
      email = unique_user_email()

      {:ok, user} =
        Accounts.register_user(
          system(),
          %{
            email: email,
            password: valid_user_password(),
            terms_of_service: true
          }
        )

      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.password)
      assert is_nil(user.confirmed_at)

      [audit_log] = AuditLog.list_by_user(user, action: "accounts.register_user")

      assert audit_log.params == %{"email" => email}
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_registration(%User{})
      assert changeset.required == [:password, :email]
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
      assert changeset.action == nil
    end

    test "validates the current password" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{}, "bad")
      assert %{current_password: ["is not valid"]} = errors_on(changeset)
      assert changeset.action == :validate
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Accounts.apply_user_email(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)

      {:error, changeset} = Accounts.apply_user_email(user, valid_user_password(), %{email: ""})
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for e-mail for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates e-mail uniqueness", %{user: user} do
      %{email: email} = user_fixture()

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the e-mail without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Accounts.apply_user_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert Accounts.get_user!(user.id).email != email
    end
  end

  describe "deliver_update_user_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_user_email_instructions(
            system(),
            user,
            "current@example.com",
            url
          )
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"

      [audit_log] = AuditLog.list_all_from_system(action: "accounts.update_email.init")
      assert audit_log.params == %{"email" => user.email, "user_id" => user.id}
    end
  end

  describe "user_email_multi/3" do
    setup do
      user = user_fixture(confirmed: false)
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_user_email_instructions(
            system(),
            %{user | email: email},
            user.email,
            url
          )
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the e-mail with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, _, multi} = Accounts.user_email_multi(system(), user, token)
      assert {:ok, _} = Repo.transaction(multi)

      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)

      [audit_log] = AuditLog.list_all_from_system(action: "accounts.update_email.finish")

      assert audit_log.params == %{"email" => email, "user_id" => user.id}
    end

    test "does not update e-mail with invalid token", %{user: user} do
      assert Accounts.user_email_multi(system(), user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update e-mail if user e-mail changed", %{user: user, token: token} do
      assert Accounts.user_email_multi(system(), %{user | email: "current@example.com"}, token) ==
               :error

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update e-mail if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.user_email_multi(system(), user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
      assert changeset.action == nil
    end

    test "validates the current password" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{}, "bad")
      assert %{current_password: ["is not valid"]} = errors_on(changeset)
      assert changeset.action == :validate
    end
  end

  describe "update_user_password/4" do
    setup do
      user = user_fixture()
      audit_context = %AuditLog{user: user}

      %{user: user, audit_context: audit_context}
    end

    test "validates password", %{user: user, audit_context: audit_context} do
      {:error, changeset} =
        Accounts.update_user_password(audit_context, user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match confirmation"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{
      user: user,
      audit_context: audit_context
    } do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(audit_context, user, valid_user_password(), %{
          password: too_long
        })

      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user, audit_context: audit_context} do
      {:error, changeset} =
        Accounts.update_user_password(audit_context, user, "invalid", %{
          password: valid_user_password()
        })

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user, audit_context: audit_context} do
      {:ok, user} =
        Accounts.update_user_password(audit_context, user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")

      [audit_log] = AuditLog.list_by_user(user, action: "accounts.update_password")
      assert audit_log.action == "accounts.update_password"
      assert audit_log.params == %{"user_id" => user.id}
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(system(), user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "validate_user_current_password" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.validate_user_current_password(%User{}, nil)
      assert changeset.action == nil
    end

    test "validates the current password" do
      assert %Ecto.Changeset{} =
               changeset = Accounts.validate_user_current_password(%User{}, "bad")

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
      assert changeset.action == :validate
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture(confirmed: false)
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "get_user_by_session_token!/1" do
    setup do
      user = user_fixture(confirmed: false)
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token!(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user_by_session_token!("oops") end
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user_by_session_token!(token) end
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: user_fixture(confirmed: false)}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "get_user_by_confirmation_token/1" do
    setup do
      user = user_fixture(confirmed: false)

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns user with a valid token", %{user: user, token: token} do
      loaded_user = Accounts.get_user_by_confirmation_token(token)
      assert loaded_user.id == user.id
    end

    test "does not return user with invalid token" do
      refute Accounts.get_user_by_confirmation_token("bad")
    end

    test "does not return user with expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~U[2020-01-01 00:00:00Z]])
      refute Accounts.get_user_by_confirmation_token(token)
    end
  end

  describe "confirm_user!/1" do
    test "confirms the user and removes the token" do
      user = user_fixture(confirmed: false)
      Accounts.deliver_user_confirmation_instructions(user, & &1)
      refute user.confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)

      user = Accounts.confirm_user!(user)
      assert user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          assert Accounts.deliver_user_reset_password_instructions(system(), user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"

      [audit_log] = AuditLog.list_all_from_system(action: "accounts.reset_password.init")
      assert audit_log.params == %{"user_id" => user.id}
    end
  end

  describe "get_user_by_reset_password_token/2" do
    setup do
      user = user_fixture(confirmed: false)

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(system(), user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id} = user, token: token} do
      assert %User{id: ^id} = Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute Accounts.get_user_by_reset_password_token("oops")
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "reset_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.reset_user_password(system(), user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match confirmation"]
             } = errors_on(changeset)

      [] = AuditLog.list_all_from_system(action: "accounts.reset_password.finish")
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_user_password(system(), user, %{password: too_long})
      assert "should be at most 80 character(s)" in errors_on(changeset).password

      [] = AuditLog.list_all_from_system(action: "accounts.reset_password.finish")
    end

    test "updates the password", %{user: user} do
      {:ok, _} = Accounts.reset_user_password(system(), user, %{password: "new valid password"})
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")

      [audit_log] = AuditLog.list_all_from_system(action: "accounts.reset_password.finish")
      assert audit_log.params == %{"user_id" => user.id}
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)
      {:ok, _} = Accounts.reset_user_password(system(), user, %{password: "new valid password"})
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "upsert_user_totp/3" do
    setup do
      user = user_fixture()
      audit_context = %Bytepack.AuditLog{user: user}

      %{
        totp: %UserTOTP{user_id: user.id, secret: valid_totp_secret()},
        user: user,
        audit_context: audit_context
      }
    end

    test "validates required otp", %{totp: totp} do
      {:error, changeset} = Accounts.upsert_user_totp(system(), totp, %{code: ""})
      assert %{code: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates otp as 6 digits number", %{totp: totp} do
      {:error, changeset} = Accounts.upsert_user_totp(system(), totp, %{code: "1234567"})
      assert %{code: ["should be a 6 digit number"]} = errors_on(changeset)
    end

    test "validates otp against the secret", %{totp: totp} do
      {:error, changeset} = Accounts.upsert_user_totp(system(), totp, %{code: "123456"})
      assert %{code: ["invalid code"]} = errors_on(changeset)
    end

    test "upserts user's TOTP secret", %{totp: totp, user: user, audit_context: audit_context} do
      otp = NimbleTOTP.verification_code(totp.secret)

      assert {:ok, totp} = Accounts.upsert_user_totp(audit_context, totp, %{code: otp})
      assert Repo.get!(UserTOTP, totp.id).secret == totp.secret

      [audit_log] = Bytepack.AuditLog.list_by_user(user, action: "accounts.user_totp.enable")
      assert audit_log.params == %{"user_id" => user.id}

      new_secret = valid_totp_secret()
      new_otp = NimbleTOTP.verification_code(new_secret)

      assert {:ok, _} =
               Accounts.upsert_user_totp(audit_context, %{totp | secret: new_secret}, %{
                 code: new_otp
               })

      [audit_log] = Bytepack.AuditLog.list_by_user(user, action: "accounts.user_totp.update")
      assert audit_log.params == %{"user_id" => user.id}
    end

    test "generates backup codes if they are missing", %{
      totp: totp,
      user: user,
      audit_context: audit_context
    } do
      otp = NimbleTOTP.verification_code(totp.secret)

      assert {:ok, totp} = Accounts.upsert_user_totp(audit_context, totp, %{code: otp})

      assert length(totp.backup_codes) == 10
      assert Enum.all?(totp.backup_codes, &(byte_size(&1.code) == 8))
      assert Enum.all?(totp.backup_codes, &(:binary.first(&1.code) in ?A..?Z))

      [audit_log] = Bytepack.AuditLog.list_by_user(user, action: "accounts.user_totp.enable")
      assert audit_log.params == %{"user_id" => user.id}
    end
  end

  describe "delete_user_totp/2" do
    setup do
      user = user_fixture()
      audit_context = %Bytepack.AuditLog{user: user}

      %{totp: user_totp_fixture(user), user: user, audit_context: audit_context}
    end

    test "removes otp secret", %{totp: totp, user: user, audit_context: audit_context} do
      :ok = Accounts.delete_user_totp(audit_context, totp)
      refute Repo.get(UserTOTP, totp.id)

      [audit_log] = Bytepack.AuditLog.list_by_user(user, action: "accounts.user_totp.disable")

      assert audit_log.params == %{"user_id" => user.id}
    end
  end

  describe "regenerate_user_totp_backup_codes/2" do
    setup do
      user = user_fixture()
      audit_context = %Bytepack.AuditLog{user: user}

      %{totp: user_totp_fixture(user), user: user, audit_context: audit_context}
    end

    test "replaces backup codes", %{totp: totp, user: user, audit_context: audit_context} do
      assert Accounts.regenerate_user_totp_backup_codes(audit_context, totp).backup_codes !=
               totp.backup_codes

      [audit_log] =
        Bytepack.AuditLog.list_by_user(user, action: "accounts.user_totp.regenerate_backup_codes")

      assert audit_log.params == %{"user_id" => user.id}
    end

    test "does not persist changes made to the struct", %{
      totp: totp,
      audit_context: audit_context
    } do
      changed = %{totp | secret: "SECRET"}
      assert Accounts.regenerate_user_totp_backup_codes(audit_context, changed).secret == "SECRET"
      assert Repo.get(UserTOTP, changed.id).secret == totp.secret
    end
  end

  describe "validate_user_totp/3" do
    setup do
      user = user_fixture()
      audit_context = %Bytepack.AuditLog{user: user}

      %{totp: user_totp_fixture(user), user: user, audit_context: audit_context}
    end

    test "returns invalid if the code is not valid", %{user: user, audit_context: audit_context} do
      assert Accounts.validate_user_totp(audit_context, user, "invalid") == :invalid
      assert Accounts.validate_user_totp(audit_context, user, nil) == :invalid

      [audit_log, other_audit_log] =
        Bytepack.AuditLog.list_by_user(user, action: "accounts.user_totp.invalid_code_used")

      assert audit_log.params == %{"user_id" => user.id}
      assert other_audit_log.params == %{"user_id" => user.id}
    end

    test "returns valid for valid totp", %{user: user, totp: totp, audit_context: audit_context} do
      code = NimbleTOTP.verification_code(totp.secret)
      assert Accounts.validate_user_totp(audit_context, user, code) == :valid_totp

      [audit_log] = Bytepack.AuditLog.list_by_user(user, action: "accounts.user_totp.validated")

      assert audit_log.params == %{"user_id" => user.id}
    end

    test "returns valid for valid backup code", %{
      user: user,
      totp: totp,
      audit_context: audit_context
    } do
      at = :rand.uniform(10) - 1
      code = Enum.fetch!(totp.backup_codes, at).code
      assert Accounts.validate_user_totp(audit_context, user, code) == {:valid_backup_code, 9}
      assert Enum.fetch!(Repo.get(UserTOTP, totp.id).backup_codes, at).used_at

      [audit_log] =
        Bytepack.AuditLog.list_by_user(user,
          action: "accounts.user_totp.validated_with_backup_code"
        )

      assert audit_log.params == %{"user_id" => user.id}

      # Cannot reuse the code
      assert Accounts.validate_user_totp(audit_context, user, code) == :invalid

      [audit_log] =
        Bytepack.AuditLog.list_by_user(user, action: "accounts.user_totp.invalid_code_used")

      assert audit_log.params == %{"user_id" => user.id}
    end
  end
end
