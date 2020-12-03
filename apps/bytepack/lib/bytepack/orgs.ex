defmodule Bytepack.Orgs do
  alias Bytepack.Repo
  alias Bytepack.{Accounts, AuditLog}
  alias Bytepack.Orgs.{Invitation, Member, Membership, Org}
  import Ecto.Query, only: [from: 2]

  @membership_roles ~w(member admin)

  ## Orgs

  def list_orgs(user) do
    user
    |> Org.by_user()
    |> Repo.all()
  end

  def list_orgs() do
    Repo.all(from(o in Org, order_by: :id))
  end

  def get_org!(user, slug) when is_binary(slug) do
    user
    |> Org.by_user()
    |> Repo.get_by!(slug: slug)
  end

  def get_org!(slug) when is_binary(slug) do
    Repo.get_by!(Org, slug: slug)
  end

  def create_org(audit_context, user, attrs) do
    unless user.confirmed_at do
      raise ArgumentError, "user must be confirmed to create an org"
    end

    changeset = Org.insert_changeset(attrs)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:org, changeset)
      |> Ecto.Multi.insert(:membership, fn %{org: org} ->
        Membership.insert_changeset(org, user, "admin")
      end)
      |> AuditLog.multi(
        audit_context,
        "orgs.create",
        fn audit_log, %{org: org} -> %{audit_log | org: org, params: %{name: org.name}} end
      )

    case Repo.transaction(multi) do
      {:ok, %{org: org}} ->
        {:ok, org}

      {:error, :org, changeset, _} ->
        {:error, changeset}
    end
  end

  def update_org(%Org{} = org, attrs) do
    org
    |> Org.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_org(%Org{} = org) do
    Repo.delete(org)
  end

  def change_org(org, attrs \\ %{}) do
    if Ecto.get_meta(org, :state) == :loaded do
      Org.update_changeset(org, attrs)
    else
      Org.insert_changeset(attrs)
    end
  end

  ## Accounts

  @doc """
  Confirms a user by the given token.
  """
  def confirm_and_invite_user_by_token(token) do
    case Accounts.get_user_by_confirmation_token(token) do
      nil -> :error
      user -> {:ok, confirm_and_invite_user!(user)}
    end
  end

  @doc """
  Confirms the user and assigns all their pending invitations.
  """
  def confirm_and_invite_user!(user) do
    Repo.transaction!(fn ->
      user = Accounts.confirm_user!(user)

      user
      |> Invitation.assign_to_user_by_email(user.email)
      |> Repo.update_all([])

      user
    end)
  end

  def update_user_email(audit_context, user, token) do
    with {:ok, email, multi} <- Accounts.user_email_multi(audit_context, user, token) do
      invitations_to_update = Invitation.assign_to_user_by_email(user, email)
      invitations_to_delete = Invitation.get_stale_by_user_id(user.id)

      multi =
        multi
        |> Ecto.Multi.update_all(:updated_invitations, invitations_to_update, [])
        |> Ecto.Multi.delete_all(:deleted_invitations, invitations_to_delete)

      case Repo.transaction(multi) do
        {:ok, _} -> :ok
        {:error, _} -> :error
      end
    end
  end

  ## Members

  def list_members_by_org(org) do
    org
    |> Member.by_org()
    |> Repo.all()
  end

  def delete_member!(audit_context, org, id) do
    membership = Repo.get_by!(Membership, org_id: org.id, member_id: id)

    multi =
      Ecto.Multi.new()
      |> AuditLog.multi(audit_context, "orgs.delete_member", %{
        member_id: membership.member_id,
        email: Repo.preload(membership, :member).member.email
      })
      |> Ecto.Multi.delete(:membership, Membership.delete_changeset(membership))

    case Repo.transaction(multi) do
      {:ok, result} ->
        result

      {:error, _, changeset, _} ->
        raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  def get_membership!(user, org_slug) when is_binary(org_slug) do
    user
    |> Membership.by_user_and_org_slug(org_slug)
    |> Repo.one!()
    |> Repo.preload(:org)
  end

  def get_membership!(id) do
    Repo.get!(Membership, id)
    |> Repo.preload([:member])
  end

  def get_membership_by_org_and_write_token(org, token) do
    with {:ok, query, token} <- Membership.verify_token_query(org, ?w, token),
         %Membership{} = membership <- Repo.one(query),
         true <- Plug.Crypto.secure_compare(membership.write_token, token) do
      membership
    else
      _ -> nil
    end
  end

  def get_membership_by_org_and_read_token(org, token) do
    with {:ok, query, token} <- Membership.verify_token_query(org, ?r, token),
         %Membership{} = membership <- Repo.one(query),
         true <- Plug.Crypto.secure_compare(membership.read_token, token) do
      membership
    else
      _ -> nil
    end
  end

  def encode_membership_write_token(membership) do
    Membership.encode_write_token(membership)
  end

  def membership_roles do
    @membership_roles
  end

  def change_membership(%Membership{} = membership, attrs \\ %{}) do
    Membership.update_changeset(membership, attrs)
  end

  def update_membership(audit_context, %Membership{} = membership, attrs) do
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:membership, Membership.update_changeset(membership, attrs))
      |> AuditLog.multi(audit_context, "orgs.update_member", fn audit_log,
                                                                %{membership: membership} ->
        %{
          audit_log
          | org_id: membership.org_id,
            params: %{member_id: membership.member_id, role: membership.role}
        }
      end)

    case Repo.transaction(multi) do
      {:ok, %{membership: membership}} ->
        {:ok, membership}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  def list_memberships_by_org(org) do
    org
    |> Membership.all_by_org()
    |> Repo.all()
  end

  ## Invitations - org based

  def list_invitations_by_org(org) do
    org
    |> Invitation.by_org()
    |> Repo.all()
  end

  def get_invitation_by_org!(org, id) do
    org
    |> Invitation.by_org()
    |> Repo.get!(id)
  end

  def delete_invitation!(audit_context, invitation) do
    {:ok, %{invitation: invitation}} =
      Ecto.Multi.new()
      |> Ecto.Multi.delete(:invitation, invitation)
      |> AuditLog.multi(
        audit_context,
        "orgs.delete_invitation",
        %{invitation_id: invitation.id, email: invitation.email}
      )
      |> Repo.transaction()

    invitation
  end

  def build_invitation(%Org{} = org, params) do
    Invitation.changeset(%Invitation{org_id: org.id}, params)
  end

  def create_invitation(audit_context, org, params, invitation_url) do
    changeset = build_invitation(org, params)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:invitation, changeset)
      |> AuditLog.multi(
        audit_context,
        "orgs.create_invitation",
        Map.take(changeset.changes, ~w(email)a)
      )

    case Repo.transaction(multi) do
      {:ok, %{invitation: invitation}} ->
        Accounts.UserNotifier.deliver_org_invitation(org, invitation, invitation_url)
        {:ok, invitation}

      {:error, :invitation, changeset, _} ->
        {:error, changeset}
    end
  end

  ## Invitations - user based

  def list_invitations_by_user(user) do
    user
    |> Invitation.by_user()
    |> Repo.all()
    |> Repo.preload(:org)
  end

  def accept_invitation!(audit_context, user, id) do
    invitation = get_invitation_by_user!(user, id)
    org = Repo.one!(Ecto.assoc(invitation, :org))

    {:ok, %{membership: membership}} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:membership, Membership.insert_changeset(org, user))
      |> Ecto.Multi.delete(:invitation, invitation)
      |> AuditLog.multi(
        %{audit_context | org: org},
        "orgs.accept_invitation",
        %{invitation_id: invitation.id, email: invitation.email}
      )
      |> Repo.transaction()

    %{membership | org: org}
  end

  def reject_invitation!(audit_context, user, id) do
    invitation = get_invitation_by_user!(user, id)

    {:ok, %{invitation: invitation}} =
      Ecto.Multi.new()
      |> Ecto.Multi.delete(:invitation, invitation)
      |> AuditLog.multi(
        %{audit_context | org: Repo.preload(invitation, :org).org},
        "orgs.reject_invitation",
        %{invitation_id: invitation.id, email: invitation.email}
      )
      |> Repo.transaction()

    invitation
  end

  defp get_invitation_by_user!(user, id) do
    user
    |> Invitation.by_user()
    |> Repo.get!(id)
  end

  @doc """
  It enables a Organization as a Seller.
  """
  def enable_as_seller(%Org{} = org) do
    org
    |> Ecto.Changeset.change(%{is_seller: true})
    |> Repo.update()
  end
end
