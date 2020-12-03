defmodule Bytepack.Extensions.Ecto.IPAddress do
  use Ecto.Type

  @impl true
  def type(), do: :inet

  @impl true
  def cast(string) when is_binary(string) do
    parts = String.split(string, ".")

    case Enum.map(parts, &Integer.parse/1) do
      [{a, ""}, {b, ""}, {c, ""}, {d, ""}]
      when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 ->
        {:ok, {a, b, c, d}}

      _ ->
        :error
    end
  end

  def cast(_), do: :error

  @impl true
  def dump({_, _, _, _} = address), do: {:ok, %Postgrex.INET{address: address}}
  def dump(_), do: :error

  @impl true
  def load(%Postgrex.INET{} = struct), do: {:ok, struct.address}
  def load(_), do: :error
end
