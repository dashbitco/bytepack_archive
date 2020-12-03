defmodule BytepackWeb.ProductLive.FormComponent do
  use BytepackWeb, :live_component

  alias Bytepack.Sales

  @impl true
  def render(assigns) do
    ~L"""
    <%= f = form_for @changeset, "#",
              id: "form-product",
              phx_target: @myself,
              phx_change: "update_and_validate",
              phx_submit: "save" %>
      <%= input f, :name, phx_debounce: "blur" %>
      <%= input f, :description, using: :textarea, phx_debounce: "blur" %>
      <div class="row">
        <div class="col-md-6">
          <%= input f, :custom_instructions, using: :textarea, rows: 6, label: "Onboarding e-mail message",
            hint: "A custom Markdown message to be included in all onboarding e-mails we send to new sales" %>
        </div>
        <%= if @custom_instructions_preview do %>
          <div class="col-md-6 d-flex align-items-stretch">
            <div class="markdown-preview">
              <%= raw(@custom_instructions_preview) %>
            </div>
          </div>
        <% end %>
      </div>
      <%= input f, :url, label: "URL", phx_debounce: "blur" %>

      <div class="form-group">
        <label>Packages</label>

        <%= multiple_checkboxes f, :package_ids, @package_options %>
        <%= error_tag(f, :package_ids, class: "invalid-feedback d-block") %>

        <%= unless @can_remove_packages? do %>
          <p class="form-text text-muted mt-2">Note: This product already has sales so its existing packages cannot be removed.</p>
        <% end %>
      </div>

      <%= live_submit() %>
    </form>
    """
  end

  @impl true
  def update(assigns, socket) do
    deps_map = Bytepack.Hex.deps_map(assigns.packages)
    can_remove_packages? = Sales.can_remove_packages?(assigns.product)
    changeset = Sales.change_product(assigns.product, %{}, deps_map)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       changeset: changeset,
       deps_map: deps_map,
       can_remove_packages?: can_remove_packages?
     )
     |> assign_package_options()
     |> update_custom_instructions_preview(changeset.data.custom_instructions)}
  end

  defp update_custom_instructions_preview(socket, custom_instructions) do
    custom_instructions = custom_instructions && Cmark.to_html(custom_instructions)

    assign(socket, :custom_instructions_preview, custom_instructions)
  end

  defp assign_package_options(socket) do
    %{
      changeset: changeset,
      packages: packages,
      deps_map: deps_map,
      can_remove_packages?: can_remove_packages?
    } = socket.assigns

    ids_to_names = Map.new(packages, &{&1.id, &1.name})
    original = changeset.data.package_ids
    selected = Ecto.Changeset.get_field(changeset, :package_ids) || []

    package_options =
      for package <- packages do
        hint =
          case Map.get(deps_map, package.id, []) do
            [] -> []
            ids -> [hint: ["Depends on ", ids_to_names(ids_to_names, ids)]]
          end

        readonly =
          case am_i_readonly?(package, original, can_remove_packages?) or
                 selected_package_depends_on_me?(package, selected, deps_map) do
            true -> [readonly: true]
            false -> []
          end

        {package.name, package.id, hint ++ readonly}
      end

    assign(socket, package_options: package_options)
  end

  defp ids_to_names(ids_to_names, ids) do
    Enum.map_intersperse(ids, ", ", &Map.fetch!(ids_to_names, &1))
  end

  defp selected_package_depends_on_me?(package, selected, deps_map) do
    Enum.any?(selected, &(package.id in Map.get(deps_map, &1, [])))
  end

  defp am_i_readonly?(package, original, can_remove_packages?) do
    not can_remove_packages? and package.id in original
  end

  @impl true
  def handle_event("update_and_validate", %{"product" => product_params}, socket) do
    product_params = put_package_ids(product_params)

    changeset =
      Sales.change_product(socket.assigns.product, product_params, socket.assigns.deps_map)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign_package_options()
      |> update_custom_instructions_preview(product_params["custom_instructions"])

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"product" => product_params}, socket) do
    product_params = put_package_ids(product_params)

    save_product(socket, socket.assigns.action, product_params)
  end

  # If none of package ids checkboxes are checked, the param isn't sent so we fill it in.
  defp put_package_ids(params), do: Map.put_new(params, "package_ids", [])

  defp save_product(socket, :new, product_params) do
    org = socket.assigns.current_org
    audit_context = socket.assigns.audit_context

    case Sales.create_product(audit_context, org, product_params, socket.assigns.deps_map) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_product(socket, :edit, product_params) do
    product = socket.assigns.product
    deps_map = socket.assigns.deps_map
    audit_context = socket.assigns.audit_context

    case Sales.update_product(audit_context, product, product_params, deps_map) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
