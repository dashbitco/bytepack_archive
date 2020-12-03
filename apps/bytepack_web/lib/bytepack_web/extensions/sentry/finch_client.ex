defmodule Bytepack.Extensions.Sentry.FinchClient do
  @behaviour Sentry.HTTPClient

  def child_spec do
    {Finch, name: __MODULE__, pools: %{:default => [size: 10, count: 2]}}
  end

  def post(url, headers, body) do
    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, __MODULE__) do
      {:ok, %Finch.Response{} = response} ->
        {:ok, response.status, response.headers, response.body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
