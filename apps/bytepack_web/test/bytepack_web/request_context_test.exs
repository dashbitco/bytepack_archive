defmodule BytepackWeb.RequestContextTest do
  use BytepackWeb.ConnCase, async: true

  alias Bytepack.Accounts.User
  alias Bytepack.Orgs.Org

  import BytepackWeb.RequestContext

  describe "put_audit_context/2" do
    test "uses first IP address from x-forwarded-for", %{conn: conn} do
      conn = put_req_header(conn, "x-forwarded-for", "9.9.9.9,8.8.8.8")
      audit_context = put_audit_context(conn, []).assigns.audit_context
      assert audit_context.ip_address == {9, 9, 9, 9}
    end

    test "handles invalid IP address from x-forwarded-for", %{conn: conn} do
      conn = put_req_header(conn, "x-forwarded-for", "9.9.9.bad")
      audit_context = put_audit_context(conn, []).assigns.audit_context
      refute audit_context.ip_address
    end
  end

  describe "put_sentry_context/2" do
    test "stores user and org information", %{conn: conn} do
      conn
      |> assign(:current_user, %User{id: 1})
      |> assign(:current_org, %Org{id: 1})
      |> put_sentry_context()

      assert Sentry.Context.get_all().user == %{id: 1, username: "User 1", org_id: 1}
    end

    test "stores request information", %{conn: conn} do
      conn
      |> put_req_header("user-agent", "test")
      |> put_resp_header("x-request-id", "abcdef")
      |> put_sentry_context()

      assert Sentry.Context.get_all().request == %{
               env: %{REQUEST_ID: "abcdef", SERVER_NAME: "www.example.com"},
               headers: %{"User-Agent": "test"},
               method: "GET",
               query_string: "",
               url: "http://www.example.com/"
             }
    end
  end
end
