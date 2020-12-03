defmodule Bytepack.ContactTest do
  use Bytepack.DataCase, async: true

  import Bytepack.{AccountsFixtures, SwooshHelpers}
  alias Bytepack.Contact

  describe "send_message/3" do
    @bytepack_email "contact@bytepack.io"
    @email_subject "[Contact Form] Selling with bytepack"
    @valid_params %{
      email: unique_user_email(),
      comment: "I want to start selling my package.",
      package_managers: "NPM, Hex",
      product_url: "https://bytepack.io"
    }

    test "sends email with submitted contact information" do
      user = Bytepack.AccountsFixtures.user_fixture()

      Contact.send_message(@valid_params, :sell, user)

      assert_received_email(
        to: @bytepack_email,
        subject: @email_subject,
        body_text: inspect(user.id)
      )
    end

    test "validates params" do
      {:error, changeset} = Contact.send_message(%{}, :general, nil)

      assert %{
               subject: ["can't be blank"],
               email: ["can't be blank"],
               comment: ["can't be blank"]
             } = errors_on(changeset)
    end
  end
end
