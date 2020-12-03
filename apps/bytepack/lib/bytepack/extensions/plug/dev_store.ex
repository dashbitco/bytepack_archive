defmodule Bytepack.Extensions.Plug.DevStore do
  use Plug.Router

  @dir Path.expand("../../../../tmp/store", __DIR__)
  def dir(), do: @dir

  @moduledoc """
  An easy development store.

  It serves files at `http://localhost:PORT` and stores them at `#{@dir}`.
  """

  plug(Plug.Static, at: "/", from: @dir)
  plug(:match)
  plug(:dispatch)

  put "*path" do
    path = Path.join([@dir | path])

    if path =~ "error" do
      raise "triggered store error"
    else
      File.mkdir_p!(Path.dirname(path))
      pid = File.open!(path, [:write])
      {:ok, conn} = with_req_body(conn, fn {:data, data} -> IO.binwrite(pid, data) end)
      :ok = File.close(pid)
      send_resp(conn, 200, "ok")
    end
  end

  delete "*path" do
    File.rm!(Path.join([@dir | path]))
    send_resp(conn, 200, "ok")
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  defp with_req_body(conn, fun) do
    case Plug.Conn.read_body(conn) do
      {:more, partial, conn} ->
        fun.({:data, partial})
        read_body(conn, fun)

      {:ok, body, conn} ->
        fun.({:data, body})
        {:ok, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def base_url() do
    "http://localhost:#{port()}/"
  end

  defp port() do
    Application.get_env(:bytepack, :dev_store)[:port]
  end

  def child_spec(_) do
    if port = port() do
      Plug.Cowboy.child_spec(scheme: :http, plug: __MODULE__, port: port)
    else
      %{id: __MODULE__, start: {Function, :identity, [:ignore]}}
    end
  end
end
