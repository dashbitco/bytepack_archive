defmodule BytepackWeb.HTMLHelpersTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML, only: [safe_to_string: 1]
  import BytepackWeb.HTMLHelpers

  defp changeset(data \\ %{}) do
    data = Map.merge(%{name: nil, active: nil}, data)
    Ecto.Changeset.change({data, %{name: :string, active: :boolean}})
  end

  defp form(changeset \\ changeset()) do
    Phoenix.HTML.Form.form_for(changeset, "/", as: :user)
  end

  describe "input/3" do
    test "text field" do
      input = form() |> input(:name) |> safe_to_string()

      assert input =~ ~s(<div class="form-group" phx-feedback-for="user_name">)
      assert input =~ ~s(<label for="user_name">Name</label>)

      assert input =~
               ~s(<input class="form-control" id="user_name" name="user[name]" type="text" phx-debounce>)
    end

    test "text field with id" do
      input = form() |> input(:name, id: "custom-id") |> safe_to_string()

      assert input =~ ~s(<div class="form-group" phx-feedback-for="custom-id">)
      assert input =~ ~s(<label for="custom-id">Name</label>)

      assert input =~
               ~s(<input class="form-control" id="custom-id" name="user[name]" type="text" phx-debounce>)
    end

    test "text field with custom debounce" do
      assert form() |> input(:name, phx_debounce: "blur") |> safe_to_string() =~
               ~s(<input class="form-control" id="user_name" name="user[name]" phx-debounce="blur" type="text">)
    end

    test "text field on success but blank" do
      input =
        changeset()
        |> Map.put(:action, :valid)
        |> form()
        |> input(:name)
        |> safe_to_string()

      assert input =~
               ~s(<input class="form-control" id="user_name" name="user[name]" type="text" phx-debounce>)
    end

    test "text field on success but filled" do
      input =
        changeset(%{name: "hello"})
        |> Map.put(:action, :valid)
        |> form()
        |> input(:name)
        |> safe_to_string()

      assert input =~
               ~s(<input class="form-control is-valid" id="user_name" name="user[name]" type="text" value="hello" phx-debounce>)
    end

    test "text field on error" do
      input =
        changeset()
        |> Ecto.Changeset.add_error(:name, "is invalid")
        |> form()
        |> input(:name)
        |> safe_to_string()

      assert input =~
               ~s(<input class="form-control" id="user_name" name="user[name]" type="text" phx-debounce>)

      input =
        changeset()
        |> Ecto.Changeset.add_error(:name, "is invalid")
        |> Map.put(:action, :invalid)
        |> form()
        |> input(:name)
        |> safe_to_string()

      assert input =~
               ~s(<input class="form-control is-invalid" id="user_name" name="user[name]" type="text" phx-debounce>)
    end

    test "checkbox" do
      input = form() |> input(:active, using: :checkbox) |> safe_to_string()

      assert input =~
               ~s(<div class="form-group custom-control custom-checkbox" phx-feedback-for="user_active">)

      assert input =~ ~s(<input class="custom-control-input" id="user_active")
      assert input =~ ~s(<label class="custom-control-label" for="user_active">Active</label>)
    end

    test "select" do
      input = form() |> input(:name, using: :select, options: ~w(foo bar)) |> safe_to_string()

      assert input =~ ~s(<div class="form-group" phx-feedback-for="user_name">)
      assert input =~ ~s(<label for="user_name">Name</label>)
      assert input =~ ~s(<select class="custom-select" id="user_name" name="user[name]">)
      assert input =~ ~s(<option value="bar">bar</option>)

      input =
        form()
        |> input(:name, using: :select, options: ~w(foo bar), disabled: true)
        |> safe_to_string()

      assert input =~ ~s(<select class="custom-select" id="user_name" name="user[name]" disabled>)
    end
  end

  describe "submit" do
    test "renders wrapped button" do
      assert submit("Hello", class: "extra") |> safe_to_string() ==
               ~s(<div class="form-submit"><button class="btn btn-primary extra" type="submit">Hello</button></div>)
    end
  end

  describe "live_submit" do
    test "renders wrapped button" do
      assert live_submit(class: "extra") |> safe_to_string() ==
               ~s(<div class="form-submit"><button class="btn btn-primary extra" phx-disable-with="Submitting..." type="submit">Submit</button></div>)
    end
  end

  describe "button/2" do
    test "regular" do
      link = button("Submit", []) |> safe_to_string()
      assert link =~ ~s(href="#">Submit</a>)
    end

    test "with tooltip" do
      link = button("Submit", tooltip: "Tooltip text") |> safe_to_string()

      assert link =~
               ~s(data-title="Tooltip text" data-toggle="tooltip" href="#">Submit</a>)
    end

    test "with tooltip and disabled" do
      span = button("Submit", tooltip: "Tooltip text", disabled: true) |> safe_to_string()

      assert span =~
               ~s(<span class="d-inline-block" data-title="Tooltip text" data-toggle="tooltip")

      assert span =~ ~s(<a class="disabled btn" href="#">Submit</a>)
    end
  end

  describe "img_srcset_tag" do
    test "generates srcset for 2x and 3x" do
      assert img_srcset_tag(BytepackWeb.Endpoint, "/images/3rd/stripe", :png) |> safe_to_string() ==
               ~s|<img src="/images/3rd/stripe.png" srcset="/images/3rd/stripe@2x.png 2x, /images/3rd/stripe@3x.png 3x">|
    end
  end

  describe "multiple_checkboxes" do
    test "readonly" do
      conn = Plug.Test.conn(:post, "/", %{product: %{package_ids: ["1", "2", "3"]}})
      form = Phoenix.HTML.Form.form_for(conn, "#", as: :product)
      items = [{"first", 1, [readonly: true]}, {"third", 3, []}, {"fifth", 5, [readonly: true]}]

      assert form
             |> multiple_checkboxes(:package_ids, items)
             |> Phoenix.HTML.html_escape()
             |> Phoenix.HTML.safe_to_string() == """
             <div class="custom-control custom-checkbox">\
             <input checked="checked" class="custom-control-input" disabled="disabled" id="product_package_ids_1" name="product[package_ids][]" type="checkbox" value="1">\
             <input name="product[package_ids][]" type="hidden" value="1">\
             <label class="custom-control-label" for="product_package_ids_1">first</label>\
             </div>\
             <div class="custom-control custom-checkbox">\
             <input checked="checked" class="custom-control-input" id="product_package_ids_3" name="product[package_ids][]" type="checkbox" value="3">\
             <label class="custom-control-label" for="product_package_ids_3">third</label>\
             </div>\
             <div class="custom-control custom-checkbox">\
             <input class="custom-control-input" disabled="disabled" id="product_package_ids_5" name="product[package_ids][]" type="checkbox" value="5">\
             <label class="custom-control-label" for="product_package_ids_5">fifth</label>\
             </div>\
             """
    end
  end

  describe "code_snippet/2" do
    test "requires an id" do
      assert_raise KeyError, fn ->
        code_snippet("some code")
      end
    end
  end
end
