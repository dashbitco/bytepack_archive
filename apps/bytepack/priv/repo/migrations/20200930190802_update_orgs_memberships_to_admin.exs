defmodule Bytepack.Repo.Migrations.UpdateOrgsMembershipsToAdmin do
  use Ecto.Migration

  def up do
    Bytepack.Repo.update_all(Bytepack.Orgs.Membership, set: [role: "admin"])
  end

  def down do
    Bytepack.Repo.update_all(Bytepack.Orgs.Membership, set: [role: "member"])
  end
end
