Bytepack.Repo.query!("TRUNCATE TABLE users RESTART IDENTITY CASCADE")
Bytepack.Repo.query!("TRUNCATE TABLE orgs RESTART IDENTITY CASCADE")

unless Code.ensure_loaded?(Bytepack.AccountsFixtures) do
  Code.require_file(Path.expand("../../test/support/fixtures/accounts_fixtures.ex", __DIR__))
end

unless Code.ensure_loaded?(Bytepack.PackagesFixtures) do
  Code.require_file(Path.expand("../../test/support/fixtures/packages_fixtures.ex", __DIR__))
end

unless Code.ensure_loaded?(Bytepack.SalesFixtures) do
  Code.require_file(Path.expand("../../test/support/fixtures/sales_fixtures.ex", __DIR__))
end

alias Bytepack.{
  AccountsFixtures,
  PackagesFixtures,
  SalesFixtures,
  Orgs
}

import Bytepack.AuditLog, only: [system: 0]

alice = AccountsFixtures.staff_fixture(%{email: "alice@example.com", password: "secret123456"})
bob = AccountsFixtures.user_fixture(%{email: "bob@example.com", password: "secret123456"})
carol = AccountsFixtures.user_fixture(%{email: "carol@example.com", password: "secret123456"})

AccountsFixtures.user_fixture(%{
  email: "dave@example.com",
  password: "secret123456",
  confirmed: false
})

{:ok, acme} =
  Orgs.create_org(system(), alice, %{name: "Acme", slug: "acme", email: "acme@example.com"})

{:ok, bob_invitation} = Orgs.create_invitation(system(), acme, %{email: bob.email}, "/")
{:ok, _} = Orgs.create_invitation(system(), acme, %{email: carol.email}, "/")
Orgs.accept_invitation!(system(), bob, bob_invitation.id)

tarball = PackagesFixtures.hex_package_tarball("foo-1.0.0/foo-1.0.0.tar")
{:ok, _} = Bytepack.Hex.publish(system(), acme, tarball)

tarball = PackagesFixtures.hex_package_tarball("foo-1.1.0/foo-1.1.0.tar")
{:ok, _} = Bytepack.Hex.publish(system(), acme, tarball)

tarball = PackagesFixtures.hex_package_tarball("bar-1.0.0/bar-1.0.0.tar")
{:ok, _} = Bytepack.Hex.publish(system(), acme, tarball)

tarball = PackagesFixtures.hex_package_tarball("baz-1.0.0/baz-1.0.0.tar")
{:ok, _} = Bytepack.Hex.publish(system(), acme, tarball)

# hardcode alice's tokens for automated tests against local dev server
Orgs.get_membership!(alice, acme.slug)
|> Ecto.Changeset.change(%{
  write_token: Base.url_decode64!("PIDRtu8F0Dax_HozFlcjFaICU1X3LKLC"),
  read_token: Base.url_decode64!("cdAMJ-dyrIzxTN9JoLG0Ub5zR9A43gCp")
})
|> Bytepack.Repo.update!()

Bytepack.Orgs.enable_as_seller(acme)
seller = Bytepack.Sales.get_seller!(acme)

{:ok, _} =
  Bytepack.Sales.update_seller(
    system(),
    seller,
    %{
      email: "acme@example.com",
      legal_name: "Acme Inc.",
      address_city: "Gothan",
      address_line1: "5th av",
      address_country: "BR"
    }
  )

foo = Bytepack.Packages.get_available_package_by!(acme, type: "hex", name: "foo")
bar = Bytepack.Packages.get_available_package_by!(acme, type: "hex", name: "bar")

foo_product =
  SalesFixtures.product_fixture(
    acme,
    %{
      name: "Acme Foo",
      description: "Lorem ipsum.",
      url: "http://localhost:4000",
      package_ids: [foo.id]
    }
  )

foo_bar_product =
  SalesFixtures.product_fixture(
    acme,
    %{
      name: "Acme Foo & Bar",
      description: "Lorem ipsum.",
      url: "http://localhost:4000",
      package_ids: [foo.id, bar.id]
    }
  )

{:ok, los_pollos} =
  Orgs.create_org(system(), alice, %{
    name: "Los Pollos Hermanos",
    slug: "los-pollos",
    email: "los-pollos@example.com"
  })

sale = SalesFixtures.sale_fixture(seller, foo_bar_product, email: alice.email)

{:ok, _} =
  Bytepack.Sales.deliver_create_sale_email(
    sale,
    &"http://localhost:4000/purchases/claim/#{sale.id}/#{&1}"
  )

Bytepack.Sales.complete_sale!(system(), sale, los_pollos)

SalesFixtures.sale_fixture(seller, foo_product, email: bob.email)
SalesFixtures.sale_fixture(seller, foo_product, email: carol.email)
