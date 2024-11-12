defmodule LovebombWeb.Router do
  use LovebombWeb, :router
  use Plug.ErrorHandler

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LovebombWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug, origin: ["http://localhost:3000", "https://lovebomb.app"]
    plug :fetch_session
    plug :fetch_query_params
  end

  pipeline :api_rate_limit do
    plug LovebombWeb.Plugs.RateLimit,
      max_requests: 100,
      interval_seconds: 60
  end

  pipeline :api_auth do
    plug Guardian.Plug.Pipeline,
      module: Lovebomb.Guardian,
      error_handler: LovebombWeb.AuthErrorHandler

    plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
    plug Guardian.Plug.EnsureAuthenticated
    plug Guardian.Plug.LoadResource
    plug LovebombWeb.Plugs.CurrentUser
  end

  pipeline :ensure_admin do
    plug LovebombWeb.Plugs.EnsureAdmin
  end

  scope "/", LovebombWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # scope "/api", LovebombWeb do
  #   pipe_through [:api, :api_auth]

  #   resources "/partnerships", PartnershipController do
  #     get "/stats", PartnershipController, :stats
  #     get "/achievements", PartnershipController, :achievements
  #     resources "/interactions", PartnershipInteractionController, only: [:index, :create]
  #   end
  # end

  scope "/api/v1", LovebombWeb.Api.V1 do
    pipe_through [:api, :api_rate_limit]

    # Authentication endpoints
    post "/users/register", UserController, :register
    post "/users/login", UserController, :login
    post "/users/reset_password", UserController, :request_password_reset
    put "/users/reset_password", UserController, :reset_password
  end

  scope "/api/v1", LovebombWeb.Api.V1 do
    pipe_through [:api, :api_rate_limit, :api_auth]

    # User management
    delete "/users/logout", UserController, :logout
    post "/users/refresh_token", UserController, :refresh_token

    # Profile management (we'll implement these next)
    resources "/profile", ProfileController, singleton: true
    put "/profile/preferences", ProfileController, :update_preferences
    put "/profile/password", ProfileController, :update_password
    post "/profile/avatar", ProfileController, :upload_avatar

    # Questions and answers (coming soon)
    get "/questions/daily", QuestionController, :daily
    resources "/questions", QuestionController, only: [:index, :show]
    resources "/answers", AnswerController, only: [:create, :index, :show]
    post "/answers/:id/react", AnswerController, :react

    # Partnerships (future implementation)
    resources "/partnerships", PartnershipController do
      get "/stats", PartnershipController, :stats
      get "/timeline", PartnershipController, :timeline
      resources "/answers", PartnershipAnswerController, only: [:index]
    end

    # Notifications (future implementation)
    resources "/notifications", NotificationController, only: [:index, :show]
    put "/notifications/read", NotificationController, :mark_read
    put "/notifications/preferences", NotificationController, :update_preferences
  end

  scope "/api/v1/admin", LovebombWeb.Api.V1.Admin do
    pipe_through [:api, :api_rate_limit, :api_auth, :ensure_admin]

    resources "/users", UserController, except: [:new, :edit]
    resources "/questions", QuestionController, except: [:new, :edit]
    get "/stats", StatsController, :index
    get "/reports", ReportController, :index
  end

  # Error handlers
  # def handle_errors(conn, %{reason: %Phoenix.Router.NoRouteError{}}) do
  #   conn
  #   |> put_status(:not_found)
  #   |> put_view(json: LovebombWeb.ErrorJSON)
  #   |> render(:"404")
  # end

  # def handle_errors(conn, %{reason: %Guardian.Plug.Error{}}) do
  #   conn
  #   |> put_status(:unauthorized)
  #   |> put_view(json: LovebombWeb.ErrorJSON)
  #   |> render(:"401")
  # end

  # def handle_errors(conn, _) do
  #   conn
  #   |> put_status(:internal_server_error)
  #   |> put_view(json: LovebombWeb.ErrorJSON)
  #   |> render(:"500")
  # end

  def handle_errors(conn, %{reason: %Phoenix.Router.NoRouteError{}}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: LovebombWeb.ErrorJSON)
    |> render(:"404")
  end

  def handle_errors(conn, %{reason: :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: LovebombWeb.ErrorJSON)
    |> render(:"401")
  end

  def handle_errors(conn, %{reason: :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: LovebombWeb.ErrorJSON)
    |> render(:"403")
  end

  # Other scopes may use custom stacks.
  # scope "/api", LovebombWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:lovebomb, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LovebombWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
