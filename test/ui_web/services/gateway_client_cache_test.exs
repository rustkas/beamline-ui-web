defmodule UiWeb.Services.GatewayClientCacheTest do
  use ExUnit.Case, async: false

  alias UiWeb.Services.GatewayClient

  setup do
    # Clear cache before each test
    Cachex.clear(:gateway_cache)
    :ok
  end

  describe "check_health/0 with caching" do
    test "first call performs actual check" do
      # Mock Gateway должен быть запущен на порту 8081
      # Или реальный Gateway на 8080
      result = GatewayClient.check_health()

      # check_health returns {:ok, body} or {:error, reason}
      case result do
        {:ok, body} when is_map(body) ->
          # After normalization, body should be a map with status/cached_at
          assert Map.has_key?(body, "cached_at") || Map.has_key?(body, "status")

        {:error, _reason} ->
          # Gateway может быть недоступен в тестах - это нормально
          :ok

        # Handle case when result is a map directly (shouldn't happen, but handle it)
        body when is_map(body) ->
          assert Map.has_key?(body, "cached_at") || Map.has_key?(body, "status")
      end
    end

    test "subsequent calls within TTL use cache" do
      # First call
      result1 = GatewayClient.check_health()

      case result1 do
        result1 when is_map(result1) ->
          cached_at1 = result1["cached_at"]

          # Wait 1 second
          Process.sleep(1_000)

          # Second call (should be cached)
          result2 = GatewayClient.check_health()

          case result2 do
            result2 when is_map(result2) ->
              cached_at2 = result2["cached_at"]

              # Same cached_at means cache hit
              assert cached_at1 == cached_at2

            {:error, _} ->
              # Gateway unavailable - skip test
              :ok
          end

        {:error, _} ->
          # Gateway unavailable - skip test
          :ok
      end
    end

    test "cache expires after TTL" do
      # First call
      result1 = GatewayClient.check_health()

      case result1 do
        result1 when is_map(result1) ->
          cached_at1 = result1["cached_at"]

          # Wait 6 seconds (TTL = 5 seconds)
          Process.sleep(6_000)

          # Second call (cache should be expired)
          result2 = GatewayClient.check_health()

          case result2 do
            result2 when is_map(result2) ->
              cached_at2 = result2["cached_at"]

              # Different cached_at means cache miss
              assert cached_at1 != cached_at2

            {:error, _} ->
              # Gateway unavailable - skip test
              :ok
          end

        {:error, _} ->
          # Gateway unavailable - skip test
          :ok
      end
    end

    test "concurrent calls are deduplicated" do
      # Spawn 100 concurrent health checks
      tasks =
        for _ <- 1..100 do
          Task.async(fn -> GatewayClient.check_health() end)
        end

      # Wait for all
      results = Task.await_many(tasks, 10_000)

      # All should succeed (map) or all fail (deduplicated)
      success_count = Enum.count(results, fn r when is_map(r) -> true; _ -> false end)
      error_count = Enum.count(results, fn {:error, _} -> true; _ -> false end)

      # Either all succeed or all fail (deduplication)
      assert success_count == 100 || error_count == 100

      # If all succeeded, check cached_at is same (deduplicated)
      if success_count == 100 do
        cached_ats = Enum.map(results, fn r when is_map(r) -> r["cached_at"] end)
        assert length(Enum.uniq(cached_ats)) == 1
      end
    end
  end

  describe "check_health!/1 with force" do
    test "bypasses cache" do
      # First call (cached)
      result1 = GatewayClient.check_health()

      case result1 do
        result1 when is_map(result1) ->
          cached_at1 = result1["cached_at"]

          # Force refresh
          result2 = GatewayClient.check_health!(force: true)

          case result2 do
            result2 when is_map(result2) ->
              cached_at2 = result2["cached_at"]

              # Should be different (force bypassed cache)
              assert cached_at1 != cached_at2

            {:error, _} ->
              # Gateway unavailable - skip test
              :ok
          end

        {:error, _} ->
          # Gateway unavailable - skip test
          :ok
      end
    end
  end

  describe "cached_health_status/0" do
    test "returns nil when cache empty" do
      assert GatewayClient.cached_health_status() == nil
    end

    test "returns cached result without network call" do
      # Prime cache
      result = GatewayClient.check_health()

      case result do
        result when is_map(result) ->
          # Get from cache (no network)
          cached = GatewayClient.cached_health_status()
          assert cached != nil
          assert Map.has_key?(cached, "cached_at")

        {:error, _} ->
          # Gateway unavailable - skip test
          :ok
      end
    end
  end
end

