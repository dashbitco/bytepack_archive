defmodule BytepackWeb.HTMLHelpers do
  @moduledoc """
  Functions for generating HTML used throughout the app.
  """

  use Phoenix.HTML
  import Phoenix.HTML.Form, except: [submit: 1, submit: 2]
  import Phoenix.HTML.Link, only: []
  import Phoenix.LiveView.Helpers, only: [sigil_L: 2]

  alias BytepackWeb.Router.Helpers, as: Routes
  alias BytepackWeb.ErrorHelpers

  def code_snippet(code, opts \\ []) do
    assigns = %{}

    id = Keyword.fetch!(opts, :id)

    ~L"""
    <div class="code-snippet" id="<%= id %>" phx-hook="CopyToClipboard">
      <div class="code-snippet__button">
        <div class="code-snippet__copied pr-1">Copied!</div>
        <span class="feather-icon icon-copy code-snippet__icon"></span>
      </div>
      <pre class="bg-light p-2 my-3"><code class="code-snippet__code-with-button"><%= code %></code></pre>
      <textarea class="code-snippet__textarea"><%= code %></textarea>
    </div>
    """
  end

  @doc """
  Generates an img with srcset for 2x and 3x.

  For example, if `path` is "/images/foo" and `ext` is `:png`,
  it expects the following assets to exist:

    * /images/foo.png
    * /images/foo@2x.png
    * /images/foo@3x.png

  """
  def img_srcset_tag(url_context, path, ext, opts \\ [])
      when is_binary(path) and is_atom(ext) and is_list(opts) do
    src = Routes.static_path(url_context, "#{path}.#{ext}")

    set = [
      {Routes.static_path(url_context, "#{path}@2x.#{ext}"), "2x"},
      {Routes.static_path(url_context, "#{path}@3x.#{ext}"), "3x"}
    ]

    img_tag(src, [srcset: set] ++ opts)
  end

  @doc """
  Defines an input, a label, and other elements associated with a given `field`.

  ## Options:

    * `:using` - the type of the input, defaults to a type inferred from the
      field name using `Phoenix.HTML.Form.html.input_type/3`. `input_type/3`
      relies on the database type and, if the database type is a string,
      it uses the field name to inflect the type for email, url, search,
      and password. `:checkbox` and `:select` types are also supported.

    * `:label` - the text of the label, defaults to one inferred from the field
      name.

  All remaining options are automatically passed to the underlying input element.
  """
  def input(form, field, opts \\ []) do
    {type, opts} =
      Keyword.pop_lazy(opts, :using, fn -> Phoenix.HTML.Form.input_type(form, field) end)

    {label_text, opts} = Keyword.pop(opts, :label, humanize(field))
    wrapper(type, form, field, label_text, opts)
  end

  defp wrapper(:checkbox, form, field, label_text, opts) do
    wrapper_opts = [
      class: "form-group custom-control custom-checkbox",
      phx_feedback_for: input_id(form, field)
    ]

    label_opts = [class: "custom-control-label"] ++ label_for(opts)
    input_opts = [class: "custom-control-input#{state_class(form, field)}"]

    content_tag :div, wrapper_opts do
      label = label(form, field, label_text, label_opts)
      input = input(:checkbox, form, field, input_opts)
      error = ErrorHelpers.error_tag(form, field)
      [input, label, error || ""]
    end
  end

  defp wrapper(:select, form, field, label_text, opts) do
    {options, opts} = Keyword.pop(opts, :options, [])
    {disabled, opts} = Keyword.pop(opts, :disabled, false)

    wrapper_opts = [class: "form-group", phx_feedback_for: opts[:id] || input_id(form, field)]
    label_opts = label_for(opts)
    input_opts = [class: "custom-select#{state_class(form, field)}", disabled: disabled] ++ opts

    content_tag :div, wrapper_opts do
      label = label(form, field, label_text, label_opts)
      input = select(form, field, options, input_opts)
      error = ErrorHelpers.error_tag(form, field)
      [label, input, error || ""]
    end
  end

  defp wrapper(type, form, field, label_text, opts) do
    wrapper_opts = [class: "form-group", phx_feedback_for: opts[:id] || input_id(form, field)]
    label_opts = label_for(opts)

    input_opts =
      [class: "form-control#{state_class(form, field)}"] ++
        Keyword.put_new(opts, :phx_debounce, true)

    content_tag :div, wrapper_opts do
      label = label(form, field, label_text, label_opts)
      input = input(type, form, field, input_opts)
      error = ErrorHelpers.error_tag(form, field)

      hint =
        if opts[:hint] do
          content_tag(:small, opts[:hint], class: "form-text text-muted")
        else
          []
        end

      [label, input, hint, error || ""]
    end
  end

  defp label_for(opts) do
    if id = opts[:id], do: [for: id], else: []
  end

  defp state_class(%{source: %{action: _}} = form, field) do
    cond do
      # If the form was not submitted/validated, don't show anything
      is_nil(form.source.action) -> ""
      # Otherwise we mark it as invalid if there is an error
      form.errors[field] -> " is-invalid"
      # But do nothing if the field was not filled (such as it was filled and then emptied)
      input_value(form, field) in ["", nil] -> ""
      # Otherwise it is valid
      true -> " is-valid"
    end
  end

  defp state_class(_, _field) do
    ""
  end

  defp input(type, form, field, input_opts) do
    apply(Phoenix.HTML.Form, type, [form, field, input_opts])
  end

  @doc """
  Generates a set of checkboxes for the given `items`.

  The items are a list of tuples like this:

      {"Admin", "admin", [hint: "extra text"]}

  """
  def multiple_checkboxes(form, field, items) do
    id_prefix = input_id(form, field) <> "_"
    name = input_name(form, field) <> "[]"
    checked = Enum.map(input_value(form, field) || [], &to_string/1)

    multiple_checkboxes(items, id_prefix, name, checked)
  end

  defp multiple_checkboxes(items, id_prefix, name, checked) do
    for item <- items do
      {label, value, extra} = item

      content_tag :div, class: "custom-control custom-checkbox" do
        readonly? = Keyword.get(extra, :readonly, false)
        checked? = to_string(value) in checked
        hint = Keyword.get(extra, :hint)
        id = "#{id_prefix}#{value}"

        opts = [type: :checkbox, value: value, name: name, id: id, class: "custom-control-input"]
        opts = if checked?, do: [checked: "checked"] ++ opts, else: opts
        opts = if readonly?, do: [disabled: "disabled"] ++ opts, else: opts

        checkbox = tag(:input, opts)
        label = content_tag(:label, label, for: id, class: "custom-control-label")
        hint = if(hint, do: content_tag(:small, hint, class: "form-text text-muted"), else: [])

        hidden =
          if(checked? && readonly?,
            do: tag(:input, type: :hidden, value: value, name: name),
            else: []
          )

        [checkbox, hidden, label, hint]
      end
    end
  end

  @doc """
  Generates a set of radio buttons for the given `items`.
  """
  def radio_buttons(items, id_prefix, name, checked) do
    for {label, value} <- items do
      content_tag :div, class: "custom-control custom-control-inline custom-radio" do
        checked? = to_string(value) == checked
        id = "#{id_prefix}#{value}"

        opts = [type: :radio, value: value, name: name, id: id, class: "custom-control-input"]
        opts = if checked?, do: [checked: "checked"] ++ opts, else: opts
        radio = tag(:input, opts)
        label = content_tag(:label, label, for: id, class: "custom-control-label")

        [radio, label]
      end
    end
  end

  @doc """
  Generates a submit button to send the form.
  """
  def submit(text, opts \\ []) do
    content_tag :div, class: "form-submit" do
      opts = Keyword.update(opts, :class, "btn btn-primary", &("btn btn-primary " <> &1))
      Phoenix.HTML.Form.submit(text, opts)
    end
  end

  @doc """
  Generates a live submit button with reasonable defaults.
  """
  def live_submit(opts \\ []) do
    submit("Submit", [phx_disable_with: "Submitting..."] ++ opts)
  end

  @doc """
  Generates a link that looks like a button.

  Extends `Phoenix.HTML.Link.link/2` with the following options:

    * `:tooltip` - sets `data-title` to this value along with `data-toggle="tooltip"`.
      If `:disabled` is set, the link is wrapped in an outer span.

    * `:disabled` - adds `disabled` css class

  A `btn` css class is automatically prepended.
  """
  def button(opts, do: contents) do
    button(contents, opts)
  end

  def button(contents, opts) do
    if opts[:to] do
      raise ArgumentError, "do not pass :to to button/2, it is always set to `#`"
    end

    opts =
      opts
      |> Keyword.put(:to, "#")
      |> Keyword.update(:class, "btn", &("btn " <> &1))

    cond do
      opts[:tooltip] && opts[:disabled] ->
        {tooltip, opts} = Keyword.pop(opts, :tooltip)
        opts = Keyword.delete(opts, :disabled)
        opts = Keyword.update(opts, :class, "disabled", &("disabled " <> &1))

        content_tag :span,
          class: "d-inline-block",
          tabindex: "0",
          data: [toggle: "tooltip", title: tooltip] do
          Phoenix.HTML.Link.link(contents, opts)
        end

      opts[:tooltip] ->
        {tooltip, opts} = Keyword.pop(opts, :tooltip)

        opts =
          opts
          |> Keyword.put_new(:data_toggle, "tooltip")
          |> Keyword.put_new(:data_title, tooltip)

        Phoenix.HTML.Link.link(contents, opts)

      true ->
        Phoenix.HTML.Link.link(contents, opts)
    end
  end

  @doc """
  Renders a component inside the `BytepackWeb.Modal` component.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <%= live_modal @socket, BytepackWeb.OrgLive.FormComponent,
        id: @org.id || :new,
        action: @live_action,
        org: @org,
        return_to: Routes.dashboard_index_path(@socket, :index) %>
  """
  def live_modal(socket, component, opts) do
    require Phoenix.LiveView.Helpers
    path = Keyword.fetch!(opts, :return_to)
    modal_opts = [id: :modal, return_to: path, component: component, opts: opts]
    Phoenix.LiveView.Helpers.live_component(socket, BytepackWeb.ModalComponent, modal_opts)
  end

  @doc """
  Returns the `csp_nonce` sent on request headers.
  """
  def csp_nonce(conn), do: conn.assigns[:csp_nonce]

  @doc """
  Returns x-request-id meta info.
  """
  def request_id_tag() do
    request_id = :logger.get_process_metadata()[:request_id]
    tag(:meta, name: "x-request-id", content: request_id)
  end

  @doc """
  Returns x-user-id meta info.
  """
  def user_id_tag(conn) do
    user = conn.assigns[:current_user]
    user_id = if user, do: user.id, else: ""
    tag(:meta, name: "x-user-id", content: user_id)
  end
end
