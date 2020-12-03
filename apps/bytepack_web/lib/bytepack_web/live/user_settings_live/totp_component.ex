defmodule BytepackWeb.UserSettingsLive.TOTPComponent do
  use BytepackWeb, :live_component

  alias Bytepack.Accounts

  @qrcode_size 264

  @impl true
  def render(assigns) do
    ~L"""
    <div>
      <%= if @current_totp do %>
        <div class="ribbon ribbon-success float-right ribbon-top"><i class="feather-icon icon-check font-weight-bold mr-1"></i> Enabled</div>
      <% end %>
      <h4 class="mb-3">Two-factor authentication</h4>
      <%= if @backup_codes, do: render_backup_codes(assigns) %>
      <%= if @editing_totp, do: render_totp_form(assigns), else: render_enable_form(assigns) %>
    </div>
    """
  end

  defp render_backup_codes(assigns) do
    ~L"""
    <div id="modal" class="live-modal" tabindex="-1"
      phx-capture-click="hide_backup_codes"
      phx-window-keydown="hide_backup_codes"
      phx-target="<%= @myself %>"
      phx-key="escape">

      <div class="modal-dialog modal-lg"  role="document">
        <div class="modal-content">
          <a class="close" href="#" phx-target="<%= @myself %>" phx-click="hide_backup_codes">&times;</a>

          <div class="modal-header">
            <h4 class="modal-title">Backup codes</h4>
          </div>

          <div class="modal-body">
            <p>
              Two-factor authentication is enabled. In case you lose access to your
              phone, you will need one of the backup codes below.
              <strong>Keep these backup codes safe</strong>. You can also generate
              new codes at any time.
            </p>

            <div class="row mx-5 my-4 ">
              <%= for backup_code <- @backup_codes do %>
                <div class="col-6 text-center text-monospace">
                  <h4>
                    <%= if backup_code.used_at do %>
                      <del class="text-muted"><%= backup_code.code %></del>
                    <% else %>
                      <%= backup_code.code %>
                    <% end %>
                  </h4>
                </div>
              <% end %>
            </div>
          </div>

          <div class="modal-footer">
            <%= if @editing_totp do %>
              <button id="btn-regenerate-backup" type="button" class="btn btn-light"
                      phx-click="regenerate_backup_codes" phx-target="<%= @myself %>"
                      data-confirm="Are you sure you want to regenerate your backup codes?">
                Regenerate backup codes
              </button>
            <% end %>

            <button id="btn-hide-backup" type="button" class="btn btn-secondary" phx-click="hide_backup_codes" phx-target="<%= @myself %>">
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_totp_form(assigns) do
    ~L"""
    <%= f = form_for @totp_changeset, "#", id: "form-update-totp", phx_submit: "update_totp", phx_target: @myself %>
      <p>To <%= if @current_totp, do: "change", else: "enable" %> two-factor authentication,

      <%= if @secret_display == :as_text do %>
        enter the secret below into your two-factor authentication app in your phone.</p>

        <div id="totp-secret" class="my-4 h3">
          <%= format_secret(@editing_totp.secret) %>
        </div>
        <div class="my-4">
          Or <a href="#" phx-click="display_secret_as_qrcode" phx-target="<%= @myself %>">scan the QR Code</a> instead.
        </div>
      <% else %>
        scan the image below with the two-factor authentication app in your phone
        and then enter the authentication code at the bottom. If you can't use QR Code,
        <a href="#" id="btn-manual-secret" phx-click="display_secret_as_text" phx-target="<%= @myself %>">enter your secret</a>
        manually.</p>

        <div class="my-4 text-center">
          <div class="d-inline-block">
            <%= generate_qrcode(@qrcode_uri) %>
          </div>
        </div>
      <% end %>

      <%= input f, :code, label: "Authentication code", autocomplete: "off" %>

      <div class="form-group">
        <button class="btn btn-primary" type="submit" phx-disable-with="Verifying...">
          Verify code
        </button>
        <button id="btn-cancel-totp" type="button" class="btn btn-secondary" phx-click="cancel_totp" phx-target="<%= @myself %>">
          Cancel
        </button>
      </div>

      <%= if @current_totp do %>
        <p class="mt-4 mb-0">
          You may also
          <a href="#" id="btn-show-backup" phx-click="show_backup_codes" phx-target="<%= @myself %>">
            see your available backup codes
          </a>
          or
          <a href="#" id="btn-disable-totp" phx-click="disable_totp" phx-target="<%= @myself %>"
            data-confirm="Are you sure you want to disable Two-factor authentication?">
            disable two-factor authentication
          </a>
          altogether.
        </p>
      <% end %>
    </form>
    """
  end

  defp render_enable_form(assigns) do
    ~L"""
    <%= f = form_for @user_changeset, "#",
              id: "form-submit-totp",
              phx_change: "change_totp",
              phx_submit: "submit_totp",
              phx_target: @myself %>
      <%= input f, :current_password,
            name: "current_password",
            phx_debounce: "blur",
            id: "current_password_for_totp",
            label: "Enter your current password to #{if @current_totp, do: "change", else: "enable"} 2FA",
            value: @current_password %>

      <%= submit "#{if @current_totp, do: "Change", else: "Enable"} two-factor authentication" %>
    </form>
    """
  end

  @impl true
  def update(assigns, socket) do
    if socket.assigns[:current_user] do
      {:ok, socket}
    else
      {:ok,
       socket
       |> assign(:audit_context, assigns.audit_context)
       |> assign(:current_user, assigns.current_user)
       |> assign(:backup_codes, nil)
       |> reset_assigns(Accounts.get_user_totp(assigns.current_user))}
    end
  end

  @impl true
  def handle_event("show_backup_codes", _, socket) do
    {:noreply, assign(socket, :backup_codes, socket.assigns.editing_totp.backup_codes)}
  end

  @impl true
  def handle_event("hide_backup_codes", _, socket) do
    {:noreply, assign(socket, :backup_codes, nil)}
  end

  @impl true
  def handle_event("regenerate_backup_codes", _, socket) do
    totp =
      Bytepack.Accounts.regenerate_user_totp_backup_codes(
        socket.assigns.audit_context,
        socket.assigns.editing_totp
      )

    socket =
      socket
      |> assign(:backup_codes, totp.backup_codes)
      |> assign(:editing_totp, totp)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_totp", %{"user_totp" => params}, socket) do
    editing_totp = socket.assigns.editing_totp
    audit_context = socket.assigns.audit_context

    case Accounts.upsert_user_totp(audit_context, editing_totp, params) do
      {:ok, current_totp} ->
        {:noreply,
         socket
         |> reset_assigns(current_totp)
         |> assign(:backup_codes, current_totp.backup_codes)}

      {:error, changeset} ->
        {:noreply, assign(socket, totp_changeset: changeset)}
    end
  end

  @impl true
  def handle_event("disable_totp", _, socket) do
    :ok = Accounts.delete_user_totp(socket.assigns.audit_context, socket.assigns.editing_totp)
    {:noreply, reset_assigns(socket, nil)}
  end

  @impl true
  def handle_event("display_secret_as_qrcode", _, socket) do
    {:noreply, assign(socket, :secret_display, :as_qrcode)}
  end

  @impl true
  def handle_event("display_secret_as_text", _, socket) do
    {:noreply, assign(socket, :secret_display, :as_text)}
  end

  @impl true
  def handle_event("change_totp", %{"current_password" => current_password}, socket) do
    {:noreply, assign_user_changeset(socket, current_password)}
  end

  @impl true
  def handle_event("submit_totp", %{"current_password" => current_password}, socket) do
    socket = assign_user_changeset(socket, current_password)

    if socket.assigns.user_changeset.valid? do
      user = socket.assigns.current_user
      editing_totp = socket.assigns.current_totp || %Accounts.UserTOTP{user_id: user.id}
      app = "Bytepack App"
      secret = NimbleTOTP.secret()
      qrcode_uri = NimbleTOTP.otpauth_uri("#{app}:#{user.email}", secret, issuer: app)

      editing_totp = %{editing_totp | secret: secret}
      totp_changeset = Accounts.change_user_totp(editing_totp)

      socket =
        socket
        |> assign(:editing_totp, editing_totp)
        |> assign(:totp_changeset, totp_changeset)
        |> assign(:qrcode_uri, qrcode_uri)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_totp", _, socket) do
    {:noreply, reset_assigns(socket, socket.assigns.current_totp)}
  end

  defp reset_assigns(socket, totp) do
    socket
    |> assign(:current_totp, totp)
    |> assign(:secret_display, :as_qrcode)
    |> assign(:editing_totp, nil)
    |> assign(:totp_changeset, nil)
    |> assign(:qrcode_uri, nil)
    |> assign_user_changeset(nil)
  end

  defp assign_user_changeset(socket, current_password) do
    user = socket.assigns.current_user

    socket
    |> assign(:current_password, current_password)
    |> assign(:user_changeset, Accounts.validate_user_current_password(user, current_password))
  end

  defp generate_qrcode(uri) do
    uri
    |> EQRCode.encode()
    |> EQRCode.svg(width: @qrcode_size)
    |> raw()
  end

  defp format_secret(secret) do
    secret
    |> Base.encode32(padding: false)
    |> String.graphemes()
    |> Enum.map(&maybe_highlight_digit/1)
    |> Enum.chunk_every(4)
    |> Enum.intersperse(" ")
    |> raw()
  end

  defp maybe_highlight_digit(char) do
    case Integer.parse(char) do
      :error -> char
      _ -> ~s(<span class="text-primary">#{char}</span>)
    end
  end
end
