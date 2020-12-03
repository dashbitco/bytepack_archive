defmodule BytepackWeb.PackageLive.ShowComponent do
  use BytepackWeb, :live_component

  alias Bytepack.Orgs.Membership

  @impl true
  def update(assigns, socket) do
    {:ok,
     assign(socket, assigns)
     |> assign_new(:base_url, fn -> base_url(assigns.type, socket, assigns.current_org) end)
     |> assign_new(:testing_instructions, fn -> false end)
     |> assign_new(:update_instructions, fn -> false end)}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="card ribbon-box">
      <div class="card-body">
        <%= live_component(@socket, BytepackWeb.PackageLive.PackageTypeRibbonComponent, type: @package.type) %>
        <h4 class="card-title"><%= @package.name %></h4>
        <h6 class="card-subtitle text-muted mb-3">
          <div class="dropdown">
            <a class="package-show-component__version-link" data-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="true">
              v<%= @selected_release.release.version %> <span class="feather-icon icon-chevron-down"></span>
            </a>

            <div class="package-show-component__dropdown-menu dropdown-menu dropdown-menu-animated">
              <div class="dropdown-header px-2 py-1">
                <small class="font-weight-bold">Choose release version</small>
              </div>
              <%= for release <- @package.releases do %>
                <a class="dropdown-item p-2" phx-click="choose_package_version" phx-value-version="<%= release.version %>"><%= release.version %></a>
              <% end %>
            </div>
          </div>
        </h6>

        <p>
        <%= text_to_html(@package.description) %>
        </p>

        <%= if @package.external_doc_url do %>
          <p>
          <strong>External documentation</strong>: <a href="<%= @package.external_doc_url %>" target="_blank"><%= @package.external_doc_url %></a>
          </p>
        <% end %>
      </div>
    </div>

    <%= if @selected_release.deps != [] do %>
      <div class="card">
        <div class="card-body">
          <h4 class="mb-3">Dependencies</h4>

          <ul>
          <%= for dep <- @selected_release.deps do %>
            <li><%= dep_link(@type, @socket, @current_org, dep) %></li>
          <% end %>
          </ul>
        </div>
      </div>
    <% end %>

    <%= if @type == :test do %>
      <div class="row">
        <div class="col-md-6">
          <div class="card">
            <div class="card-body">
              <h4 class="mb-3">Publish new version</h4>

              <div class="alert alert-warning mb-3 mt-0" role="alert">
                The instructions below are associated to your account and they are <strong>private</strong>.
                You can invite new users to publish packages <%= link "in the Team page", to: Routes.team_index_path(@socket, :index, @current_org) %>.
              </div>

              <%= if @update_instructions do %>
                <button id="btn-update-hide" class="btn btn-light mb-3" phx-target="<%= @myself %>" phx-click="toggle_update_instructions">Hide instructions</button>
                <%= update_snippet(assigns) %>
              <% else %>
                <button id="btn-update-show" class="btn btn-light" phx-target="<%= @myself %>" phx-click="toggle_update_instructions">Show instructions</button>
              <% end %>
            </div>
          </div>
        </div>

        <div class="col-md-6">
          <div class="card">
            <div class="card-body">
              <h4 class="mb-3">Testing</h4>

              <div class="alert alert-warning mb-3 mt-0" role="alert">
                The instructions below are associated to your account and they are <strong>private</strong>.
                Use these steps only for <strong>personal testing</strong> and not for package distribution.
              </div>

              <%= if @testing_instructions do %>
                <button id="btn-testing-hide" class="btn btn-light mb-3" phx-target="<%= @myself %>" phx-click="toggle_testing_instructions">Hide instructions</button>
                <%= installation_snippet(assigns) %>
              <% else %>
                <button id="btn-testing-show" class="btn btn-light" phx-target="<%= @myself %>" phx-click="toggle_testing_instructions">Show instructions</button>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    <% else %>
      <%= unless @purchase_revoked? do %>
        <div class="card">
          <div class="card-body">
            <h4 class="mb-3" id="installation">Installation</h4>

            <div class="alert alert-warning mb-3 mt-0" role="alert">
              The instructions below are associated to your account and they are <strong>private</strong>.
              To give others users in your organization access to this package, invite them <%= link "in the Team page", to: Routes.team_index_path(@socket, :index, @current_org) %>.
            </div>

            <%= installation_snippet(assigns) %>
          </div>
        </div>
      <% end %>
    <% end %>
    """
  end

  defp dep_link(_type, _socket, _org, %{repository: "hexpm"} = dep) do
    ~E"""
    <a href="https://hex.pm/packages/<%= dep.package %>" target="_blank"><%= dep.package %></a> <%= dep.requirement %> <span class="badge badge-light font-14 ml-1">external</span>
    """
  end

  defp dep_link(:test, socket, org, %{repository: nil} = dep) do
    ~E"""
    <%= live_redirect(dep.package, to: Routes.package_show_path(socket, :show, org, "hex", dep.package)) %> <%= dep.requirement %>
    """
  end

  defp dep_link({:purchase, purchase}, socket, org, %{repository: nil} = dep) do
    ~E"""
    <%= live_patch(dep.package, to: Routes.purchase_show_path(socket, :show, org, purchase, "hex", dep.package)) %> <%= dep.requirement %>
    """
  end

  defp base_url(:test, socket, org), do: Routes.hex_test_repo_url(socket, :repo_index, org)
  defp base_url({:purchase, _}, socket, org), do: Routes.hex_repo_url(socket, :repo_index, org)

  defp update_snippet(assigns) do
    ~L"""
    <h5>Step 1: Publish your new version</h5>
    <%= code_snippet("HEX_API_KEY=\"#{Membership.encode_write_token(@current_membership)}\" mix hex.publish package", id: "update") %>
    """
  end

  defp installation_snippet(assigns) do
    ~L"""
    <h5>Step 1: download public key</h5>
    <%= code_snippet("curl --fail -H \"authorization: #{Membership.encode_read_token(@current_membership)}\" #{@base_url}/public_key > public_key.pem", id: "installation_step1") %>
    <h5>Step 2: Add <%= @current_org.slug %> repository</h5>
    <%= code_snippet("mix hex.repo add #{@current_org.slug} #{@base_url} --public-key public_key.pem --auth-key #{Membership.encode_read_token(@current_membership)}", id: "installation_step2") %>
    <h5>Step 3: Add <%= @package.name %> to your mix.exs</h5>
    <%= deps_snippet(assigns) %>
    """
  end

  defp deps_snippet(assigns) do
    code_snippet(
      ~L"""
      def deps do
        [
          {:<%= @package.name %>, ">= 0.0.0", repo: "<%= @current_org.slug %>"}
        ]
      end
      """,
      id: "deps"
    )
  end

  @impl true
  def handle_event("toggle_update_instructions", _, socket) do
    {:noreply, update(socket, :update_instructions, &not/1)}
  end

  @impl true
  def handle_event("toggle_testing_instructions", _, socket) do
    {:noreply, update(socket, :testing_instructions, &not/1)}
  end
end
