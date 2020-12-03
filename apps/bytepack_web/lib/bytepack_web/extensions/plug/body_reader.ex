defmodule BytepackWeb.Extensions.Plug.BodyReader do
  @moduledoc """
  This module is useful in the context where we want to override or wrap the `Plug.Conn.read_body/2`
  function.
  """

  @doc """
  This function will store the original body of a request into the `raw_body`
  assignment on `%Plug.Conn{}` as an IO data.

  It is required that you configure the `Plug.Parsers` to use this function
  as a body reader in order to be able to use this module as a Plug.

  On `BytepackWeb.Endpoint` you can configure it as the following:

      plug Plug.Parsers,
        body_reader: {BytepackWeb.Extensions.Plug.BodyReader, :cache_raw_body, []}

  For more info, check this PR: https://github.com/elixir-plug/plug/pull/698
  """
  def cache_raw_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])

      {:ok, body, conn}
    end
  end
end
