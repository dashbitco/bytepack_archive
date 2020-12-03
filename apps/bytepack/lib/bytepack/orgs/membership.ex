defmodule Bytepack.Orgs.Membership do
  use Bytepack.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Bytepack.Orgs.{Member, Org}
  alias Bytepack.Accounts.User

  @rand_size 24
  @default_role "member"
  @admin_role "admin"

  schema "orgs_memberships" do
    field :write_token, :binary
    field :read_token, :binary
    # TODO: use Ecto.Enum when we use v3.5
    field :role, :string

    belongs_to :member, Member
    belongs_to :org, Org
    timestamps()
  end

  def by_user_and_org_slug(%User{} = user, org_slug) do
    from(ms in __MODULE__,
      join: org in assoc(ms, :org),
      on: [slug: ^org_slug],
      where: ms.member_id == ^user.id
    )
  end

  def all_by_org(%Org{} = org) do
    from(ms in __MODULE__,
      join: m in assoc(ms, :member),
      join: o in assoc(ms, :org),
      on: o.id == ^org.id,
      preload: [:member]
    )
  end

  def encode_read_token(%__MODULE__{} = membership) do
    "r_" <>
      Integer.to_string(membership.id, 32) <>
      "_" <>
      Base.url_encode64(membership.read_token)
  end

  def encode_write_token(%__MODULE__{} = membership) do
    "w_" <>
      Integer.to_string(membership.id, 32) <>
      "_" <>
      Base.url_encode64(membership.write_token)
  end

  @doc """
  Checks if the `encoded_token` is valid and returns its underlying lookup query.

  The `encoded_token` is in the form `<mode>_<encoded_membership_id>_<token>`.

  Returns the query to get the membership and the token to check against.
  """
  def verify_token_query(org, mode, encoded_token) when is_binary(encoded_token) do
    with <<^mode, ?_, encoded_token::binary>> <- encoded_token,
         [encoded_id, encoded_token] <- :binary.split(encoded_token, "_"),
         {id, ""} <- Integer.parse(encoded_id, 32),
         {:ok, token} <- Base.url_decode64(encoded_token, padding: false) do
      query = from(membership in __MODULE__, where: [org_id: ^org.id, id: ^id])
      {:ok, query, token}
    else
      _ -> :error
    end
  end

  def insert_changeset(org, user, role \\ @default_role) do
    write_token = :crypto.strong_rand_bytes(@rand_size)
    read_token = :crypto.strong_rand_bytes(@rand_size)

    change(%__MODULE__{
      org_id: org.id,
      member_id: user.id,
      write_token: write_token,
      role: role,
      read_token: read_token
    })
  end

  def update_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, ~w[admin member])
    |> prepare_changes(fn changeset ->
      current_role = membership.role
      new_role = get_change(changeset, :role)

      if current_role == @admin_role && new_role != current_role do
        validate_at_least_one_admin(changeset)
      else
        changeset
      end
    end)
  end

  def delete_changeset(%__MODULE__{} = membership) do
    membership
    |> change()
    |> prepare_changes(&validate_at_least_one_admin/1)
  end

  defp validate_at_least_one_admin(changeset) do
    org_id = changeset.data.org_id
    member_id = changeset.data.member_id

    query =
      from(m in __MODULE__,
        where: m.org_id == ^org_id and m.role == @admin_role and m.member_id != ^member_id,
        select: count(1)
      )

    if changeset.repo.one!(query) > 0 do
      changeset
    else
      add_error(changeset, :role, "cannot remove last admin of the organization")
    end
  end
end
