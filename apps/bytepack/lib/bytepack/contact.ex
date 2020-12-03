defmodule Bytepack.Contact do
  alias Bytepack.Contact.Message
  import Ecto.Changeset

  @doc """
  Builds a contact form message.
  """
  def build_message(params, :sell), do: Message.sell_changeset(%Message{}, params)
  def build_message(params, :general), do: Message.general_changeset(%Message{}, params)

  @doc """
  Sends the contact form message and attaches user data information (if the user is logged in).
  """
  def send_message(params, category, user) do
    params
    |> build_message(category)
    |> maybe_add_user_data(user)
    |> apply_action(:insert)
    |> case do
      {:ok, message} ->
        _ =
          message
          |> Message.to_email(category)
          |> Bytepack.Mailer.deliver_with_logging()

        {:ok, message}

      error ->
        error
    end
  end

  defp maybe_add_user_data(changeset, %{id: id}), do: change(changeset, %{user_id: id})
  defp maybe_add_user_data(changeset, _), do: changeset
end
