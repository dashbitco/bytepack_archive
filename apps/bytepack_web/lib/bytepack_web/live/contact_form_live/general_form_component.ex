defmodule BytepackWeb.ContactFormLive.GeneralFormComponent do
  use BytepackWeb, :live_component

  alias Bytepack.Contact

  @impl true
  def render(assigns) do
    ~L"""
      <%= f = form_for @changeset, "#",
                id: "general_form",
                class: "contact-form",
                phx_submit: "submit",
                phx_target: @myself %>
        <%= input f, :email, label: "Your email" %>
        <%= input f, :subject, label: "Subject" %>
        <%= input f, :comment, using: :textarea, label: "Message", rows: 6 %>
        <div class="row mt-3">
          <div class="col-12 text-right">
            <button class="btn btn-primary contact-form__button">Send message <i class="feather-icon icon-chevron-right"></i> </button>
          </div>
        </div>
      </form>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = Contact.build_message(%{}, :general)

    {:ok,
     socket
     |> assign(:current_user, assigns.current_user)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("submit", %{"message" => message_params}, socket) do
    message_params
    |> Contact.send_message(:general, socket.assigns.current_user)
    |> case do
      {:ok, _} ->
        {:noreply, push_patch(socket, to: Routes.contact_form_index_path(socket, :message_sent))}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
