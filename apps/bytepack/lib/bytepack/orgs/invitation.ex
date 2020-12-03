defmodule Bytepack.Orgs.Invitation do
  use Bytepack.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Bytepack.Repo
  alias Bytepack.Orgs.{Org, Membership}
  alias Bytepack.Accounts

  schema "orgs_invitations" do
    field :email, :string
    belongs_to :org, Org
    belongs_to :user, Accounts.User
    timestamps()
  end

  def by_org(%Org{} = org) do
    from(__MODULE__, where: [org_id: ^org.id])
  end

  def by_user(%Accounts.User{} = user) do
    from(__MODULE__, where: [user_id: ^user.id])
  end

  @doc """
  Find invitations by `email` and assign them to the `user`.
  """
  def assign_to_user_by_email(%Accounts.User{} = user, email) do
    from(__MODULE__, where: [email: ^email], update: [set: [user_id: ^user.id]])
  end

  @doc """
  Get invitations for `user_id` for which the user already joined the org.
  """
  def get_stale_by_user_id(user_id) do
    from(i in __MODULE__,
      join: o in assoc(i, :org),
      join: ms in "orgs_memberships",
      on: ms.org_id == o.id and ms.member_id == ^user_id
    )
  end

  @already_invited "is already invited"

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> Bytepack.Extensions.Ecto.Validations.validate_email(:email)
    |> unsafe_validate_unique([:email, :org_id], Repo, message: @already_invited)
    |> unique_constraint([:email, :org_id], message: @already_invited)
    |> put_user_id()
    |> ensure_user_not_already_in_org()
  end

  defp put_user_id(%{valid?: true} = changeset) do
    email = fetch_change!(changeset, :email)
    user = Accounts.get_user_by_email(email)
    put_change(changeset, :user_id, user && user.confirmed_at && user.id)
  end

  defp put_user_id(changeset), do: changeset

  defp ensure_user_not_already_in_org(changeset) do
    org_id = changeset.data.org_id
    user_id = get_change(changeset, :user_id)

    if user_id && Repo.exists?(from(Membership, where: [org_id: ^org_id, member_id: ^user_id])) do
      add_error(changeset, :email, "already in this organization")
    else
      changeset
    end
  end
end
