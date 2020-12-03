defmodule Bytepack.Repo do
  use Ecto.Repo,
    otp_app: :bytepack,
    adapter: Ecto.Adapters.Postgres

  def transaction!(fun, opts \\ []) when is_function(fun, 0) do
    case transaction(fun, opts) do
      {:ok, result} -> result
      {:error, _} = other -> raise "transaction failed with #{inspect(other)}"
    end
  end
end
