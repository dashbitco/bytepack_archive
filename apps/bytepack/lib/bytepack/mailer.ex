defmodule Bytepack.Mailer do
  use Swoosh.Mailer, otp_app: :bytepack

  require Logger
  @logo_url "https://bytepack.io/images/bytepack_logo_white.png"

  def deliver_with_logging(mail) do
    case deliver(mail) do
      {:ok, _} ->
        {:ok, mail}

      {:error, reason} ->
        Logger.error("""
        Email delivery failed:

        Subject: #{mail.subject}
        To: #{inspect(mail.to)}
        Reason: #{inspect(reason, pretty: true)}
        """)

        {:error, reason}
    end
  end

  def html_template(template_params) do
    """
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <!--[if gte mso 9]><xml>
          <o:OfficeDocumentSettings>
          <o:AllowPNG/>
          <o:PixelsPerInch>96</o:PixelsPerInch>
          </o:OfficeDocumentSettings>
        </xml><![endif]-->
      </head>
      <body style="margin: 0; padding: 0; min-width: 100%; background-color: #dee2e6;">
        <div style="background-color: #ffffff; box-sizing: border-box; display: block; Margin: 20px auto; max-width: 580px; padding: 0;">
          <table cellpadding="0" cellspacing="0" width="100%">
            <tr>
              <td style="background-color: #333333; padding: 30px;">
                <center><img src="#{@logo_url}" alt="Bytepack" width="116" height="45" align="center" /></center>
              </td>
            </tr>
            <tr>
              <td style="font-family:sans-serif; font-size: 16px; padding: 20px 30px;">
                #{html_sections(template_params)}
              </td>
            </tr>
            <tr>
              <td style="background-color: #eef1f3; font-family:sans-serif; font-size: 16px; padding: 20px 30px;">
                <center>
                  <a style="color: #888888; font-family: sans-serif; font-size: 16px;" href="https://bytepack.io">Log in to Bytepack</a>
                </center>
              </td>
            </tr>
          </table>
        </div>
      </body>
    </html>
    """
  end

  def text_template(template_params) do
    """

    ==============================

    #{text_sections(template_params)}

    Bytepack - https://bytepack.io/

    ==============================
    """
  end

  defp text_sections(template_params) do
    template_params
    |> add_markdown_section()
    |> Keyword.values()
    |> Enum.join("\n\n")
  end

  defp add_markdown_section(template_params) do
    template_params
    |> Enum.map(fn {type, value} ->
      if type == :markdown do
        {title, markdown} = value
        {type, "\n\n#{title}\n\n#{markdown}"}
      else
        {type, value}
      end
    end)
  end

  defp html_sections(template_params) do
    for {type, value} <- template_params,
        do: html_section(type, value)
  end

  defp html_section(:markdown, {title, value}) do
    html = Cmark.to_html(value)

    ~s"""
    <table cellpadding="0" cellspacing="0" width="100%">
      <tr>
        <td style="background-color: #f6f6f6; padding: 25px 30px;">
          <strong>#{title}</strong>
          #{html}
        </td>
      </tr>
    </table>
    """
  end

  defp html_section(type, value) do
    ~s|<p style="font-family: sans-serif; font-size: 16px; line-height: 1.5; padding-top: 0;">| <>
      html_section_by_type(type, value) <> ~s|</p>|
  end

  defp html_section_by_type(:url, value) do
    ~s|<a href="#{value}" style="word-break: break-all; word-wrap: break-word; color: #727cf5;">| <>
      value <> ~s|</a>|
  end

  defp html_section_by_type(_, text) do
    text
  end
end
