defmodule BytepackWeb.Router do
  use BytepackWeb, :router

  import Phoenix.LiveView.Router
  import Phoenix.LiveDashboard.Router
  import Phoenix.LiveView.Router
  import BytepackWeb.UserAuth
  import BytepackWeb.RequestContext

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {BytepackWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :put_audit_context
    plug :put_sentry_context

    plug BytepackWeb.Extensions.Plug.CSPHeader,
         Application.compile_env!(:bytepack_web, :csp_config)
  end

  pipeline :landing do
    plug :put_root_layout, {BytepackWeb.LayoutView, :landing}
  end

  pipeline :admin do
    plug :require_authenticated_user
    plug :require_staff
  end

  pipeline :hex_api do
    plug BytepackWeb.Hex.Auth, :api
    plug :put_audit_context
    plug :put_sentry_context
  end

  pipeline :hex_repo do
    plug BytepackWeb.Hex.Auth, :repo
    plug :put_audit_context
    plug :put_sentry_context
  end

  pipeline :webhook do
    plug BytepackWeb.Webhooks.SellerAuth
    plug BytepackWeb.Webhooks.HTTPSignature
    plug :accepts, ["json"]
    plug :put_audit_context
    plug :put_sentry_context
  end

  # institutional

  scope "/", BytepackWeb do
    pipe_through [:browser, :landing]

    get "/", PageController, :index
    live "/contact/sell", ContactFormLive.Index, :sell
    live "/contact/other", ContactFormLive.Index, :other
    live "/contact/report_issue", ContactFormLive.Index, :report_issue
    live "/contact/done", ContactFormLive.Index, :message_sent
    live "/contact", ContactFormLive.Index, :index
  end

  # require not authenticated

  scope "/", BytepackWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/login", UserSessionController, :new
    post "/users/login", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  # require authenticated

  scope "/", BytepackWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/totp", UserTOTPController, :new
    post "/users/totp", UserTOTPController, :create

    live "/users/settings", UserSettingsLive.Index, :index, as: :user_settings
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
    put "/users/settings/update_password", UserSettingsController, :update_password
    delete "/users/logout", UserSessionController, :delete

    get "/oauth/stripe", OAuthController, :stripe, as: :oauth

    live "/dashboard", DashboardLive.Index, :index
    # Duplicated route while we don't have the org dashboard
    live "/dashboard/:org_slug/purchases", PurchaseLive.Index, :index, as: :org_dashboard_index
    live "/dashboard/:org_slug/edit", OrgLive.Edit, :edit
    live "/dashboard/:org_slug/team", TeamLive.Index, :index
    live "/dashboard/:org_slug/team/invite", TeamLive.Index, :invite
    live "/dashboard/:org_slug/team/memberships/:id/edit", TeamLive.Index, :edit_membership
    live "/dashboard/:org_slug/packages", PackageLive.Index, :index
    live "/dashboard/:org_slug/packages/new", PackageLive.New, :new
    live "/dashboard/:org_slug/packages/:type/:name", PackageLive.Show, :show
    live "/dashboard/:org_slug/packages/:type/:name/edit", PackageLive.Show, :edit
    live "/dashboard/:org_slug/packages/:type/:name/:release_version", PackageLive.Show, :show
    live "/dashboard/:org_slug/products", ProductLive.Index, :index
    live "/dashboard/:org_slug/products/new", ProductLive.New, :new
    live "/dashboard/:org_slug/products/:id/edit", ProductLive.Edit, :edit
    live "/dashboard/:org_slug/sales", SaleLive.Index, :index
    live "/dashboard/:org_slug/sales/new", SaleLive.Index, :new
    live "/dashboard/:org_slug/sales/:id/edit", SaleLive.Index, :edit
    live "/dashboard/:org_slug/sales/:id/revoke", SaleLive.Index, :revoke
    live "/dashboard/:org_slug/purchases", PurchaseLive.Index, :index
    live "/dashboard/:org_slug/purchases/:id", PurchaseLive.Show, :show

    live "/dashboard/:org_slug/purchases/:id/:package_type/:package_name",
         PurchaseLive.Show,
         :show

    live "/dashboard/:org_slug/purchases/:id/:package_type/:package_name/:release_version",
         PurchaseLive.Show,
         :show

    live "/organizations/new", OrgLive.New, :new
  end

  # maybe authenticated

  scope "/", BytepackWeb do
    pipe_through [:browser]

    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :confirm

    scope "/onboarding", Onboarding, as: :onboarding do
      pipe_through [:maybe_store_user_return_to]
      live "/purchases/:sale_id/:token", PurchaseLive.Index, :index
    end
  end

  scope "/webhooks/sellers/v1/:org_slug", BytepackWeb, as: :webhook do
    pipe_through [:webhook]

    post "/sales", Webhooks.SaleController, :create
    patch "/sales/update", Webhooks.SaleController, :update
    patch "/sales/revoke", Webhooks.SaleController, :revoke
  end

  # package manager specifics

  scope "/pkg/hex/:org_slug/api", BytepackWeb.Hex, as: :hex do
    pipe_through [:hex_api]

    get "/", APIController, :api_index
    get "/users/me", APIController, :me
    post "/publish", APIController, :publish
    post "/packages/:name/releases/:version/docs", APIController, :publish_docs
  end

  for context <- [:repo, :test_repo] do
    as = "hex#{if context == :test_repo, do: "_test"}"
    assigns = %{hex_context: context}

    scope "/pkg/hex/:org_slug/#{context}", BytepackWeb.Hex, as: as, assigns: assigns do
      pipe_through [:hex_repo]

      get "/", RepoController, :repo_index
      get "/names", RepoController, :get_names
      get "/versions", RepoController, :get_versions
      get "/packages/:name", RepoController, :get_package
      get "/tarballs/*basename", RepoController, :get_tarball
      get "/public_key", RepoController, :public_key
    end
  end

  # authenticated with admin powers

  scope "/sudo", BytepackWeb.Admin, as: :admin do
    pipe_through [:browser, :admin]

    live_dashboard "/dashboard", metrics: BytepackWeb.Telemetry, csp_nonce_assign_key: :csp_nonce
    live "/sellers", SellerLive.Index, :index
    live "/sellers/:slug", SellerLive.Index, :edit
  end

  if Mix.env() in [:dev, :test] do
    scope "/dev" do
      forward "/swoosh", Plug.Swoosh.MailboxPreview, base_path: "/dev/swoosh"
    end
  end
end
