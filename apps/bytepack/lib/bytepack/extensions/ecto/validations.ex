defmodule Bytepack.Extensions.Ecto.Validations do
  import Ecto.Changeset

  def validate_email(changeset, field) do
    changeset
    |> validate_format(field, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(field, max: 160)
  end

  def normalize_and_validate_url(changeset, field) do
    url_change = get_change(changeset, field)

    cond do
      is_nil(url_change) || valid_url?(url_change) ->
        changeset

      without_schema?(url_change) && valid_url?("https://" <> url_change) ->
        force_change(changeset, field, "https://" <> url_change)

      true ->
        add_error(changeset, field, "should be a HTTP or HTTPS link")
    end
  end

  defp valid_url?(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.scheme in ~w(http https) && uri.host
  end

  defp without_schema?(url) when is_binary(url) do
    is_nil(URI.parse(url).scheme)
  end
end
