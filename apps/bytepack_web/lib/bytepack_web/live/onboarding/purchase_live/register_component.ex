defmodule BytepackWeb.Onboarding.PurchaseLive.RegisterComponent do
  use BytepackWeb, :live_component

  alias Bytepack.Purchases

  @impl true
  def render(assigns) do
    ~L"""
    <%= form_tag Routes.user_session_path(@socket, :create),
          id: "form-claim-login",
          phx_trigger_action: @login_submit %>
      <%= hidden_input :user, :email, value: @changeset.changes[:user_email] %>
      <%= hidden_input :user, :password, value: @changeset.changes[:user_password] %>
    </form>

    <%= f = form_for @changeset, "#",
          id: "form-claim",
          phx_target: @myself,
          phx_change: "validate",
          phx_submit: "save" %>
      <div class="purchase-page__section-header"><span class="feather-icon icon-user mr-2"></span>Your user details</div>

      <%= input f, :user_email, disabled: true %>
      <%= input f, :user_password, required: true, value: input_value(f, :user_password), phx_debounce: "blur" %>

      <div class="purchase-page__section-header mt-4"><span class="feather-icon icon-home mr-2"></span> Your organization</div>

      <%= input f, :organization_name, required: true %>
      <%= input f, :organization_slug, required: true, hint: "Short text used in urls. Cannot be changed" %>
      <%= input f, :organization_email, required: true, hint: "Public e-mail address" %>

      <%= input f, :terms_of_service, using: :checkbox, label: "I have read and accept the Privacy Policy and Terms and Conditions" %>

      <div class="text-center py-3">
        <%= live_submit() %>
        <div class="mt-2">
          or
          <%= link "log in with an existing account", to: Routes.user_session_path(@socket, :new) %>
        </div>
      </div>
    </form>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset =
      Purchases.change_buyer_registration(%Purchases.BuyerRegistration{}, %{
        user_email: assigns.sale.email,
        organization_email: assigns.sale.email
      })

    {:ok,
     socket
     |> assign(assigns)
     |> assign(changeset: changeset, login_submit: false)}
  end

  @impl true
  def handle_event("validate", %{"buyer_registration" => params}, socket) do
    changeset =
      %Purchases.BuyerRegistration{}
      |> Ecto.Changeset.change(user_email: socket.assigns.sale.email)
      |> Purchases.change_buyer_registration(params)
      |> Map.replace!(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("save", %{"buyer_registration" => params}, socket) do
    case Purchases.register_buyer(socket.assigns.audit_context, socket.assigns.sale, params) do
      {:ok, %{org: _org}} ->
        {:noreply, assign(socket, login_submit: true)}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
