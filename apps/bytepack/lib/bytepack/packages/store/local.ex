defmodule Bytepack.Packages.Store.Local do
  @behaviour Bytepack.Packages.Store

  @impl true
  def get_request(path) do
    Finch.build(:get, base_url() <> path)
  end

  @impl true
  def put!(path, data) do
    request = Finch.build(:put, base_url() <> path, [], data)
    {:ok, %{status: 200}} = Finch.request(request, Bytepack.Finch)
    :ok
  end

  @impl true
  def delete!(path) do
    request = Finch.build(:delete, base_url() <> path, [])
    {:ok, %{status: 200}} = Finch.request(request, Bytepack.Finch)
    :ok
  end

  defp base_url(), do: Bytepack.Extensions.Plug.DevStore.base_url()
end
