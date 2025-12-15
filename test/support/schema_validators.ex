defmodule UiWeb.Test.SchemaValidators do
  @moduledoc """
  Schema validation helpers for Gateway API contracts.
  
  Validates response schemas to ensure API contract compliance.
  """
  
  @doc """
  Validate Gateway health response schema.
  
  Required fields:
  - status: "ok" | "degraded" | "unhealthy"
  - nats: map with "connected" boolean
  - timestamp_ms: integer
  """
  def validate_health_schema(health) when is_map(health) do
    required_fields = ["status", "nats", "timestamp_ms"]
    
    Enum.all?(required_fields, &Map.has_key?(health, &1)) and
      health["status"] in ["ok", "degraded", "unhealthy"] and
      is_map(health["nats"]) and
      is_boolean(health["nats"]["connected"]) and
      is_integer(health["timestamp_ms"])
  end
  
  def validate_health_schema(_), do: false
  
  @doc """
  Validate Gateway metrics response schema.
  
  Required fields:
  - latency: map with p50, p95, p99 (numbers)
  
  Optional fields:
  - rps: number | null
  - error_rate: number | null
  """
  def validate_metrics_schema(metrics) when is_map(metrics) do
    is_map(metrics["latency"]) and
      has_numeric_field?(metrics["latency"], "p50") and
      has_numeric_field?(metrics["latency"], "p95") and
      has_numeric_field?(metrics["latency"], "p99")
  end
  
  def validate_metrics_schema(_), do: false
  
  @doc """
  Validate message acknowledgment schema.
  
  Required fields:
  - message_id: string
  - ack_timestamp_ms: integer
  - status: "published" | "queued" | "rejected"
  """
  def validate_ack_schema(ack) when is_map(ack) do
    required_fields = ["message_id", "ack_timestamp_ms", "status"]
    
    Enum.all?(required_fields, &Map.has_key?(ack, &1)) and
      is_binary(ack["message_id"]) and
      is_integer(ack["ack_timestamp_ms"]) and
      ack["status"] in ["published", "queued", "rejected"]
  end
  
  def validate_ack_schema(_), do: false
  
  defp has_numeric_field?(map, field) when is_map(map) do
    Map.has_key?(map, field) and is_number(map[field])
  end
  
  defp has_numeric_field?(_, _), do: false
end

