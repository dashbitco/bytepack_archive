defmodule BytepackWeb.Webhooks.SaleView do
  use BytepackWeb, :view
  alias BytepackWeb.Webhooks.SaleView

  def render("show.json", %{sale: sale}) do
    %{sale: render_one(sale, SaleView, "sale.json")}
  end

  def render("sale.json", %{sale: sale}) do
    %{
      id: sale.id,
      product_id: sale.product_id,
      email: sale.email,
      external_id: sale.external_id
    }
  end

  def render("error.json", %{changeset: changeset}) do
    %{errors: error_map(changeset)}
  end
end
