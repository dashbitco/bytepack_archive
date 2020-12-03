defmodule Bytepack.OrgsTest do
  use Bytepack.DataCase, async: true

  import Bytepack.OrgsFixtures
  import Bytepack.AccountsFixtures
  import Bytepack.SwooshHelpers

  alias Bytepack.Orgs
  alias Bytepack.Orgs.Org
  alias Bytepack.{Accounts, AuditLog}

  describe "orgs" do
    test "list_orgs/1 returns all from a given user" do
      alice = user_fixture()
      acme = org_fixture(alice)

      bob = user_fixture()
      org_fixture(bob)

      [loaded] = Orgs.list_orgs(alice)
      assert loaded.id == acme.id
    end

    test "list_orgs/0 returns all orgs" do
      alice = user_fixture()
      acme = org_fixture(alice)

      bob = user_fixture()
      los_pollos = org_fixture(bob)

      [first, last] = Orgs.list_orgs()
      assert first.id == acme.id
      assert last.id == los_pollos.id
    end

    test "get_org!/1 returns the org with given slug" do
      alice = user_fixture()
      acme = org_fixture(alice)

      bob = user_fixture()
      evilcorp = org_fixture(bob)

      assert Orgs.get_org!(alice, acme.slug)

      assert_raise Ecto.NoResultsError, fn ->
        Orgs.get_org!(alice, evilcorp.slug)
      end
    end

    test "create_org/3 with valid data creates an org" do
      user = user_fixture()

      assert {:ok, %Org{} = org} =
               Orgs.create_org(system(), user, %{
                 name: "org",
                 slug: "org",
                 email: "org@example.com"
               })

      assert org.name == "org"

      [audit_log] = AuditLog.list_by_org(org, action: "orgs.create")
      assert audit_log.params == %{"name" => org.name}

      membership = Orgs.get_membership!(user, org.slug)

      assert membership.role == "admin"
    end

    test "create_org/3 validates required fields (name and slug)" do
      user = user_fixture()
      assert {:error, changeset} = Orgs.create_org(system(), user, %{})
      assert %{name: ["can't be blank"], slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_org/3 validates slug's format" do
      user = user_fixture()
      assert {:error, changeset} = Orgs.create_org(system(), user, %{slug: "My org"})
      message = "should only contain lower case ASCII letters (from a to z), digits and -"
      assert %{slug: [^message]} = errors_on(changeset)
    end

    test "create_org/3 validates unique slug" do
      user = user_fixture()

      assert {:ok, %Org{}} =
               Orgs.create_org(system(), user, %{
                 name: "org1",
                 slug: "org",
                 email: "org1@example.com"
               })

      assert {:error, changeset} = Orgs.create_org(system(), user, %{name: "org2", slug: "org"})
      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "update_org/2 with valid data updates the org" do
      user = user_fixture()
      org = org_fixture(user)
      assert {:ok, %Org{} = org} = Orgs.update_org(org, %{name: "updated-org"})
      assert org.name == "updated-org"
    end

    test "update_org/2 with invalid data returns error changeset" do
      user = user_fixture()
      org = org_fixture(user)
      assert {:error, %Ecto.Changeset{}} = Orgs.update_org(org, %{name: ""})
      assert Orgs.get_org!(user, org.slug).name == org.name
    end

    test "update_org/3 doesn't allow editing slug" do
      user = user_fixture()
      org = org_fixture(user)
      assert {:ok, updated_org} = Orgs.update_org(org, %{slug: "other-slug"})
      assert updated_org.slug == org.slug
    end

    test "delete_org/1 deletes the org" do
      user = user_fixture()
      org = org_fixture(user)
      assert {:ok, %Org{}} = Orgs.delete_org(org)
      assert_raise Ecto.NoResultsError, fn -> Orgs.get_org!(user, org.slug) end
    end

    test "change_org/3 returns an org changeset" do
      user = user_fixture()
      org = org_fixture(user)
      assert %Ecto.Changeset{required: [:slug, :name, :email]} = Orgs.change_org(%Org{})
      assert %Ecto.Changeset{required: [:name, :email]} = Orgs.change_org(org)
    end

    test "enable_as_seller/1 enables an organization as seller" do
      org = org_fixture(user_fixture(), %{is_seller: false})
      assert {:ok, %Org{is_seller: true}} = Orgs.enable_as_seller(org)
    end
  end

  describe "members" do
    alias Bytepack.Orgs.Membership
    alias Bytepack.Accounts

    test "list_members_by_org/1 returns members in org" do
      alice = user_fixture()
      acme = org_fixture(alice)

      bob = user_fixture()
      org_fixture(bob)

      [loaded] = Orgs.list_members_by_org(acme)
      assert loaded.id == alice.id
    end

    test "delete_member!/3 deletes the membership" do
      alice = user_fixture()
      acme = org_fixture(alice)
      bob = member_fixture(acme)

      assert %{membership: %Membership{}} = Orgs.delete_member!(system(acme), acme, bob.id)
      assert [loaded] = Orgs.list_members_by_org(acme)
      assert loaded.id == alice.id
      assert Accounts.get_user!(bob.id)

      [audit_log] = AuditLog.list_by_org(acme, action: "orgs.delete_member")
      assert audit_log.params == %{"member_id" => bob.id, "email" => bob.email}
    end

    test "delete_member!/3 outside of org" do
      alice = user_fixture()
      acme = org_fixture(alice)
      bob = user_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Orgs.delete_member!(system(), acme, bob.id)
      end
    end

    test "delete_member!/3 last admin" do
      alice = user_fixture()
      acme = org_fixture(alice)

      assert_raise Ecto.InvalidChangesetError,
                   ~r/cannot remove last admin of the organization/,
                   fn ->
                     Orgs.delete_member!(system(), acme, alice.id)
                   end
    end

    test "get_membership_by_org_and_write_token/2 with valid token" do
      user = user_fixture()
      org = org_fixture(user)
      membership = Bytepack.Repo.one!(Bytepack.Orgs.Membership)
      token = Bytepack.Orgs.encode_membership_write_token(membership)

      assert Orgs.get_membership_by_org_and_write_token(org, token) == membership

      org2 = org_fixture(user)
      org3 = org_fixture(user_fixture())
      refute Orgs.get_membership_by_org_and_write_token(org2, token)
      refute Orgs.get_membership_by_org_and_write_token(org3, token)
    end

    test "get_membership_by_org_and_write_token/2 with invalid token" do
      org = org_fixture(user_fixture())

      refute Orgs.get_membership_by_org_and_write_token(org, "bad")
      refute Orgs.get_membership_by_org_and_write_token(org, Base.url_encode64("bad"))
    end

    test "get_membership_by_org_and_read_token/2 with valid token" do
      user = user_fixture()
      org = org_fixture(user)
      membership = Bytepack.Repo.one!(Bytepack.Orgs.Membership)
      token = Bytepack.Orgs.Membership.encode_read_token(membership)

      assert Orgs.get_membership_by_org_and_read_token(org, token) == membership

      org2 = org_fixture(user)
      org3 = org_fixture(user_fixture())
      refute Orgs.get_membership_by_org_and_read_token(org2, token)
      refute Orgs.get_membership_by_org_and_read_token(org3, token)
    end

    test "get_membership_by_org_and_read_token/2 with invalid token" do
      org = org_fixture(user_fixture())

      refute Orgs.get_membership_by_org_and_read_token(org, "bad")
      refute Orgs.get_membership_by_org_and_read_token(org, Base.url_encode64("bad"))
    end

    test "encode_membership_write_token/1" do
      user = user_fixture()
      org_fixture(user)

      membership = Bytepack.Repo.one!(Bytepack.Orgs.Membership)
      token = Bytepack.Orgs.encode_membership_write_token(membership)

      assert <<?w, ?_, encoded_token::binary>> = token

      [encoded_id, encoded_token] = :binary.split(encoded_token, "_")
      {id, ""} = Integer.parse(encoded_id, 32)
      {:ok, decoded_token} = Base.url_decode64(encoded_token, padding: false)

      assert decoded_token == membership.write_token
      assert id == membership.id
    end

    test "update_membership/2" do
      admin = user_fixture()
      acme = org_fixture(admin)
      bob = user_fixture()
      bob_membership = membership_fixture(acme, bob)

      assert {:ok, updated_membership} =
               Orgs.update_membership(system(), bob_membership, %{role: "admin"})

      assert updated_membership.role == "admin"

      [audit_log] = AuditLog.list_by_org(acme, action: "orgs.update_member")
      assert audit_log.params == %{"member_id" => bob.id, "role" => "admin"}
    end

    test "updated_membership/2 does not allow last admin to became a member" do
      admin = user_fixture()
      org_fixture(admin)
      admin_membership = Bytepack.Repo.one!(Bytepack.Orgs.Membership)

      assert {:error, changeset} =
               Orgs.update_membership(system(), admin_membership, %{role: "member"})

      assert "cannot remove last admin of the organization" in errors_on(changeset).role
    end
  end

  describe "invitations" do
    alias Bytepack.Accounts
    alias Bytepack.Orgs.Invitation

    test "create_invitation/4 with confirmed user" do
      org = org_fixture(user_fixture())
      user = user_fixture()

      assert {:ok, invitation} =
               Orgs.create_invitation(system(org), org, %{email: user.email}, "/")

      assert invitation.org_id == org.id
      assert invitation.user_id == user.id

      email_data =
        assert_received_email(to: user.email, subject: "Invitation to join #{org.name}")

      assert email_data.text_body =~ ~r/You can join the organization by visiting the url below/

      [audit_log] = AuditLog.list_by_org(org, action: "orgs.create_invitation")
      assert audit_log.org_id == org.id
      assert audit_log.params == %{"email" => user.email}
    end

    test "create_invitation/4 with unconfirmed user" do
      org = org_fixture(user_fixture())
      user = user_fixture(confirmed: false)

      assert {:ok, invitation} =
               Orgs.create_invitation(system(org), org, %{email: user.email}, "/")

      assert invitation.org_id == org.id
      refute invitation.user_id

      email_data =
        assert_received_email(to: user.email, subject: "Invitation to join #{org.name}")

      assert email_data.text_body =~ ~r/You can join the organization by registering an account/

      [audit_log] = AuditLog.list_by_org(org, action: "orgs.create_invitation")
      assert audit_log.org_id == org.id
      assert audit_log.params == %{"email" => user.email}

      token =
        extract_user_token(fn url ->
          Bytepack.Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, user} = Orgs.confirm_and_invite_user_by_token(token)
      invitation = Repo.get!(Invitation, invitation.id)
      assert invitation.user_id == user.id
    end

    test "create_invitation/4 with user outside of the system" do
      org = org_fixture(user_fixture())
      email = unique_user_email()
      assert {:ok, invitation} = Orgs.create_invitation(system(), org, %{email: email}, "/")
      assert invitation.org_id == org.id
      refute invitation.user_id

      email_data = assert_received_email(to: email, subject: "Invitation to join #{org.name}")

      assert email_data.text_body =~
               "You can join the organization by registering an account using the url below"

      user = user_fixture(email: email)
      invitation = Repo.get!(Invitation, invitation.id)
      assert invitation.user_id == user.id
    end

    test "create_invitation/4 with invalid email" do
      org = org_fixture(user_fixture())
      assert {:error, changeset} = Orgs.create_invitation(system(), org, %{email: "bad"}, "/")
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "create_invitation/4 with user already in org" do
      user = user_fixture()
      org = org_fixture(user)

      assert {:error, changeset} =
               Orgs.create_invitation(system(), org, %{email: user.email}, "/")

      assert "already in this organization" in errors_on(changeset).email
    end

    test "create_invitation/4 with user already invited" do
      org = org_fixture(user_fixture())
      user = user_fixture()
      assert {:ok, _} = Orgs.create_invitation(system(), org, %{email: user.email}, "/")

      assert {:error, changeset} =
               Orgs.create_invitation(system(), org, %{email: user.email}, "/")

      assert "is already invited" in errors_on(changeset).email
    end

    test "accept_invitation!/3 by confirmed user" do
      org = org_fixture(user_fixture())
      user = user_fixture()
      invitation = invitation_fixture(org, email: user.email)
      membership = Orgs.accept_invitation!(system(), user, invitation.id)
      assert membership.org_id == org.id
      assert membership.member_id == user.id
      assert [] = Repo.all(Invitation)

      [audit_log] = AuditLog.list_by_org(org, action: "orgs.accept_invitation")
      assert audit_log.org_id == org.id
      assert audit_log.params == %{"invitation_id" => invitation.id, "email" => invitation.email}
    end

    test "accept_invitation!/3 by unconfirmed user" do
      org = org_fixture(user_fixture())
      user = user_fixture(confirmed: false)
      invitation = invitation_fixture(org, email: user.email)

      assert_raise Ecto.NoResultsError, fn ->
        Orgs.accept_invitation!(system(), user, invitation.id)
      end
    end

    test "create two invitations for same org, accept one, and change email to the other" do
      org = org_fixture(user_fixture())
      email1 = unique_user_email()
      email2 = unique_user_email()
      assert {:ok, invitation1} = Orgs.create_invitation(system(), org, %{email: email1}, "/")
      assert {:ok, invitation2} = Orgs.create_invitation(system(), org, %{email: email2}, "/")

      password = valid_user_password()
      user = user_fixture(email: email1, password: password)
      assert Repo.get!(Invitation, invitation1.id).user_id == user.id
      refute Repo.get!(Invitation, invitation2.id).user_id

      Orgs.accept_invitation!(system(), user, invitation1.id)
      {:ok, applied_user} = Accounts.apply_user_email(user, password, %{email: email2})

      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_user_email_instructions(
            AuditLog.system(),
            applied_user,
            email1,
            url
          )
        end)

      :ok = Orgs.update_user_email(system(), user, token)
      refute Repo.get(Invitation, invitation2.id)
    end

    test "create two invitations for different orgs, accept one, and change email to the other" do
      org1 = org_fixture(user_fixture())
      org2 = org_fixture(user_fixture())
      email1 = unique_user_email()
      email2 = unique_user_email()
      assert {:ok, invitation1} = Orgs.create_invitation(system(), org1, %{email: email1}, "/")
      assert {:ok, invitation2} = Orgs.create_invitation(system(), org2, %{email: email2}, "/")

      password = valid_user_password()
      user = user_fixture(email: email1, password: password)
      assert Repo.get!(Invitation, invitation1.id).user_id == user.id
      refute Repo.get!(Invitation, invitation2.id).user_id

      Orgs.accept_invitation!(system(), user, invitation1.id)

      {:ok, applied_user} = Accounts.apply_user_email(user, password, %{email: email2})

      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_user_email_instructions(
            AuditLog.system(),
            applied_user,
            email1,
            url
          )
        end)

      :ok = Orgs.update_user_email(system(), user, token)
      assert Repo.get(Invitation, invitation2.id).user_id == user.id
    end

    test "reject_invitation!/3" do
      org = org_fixture(user_fixture())
      user = user_fixture()
      invitation = invitation_fixture(org, email: user.email)
      Orgs.reject_invitation!(system(), user, invitation.id)
      assert [] = Repo.all(Invitation)

      [audit_log] = AuditLog.list_by_org(org, action: "orgs.reject_invitation")
      assert audit_log.org_id == org.id
      assert audit_log.params == %{"invitation_id" => invitation.id, "email" => invitation.email}
    end

    test "delete_invitation!/2" do
      org = org_fixture(user_fixture())
      user = user_fixture()

      assert {:ok, invitation} = Orgs.create_invitation(system(), org, %{email: user.email}, "/")
      assert Orgs.delete_invitation!(system(org), invitation)

      [audit_log] = AuditLog.list_by_org(org, action: "orgs.delete_invitation")
      assert audit_log.org_id == org.id
      assert audit_log.params == %{"invitation_id" => invitation.id, "email" => invitation.email}
    end
  end
end
