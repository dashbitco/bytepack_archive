defmodule BytepackWeb.Webhooks.SaleController do
  use BytepackWeb, :controller

  alias Bytepack.Sales

  def create(conn, %{"sale" => params}) do
    case Sales.create_sale(conn.assigns.audit_context, conn.assigns.current_seller, params) do
      {:ok, sale} ->
        Sales.deliver_create_sale_email(
          sale,
          &Routes.onboarding_purchase_index_url(conn, :index, sale.id, &1)
        )

        conn
        |> put_status(:created)
        |> render("show.json", sale: sale)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", changeset: changeset)
    end
  end

  def update(conn, %{"sale" => sale_params} = params) do
    sale = get_sale_by_id_or_external_id(conn, params)

    case Sales.update_sale(conn.assigns.audit_context, sale, sale_params) do
      {:ok, sale} ->
        render(conn, "show.json", sale: sale)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", changeset: changeset)
    end
  end

  def revoke(conn, %{"sale" => sale_params} = params) do
    sale = get_sale_by_id_or_external_id(conn, params)

    case Sales.revoke_sale(conn.assigns.audit_context, sale, sale_params) do
      {:ok, sale} ->
        conn
        |> put_status(:ok)
        |> render("show.json", sale: sale)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", changeset: changeset)
    end
  end

  defp get_sale_by_id_or_external_id(conn, %{"id" => id}) do
    Sales.get_sale!(conn.assigns.current_seller, id)
  end

  defp get_sale_by_id_or_external_id(conn, %{"external_id" => external_id}) do
    Sales.get_sale_by_external_id!(conn.assigns.current_seller, external_id)
  end
end
