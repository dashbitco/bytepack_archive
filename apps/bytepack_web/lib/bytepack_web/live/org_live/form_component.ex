defmodule BytepackWeb.OrgLive.FormComponent do
  use BytepackWeb, :live_component
  alias Bytepack.Orgs

  @impl true
  def render(assigns) do
    ~L"""
    <%= f = form_for @changeset, "#",
              id: "form-org",
              phx_target: @myself,
              phx_change: "validate",
              phx_submit: "save" %>
      <%= input f, :name %>
      <%= input f, :slug, disabled: @action == :edit, hint: "Short text used in urls. Cannot be changed" %>
      <%= input f, :email, hint: "Public e-mail address" %>
      <%= live_submit() %>
    </form>
    """
  end

  @impl true
  def update(%{org: org} = assigns, socket) do
    changeset = Orgs.change_org(org, %{email: assigns.current_user.email})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"org" => org_params}, socket) do
    changeset =
      Orgs.change_org(socket.assigns.org, org_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"org" => org_params}, socket) do
    save_org(socket, socket.assigns.action, org_params)
  end

  defp save_org(socket, :edit, org_params) do
    case Orgs.update_org(socket.assigns.org, org_params) do
      {:ok, _org} ->
        {:noreply,
         socket
         |> put_flash(:info, "Organization updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_org(socket, :new, org_params) do
    case Orgs.create_org(socket.assigns.audit_context, socket.assigns.current_user, org_params) do
      {:ok, _org} ->
        {:noreply,
         socket
         |> put_flash(:info, "Organization created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
