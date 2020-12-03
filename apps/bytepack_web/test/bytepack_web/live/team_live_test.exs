defmodule BytepackWeb.TeamLiveTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Bytepack.OrgsFixtures

  alias Bytepack.Accounts
  setup :register_and_login_user

  test "lists members", %{conn: conn, org: org, user: admin} do
    member = member_fixture(org)

    {:ok, _, html} = live(conn, Routes.team_index_path(conn, :index, org))
    assert html =~ "Members"
    assert html =~ member.email
    assert html =~ admin.email
  end

  test "deletes member", %{conn: conn, org: org, user: user} do
    member = member_fixture(org)
    token = Accounts.generate_user_session_token(Accounts.get_user!(member.id))
    BytepackWeb.Endpoint.subscribe("user_sessions:#{token}")

    {:ok, team_live, _} = live(conn, Routes.team_index_path(conn, :index, org))

    html =
      team_live
      |> element("#member-#{member.id} a", "Remove user")
      |> render_click()

    assert html =~ "Member deleted successfully"
    refute html =~ member.email

    assert team_live
           |> element("#member-#{user.id} a.disabled")
           |> has_element?()

    assert_received %Phoenix.Socket.Broadcast{event: "disconnect", topic: topic}
    assert topic == "user_sessions:" <> token
  end

  test "leave organization", %{conn: conn, org: org, user: user} do
    admin_fixture(org)

    {:ok, team_live, _} = live(conn, Routes.team_index_path(conn, :index, org))

    {:ok, _, html} =
      team_live
      |> element("#member-#{user.id} a", "Leave")
      |> render_click()
      |> follow_redirect(conn, Routes.dashboard_index_path(conn, :index))

    assert html =~ "You have left #{org.name}"
  end

  test "create invitation", %{conn: conn, org: org} do
    {:ok, team_live, _} = live(conn, Routes.team_index_path(conn, :index, org))

    {:ok, form_live, _} =
      team_live
      |> element("#invite-button")
      |> render_click()
      |> follow_redirect(conn)

    assert form_live
           |> form("#form-invite", invitation: [email: "bad"])
           |> render_change() =~ "must have the @ sign and no spaces"

    invitation_email = "alice@example.com"

    {:ok, _, html} =
      form_live
      |> form("#form-invite", invitation: [email: invitation_email])
      |> render_submit()
      |> follow_redirect(conn, Routes.team_index_path(conn, :index, org))

    assert html =~ "Invitation created successfully"
    assert html =~ invitation_email
  end

  test "delete invitation", %{conn: conn, org: org} do
    invitation = invitation_fixture(org)
    {:ok, team_live, _} = live(conn, Routes.team_index_path(conn, :index, org))

    html =
      team_live
      |> element("#invitation-#{invitation.id} a", "Delete")
      |> render_click()

    assert html =~ "Invitation deleted successfully"
    assert html =~ "No pending invitations."
  end

  test "make a member an admin", %{conn: conn, org: org} do
    member = member_fixture(org)

    {:ok, team_live, _} = live(conn, Routes.team_index_path(conn, :index, org))

    {:ok, form_live, html} =
      team_live
      |> element("#member-#{member.id} a", "Edit")
      |> render_click()
      |> follow_redirect(conn)

    assert html =~ member.email

    {:ok, _, html} =
      form_live
      |> form("#form-membership", membership: [role: "admin"])
      |> render_submit()
      |> follow_redirect(conn, Routes.team_index_path(conn, :index, org))

    assert html =~ "Membership updated successfully"
    assert html =~ "admin"
  end

  test "does not allow the last admin to be removed", %{conn: conn, org: org, user: admin} do
    {:ok, team_live, _} = live(conn, Routes.team_index_path(conn, :index, org))

    {:ok, _form_live, html} =
      team_live
      |> element("#member-#{admin.id} a", "Edit")
      |> render_click()
      |> follow_redirect(conn)

    assert html =~ admin.email
    assert html =~ "by removing yourself from admins you won&apos;t be able to regain access"
  end
end
