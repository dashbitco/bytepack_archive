defmodule Bytepack.OrgsFixtures do
  alias Bytepack.{AuditLog, AccountsFixtures, Orgs, Orgs.Member, Orgs.Membership}

  def unique_org_name(), do: "org#{System.unique_integer([:positive])}"
  def unique_org_email(), do: "org#{System.unique_integer([:positive])}@example.com"
  def unique_invitation_email(), do: "invitation#{System.unique_integer([:positive])}@example.com"

  def org_fixture(user, attrs \\ %{}) do
    name = unique_org_name()

    attrs =
      Enum.into(attrs, %{
        name: name,
        slug: name,
        email: unique_org_email(),
        is_seller: true
      })

    {:ok, org} = Orgs.create_org(AuditLog.system(), user, attrs)

    org
    |> Ecto.Changeset.change(is_seller: attrs[:is_seller])
    |> Bytepack.Repo.update!()
  end

  def member_fixture(org, user_attrs \\ %{}) do
    user = AccountsFixtures.user_fixture(user_attrs)
    membership_fixture(org, user)
    struct!(Member, Map.take(user, [:id, :email]))
  end

  def membership_fixture(org, user, role \\ "member") do
    Bytepack.Repo.insert!(Membership.insert_changeset(org, user, role))
  end

  def admin_fixture(org, user_attrs \\ %{}) do
    user = AccountsFixtures.user_fixture(user_attrs)
    membership_fixture(org, user, "admin")
    struct!(Member, Map.take(user, [:id, :email]))
  end

  def invitation_fixture(org, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        email: unique_invitation_email()
      })

    {:ok, org} = Orgs.create_invitation(AuditLog.system(), org, attrs, "/")
    org
  end
end
