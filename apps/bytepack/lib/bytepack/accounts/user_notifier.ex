defmodule Bytepack.Accounts.UserNotifier do
  require Logger
  alias Swoosh.Email
  alias Bytepack.Mailer

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    template_params = [
      header: "Hi #{user.email},",
      body: "You can confirm your account by visiting the url below:",
      url: url,
      footer: "If you didn't create an account with us, please ignore this."
    ]

    deliver(user.email, "Account confirmation", template_params)
  end

  @doc """
  Deliver instructions to reset password account.
  """
  def deliver_reset_password_instructions(user, url) do
    template_params = [
      header: "Hi #{user.email},",
      body: "You can reset your password by visiting the url below:",
      url: url,
      footer: "If you didn't request this change, please ignore this."
    ]

    deliver(user.email, "Reset password", template_params)
  end

  @doc """
  Deliver instructions to update your e-mail.
  """
  def deliver_update_user_email_instructions(user, url) do
    template_params = [
      p: "Hi #{user.email},",
      p: "You can change your e-mail by visiting the url below:",
      url: url,
      p: "If you didn't request this change, please ignore this."
    ]

    deliver(user.email, "Update e-mail instructions", template_params)
  end

  @doc """
  Deliver org invitation.
  """
  def deliver_org_invitation(org, invitation, url) do
    body =
      if invitation.user_id do
        "You can join the organization by visiting the url below:"
      else
        "You can join the organization by registering an account using the url below:"
      end

    template_options = [
      p: "Hi #{invitation.email},",
      p: body,
      url: url
    ]

    deliver(invitation.email, "Invitation to join #{org.name}", template_options)
  end

  @doc """
  Deliver instructions to complete the sale.
  """
  def deliver_create_sale_email(sale, url) do
    template_options = [
      p: "Hi #{sale.email},",
      p: "You have purchased #{sale.product.name}!",
      p:
        "#{sale.product.name} is available for download on Bytepack. Click the url below to create your Bytepack account and access it.",
      url: url
    ]

    template_options =
      if sale.product.custom_instructions do
        title = "A message from the #{sale.product.name} team:"

        template_options ++ [markdown: {title, sale.product.custom_instructions}]
      else
        template_options
      end

    deliver(sale.email, "Access your #{sale.product.name} purchase on Bytepack", template_options)
  end

  defp deliver(to, subject, template_params) do
    Email.new()
    |> Email.to(to)
    |> Email.from({"Bytepack", "contact@bytepack.io"})
    |> Email.subject(subject)
    |> Email.text_body(Mailer.text_template(template_params))
    |> Email.html_body(Mailer.html_template(template_params))
    |> Mailer.deliver_with_logging()
  end
end
