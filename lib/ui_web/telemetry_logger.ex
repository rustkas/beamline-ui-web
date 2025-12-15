defmodule UiWeb.TelemetryLogger do
  @moduledoc """
  Telemetry event handler that logs gateway and NATS events to structured JSON logs.

  Attaches to:
  - `[:ui_web, :gateway, :request]` - Gateway HTTP requests (legacy)
  - `[:ui_web, :gateway, :health_check]` - Gateway health checks
  - `[:ui_web, :nats, :event]` - NATS events received
  - `[:ui_web, :client, :request]` - Client layer requests (new)
  - `[:ui_web, :client, :response]` - Client layer responses (new)
  - `[:ui_web, :live, :action]` - LiveView actions (new)
  """

  require Logger

  @doc """
  Attach telemetry handlers for UI-Web events.
  """
  def attach do
    :telemetry.attach_many(
      "ui-web-logger",
      [
        [:ui_web, :gateway, :request],
        [:ui_web, :gateway, :health_check],
        [:ui_web, :nats, :event],
        [:ui_web, :client, :request],
        [:ui_web, :client, :response],
        [:ui_web, :live, :action]
      ],
      &__MODULE__.handle_event/4,
      %{}
    )
  end

  @doc """
  Detach telemetry handlers.
  """
  def detach do
    :telemetry.detach("ui-web-logger")
  end

  def handle_event([:ui_web, :gateway, :request], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.info("gateway_request",
      duration_ms: duration_ms,
      method: metadata.method,
      path: metadata.path,
      result: metadata.result
    )
  end

  def handle_event([:ui_web, :gateway, :health_check], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.info("gateway_health_check",
      duration_ms: duration_ms,
      result: metadata.result
    )
  end

  def handle_event([:ui_web, :nats, :event], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.info("nats_event",
      duration_ms: duration_ms,
      size_bytes: measurements.size_bytes,
      nats_topic: metadata.nats_topic,
      phoenix_topic: metadata.phoenix_topic,
      event_type: metadata.event_type,
      result: metadata.result
    )
  end

  def handle_event([:ui_web, :client, :request], _measurements, metadata, _config) do
    Logger.info("client_request",
      client: metadata.client,
      operation: metadata.operation,
      method: metadata.method,
      url: metadata.url,
      query: metadata.query,
      tenant_id: metadata.tenant_id,
      user_id: metadata.user_id,
      request_id: metadata.request_id
    )
  end

  def handle_event([:ui_web, :client, :response], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    level = if metadata.success, do: :info, else: :error

    Logger.log(level, "client_response",
      client: metadata.client,
      operation: metadata.operation,
      method: metadata.method,
      url: metadata.url,
      status: metadata.status,
      success: metadata.success,
      error_reason: metadata.error_reason,
      duration_ms: duration_ms,
      tenant_id: metadata.tenant_id,
      user_id: metadata.user_id,
      request_id: metadata.request_id
    )
  end

  def handle_event([:ui_web, :live, :action], _measurements, metadata, _config) do
    Logger.info("liveview_action",
      liveview: inspect(metadata.liveview),
      event: metadata.event,
      tenant_id: metadata.tenant_id,
      user_id: metadata.user_id,
      request_id: metadata.request_id
    )
  end
end

