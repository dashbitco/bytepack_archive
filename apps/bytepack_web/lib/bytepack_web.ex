defmodule BytepackWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use BytepackWeb, :controller
      use BytepackWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      @moduledoc false
      use Phoenix.Controller, namespace: BytepackWeb

      import Plug.Conn
      import BytepackWeb.Gettext
      import Phoenix.LiveView.Controller
      alias BytepackWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      @moduledoc false

      use Phoenix.View,
        root: "lib/bytepack_web/templates",
        namespace: BytepackWeb

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      @moduledoc false
      use Phoenix.LiveComponent
      alias BytepackWeb.MountHelpers

      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      @moduledoc false

      use Phoenix.LiveView, layout: {BytepackWeb.LayoutView, "live.html"}
      alias BytepackWeb.MountHelpers

      unquote(view_helpers())
    end
  end

  def router do
    quote do
      @moduledoc false
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      @moduledoc false
      use Phoenix.Channel

      import BytepackWeb.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Remove built-in helpers in favor of the bootstrap based ones
      import Phoenix.HTML.Form, except: [submit: 1, submit: 2]
      import Phoenix.HTML.Link, except: [button: 2]
      import BytepackWeb.HTMLHelpers
      import BytepackWeb.ErrorHelpers

      import Phoenix.View
      import Phoenix.LiveView.Helpers
      import BytepackWeb.Gettext

      alias BytepackWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
