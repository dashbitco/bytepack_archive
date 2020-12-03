defmodule Bytepack.SalesFixtures do
  alias Bytepack.Sales

  defp padded_unique_integer do
    # We use a padded string because we sort by name and we want to keep the name
    # deterministic, otherwise 10 will become before 9 on lexical sorting.
    System.unique_integer([:positive, :monotonic])
    |> Integer.to_string()
    |> String.pad_leading(10, "0")
  end

  def unique_product_name(), do: "product-#{padded_unique_integer()}"

  def unique_product_url(), do: "https://product#{System.unique_integer([:positive])}.example.com"

  def unique_webhook_signature_secret(),
    do: "wh_sig_test_#{Base.encode16(:crypto.strong_rand_bytes(32), case: :lower)}"

  def product_fixture(org, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        name: unique_product_name(),
        description: "Lorem ipsum.",
        url: unique_product_url(),
        deps_map: %{}
      })
      |> Map.put_new_lazy(:package_ids, fn ->
        [Bytepack.PackagesFixtures.package_fixture(org).id]
      end)

    {:ok, product} =
      Bytepack.Sales.create_product(Bytepack.AuditLog.system(), org, attrs, attrs.deps_map)

    product
  end

  def unique_sale_email(), do: "email#{System.unique_integer([:positive])}@example.com"

  def sale_fixture(seller_or_org, product, attrs \\ %{})

  def sale_fixture(%Bytepack.Orgs.Org{} = org, product, attrs) do
    sale_fixture(Bytepack.Sales.get_seller!(org), product, attrs)
  end

  def sale_fixture(%Bytepack.Sales.Seller{} = seller, product, attrs) do
    audit_context = Bytepack.AuditLog.system()

    attrs =
      Enum.into(attrs, %{
        email: unique_sale_email(),
        product_id: product.id
      })

    {:ok, sale} = Sales.create_sale(audit_context, seller, attrs)

    sale
  end

  def revoked_sale_fixture(seller, product, attrs \\ %{}) do
    audit_context = Bytepack.AuditLog.system()
    sale = sale_fixture(seller, product, attrs)
    {:ok, sale} = Sales.revoke_sale(audit_context, sale, %{revoke_reason: "unpaid"})
    sale
  end

  def seller_fixture(%Bytepack.Orgs.Org{is_seller: true} = org, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        email: "seller#{System.unique_integer([:positive])}@example.com",
        legal_name: "Acme Inc.",
        address_city: "Gothan",
        address_line1: "5th av",
        address_country: "BR"
      })

    {:ok, seller} =
      Sales.update_seller(
        Bytepack.AuditLog.system(),
        %Sales.Seller{
          id: org.id
        },
        attrs
      )

    seller
  end
end
