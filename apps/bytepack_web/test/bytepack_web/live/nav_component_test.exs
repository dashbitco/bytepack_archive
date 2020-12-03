defmodule BytepackWeb.NavComponentTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Bytepack.OrgsFixtures
  alias BytepackWeb.NavComponent

  setup :register_and_login_user

  test "no organization selected", %{conn: conn, user: user, org: org} do
    content =
      render_component(NavComponent,
        acl: [:user, :dashboard],
        current_user: user,
        current_org: nil,
        current_membership: %{org: %{is_seller: false}}
      )

    assert content =~ "Welcome,"
    assert content =~ user.email
    assert content =~ "Choose Organization"
    assert content =~ ~s[href="#{Routes.org_dashboard_index_path(conn, :index, org.slug)}">]
    assert content =~ org.name
  end

  test "one of one organization selected", %{conn: conn, user: user, org: org} do
    content =
      render_component(NavComponent,
        acl: [:user, :dashboard],
        current_user: user,
        current_org: org,
        current_membership: %{org: %{is_seller: false}}
      )

    assert content =~ org.name
    assert content =~ user.email
    refute content =~ "Choose Organization"

    refute content =~
             ~s[href="#{Routes.org_dashboard_index_path(conn, :index, org.slug)}">#{org.name}"]
  end

  test "one of many organizations selected", %{conn: conn, user: user, org: org} do
    another_org = org_fixture(user)

    content =
      render_component(NavComponent,
        acl: [:user, :dashboard],
        current_user: user,
        current_org: org,
        current_membership: %{org: %{is_seller: false}}
      )

    assert content =~ org.name
    assert content =~ user.email
    assert content =~ "Choose Organization"

    assert content =~
             ~s[href="#{Routes.org_dashboard_index_path(conn, :index, another_org.slug)}">#{
               another_org.name
             }]

    refute content =~
             ~s[href="#{Routes.org_dashboard_index_path(conn, :index, org.slug)}">#{org.name}]
  end
end
