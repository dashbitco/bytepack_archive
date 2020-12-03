defmodule Bytepack.PurchasesTest do
  use Bytepack.DataCase, async: true

  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.PackagesFixtures
  import Bytepack.SalesFixtures

  alias Bytepack.Sales
  alias Bytepack.Purchases

  setup do
    seller_org = org_fixture(user_fixture())
    buyer_user = user_fixture()
    buyer_org = org_fixture(buyer_user)

    package = package_fixture(seller_org)
    package_fixture(seller_org)

    [
      seller_org: seller_org,
      buyer_org: buyer_org,
      buyer_user: buyer_user,
      package: package
    ]
  end

  test "list_all_purchases/1", %{
    seller_org: seller_org,
    buyer_org: buyer_org,
    buyer_user: buyer_user
  } do
    package = package_with_multiple_releases_fixture(seller_org)
    product = product_fixture(seller_org, package_ids: [package.id])
    assert [] = Purchases.list_all_purchases(buyer_org)

    sale = sale_fixture(seller_org, product, email: buyer_user.email)
    Sales.complete_sale!(system(), sale, buyer_org)
    assert [sale] = Purchases.list_all_purchases(buyer_org)
    assert sale.product_id == product.id

    Sales.revoke_sale(system(), sale, %{revoke_reason: "unpaid"})
    assert [revoked_sale] = Purchases.list_all_purchases(buyer_org)
    assert revoked_sale.id == sale.id
    assert revoked_sale.revoked_at
  end

  test "list_available_purchases_by_buyer_ids/1", %{
    seller_org: seller_org1,
    buyer_org: buyer_org1,
    buyer_user: buyer_user
  } do
    seller_org2 = org_fixture(user_fixture())
    buyer_org2 = org_fixture(buyer_user)
    product1 = product_fixture(seller_org1)
    product2 = product_fixture(seller_org2)

    sale1 = sale_fixture(seller_org1, product1, email: buyer_user.email)
    sale2 = sale_fixture(seller_org2, product2, email: buyer_user.email)

    Sales.complete_sale!(system(), sale1, buyer_org1)
    Sales.complete_sale!(system(), sale2, buyer_org2)

    purchases = Purchases.list_available_purchases_by_buyer_ids([buyer_org1.id, buyer_org2.id])
    product_ids = Enum.map(purchases, & &1.product_id)
    assert product_ids == [product2.id, product1.id]

    Sales.revoke_sale(system(), sale1, %{revoke_reason: "unpaid"})
    assert Purchases.list_available_purchases_by_buyer_ids([buyer_org1.id]) == []
  end

  test "list_pending_purchases_by_email/1", %{
    seller_org: seller_org1,
    buyer_org: buyer_org1,
    buyer_user: buyer_user
  } do
    seller_org2 = org_fixture(user_fixture())
    product1 = product_fixture(seller_org1)
    product2 = product_fixture(seller_org2)
    product3 = product_fixture(seller_org2)

    sale1 = sale_fixture(seller_org1, product1, email: buyer_user.email)
    sale_fixture(seller_org2, product2, email: buyer_user.email)
    sale3 = sale_fixture(seller_org2, product3, email: buyer_user.email)

    purchases = Purchases.list_pending_purchases_by_email(buyer_user.email)
    product_ids = Enum.map(purchases, & &1.product_id)
    assert product_ids == [product3.id, product2.id, product1.id]

    Sales.complete_sale!(system(), sale3, buyer_org1)
    Sales.revoke_sale(system(), sale1, %{revoke_reason: "unpaid"})

    purchases = Purchases.list_pending_purchases_by_email(buyer_user.email)
    product_ids = Enum.map(purchases, & &1.product_id)
    assert product_ids == [product2.id]
  end

  test "get_any_purchase_with_releases!/2", %{
    seller_org: seller_org,
    buyer_org: buyer_org,
    buyer_user: buyer_user
  } do
    package = package_with_multiple_releases_fixture(seller_org)
    product = product_fixture(seller_org, package_ids: [package.id])
    sale = sale_fixture(seller_org, product, email: buyer_user.email)
    Sales.complete_sale!(system(), sale, buyer_org)

    purchase = Purchases.get_any_purchase_with_releases!(buyer_org, sale.id)
    package = hd(purchase.product.packages)
    assert Enum.map(package.releases, & &1.version) == ["1.3.0", "1.1.0", "1.0.0"]

    Sales.revoke_sale(system(), sale, %{revoke_reason: "unpaid"})
    assert Purchases.get_any_purchase_with_releases!(buyer_org, sale.id)
  end

  describe "claim_purchase/4" do
    setup %{seller_org: seller_org} do
      product = product_fixture(seller_org)
      sale = sale_fixture(seller_org, product)
      token = Purchases.purchase_token(sale)
      %{product: product, sale: sale, token: token}
    end

    test "returns sale for a user", %{sale: sale, token: token} do
      user = user_fixture(email: sale.email)
      assert {:ok, ^sale} = Purchases.claim_purchase(user, [], sale.id, token)
    end

    test "returns sale for no user", %{sale: sale, token: token} do
      assert {:ok, ^sale} = Purchases.claim_purchase(nil, nil, sale.id, token)
    end

    test "handles sales that has been already claimed by the user", %{sale: sale, token: token} do
      buyer = user_fixture(email: sale.email)
      buyer_org = org_fixture(buyer)
      Sales.complete_sale!(system(), sale, buyer_org)

      assert {:already_claimed, loaded_sale} =
               Purchases.claim_purchase(buyer, [buyer_org], sale.id, token)

      assert loaded_sale.id == sale.id
    end

    test "returns error on invalid sale", %{sale: sale, token: token} do
      assert {:error, "Purchase not found"} = Purchases.claim_purchase(nil, nil, sale.id, "bad")
      assert {:error, "Purchase not found"} = Purchases.claim_purchase(nil, nil, 0, token)

      Sales.revoke_sale(system(), sale, %{revoke_reason: "unpaid"})
      assert {:error, "Purchase not found"} = Purchases.claim_purchase(nil, nil, sale.id, token)
    end

    test "returns error on sale and user e-mail mismatch", %{sale: sale, token: token} do
      user = user_fixture(email: unique_user_email())

      assert {:error,
              "The purchase was made with a different e-mail address than the one used by this account"} =
               Purchases.claim_purchase(user, [], sale.id, token)
    end

    test "returns error on completed sale", %{sale: sale, token: token} do
      Sales.complete_sale!(system(), sale, org_fixture(user_fixture(%{email: sale.email})))

      assert {:error, "Purchase has already been linked to another account"} =
               Purchases.claim_purchase(nil, nil, sale.id, token)
    end
  end

  ## Packages

  test "list_available_packages/1", %{
    seller_org: seller_org,
    buyer_org: buyer_org,
    buyer_user: buyer_user,
    package: package
  } do
    product = product_fixture(seller_org, package_ids: [package.id])
    assert [] = Purchases.list_available_packages(buyer_org)

    sale = sale_fixture(seller_org, product, email: buyer_user.email)
    Sales.complete_sale!(system(), sale, buyer_org)
    assert Purchases.list_available_packages(buyer_org) == [package]
    assert Purchases.list_available_packages(buyer_org, type: "hex") == [package]
    assert Purchases.list_available_packages(buyer_org, type: "none") == []

    Sales.revoke_sale(system(), sale, %{revoke_reason: "unpaid"})
    assert Purchases.list_available_packages(buyer_org) == []
  end

  ## Buyer Registration

  describe "register_buyer/3" do
    setup %{seller_org: seller_org} do
      product = product_fixture(seller_org)
      sale = sale_fixture(seller_org, product)
      %{sale: sale}
    end

    test "creates a user, an org, and completes the sale", %{sale: sale} do
      org_name = unique_org_name()

      params = %{
        user_password: valid_user_password(),
        organization_name: org_name,
        organization_slug: org_name,
        organization_email: unique_org_email(),
        terms_of_service: true
      }

      assert {:ok, %{org: org, user: user, sale: sale}} =
               Purchases.register_buyer(system(), sale, params)

      assert org.name == params.organization_name
      assert org.slug == params.organization_slug
      assert org.email == params.organization_email

      assert user.email == sale.email
      assert user.confirmed_at

      assert sale.completed_at
      assert sale.buyer_id == org.id
    end

    test "handles user errors", %{sale: sale} do
      {:error, changeset} = Purchases.register_buyer(system(), sale, %{})
      assert errors_on(changeset).user_password == ["can't be blank"]
      assert errors_on(changeset).terms_of_service == ["You must agree before continuing"]

      # we only attempt creating an org after we successfully created a user
      assert Keyword.keys(changeset.errors) == [:user_password, :terms_of_service]
    end

    test "handles org errors", %{sale: sale} do
      {:error, changeset} =
        Purchases.register_buyer(system(), sale, %{
          user_password: valid_user_password(),
          terms_of_service: true
        })

      assert errors_on(changeset).organization_name == ["can't be blank"]

      assert Keyword.keys(changeset.errors) == [
               :organization_email,
               :organization_name,
               :organization_slug
             ]
    end
  end
end
