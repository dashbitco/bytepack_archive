defmodule Bytepack.SwooshHelpers do
  alias Swoosh.Adapters.Local.Storage.Memory

  @doc """
  Asserts exactly one email with given `attributes` was received.

  Attributes can be `:to` (required) and `:subject`.

  Returns the matched email.
  """
  def assert_received_email(attributes) do
    to = Keyword.fetch!(attributes, :to)
    subject = Keyword.get(attributes, :subject)
    html_body = Keyword.get(attributes, :html_body)

    emails =
      for email <- Memory.all(),
          to in Enum.map(email.to, &elem(&1, 1)),
          (!subject or email.subject == subject) and (!html_body or email.html_body =~ html_body) do
        email
      end

    case emails do
      [email] ->
        email

      [] ->
        raise "expected exactly one email with #{inspect(attributes)}, got none"

      other ->
        raise """
        expected exactly one email with #{inspect(attributes)}, got:

        #{inspect(other, pretty: true)}
        """
    end
  end
end
