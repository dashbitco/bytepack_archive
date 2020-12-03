defmodule BytepackWeb.ErrorView do
  use BytepackWeb, :view

  def render("404.html", assigns) do
    render_error_page(
      assigns,
      "Page not found",
      "The link you have followed may be broken or the page may have been removed."
    )
  end

  def render("403.html", assigns) do
    render_error_page(assigns, "Access denied", "You are not authorized to access this page.")
  end

  def render("500.html", assigns) do
    render_error_page(
      assigns,
      "Internal server error",
      "An error occured and your request couldn't be completed. Please try again later."
    )
  end

  def template_not_found(_template, assigns) do
    render_error_page(
      assigns,
      "Page not available",
      "There was a problem with your request and this page could not be displayed."
    )
  end

  defp render_error_page(assigns, title, description) do
    assigns = Map.merge(assigns, %{title: title, description: description})
    render("error.html", assigns)
  end
end
