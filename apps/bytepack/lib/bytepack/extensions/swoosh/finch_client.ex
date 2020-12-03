defmodule Bytepack.Extensions.Swoosh.FinchClient do
  @moduledoc """
  Finch-based ApiClient for Swoosh.
  """

  @behaviour Swoosh.ApiClient

  @impl true
  def init do
    :ok
  end

  @impl true
  def post(url, headers, body, %Swoosh.Email{}) do
    # Postmark adapter sends url as iodata.
    url = IO.iodata_to_binary(url)
    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, Bytepack.Finch) do
      {:ok, %Finch.Response{} = response} ->
        {:ok, response.status, response.headers, response.body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
