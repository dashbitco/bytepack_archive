defmodule BytepackWeb.UserSettingsLive.ChangePasswordComponent do
  use BytepackWeb, :live_component

  alias Bytepack.Accounts

  @impl true
  def render(assigns) do
    ~L"""
    <div>
      <%= f = form_for @password_changeset, Routes.user_settings_path(@socket, :update_password),
        id: "form-update-password",
        phx_change: "validate_password",
        phx_submit: "update_password",
        phx_trigger_action: @password_trigger_action,
        phx_target: @myself %>

        <%= input f, :password, label: "New password", value: input_value(f, :password), phx_debounce: "blur" %>
        <%= input f, :password_confirmation, label: "Confirm new password", value: input_value(f, :password_confirmation), phx_debounce: "blur" %>
        <%= input f, :current_password, name: "current_password", id: "current_password_for_password", value: @current_password, phx_debounce: "blur" %>

        <%= submit "Change password", phx_disable_with: "Saving..." %>
      </form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    if socket.assigns[:current_user] do
      {:ok, socket}
    else
      {:ok,
       socket
       |> assign(:audit_context, assigns.audit_context)
       |> assign(:current_user, assigns.current_user)
       |> assign(:password_changeset, Accounts.change_user_password(assigns.current_user))
       |> assign(:current_password, nil)
       |> assign(:password_trigger_action, false)}
    end
  end

  @impl true
  def handle_event(
        "validate_password",
        %{"current_password" => current_password, "user" => user_params},
        socket
      ) do
    password_changeset =
      Accounts.change_user_password(socket.assigns.current_user, current_password, user_params)

    socket =
      socket
      |> assign(:current_password, current_password)
      |> assign(:password_changeset, password_changeset)

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "update_password",
        %{"current_password" => current_password, "user" => user_params},
        socket
      ) do
    socket = assign(socket, :current_password, current_password)

    socket.assigns.current_user
    |> Accounts.apply_user_password(current_password, user_params)
    |> case do
      {:ok, _} ->
        {:noreply, assign(socket, :password_trigger_action, true)}

      {:error, password_changeset} ->
        {:noreply, assign(socket, :password_changeset, password_changeset)}
    end
  end
end
