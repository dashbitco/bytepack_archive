defmodule Bytepack.SalesTest do
  use Bytepack.DataCase, async: true

  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.SalesFixtures
  import Bytepack.PackagesFixtures

  alias Bytepack.Sales
  alias Bytepack.Sales.{Product, Sale, Seller}

  describe "create_sale/3" do
    test "creates a new sale of a product to an email" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      seller = Sales.get_seller!(org)
      product = product_fixture(org)

      assert {:error, changeset} =
               Sales.create_sale(system(org), seller, %{
                 product_id: product.id,
                 email: "johnexample.com"
               })

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)

      assert {:ok, %Sale{} = sale} =
               Sales.create_sale(system(org), seller, %{
                 product_id: product.id,
                 external_id: "external-id",
                 email: "john@example.com"
               })

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "sales.create_sale")

      assert audit_log.params == %{
               "sale_id" => sale.id,
               "external_id" => sale.external_id,
               "email" => sale.email,
               "product_id" => sale.product_id
             }

      assert Sales.sale_state(sale) == :pending
    end

    test "validates that product belongs to seller" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})

      product = product_fixture(org)

      another_org = org_fixture(user_fixture(), %{is_seller: true})
      another_seller = Sales.get_seller!(another_org)

      assert {:error, changeset} =
               Sales.create_sale(system(), another_seller, %{
                 product_id: product.id,
                 email: "john@example.com"
               })

      assert %{product_id: ["does not belong to organization"]} = errors_on(changeset)
    end

    test "validates uniqueness of product, email and external id together" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      seller = Sales.get_seller!(org)
      product = product_fixture(org)

      {:ok, %Sale{}} =
        Sales.create_sale(system(), seller, %{
          product_id: product.id,
          external_id: "external-id",
          email: "john@example.com"
        })

      assert {:error, changeset} =
               Sales.create_sale(system(), seller, %{
                 product_id: product.id,
                 external_id: "external-id",
                 email: "john@example.com"
               })

      assert %{external_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates presence of email" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      seller = Sales.get_seller!(org)
      product = product_fixture(org)

      {:error, changeset} =
        Sales.create_sale(system(), seller, %{
          product_id: product.id,
          external_id: "external-id"
        })

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_sale/3" do
    test "updates an existing sale" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      product = product_fixture(org)
      second_product = product_fixture(org)

      sale = sale_fixture(org, product)
      %Sale{external_id: nil} = sale

      assert {:ok, %Sale{} = sale} =
               Sales.update_sale(system(org), sale, %{
                 external_id: "123456",
                 product_id: second_product.id
               })

      assert sale.external_id == "123456"

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "sales.update_sale")

      assert audit_log.params == %{
               "external_id" => "123456",
               "sale_id" => sale.id,
               "product_id" => second_product.id
             }
    end

    test "allows to remove the external id" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      product = product_fixture(org)

      sale = sale_fixture(org, product, %{external_id: "abcd1234"})

      assert {:ok, %Sale{} = sale} = Sales.update_sale(system(org), sale, %{external_id: nil})

      assert sale.external_id == nil

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "sales.update_sale")

      assert audit_log.params == %{
               "external_id" => nil,
               "sale_id" => sale.id,
               "product_id" => product.id
             }
    end

    test "validates uniqueness of product and external id together" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      seller = Sales.get_seller!(org)

      product = product_fixture(org)

      {:ok, %Sale{}} =
        Sales.create_sale(system(), seller, %{
          product_id: product.id,
          external_id: "external-id",
          email: "john@example.com"
        })

      {:ok, %Sale{} = sale} =
        Sales.create_sale(system(), seller, %{
          product_id: product.id,
          external_id: "another-external-id",
          email: "joanna@example.com"
        })

      assert {:error, changeset} =
               Sales.update_sale(system(), sale, %{external_id: "external-id"})

      assert %{external_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_sale!/2" do
    test "retrieves an existing sale if associated with org" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      product = product_fixture(org)

      sale = sale_fixture(org, product)
      %Sales.Sale{id: id} = sale

      assert %Sales.Sale{id: ^id, product: product} = Sales.get_sale!(org, sale.id)
      assert %Sales.Product{} = product

      another_user = user_fixture()
      another_org = org_fixture(another_user, %{is_seller: true})

      assert_raise Ecto.NoResultsError, fn -> Sales.get_sale!(another_org, sale.id) end
    end
  end

  describe "get_sale_by_id_and_token/2" do
    setup do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      product = product_fixture(org)
      %{sale: sale_fixture(org, product)}
    end

    test "returns a sale", %{sale: sale} do
      assert Sales.get_sale_by_id_and_token(sale.id, Base.url_encode64(sale.token)).id == sale.id
    end

    test "returns nil for bad data", %{sale: sale} do
      refute Sales.get_sale_by_id_and_token(sale.id, Base.url_encode64("bad"))
      refute Sales.get_sale_by_id_and_token(sale.id, "bad")
      refute Sales.get_sale_by_id_and_token(0, "bad")
    end

    test "returns nil for revoked sale", %{sale: sale} do
      Sales.revoke_sale(system(), sale, %{revoke_reason: "unpaid"})
      refute Sales.get_sale_by_id_and_token(sale.id, Base.url_encode64(sale.token))
    end
  end

  describe "complete_sale!/4" do
    setup do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      product = product_fixture(org)

      buyer_email = unique_sale_email()
      buyer_user = user_fixture(email: buyer_email)
      buyer = org_fixture(buyer_user)

      sale = sale_fixture(org, product, email: buyer_email, external_id: "external-id")

      {:ok,
       %{
         sale: sale,
         buyer: buyer,
         buyer_user: buyer_user,
         user: user,
         audit_context: %Bytepack.AuditLog{user: user}
       }}
    end

    test "completes a sale", %{sale: sale, buyer: buyer, audit_context: audit_context} do
      completed_at = ~U[2020-08-31 21:43:31.399289Z]

      assert %Sales.Sale{completed_at: ^completed_at, revoked_at: nil} =
               Sales.complete_sale!(audit_context, sale, buyer, completed_at)

      [audit_log] = Bytepack.AuditLog.list_by_org(buyer, action: "sales.complete_sale")

      assert audit_log.params == %{
               "sale_id" => sale.id,
               "buyer_id" => buyer.id,
               "external_id" => sale.external_id
             }
    end

    test "does not complete the sale if it was revoked", %{sale: sale, buyer: buyer} do
      {:ok, sale} = Sales.revoke_sale(system(), sale, %{revoke_reason: "unpaid"})

      assert_raise Ecto.InvalidChangesetError, ~r/cannot complete a sale that was revoked/, fn ->
        Sales.complete_sale!(system(), sale, buyer)
      end
    end

    test "confirms the buyer account if is not confirmed yet", %{
      sale: sale,
      buyer: buyer,
      buyer_user: buyer_user
    } do
      Repo.update!(Ecto.Changeset.change(buyer_user, %{confirmed_at: nil}))

      Sales.complete_sale!(system(), sale, buyer)

      buyer_user = Repo.get_by!(Bytepack.Accounts.User, email: sale.email)

      assert %DateTime{} = buyer_user.confirmed_at
    end

    test "raises an error if buyer user does not exist", %{sale: sale, buyer: buyer} do
      sale = Repo.update!(Ecto.Changeset.change(sale, %{email: unique_sale_email()}))

      assert_raise RuntimeError,
                   "the email associated with this sale does not have a correspondent user",
                   fn -> Sales.complete_sale!(system(), sale, buyer) end
    end
  end

  describe "revoke_sale/3" do
    test "mark revoked at for a sale" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      product = product_fixture(org)
      seller = seller_fixture(org)

      sale = sale_fixture(seller, product)

      assert {:ok, %Sales.Sale{revoked_at: %DateTime{}, revoke_reason: "unpaid"} = sale} =
               Sales.revoke_sale(system(org), sale, %{revoke_reason: "unpaid"})

      assert Sales.sale_state(sale) == :revoked

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "sales.revoke_sale")
      assert audit_log.params["sale_id"] == sale.id
      assert audit_log.params["revoked_at"]
    end

    test "just returns the sale if it's already revoked" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      product = product_fixture(org)
      seller = seller_fixture(org)

      sale = revoked_sale_fixture(seller, product, %{external_id: "1234"})

      assert {:ok, ^sale} = Sales.revoke_sale(system(org), sale, %{revoke_reason: "unpaid"})
    end
  end

  describe "activate_sale/3" do
    test "activate a sale that was revoked" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      product = product_fixture(org)
      seller = seller_fixture(org)

      sale = revoked_sale_fixture(seller, product, %{external_id: "1234"})

      assert {:ok, %Sales.Sale{revoked_at: nil} = sale} = Sales.activate_sale(system(org), sale)

      assert Sales.sale_state(sale) == :pending

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "sales.activate_sale")
      assert audit_log.params["sale_id"] == sale.id
      assert audit_log.params["external_id"] == "1234"
    end
  end

  describe "delete_sale/2" do
    test "deletes a pending sale" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      product = product_fixture(org)
      seller = seller_fixture(org)

      sale = sale_fixture(seller, product, external_id: "abc123")

      assert {:ok, sale} = Sales.delete_sale(system(org), sale)

      refute Bytepack.Repo.get(Sales.Sale, sale.id)

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "sales.delete_sale")

      assert audit_log.params == %{
               "sale_id" => sale.id,
               "buyer_id" => sale.buyer_id,
               "email" => sale.email,
               "external_id" => sale.external_id,
               "product_id" => sale.product_id
             }
    end

    test "does not delete a completed sale" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      product = product_fixture(org)

      buyer_email = unique_sale_email()
      buyer_user = user_fixture(email: buyer_email)
      buyer = org_fixture(buyer_user)

      sale = sale_fixture(org, product, email: buyer_email)
      completed_sale = Sales.complete_sale!(system(), sale, buyer)

      assert_raise Ecto.InvalidChangesetError,
                   ~r/cannot be deleted because it is completed/,
                   fn ->
                     Sales.delete_sale(system(), completed_sale)
                   end
    end
  end

  describe "sale_state/2" do
    test "returns calculated sale status" do
      now = DateTime.utc_now()
      completed = %Sales.Sale{completed_at: now, buyer_id: 42}

      assert Sales.sale_state(completed) == :active

      assert Sales.sale_state(%{completed | revoked_at: now}) == :revoked

      pending = %Sales.Sale{buyer_id: nil, completed_at: nil, revoked_at: nil}
      assert Sales.sale_state(pending) == :pending
      assert Sales.sale_state(%{pending | revoked_at: now}) == :revoked
    end
  end

  describe "can_be_activated?/1" do
    test "allow a revoked sale to be activated" do
      now = DateTime.utc_now()
      revoked_pending = %Sales.Sale{revoked_at: now}

      assert Sales.can_be_activated?(revoked_pending)

      revoked_completed = %Sales.Sale{completed_at: now, revoked_at: now, buyer_id: 42}

      assert Sales.can_be_activated?(revoked_completed)

      refute Sales.can_be_activated?(%Sales.Sale{})
      refute Sales.can_be_activated?(%Sales.Sale{completed_at: now})
    end
  end

  describe "can_be_revoked?/1" do
    test "allow an active sale to be revoked" do
      now = DateTime.utc_now()

      assert Sales.can_be_revoked?(%Sales.Sale{})

      completed = %Sales.Sale{completed_at: now, buyer_id: 42}

      assert Sales.can_be_revoked?(completed)

      refute Sales.can_be_revoked?(%Sales.Sale{revoked_at: now})
    end
  end

  describe "can_be_deleted?/1" do
    test "allow a pending or revoked but not completed sale to be deleted" do
      now = DateTime.utc_now()

      assert Sales.can_be_deleted?(%Sales.Sale{})

      completed = %Sales.Sale{completed_at: now, buyer_id: 42}

      refute Sales.can_be_deleted?(completed)

      assert Sales.can_be_deleted?(%Sales.Sale{revoked_at: now})
    end
  end

  describe "update_seller/3" do
    test "validates attributes" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      seller = Sales.get_seller!(org)

      assert {:error, changeset} =
               Sales.update_seller(system(org), seller, %{address_country: "XX"})

      assert %{address_country: ["is invalid"]} = errors_on(changeset)
      assert %{legal_name: ["can't be blank"]} = errors_on(changeset)
      assert %{address_city: ["can't be blank"]} = errors_on(changeset)
      assert %{address_line1: ["can't be blank"]} = errors_on(changeset)

      assert {:ok, %Seller{}} =
               Sales.update_seller(system(org), seller, %{
                 email: "acme@example.com",
                 legal_name: "Acme Inc.",
                 address_city: "Gothan",
                 address_line1: "5th av",
                 address_country: "BR"
               })

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "sales.update_seller")

      assert audit_log.params == %{"legal_name" => "Acme Inc.", "seller_id" => seller.id}
    end
  end

  describe "activate_seller/3" do
    test "enables org as seller and update seller attributes" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: false})
      seller = %Seller{id: org.id}

      assert {:error, changeset} = Sales.activate_seller(org, seller, %{address_country: "XX"})

      assert %{address_country: ["is invalid"]} = errors_on(changeset)

      assert {:ok, %Seller{} = seller} =
               Sales.activate_seller(org, seller, %{
                 email: "acme@example.com",
                 legal_name: "Acme Inc.",
                 address_city: "Gothan",
                 address_line1: "5th av",
                 address_country: "BR"
               })

      assert seller.legal_name == "Acme Inc."
      assert byte_size(seller.webhook_http_signature_secret) > 30
      assert Bytepack.Repo.get!(Bytepack.Orgs.Org, org.id).is_seller
    end
  end

  describe "encode_http_signature_secret/1" do
    test "encode seller's http signature secret" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      seller = seller_fixture(org)

      assert <<"wh_sig_", encoded_secret::binary()>> = Sales.encode_http_signature_secret(seller)

      assert Base.url_decode64!(encoded_secret, padding: false) ==
               seller.webhook_http_signature_secret
    end
  end

  describe "get_seller!/1" do
    test "returns an existing org as seller" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})

      assert %Seller{id: org_id} = Sales.get_seller!(org)
      assert org_id == org.id
    end

    test "raises error when org is not a seller" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: false})

      assert_raise Ecto.NoResultsError, fn -> Sales.get_seller!(org) end
    end

    test "raises error when org does not exist" do
      assert_raise Ecto.NoResultsError, fn -> Sales.get_seller!(%Bytepack.Orgs.Org{id: 0}) end
    end
  end

  describe "create_product/4" do
    test "with valid data" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      foo = package_fixture(org)
      bar = package_fixture(org)
      unrelated_package = package_fixture(org_fixture(user))

      {:ok, product} =
        Sales.create_product(
          system(org),
          org,
          %{
            name: "foo",
            description: "bar",
            url: "https://foo.com",
            package_ids: [bar.id, unrelated_package.id]
          },
          %{bar.id => MapSet.new([foo.id])}
        )

      assert product.name == "foo"
      assert product.description == "bar"
      assert Enum.sort(product.packages) == Enum.sort([foo, bar])

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "sales.create_product")

      assert audit_log.params == %{"name" => "foo"}
    end

    test "requires package ids" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})

      {:error, changeset} =
        Sales.create_product(
          system(org),
          org,
          %{name: "foo", description: "bar", url: "https://foo.com"},
          %{}
        )

      assert errors_on(changeset).package_ids == ["can't be blank"]
    end

    test "with invalid data" do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})

      {:error, changeset} = Sales.create_product(system(org), org, %{name: ""}, %{})

      assert "can't be blank" in errors_on(changeset).name

      assert [] = Bytepack.AuditLog.list_by_org(org, action: "sales.create_product")
    end
  end

  describe "update_product/4" do
    setup do
      user = user_fixture()
      org = org_fixture(user, %{is_seller: true})
      foo = package_fixture(org)
      bar = package_fixture(org)
      product = product_fixture(org, package_ids: [foo.id])
      %{org: org, product: product, foo: foo, bar: bar}
    end

    test "with valid data updates name keeping packages",
         %{product: product, foo: foo, org: org} do
      original_name = product.name
      {:ok, product} = Sales.update_product(system(org), product, %{name: "updated"}, %{})
      assert product.name == "updated"
      assert Repo.preload(product, :packages, force: true).packages == [foo]

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "sales.update_product")

      assert audit_log.params == %{
               "original_name" => original_name,
               "new_name" => "updated",
               "product_id" => product.id
             }
    end

    test "with valid data updates name replacing packages",
         %{product: product, bar: bar} do
      {:ok, product} =
        Sales.update_product(system(), product, %{name: "updated", package_ids: [bar.id]}, %{})

      assert product.name == "updated"
      assert Repo.preload(product, :packages, force: true).packages == [bar]
    end

    test "with valid data updates name adding packages",
         %{org: org, product: product, foo: foo, bar: bar} do
      sale_fixture(org, product)

      {:ok, product} =
        Sales.update_product(system(), product, %{name: "updated", package_ids: [bar.id]}, %{})

      assert product.name == "updated"
      assert Repo.preload(product, :packages, force: true).packages == [foo, bar]
    end
  end

  describe "change_product/3" do
    test "normalizes URL" do
      changeset = Sales.change_product(%Product{}, %{url: "https://acme.com"}, %{})
      assert changeset.changes.url == "https://acme.com"

      changeset = Sales.change_product(%Product{}, %{url: "acme.com"}, %{})
      assert changeset.changes.url == "https://acme.com"
    end
  end

  describe "list_products_by_seller_ids/1" do
    test "List products across all provided orgs" do
      seller_user = user_fixture()
      buyer_user1 = user_fixture()
      buyer_user2 = user_fixture()
      seller_org1 = org_fixture(seller_user)
      seller_org2 = org_fixture(seller_user)
      buyer_org1 = org_fixture(buyer_user1)
      buyer_org2 = org_fixture(buyer_user2)

      product1 = product_fixture(seller_org1)
      product2 = product_fixture(seller_org2)

      sale1 = sale_fixture(seller_org1, product1, email: buyer_user1.email)
      sale2 = sale_fixture(seller_org2, product2, email: buyer_user2.email)

      Sales.complete_sale!(system(), sale1, buyer_org1)
      Sales.complete_sale!(system(), sale2, buyer_org2)

      products = Sales.list_products_by_seller_ids([seller_org1.id, seller_org2.id])
      product_ids = Enum.map(products, & &1.id)

      assert product_ids == [product1.id, product2.id]
    end
  end
end
