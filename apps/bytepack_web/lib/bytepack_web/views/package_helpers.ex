defmodule BytepackWeb.PackageHelpers do
  use Phoenix.HTML
  alias BytepackWeb.Router.Helpers, as: Routes

  def package_icon(socket, type) when type in ~w(hex npm) do
    ~E"""
    <img src="<%= Routes.static_path(socket, "/images/packages/#{type}_icon.svg") %>" />
    """
  end
end
