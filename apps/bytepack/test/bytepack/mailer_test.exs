defmodule Bytepack.MailerTest do
  use Bytepack.DataCase, async: true
  alias Bytepack.Mailer

  describe "html_template/1" do
    test "generates html based on params passed" do
      params = [
        header: "Header text",
        body: "Body text",
        url: "https://bytepack.io/email_link",
        footer: "Footer text"
      ]

      generated_html = Mailer.html_template(params)

      assert generated_html =~ params[:header]
      assert generated_html =~ params[:body]
      assert generated_html =~ ~r/<a href="#{params[:url]}".*#{params[:url]}<\/a>/
      assert generated_html =~ params[:footer]
    end

    test "parses markdown in custom instalation instructions section" do
      params = [
        header: "Header text",
        markdown: {"A message from the Some Product team", "**strong** *em*"}
      ]

      generated_html = Mailer.html_template(params)

      assert generated_html =~ ~s|A message from the Some Product team|
      assert generated_html =~ ~s|<strong>strong</strong>|
      assert generated_html =~ ~s|<em>em</em>|
    end
  end

  describe "text_template/1" do
    test "generates text based on params passed" do
      params = [
        header: "Header text",
        body: "Body text",
        url: "https://bytepack.io/email_link",
        footer: "Footer text"
      ]

      generated_text = Mailer.text_template(params)

      assert generated_text =~ params[:header]
      assert generated_text =~ params[:body]
      assert generated_text =~ params[:url]
      assert generated_text =~ params[:footer]
    end
  end

  test "displays markdown section with a title" do
    params = [
      markdown: {"A message from the Some Product team", "**strong** *em*"}
    ]

    generated_text = Mailer.text_template(params)

    assert generated_text =~ ~s|A message from the Some Product team|
    assert generated_text =~ ~s|**strong**|
    assert generated_text =~ ~s|*em*|
  end
end
