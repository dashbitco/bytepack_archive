defmodule BytepackWeb.PackageLive.FormComponent do
  use BytepackWeb, :live_component
  alias Bytepack.Packages

  @impl true
  def render(assigns) do
    ~L"""
    <div class="modal-header">
      <h4 class="modal-title"><%= @title %></h4>
    </div>
    <div class="modal-body">
      <%= f = form_for @changeset, "#",
                id: "form-package",
                phx_target: @myself,
                phx_change: "validate",
                phx_submit: "save" %>
        <%= input f, :description, using: :textarea, rows: 6 %>
        <%= input f, :external_doc_url, phx_debounce: "blur" %>

        <%= live_submit() %>
      </form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = Packages.change_package(assigns.package)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:title, "Edit package")
     |> assign_new(:changeset, fn -> changeset end)}
  end

  @impl true
  def handle_event("validate", %{"package" => params}, socket) do
    changeset =
      socket.assigns.package
      |> Packages.change_package(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"package" => params}, socket) do
    assigns = socket.assigns

    case Packages.update_package(assigns.audit_context, assigns.package, params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Package updated successfully")
         |> push_redirect(to: assigns.return_to)}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
