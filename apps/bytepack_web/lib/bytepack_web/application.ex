defmodule BytepackWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    Logger.add_backend(Sentry.LoggerBackend)

    children = [
      # Start the Telemetry supervisor
      BytepackWeb.Telemetry,
      # Start the Endpoint (http/https)
      BytepackWeb.Endpoint
      # Start a worker by calling: BytepackWeb.Worker.start_link(arg)
      # {BytepackWeb.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BytepackWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BytepackWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
