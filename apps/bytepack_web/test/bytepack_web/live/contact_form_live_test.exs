defmodule BytepackWeb.ContactFormLiveTest do
  use BytepackWeb.ConnCase, async: true

  alias Bytepack.Sales

  import Phoenix.LiveViewTest
  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.SalesFixtures
  import Bytepack.SwooshHelpers

  defp general_message_fixture() do
    %{
      email: unique_user_email(),
      subject: "Support request",
      comment: "I need some help."
    }
  end

  defp sell_message_fixture() do
    %{
      email: unique_user_email(),
      comment: "I want to start selling my package.",
      package_managers: "NPM, Hex",
      product_url: "https://bytepack.io"
    }
  end

  describe "Index - logged out" do
    @sell_button_text "I want to start selling with Bytepack"
    @sell_email_subject "[Contact Form] Selling with bytepack"
    @general_button_text "I have other questions, requests or suggestions"
    @general_email_subject "[Contact Form] Subject: \"__SUBMITTED_SUBJECT__\""
    @bytepack_contact_email "contact@bytepack.io"
    @message_sent_title "Message sent"
    @message_sent_description "Thank you for reaching out!"
    @html_body_no_user_id "<b>User id</b>\n  <br />\n  ---"
    @report_issue_button_text "I have a problem with a package/purchase"
    @report_issue_no_products_message "You currently do not own any products on Bytepack."

    test "sends email after submitting 'sell with Bytepack' form", %{conn: conn} do
      {:ok, index_live, _} = live(conn, Routes.contact_form_index_path(conn, :index))

      index_live
      |> element("#category-button--sell .card-header", @sell_button_text)
      |> render_click()

      message = sell_message_fixture()

      index_live
      |> form("#sell_form", message: message)
      |> render_submit()

      email =
        assert_received_email(
          to: @bytepack_contact_email,
          subject: @sell_email_subject,
          html_body: @html_body_no_user_id
        )

      assert email.html_body =~ message.email
      assert email.html_body =~ message.package_managers
      assert email.html_body =~ message.product_url
      assert email.html_body =~ message.comment

      html = render(index_live)

      assert html =~ @message_sent_title
      assert html =~ @message_sent_description
    end

    test "sends email after submitting the general contact form", %{conn: conn} do
      {:ok, index_live, _} = live(conn, Routes.contact_form_index_path(conn, :index))

      index_live
      |> element("#category-button--other .card-header", @general_button_text)
      |> render_click()

      message = general_message_fixture()

      index_live
      |> form("#general_form", message: message)
      |> render_submit()

      full_subject =
        String.replace(
          @general_email_subject,
          "__SUBMITTED_SUBJECT__",
          message.subject
        )

      email =
        assert_received_email(
          to: @bytepack_contact_email,
          subject: full_subject,
          html_body: @html_body_no_user_id
        )

      assert email.html_body =~ message.email
      assert email.html_body =~ message.subject
      assert email.html_body =~ message.comment

      html = render(index_live)

      assert html =~ @message_sent_title
      assert html =~ @message_sent_description
    end

    test "does not show issue reporting option", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, Routes.contact_form_index_path(conn, :index))

      refute html =~ @report_issue_button_text
    end
  end

  describe "Index - logged in" do
    setup :register_and_login_user

    test "sends generated email with user id attached", %{conn: conn, user: user} do
      {:ok, index_live, _} = live(conn, Routes.contact_form_index_path(conn, :index))

      index_live
      |> element("#category-button--sell .card-header", @sell_button_text)
      |> render_click()

      message = sell_message_fixture()

      index_live
      |> form("#sell_form", message: message)
      |> render_submit()

      email =
        assert_received_email(
          to: @bytepack_contact_email,
          subject: @sell_email_subject,
          html_body: message.email
        )

      assert email.subject == @sell_email_subject
      assert email.html_body =~ "<b>User id</b>\n  <br />\n  #{user.id}"
      assert email.html_body =~ message.email
      assert email.html_body =~ message.package_managers
      assert email.html_body =~ message.product_url
      assert email.html_body =~ message.comment

      html = render(index_live)

      assert html =~ @message_sent_title
      assert html =~ @message_sent_description
    end

    test "shows contact information for selected product", %{conn: conn, user: user} do
      {:ok, index_live, _} = live(conn, Routes.contact_form_index_path(conn, :index))

      seller_org = org_fixture(user_fixture())
      buyer_org = org_fixture(user)
      product = product_fixture(seller_org)
      sale = sale_fixture(seller_org, product, email: user.email)
      Sales.complete_sale!(Bytepack.AuditLog.system(), sale, buyer_org)

      index_live
      |> element("#category-button--report_issue .card-header", @report_issue_button_text)
      |> render_click()

      html =
        index_live
        |> element("#report-issue-form")
        |> render_change(%{purchase_id: sale.id})

      assert html =~
               "<strong>#{product.name}</strong> is published by <strong>#{seller_org.name}</strong>"

      assert html =~ ~s|<a class="btn btn-light" href="mailto:#{seller_org.email}"|
      assert html =~ ~s|<a class="btn btn-light" href="#{product.url}"|
    end

    test "shows a message when there are not products", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, Routes.contact_form_index_path(conn, :index))

      html =
        index_live
        |> element("#category-button--report_issue .card-header", @report_issue_button_text)
        |> render_click()

      assert html =~ @report_issue_no_products_message
    end
  end
end
