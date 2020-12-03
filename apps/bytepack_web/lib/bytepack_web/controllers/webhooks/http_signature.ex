defmodule BytepackWeb.Webhooks.HTTPSignature do
  @moduledoc """
  Verifies the request body in order to ensure that its signature is valid.
  This verification can avoid someone to send a request on behalf of our client.

  So the client must send a header with the following structure:

      t=timestamp-in-seconds,
      v1=signature

  Where the `timestamp-in-seconds` is the system time in seconds, and `signature`
  is the HMAC using the SHA256 algorithm of timestamp and the payload, signed by
  a shared secret with us.

  This is based on what Stripe is doing: https://stripe.com/docs/webhooks/signatures
  """

  defmodule RawBodyNotPresentError do
    defexception message: "raw body is not available"
  end

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @behaviour Plug
  @header "bytepack-signature"
  @schema "v1"
  @valid_period_in_seconds 300

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    with {:ok, header} <- signature_header(conn),
         {:ok, body} <- raw_body(conn),
         :ok <- verify(header, body, fetch_secret!(conn), opts) do
      conn
    else
      {:error, error} ->
        conn
        |> put_status(400)
        |> json(%{
          "error" => %{"status" => "400", "title" => "HTTP Signature is invalid: #{error}"}
        })
        |> halt()
    end
  end

  defp fetch_secret!(conn) do
    Bytepack.Sales.encode_http_signature_secret(conn.assigns.current_seller)
  end

  defp signature_header(conn) do
    case get_req_header(conn, @header) do
      [header] when is_binary(header) ->
        {:ok, header}

      _ ->
        {:error, "signature is not present in header #{inspect(@header)}"}
    end
  end

  defp raw_body(conn) do
    case conn do
      %Plug.Conn{assigns: %{raw_body: raw_body}} ->
        {:ok, IO.iodata_to_binary(raw_body)}

      _ ->
        raise RawBodyNotPresentError
    end
  end

  ## Sign and verify

  @doc """
  Sign a payload with timestamp using HMAC with the SHA256 algorithm and a secret.
  """
  @spec sign(String.t(), integer(), String.t(), String.t()) :: {:ok, String.t()}
  def sign(payload, timestamp, secret, schema \\ @schema) do
    {:ok, "t=#{timestamp},#{schema}=#{hash(timestamp, payload, secret)}"}
  end

  defp hash(timestamp, payload, secret) do
    :hmac
    |> :crypto.mac(:sha256, "#{timestamp}.#{payload}", secret)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies a given `HTTPSignature` with its associated payload and secret.
  What it does is to regenerate the signature in order to check if matches with
  the original.

  Internally it uses `Plug.Crypto.secure_compare/2` in order to avoid timing attacks.
  """
  @spec verify(HTTPSignature.t(), String.t(), String.t(), Keyword.t()) ::
          :ok | {:error, String.t()}
  def verify(header, payload, secret, opts \\ []) do
    with {:ok, timestamp, hash} <- parse(header, @schema) do
      current_timestamp = Keyword.get(opts, :system, System).system_time(:second)

      cond do
        timestamp + @valid_period_in_seconds < current_timestamp ->
          {:error, "signature is too old"}

        not Plug.Crypto.secure_compare(hash, hash(timestamp, payload, secret)) ->
          {:error, "signature is incorrect"}

        true ->
          :ok
      end
    end
  end

  defp parse(signature, schema) do
    parsed =
      for pair <- String.split(signature, ","),
          destructure([key, value], String.split(pair, "=", parts: 2)),
          do: {key, value},
          into: %{}

    with %{"t" => timestamp, ^schema => hash} <- parsed,
         {timestamp, ""} <- Integer.parse(timestamp) do
      {:ok, timestamp, hash}
    else
      _ -> {:error, "signature is in a wrong format or is missing #{schema} schema"}
    end
  end
end
