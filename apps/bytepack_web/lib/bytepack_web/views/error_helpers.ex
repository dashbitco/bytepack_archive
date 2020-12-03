defmodule BytepackWeb.ErrorHelpers do
  @moduledoc """
  Functions for generating error related things
  """

  use Phoenix.HTML

  @doc """
  Traverses a changeset and translate the errors within.
  It returns a map that has lists with error messages or other maps in case
  of nested associations.
  """
  def error_map(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  @doc """
  It does the same as `error_map/1` but it will return
  only the first error message for given a field. Errors from
  associations and similar are discarded.
  """
  def error_map_unwrapped(changeset) do
    changeset
    |> error_map()
    |> unpack_messages()
  end

  defp unpack_messages(errors) do
    for {key, [message | _]} <- errors, into: %{} do
      {Atom.to_string(key), message}
    end
  end

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field, opts \\ []) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:span, translate_error(error), Keyword.merge([class: "invalid-feedback"], opts))
    end)
  end

  # Translates an error message using gettext.
  defp translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(BytepackWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(BytepackWeb.Gettext, "errors", msg, opts)
    end
  end
end
