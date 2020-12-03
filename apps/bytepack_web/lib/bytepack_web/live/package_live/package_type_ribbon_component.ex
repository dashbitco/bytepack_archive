defmodule BytepackWeb.PackageLive.PackageTypeRibbonComponent do
  use BytepackWeb, :live_component
  alias BytepackWeb.PackageHelpers

  @impl true
  def render(assigns) do
    ~L"""
    <div class="ribbon ribbon-secondary float-right package-type-ribbon ribbon-top">
      <%= PackageHelpers.package_icon(@socket, @type) %><%= @type %>
    </div>
    """
  end

  def icon(socket, type) when type in ~w(hex npm) do
    ~E"""
    <img src="<%= Routes.static_path(socket, "/images/packages/#{type}_icon.svg") %>" />
    """
  end
end
