defmodule Bytepack.Orgs.Member do
  use Bytepack.Schema
  import Ecto.Query
  alias Bytepack.Orgs.Org

  schema "users" do
    field :email, :string
  end

  def by_org(%Org{} = org) do
    from(m in __MODULE__,
      inner_join: ms in "orgs_memberships",
      on: ms.member_id == m.id and ms.org_id == ^org.id,
      order_by: m.email
    )
  end
end
