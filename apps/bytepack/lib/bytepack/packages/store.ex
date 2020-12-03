defmodule Bytepack.Packages.Store do
  @callback get_request(Path.t()) :: Finch.Request.t()

  @callback put!(Path.t(), binary()) :: :ok

  @callback delete!(Path.t()) :: :ok

  def get_request(path) do
    api().get_request(path)
  end

  def get(path) do
    Finch.request(get_request(path), Bytepack.Finch)
  end

  def put!(path, data) do
    api().put!(path, data)
  end

  def delete!(path) do
    api().delete!(path)
  end

  def api() do
    Application.fetch_env!(:bytepack, :packages_store)[:api]
  end
end
