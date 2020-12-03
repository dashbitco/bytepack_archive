defmodule Bytepack.Contact.Message do
  use Bytepack.Schema

  import Ecto.Changeset
  alias Swoosh.Email
  alias __MODULE__
  @bytepack_contact_email "contact@bytepack.io"

  embedded_schema do
    field :email, :string
    field :user_id, :integer
    field :package_managers, :string
    field :product_url, :string
    field :comment, :string
    field :subject, :string
  end

  def sell_changeset(message, attrs) do
    message
    |> cast(attrs, [:email, :package_managers, :product_url, :comment])
    |> validate_required([:email])
    |> Bytepack.Extensions.Ecto.Validations.validate_email(:email)
  end

  def general_changeset(message, attrs) do
    message
    |> cast(attrs, [:email, :subject, :comment])
    |> validate_required([:email, :subject, :comment])
    |> Bytepack.Extensions.Ecto.Validations.validate_email(:email)
  end

  def to_email(%Message{} = message, category) do
    subject = subject_text(message, category)
    body = body_text(message, category)

    Email.new()
    |> Email.to(@bytepack_contact_email)
    |> Email.from({"Bytepack", @bytepack_contact_email})
    |> Email.subject(subject)
    |> Email.html_body(body)
  end

  defp subject_text(_message, :sell),
    do: "[Contact Form] Selling with bytepack"

  defp subject_text(message, _),
    do: ~s|[Contact Form] Subject: "#{String.slice(message.subject, 0..100)}"|

  defp body_text(%Message{} = message, category) do
    fields_text =
      for {field_key, field_title} <- fields(category),
          field_value = Map.get(message, field_key) || "---",
          into: "",
          do: field_text(field_title, field_value)

    """
    <p>New message was sent via the Bytepack contact form.<p>

    <p>Category: #{category_name(category)}</p>

    #{fields_text}
    """
  end

  defp category_name(:sell), do: "Selling with Bytepack"
  defp category_name(:general), do: "Other"

  defp fields(:sell),
    do: [
      user_id: "User id",
      email: "User e-mail",
      product_url: "Is your product already live? If so what is its url?",
      package_managers: "Which package managers do you want to use to deliver your product ",
      comment: "Extra comments"
    ]

  defp fields(:general),
    do: [
      user_id: "User id",
      email: "User e-mail",
      subject: "Subject",
      comment: "Message"
    ]

  defp field_text(title, value) do
    """
    <p>
      <b>#{title}</b>
      <br />
      #{value}
    <p>
    """
  end
end
