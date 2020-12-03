defmodule BytepackWeb.PageController do
  use BytepackWeb, :controller

  plug :put_layout, false

  def index(conn, _params) do
    conn
    |> assign(:homepage, true)
    |> render("index.html")
  end
end
