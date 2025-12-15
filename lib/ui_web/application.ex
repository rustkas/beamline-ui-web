defmodule UiWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Attach telemetry logger (for dev/test/prod)
    UiWeb.TelemetryLogger.attach()

    # Initialize ETS cache table for URL preview component
    :ets.new(:url_preview_cache, [:set, :public, :named_table])

    children = [
      UiWebWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:ui_web, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: UiWeb.PubSub},
      # Cache для health checks (должен быть перед GatewayClient)
      {Cachex, name: :gateway_cache},
      # Gateway Client with health monitoring
      UiWeb.Services.GatewayClient,
      # NATS Connection (conditional)
      nats_child_spec(),
      # Realtime bridge: subscribes to Gateway SSE and broadcasts into Channels
      UiWeb.SSEBridge,
      # Real-time event subscriber
      {UiWeb.Realtime.EventSubscriber, []},
      # Start to serve requests, typically the last entry
      UiWebWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: UiWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp nats_child_spec do
    if Application.get_env(:ui_web, :features, [])[:enable_real_time] do
      nats_config = Application.get_env(:ui_web, :nats, [])
      nats_url = Keyword.get(nats_config, :url, "nats://localhost:4222")

      uri = URI.parse(nats_url)
      host = uri.host || "localhost"
      port = uri.port || 4222

      %{
        id: :gnat,
        start: {
          Gnat.ConnectionSupervisor,
          :start_link,
          [
            %{
              name: :gnat,
              connection_settings: [
                %{host: host, port: port}
              ]
            }
          ]
        }
      }
    else
      # Dummy child when real-time disabled
      Supervisor.child_spec({Task, fn -> :ok end}, id: :nats_disabled, restart: :temporary)
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    UiWebWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
