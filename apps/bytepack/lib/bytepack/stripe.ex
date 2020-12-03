defmodule Bytepack.Stripe do
  import Ecto.Query
  alias Bytepack.Repo
  alias Bytepack.Sales.Seller
  alias Bytepack.Stripe.Client

  def oauth_url(%Seller{id: id}) do
    Client.connect_oauth_url("org_stripe_oauth", id)
  end

  def oauth_callback(params) do
    with {:ok, id, stripe_user_id} <- Client.connect_oauth_callback("org_stripe_oauth", params),
         {1, [seller]} <- Repo.update_all(update_stripe_user_id(id, stripe_user_id), []) do
      {:ok, seller}
    else
      _ -> :error
    end
  end

  defp update_stripe_user_id(seller_id, stripe_user_id) do
    from s in Seller,
      update: [set: [stripe_user_id: ^stripe_user_id]],
      where: s.id == ^seller_id and is_nil(s.stripe_user_id),
      select: s
  end
end
