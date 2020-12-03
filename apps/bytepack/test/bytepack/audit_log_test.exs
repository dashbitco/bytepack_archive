defmodule Bytepack.AuditLogTest do
  use Bytepack.DataCase, async: true

  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  alias Bytepack.AuditLog

  describe "audit!/3" do
    test "sets user_email from user" do
      user = user_fixture()
      audit_log = AuditLog.audit!(%{system() | user: user}, "orgs.create", %{name: "some org"})

      assert audit_log.action == "orgs.create"
      assert audit_log.user_email
      assert audit_log.user_email == user.email
    end

    test "validates params" do
      message = "extra keys [\"extra\"] for action orgs.create in %{extra: \"\"}"

      assert_raise AuditLog.InvalidParameterError, message, fn ->
        AuditLog.audit!(system(), "orgs.create", %{extra: ""})
      end

      message = "missing keys [\"name\"] for action orgs.create in %{}"

      assert_raise AuditLog.InvalidParameterError, message, fn ->
        AuditLog.audit!(system(), "orgs.create", %{})
      end
    end
  end

  describe "multi/4" do
    test "creates an ecto multi operation with params" do
      multi = AuditLog.multi(Ecto.Multi.new(), system(), "orgs.create", %{name: "org"})
      assert %Ecto.Multi{} = multi

      assert {:ok, %{audit: audit_log}} = Bytepack.Repo.transaction(multi)

      assert audit_log.action == "orgs.create"
      assert audit_log.params == %{name: "org"}
    end

    test "creates an ecto multi operation with a function" do
      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.insert(
          :org,
          Bytepack.Orgs.Org.insert_changeset(%{
            name: "Acme",
            slug: "another-acme",
            email: "acme@email.com"
          })
        )
        |> AuditLog.multi(system(), "orgs.create", fn audit_context, changes_so_far ->
          assert %AuditLog{} = audit_context
          assert %{org: %Bytepack.Orgs.Org{}} = changes_so_far

          %{audit_context | params: %{name: "Acme"}}
        end)

      assert {:ok, %{audit: audit_log}} = Bytepack.Repo.transaction(multi)

      assert audit_log.action == "orgs.create"
      assert audit_log.params == %{name: "Acme"}
    end

    test "raises error with invalid param inside transaction" do
      multi =
        Ecto.Multi.new()
        |> AuditLog.multi(system(), "orgs.create", fn audit_context, _ ->
          %{audit_context | params: %{invalid_param: "invalid"}}
        end)

      assert_raise AuditLog.InvalidParameterError, ~r/extra key/, fn ->
        Repo.transaction(multi)
      end

      multi = AuditLog.multi(Ecto.Multi.new(), system(), "orgs.create", %{})

      assert_raise AuditLog.InvalidParameterError, ~r/missing key/, fn ->
        Repo.transaction(multi)
      end
    end
  end

  describe "queries" do
    setup do
      user = user_fixture()
      org = org_fixture(user)
      AuditLog.audit!(system(), "orgs.create", %{name: "org by system"})
      AuditLog.audit!(%{system() | user: user}, "orgs.create", %{name: "org by user"})

      AuditLog.audit!(%{system() | org: org}, "orgs.create_invitation", %{
        email: "invitation@email"
      })

      {:ok, %{user: user, org: org}}
    end

    test "list_by_user/2 returns audit logs related to user", %{user: user} do
      assert [audit_log] = AuditLog.list_by_user(user, action: "orgs.create")
      assert audit_log.params == %{"name" => "org by user"}

      assert [] = AuditLog.list_by_user(user, action: "orgs.delete_member")

      assert [register_user_log, ^audit_log] = AuditLog.list_by_user(user)
      assert register_user_log.action == "accounts.register_user"
    end

    test "list_by_org/2 returns audit logs related to organization", %{org: org} do
      assert [audit_log] = AuditLog.list_by_org(org, action: "orgs.create_invitation")
      assert audit_log.params == %{"email" => "invitation@email"}

      assert [] = AuditLog.list_by_org(org, action: "orgs.delete_member")

      assert [register_org_log, ^audit_log] = AuditLog.list_by_org(org)

      assert register_org_log.action == "orgs.create"
      assert register_org_log.params == %{"name" => org.name}
    end

    test "list_all_from_system/1" do
      assert [audit_log] = AuditLog.list_all_from_system(action: "orgs.create")
      assert audit_log.params == %{"name" => "org by system"}
      refute audit_log.user_id
      refute audit_log.org_id

      assert [] = AuditLog.list_all_from_system(action: "orgs.delete_member")

      assert [^audit_log] = AuditLog.list_all_from_system()
    end
  end
end
