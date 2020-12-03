defmodule Bytepack.Extensions.Sentry.Filter do
  @behaviour Sentry.EventFilter

  def exclude_exception?(exception, _) do
    Plug.Exception.status(exception) < 500
  end
end
