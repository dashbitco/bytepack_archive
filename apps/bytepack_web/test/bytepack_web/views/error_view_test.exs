defmodule BytepackWeb.ErrorViewTest do
  use BytepackWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  setup %{conn: conn} do
    %{conn: get(conn, Routes.user_registration_path(conn, :new))}
  end

  test "renders 404.html", %{conn: conn} do
    response = render_to_string(BytepackWeb.ErrorView, "404.html", conn: conn)
    assert response =~ "Page not found"
    assert response =~ "Return to Bytepack</a>"
  end

  test "renders 403.html", %{conn: conn} do
    response = render_to_string(BytepackWeb.ErrorView, "403.html", conn: conn)
    assert response =~ "Access denied"
    assert response =~ "Return to Bytepack</a>"
  end

  test "renders 500.html", %{conn: conn} do
    response = render_to_string(BytepackWeb.ErrorView, "500.html", conn: conn)
    assert response =~ "Internal server error"
    assert response =~ "Return to Bytepack</a>"
  end

  test "renders generic error message for other status codes", %{conn: conn} do
    response = render_to_string(BytepackWeb.ErrorView, "other_code.html", conn: conn)
    assert response =~ "Page not available"
    assert response =~ "Return to Bytepack</a>"
  end
end
