defmodule Bytepack.Packages.PackageDownload do
  use Bytepack.Schema

  @primary_key false
  schema "package_downloads" do
    field :date, :date, primary_key: true

    field :size, :integer, primary_key: true
    field :counter, :integer, default: 0

    belongs_to :org, Bytepack.Orgs.Org, primary_key: true
    belongs_to :user, Bytepack.Accounts.User, primary_key: true
    belongs_to :release, Bytepack.Packages.Release, primary_key: true
  end
end
