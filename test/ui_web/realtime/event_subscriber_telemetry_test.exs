defmodule UiWeb.Realtime.EventSubscriberTelemetryTest do
  use ExUnit.Case, async: false

  alias UiWeb.Realtime.EventSubscriber

  setup do
    # Attach test telemetry handler
    parent = self()

    :telemetry.attach(
      "test-nats-event",
      [:ui_web, :nats, :event],
      fn event, measurements, metadata, _config ->
        send(parent, {:telemetry_event, event, measurements, metadata})
      end,
      %{}
    )

    on_exit(fn ->
      :telemetry.detach("test-nats-event")
    end)

    :ok
  end

  describe "NATS event telemetry" do
    test "emits telemetry for NATS event" do
      # Create a test NATS message
      event_data = %{
        "type" => "message_created",
        "data" => %{"id" => "msg_123", "content" => "test"}
      }

      body = Jason.encode!(event_data)
      topic = "beamline.messages.events.created"

      # Simulate NATS message
      # Note: PubSub broadcast may fail if not started, but telemetry should still be emitted
      {:noreply, _state} =
        EventSubscriber.handle_info({:msg, %{topic: topic, body: body}}, %{
          subscriptions: []
        })

      # Wait for telemetry event
      assert_receive {:telemetry_event, [:ui_web, :nats, :event], measurements, metadata},
                     1_000

      # Verify measurements
      assert is_integer(measurements.duration)
      assert measurements.duration >= 0
      assert is_integer(measurements.size_bytes)
      assert measurements.size_bytes > 0

      # Verify metadata
      assert metadata.nats_topic == topic
      assert metadata.phoenix_topic == "messages:updates"
      assert metadata.event_type == "message_created"
      assert metadata.result == :ok
    end

    test "emits telemetry with error result for invalid JSON" do
      # Create invalid JSON
      body = ~s({"type":"invalid_json,)
      topic = "beamline.messages.events.created"

      # Simulate NATS message with invalid JSON
      # Note: PubSub broadcast may fail if not started, but telemetry should still be emitted
      {:noreply, _state} =
        EventSubscriber.handle_info({:msg, %{topic: topic, body: body}}, %{
          subscriptions: []
        })

      # Wait for telemetry event
      assert_receive {:telemetry_event, [:ui_web, :nats, :event], measurements, metadata},
                     1_000

      # Verify measurements
      assert is_integer(measurements.duration)
      assert is_integer(measurements.size_bytes)

      # Verify metadata shows error
      assert metadata.result == :error
      assert metadata.event_type == "decode_error"
    end

    test "maps different NATS topics to Phoenix topics correctly" do
      test_cases = [
        {"beamline.extensions.events.created", "extensions:updates"},
        {"beamline.messages.events.updated", "messages:updates"},
        {"beamline.policies.events.deleted", "policies:updates"}
      ]

      for {nats_topic, expected_phoenix_topic} <- test_cases do
        event_data = %{"type" => "test", "data" => %{}}
        body = Jason.encode!(event_data)

        {:noreply, _state} =
          EventSubscriber.handle_info({:msg, %{topic: nats_topic, body: body}}, %{
            subscriptions: []
          })

        assert_receive {:telemetry_event, [:ui_web, :nats, :event], _measurements, metadata},
                        1_000

        assert metadata.nats_topic == nats_topic
        assert metadata.phoenix_topic == expected_phoenix_topic
      end
    end
  end
end
