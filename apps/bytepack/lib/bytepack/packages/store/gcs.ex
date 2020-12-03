defmodule Bytepack.Packages.Store.GCS do
  @behaviour Bytepack.Packages.Store

  @url "https://storage.googleapis.com"

  # https://cloud.google.com/storage/docs/json_api/v1/objects/get
  @impl true
  def get_request(path) do
    path = URI.encode_www_form(path)
    build(:get, "/storage/v1/b/#{bucket()}/o/#{path}?alt=media")
  end

  # https://cloud.google.com/storage/docs/json_api/v1/objects/insert
  @impl true
  def put!(path, data) do
    url = "/upload/storage/v1/b/#{bucket()}/o?uploadType=media&name=#{path}"
    request = build(:post, url, data)

    case Finch.request(request, Bytepack.Finch) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status}} ->
        message = """
        Unexpected status #{status} from GCS:

            #{request.method} #{url}
            #{inspect(request.headers)}
        """

        raise message

      {:error, exception} ->
        raise exception
    end
  end

  # https://cloud.google.com/storage/docs/json_api/v1/objects/delete
  @impl true
  def delete!(path) do
    path = URI.encode_www_form(path)
    url = "/storage/v1/b/#{bucket()}/o/#{path}"
    request = build(:delete, url)

    case Finch.request(request, Bytepack.Finch) do
      {:ok, %{status: 204}} ->
        :ok

      {:ok, %{status: status}} ->
        message = """
        Unexpected status #{status} from GCS:

            #{request.method} #{url}
            #{inspect(request.headers)}
        """

        raise message

      {:error, exception} ->
        raise exception
    end
  end

  defp build(method, path, data \\ nil) do
    headers = [{"authorization", authorization()}]
    Finch.build(method, @url <> path, headers, data)
  end

  defp bucket() do
    Keyword.fetch!(Application.fetch_env!(:bytepack, :packages_store), :bucket)
  end

  defp authorization() do
    {:ok, token} = Goth.fetch(Bytepack.Goth)
    "#{token.type} #{token.token}"
  end
end
