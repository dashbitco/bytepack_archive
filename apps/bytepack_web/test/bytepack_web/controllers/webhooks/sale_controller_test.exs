defmodule BytepackWeb.Webhooks.SaleControllerTest do
  use BytepackWeb.ConnCase

  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.SalesFixtures
  import Bytepack.SwooshHelpers

  alias BytepackWeb.Webhooks.HTTPSignature
  alias Bytepack.Orgs
  alias Bytepack.Sales

  setup %{conn: conn} do
    user = user_fixture()
    org = org_fixture(user, is_seller: true)
    seller = seller_fixture(org)

    {:ok,
     %{
       org: org,
       user: user,
       seller: seller,
       membership: Orgs.get_membership!(user, org.slug),
       conn: put_req_header(conn, "accept", "application/json")
     }}
  end

  defp post_signed(conn, path, payload, seller, membership) do
    payload = Jason.encode!(payload)

    timestamp = System.system_time(:second)

    {:ok, signature} =
      HTTPSignature.sign(payload, timestamp, Sales.encode_http_signature_secret(seller))

    token = Orgs.Membership.encode_write_token(membership)

    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
    |> put_req_header("bytepack-signature", signature)
    |> post(
      path,
      payload
    )
  end

  defp patch_signed(conn, path, payload, seller, membership) do
    payload = Jason.encode!(payload)

    timestamp = System.system_time(:second)

    {:ok, signature} =
      HTTPSignature.sign(payload, timestamp, Sales.encode_http_signature_secret(seller))

    token = Orgs.Membership.encode_write_token(membership)

    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
    |> put_req_header("bytepack-signature", signature)
    |> patch(
      path,
      payload
    )
  end

  describe "create/2" do
    test "create a new sale", %{
      conn: conn,
      user: user,
      org: org,
      seller: seller,
      membership: membership
    } do
      product = product_fixture(org)
      email = unique_invitation_email()
      external_id = "an-unique-external-id"

      conn =
        post_signed(
          conn,
          Routes.webhook_sale_path(conn, :create, org),
          %{
            "sale" => %{
              "product_id" => product.id,
              "email" => email,
              "external_id" => external_id
            }
          },
          seller,
          membership
        )

      assert %{
               "id" => id,
               "product_id" => product_id,
               "email" => email,
               "external_id" => ^external_id
             } = json_response(conn, 201)["sale"]

      assert product_id == product.id

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "sales.create_sale")

      assert audit_log.params == %{
               "sale_id" => id,
               "external_id" => external_id,
               "email" => email,
               "product_id" => product.id
             }

      assert audit_log.org_id == org.id
      assert audit_log.user_email == user.email
      assert audit_log.user_id == user.id

      assert_received_email(
        to: email,
        subject: "Access your #{product.name} purchase on Bytepack"
      )
    end

    test "does not create a sale for non-existing product", %{
      conn: conn,
      org: org,
      seller: seller,
      membership: membership
    } do
      email = unique_invitation_email()
      external_id = "an-unique-external-id"

      conn =
        post_signed(
          conn,
          Routes.webhook_sale_path(conn, :create, org),
          %{
            "sale" => %{
              "product_id" => 0,
              "email" => email,
              "external_id" => external_id
            }
          },
          seller,
          membership
        )

      assert %{
               "product_id" => ["does not exist"]
             } = json_response(conn, 422)["errors"]
    end

    test "does not create sale with invalid token", %{conn: conn, org: org} do
      product = product_fixture(org)

      conn =
        conn
        |> put_req_header("authorization", "Bearer non-sense-token")
        |> post(
          Routes.webhook_sale_path(conn, :create, org),
          %{
            "sale" => %{
              "product_id" => product.id,
              "email" => unique_invitation_email(),
              "external_id" => "unique-external-id"
            }
          }
        )

      assert %{
               "status" => "401",
               "title" => "Unauthorized"
             } = json_response(conn, 401)["error"]
    end

    test "does not create sale with invalid signature", %{
      conn: conn,
      org: org,
      seller: seller,
      membership: membership
    } do
      product = product_fixture(org)
      email = unique_invitation_email()
      external_id = "an-unique-external-id"

      conn =
        post_signed(
          conn,
          Routes.webhook_sale_path(conn, :create, org),
          %{
            "sale" => %{
              "product_id" => product.id,
              "email" => email,
              "external_id" => external_id
            }
          },
          %{seller | webhook_http_signature_secret: "another-signature"},
          membership
        )

      assert %{
               "status" => "400",
               "title" => title
             } = json_response(conn, 400)["error"]

      assert title =~ "HTTP Signature is invalid"
    end
  end

  describe "revoke/2" do
    test "revokes a sale by id", %{
      conn: conn,
      org: org,
      seller: seller,
      membership: membership
    } do
      product = product_fixture(org)
      sale = sale_fixture(seller, product)

      conn =
        patch_signed(
          conn,
          Routes.webhook_sale_path(conn, :revoke, org),
          %{
            "id" => sale.id,
            "sale" => %{
              "revoke_reason" => "unpaid"
            }
          },
          seller,
          membership
        )

      assert %{
               "id" => id,
               "product_id" => _product_id,
               "email" => _email,
               "external_id" => _
             } = json_response(conn, 200)["sale"]

      assert Sales.sale_state(Sales.get_sale!(seller, id)) == :revoked
    end

    test "revokes a sale by external id", %{
      conn: conn,
      org: org,
      seller: seller,
      membership: membership
    } do
      product = product_fixture(org)
      external_id = "alpha-beta-gama"
      sale_fixture(seller, product, %{external_id: external_id})

      conn =
        patch_signed(
          conn,
          Routes.webhook_sale_path(conn, :revoke, org),
          %{
            "external_id" => external_id,
            "sale" => %{
              "revoke_reason" => "unpaid"
            }
          },
          seller,
          membership
        )

      assert %{
               "id" => id,
               "product_id" => _product_id,
               "email" => _email,
               "external_id" => ^external_id
             } = json_response(conn, 200)["sale"]

      assert Sales.sale_state(Sales.get_sale!(seller, id)) == :revoked
    end
  end

  describe "update/2" do
    test "update a sale", %{
      conn: conn,
      user: user,
      org: org,
      seller: seller,
      membership: membership
    } do
      product = product_fixture(org)
      second_product = product_fixture(org)
      email = unique_invitation_email()

      sale =
        sale_fixture(seller, product, %{
          external_id: "an-unique-external-id",
          email: email
        })

      external_id = "another-unique-external-id"

      conn =
        patch_signed(
          conn,
          Routes.webhook_sale_path(conn, :update, org),
          %{
            "id" => sale.id,
            "sale" => %{
              "product_id" => second_product.id,
              "external_id" => external_id
            }
          },
          seller,
          membership
        )

      assert %{
               "id" => _id,
               "product_id" => product_id,
               "email" => ^email,
               "external_id" => ^external_id
             } = json_response(conn, 200)["sale"]

      assert product_id == second_product.id

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "sales.update_sale")

      assert audit_log.params == %{
               "sale_id" => sale.id,
               "external_id" => external_id,
               "product_id" => second_product.id
             }

      assert audit_log.org_id == org.id
      assert audit_log.user_email == user.email
      assert audit_log.user_id == user.id
    end

    test "does not update a sale with an non-existing product", %{
      conn: conn,
      org: org,
      seller: seller,
      membership: membership
    } do
      product = product_fixture(org)
      external_id = "an-unique-external-id"

      sale_fixture(seller, product, %{
        external_id: external_id,
        email: unique_invitation_email()
      })

      conn =
        patch_signed(
          conn,
          Routes.webhook_sale_path(conn, :update, org),
          %{
            "external_id" => external_id,
            "sale" => %{
              "product_id" => 0
            }
          },
          seller,
          membership
        )

      assert %{
               "product_id" => ["does not exist"]
             } = json_response(conn, 422)["errors"]
    end
  end
end
