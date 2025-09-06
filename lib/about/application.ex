defmodule About.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AboutWeb.Telemetry,
      About.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:about, :ecto_repos), skip: skip_migrations?()},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:about, :ash_domains),
         Application.fetch_env!(:about, Oban)
       )},
      # Start a worker by calling: About.Worker.start_link(arg)
      # {About.Worker, arg},
      # Start to serve requests, typically the last entry
      {DNSCluster, query: Application.get_env(:about, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: About.PubSub},
      AboutWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :about]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: About.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AboutWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
