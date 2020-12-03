defmodule Bytepack.Stripe.Client do
  @moduledoc """
  Interface to Stripe API.
  """

  defmodule Host do
    @callback connect_url() :: String.t()
  end

  defmodule ProdHost do
    @behaviour Host
    def connect_url, do: "https://connect.stripe.com"
  end

  require Logger

  def connect_oauth_url(context, data) do
    signed = Plug.Crypto.sign(secret_key_base(), context, data)

    "https://connect.stripe.com/oauth/authorize?response_type=code&scope=read_write" <>
      "&client_id=" <>
      platform_id() <>
      "&state=" <>
      signed
  end

  def connect_oauth_callback(context, params) do
    with %{"code" => code, "state" => state} <- params,
         {:ok, app_data} <- Plug.Crypto.verify(secret_key_base(), context, state),
         {:ok, stripe_data} <-
           connect_request(:post, "/oauth/token", [], code: code, grant_type: "authorization_code") do
      {:ok, app_data, Map.fetch!(stripe_data, "stripe_user_id")}
    else
      _ -> :error
    end
  end

  ## HTTP helpers

  defp connect_request(method, path, headers, body) do
    request(method, host().connect_url() <> path, headers, body)
  end

  defp request(method, url, headers, body) do
    {headers, body} = encode_body(headers, body)
    auth_headers = [{"authorization", "Bearer #{api_key()}"} | headers]
    request = Finch.build(method, url, auth_headers, body)

    case Finch.request(request, Bytepack.Finch) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status: status}} ->
        message = """
        Unexpected status #{status} from Stripe:

            #{method} #{url}
            #{inspect(headers)}
        """

        Logger.error(message)
        {:error, RuntimeError.exception(message)}

      {:error, error} ->
        Logger.error("""
        Could not complete request to Stripe:

            #{method} #{url}
            #{inspect(headers)}

        Reason: #{inspect(error)}
        """)

        {:error, error}
    end
  end

  defp encode_body(headers, body) when is_nil(body), do: {headers, body}
  defp encode_body(headers, body) when is_binary(body), do: {headers, body}

  defp encode_body(headers, body) do
    {[{"content-type", "application/x-www-form-urlencoded"} | headers], URI.encode_query(body)}
  end

  ## Keys and secrets

  defp host, do: Keyword.fetch!(stripe_env(), :host)
  defp api_key, do: Keyword.fetch!(stripe_env(), :api_key)
  defp platform_id, do: Keyword.fetch!(stripe_env(), :platform_id)
  defp secret_key_base, do: Keyword.fetch!(stripe_env(), :secret_key_base)
  defp stripe_env, do: Application.fetch_env!(:bytepack, :stripe)
end
