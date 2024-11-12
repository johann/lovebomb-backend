# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :lovebomb,
  ecto_repos: [Lovebomb.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :lovebomb, LovebombWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LovebombWeb.ErrorHTML, json: LovebombWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Lovebomb.PubSub,
  live_view: [signing_salt: "i2NYQxU3"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :lovebomb, Lovebomb.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  lovebomb: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  lovebomb: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :lovebomb, Lovebomb.Guardian,
  issuer: "lovebomb",
  secret_key: System.get_env("GUARDIAN_SECRET") || "your_development_secret_key"
# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :lovebomb, LovebombWeb.Endpoint,
  cors_plug_options: [
    origin: ["http://localhost:3000"],  # Add your frontend URLs
    max_age: 86400,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    headers: ["Authorization", "Content-Type", "Accept", "Origin", "User-Agent"]
  ]


# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
