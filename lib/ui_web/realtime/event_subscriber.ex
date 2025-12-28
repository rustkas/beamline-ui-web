defmodule UiWeb.Realtime.EventSubscriber do
  @moduledoc """
  Subscribes to NATS subjects and broadcasts to Phoenix PubSub.

  Subscribed subjects:
  - beamline.extensions.events.* (extension updates)
  - beamline.messages.events.* (message updates)
  - beamline.policies.events.* (policy updates)
  """

  use GenServer
  require Logger

  @topics [
    {"beamline.extensions.events.>", "extensions:updates"},
    {"beamline.messages.events.>", "messages:updates"},
    {"beamline.policies.events.>", "policies:updates"}
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    if nats_enabled?() do
      # Wait a bit for NATS connection to be ready
      Process.send_after(self(), :subscribe_all, 1000)
      {:ok, %{subscriptions: []}}
    else
      Logger.info("NATS real-time disabled")
      {:ok, %{subscriptions: []}}
    end
  end

  def handle_info(:subscribe_all, state) do
    subscriptions = subscribe_all()
    {:noreply, %{state | subscriptions: subscriptions}}
  end

  def handle_info({:msg, %{topic: topic, body: body}}, state) do
    started_at = System.monotonic_time()

    decode_result = Jason.decode(body)

    result =
      case decode_result do
        {:ok, event} ->
          phoenix_topic = map_nats_to_phoenix(topic)
          Phoenix.PubSub.broadcast(UiWeb.PubSub, phoenix_topic, {:event, event})
          Logger.debug("Broadcasted NATS event: #{topic} -> #{phoenix_topic}")
          :ok

        {:error, reason} ->
          Logger.error("Failed to decode NATS message: #{inspect(reason)}")
          {:error, reason}
      end

    duration = System.monotonic_time() - started_at

    # Extract event type from decoded event (if successful)
    event_type =
      case decode_result do
        {:ok, decoded} -> decoded["type"] || "unknown"
        {:error, _} -> "decode_error"
      end

    measurements = %{
      duration: duration,
      size_bytes: byte_size(body)
    }

    metadata = %{
      nats_topic: topic,
      phoenix_topic: map_nats_to_phoenix(topic),
      event_type: event_type,
      result: if(result == :ok, do: :ok, else: :error)
    }

    :telemetry.execute([:ui_web, :nats, :event], measurements, metadata)

    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp subscribe_all do
    Enum.map(@topics, fn {nats_subject, phoenix_topic} ->
      case subscribe_to_nats(nats_subject) do
        {:ok, sid} ->
          Logger.info("Subscribed to NATS: #{nats_subject} -> Phoenix: #{phoenix_topic}")
          {:ok, sid}

        {:error, reason} ->
          Logger.error("Failed to subscribe to #{nats_subject}: #{inspect(reason)}")
          {:error, reason}
      end
    end)
  end

  defp subscribe_to_nats(subject) do
    try do
      case Process.whereis(:gnat) do
        nil ->
          Logger.warning("NATS connection not available, retrying...")
          Process.send_after(self(), :subscribe_all, 2000)
          {:error, :not_connected}

        _pid ->
          case Gnat.sub(:gnat, self(), subject) do
            {:ok, sid} -> {:ok, sid}
            {:error, reason} -> {:error, reason}
          end
      end
    rescue
      e ->
        Logger.error("NATS subscription error: #{inspect(e)}")
        Process.send_after(self(), :subscribe_all, 2000)
        {:error, e}
    end
  end

  defp map_nats_to_phoenix("beamline.extensions.events." <> _), do: "extensions:updates"
  defp map_nats_to_phoenix("beamline.messages.events." <> _), do: "messages:updates"
  defp map_nats_to_phoenix("beamline.policies.events." <> _), do: "policies:updates"
  defp map_nats_to_phoenix("caf.worker.heartbeat." <> _), do: "workers:heartbeat"
  defp map_nats_to_phoenix(_), do: "unknown:updates"

  defp nats_enabled? do
    Application.get_env(:ui_web, :features, [])
    |> Keyword.get(:enable_real_time, false)
  end
end

