defmodule BytepackWeb.InfoBannerComponent do
  use BytepackWeb, :live_component

  @impl true
  def render(assigns) do
    ~L"""
    <div class="row">
      <div class="col-sm-12">
        <div class="card info-banner">
          <div class="card-body toll-free-box text-center">
            <h4 class="text-white">
              <i class="feather-icon icon-<%= @icon %>"></i>
              <p class="info-banner__title"><%= @title %></p>
              <p class="info-banner__description"><%= @description %></p>
              <%= if assigns[:inner_block] do %>
                <div class="info-banner__extra-content mt-3">
                  <%= render_block(@inner_block, assigns) %>
                </div>
              <% end %>
            </h4>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
