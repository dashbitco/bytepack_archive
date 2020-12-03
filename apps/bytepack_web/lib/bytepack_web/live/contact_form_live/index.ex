defmodule BytepackWeb.ContactFormLive.Index do
  use BytepackWeb, :live_view

  @categories %{
    report_issue: %{
      title: "I have a problem with a package/purchase",
      icon: "alert-circle"
    },
    sell: %{
      title: "I want to start selling with Bytepack",
      icon: "package"
    },
    other: %{
      title: "I have other questions, requests or suggestions",
      icon: "message-square"
    }
  }

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:context, :contact)
      |> assign(:page_title, "Contact")
      |> MountHelpers.assign_maybe_logged_in_defaults(session["user_token"])

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("open_category", %{"category" => category}, socket)
      when category in ["sell", "other", "report_issue"] do
    category = String.to_atom(category)
    action = if category == socket.assigns.live_action, do: :index, else: category
    {:noreply, push_patch(socket, to: Routes.contact_form_index_path(socket, action))}
  end

  defp category_button(socket, assigns, form_component, category_name) do
    ~L"""
      <div class="<%= category_button_class(category_name, @live_action) %>" id="category-button--<%= category_name %>">
        <div class="card-header contact-category-button__header d-flex py-3" phx-click="open_category" phx-value-category="<%= category_name %>">
          <div class="contact-category-button__icon bg-primary-lighten">
            <span class="feather-icon icon-<%= category_icon(category_name) %>"></span>
          </div>
          <div class="flex-grow-1">
            <%= category_title(category_name) %>
          </div>
          <div class="contact-category-button__arrow">
            <span class="feather-icon icon-chevron-right"></span>
          </div>
        </div>
        <%= if @live_action == category_name do %>
          <div class="card-body p-4">
            <%= live_component socket, form_component, current_user: assigns[:current_user], id: "category_form_#{category_name}" %>
          </div>
        <% end %>
      </div>
    """
  end

  defp category_button_class(category_name, selected_category)
       when category_name == selected_category,
       do: "card contact-category-button contact-category-button--selected"

  defp category_button_class(_, _), do: "card contact-category-button"

  defp category_icon(category_name) do
    get_in(@categories, [category_name, :icon]) || "message-square"
  end

  defp category_title(category_name) do
    get_in(@categories, [category_name, :title])
  end
end
