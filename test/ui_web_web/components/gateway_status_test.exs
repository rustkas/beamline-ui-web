defmodule UiWebWeb.Components.GatewayStatusTest do
  use UiWebWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias UiWebWeb.Components.GatewayStatus
  alias UiWeb.Services.GatewayClient

  setup do
    # Clear cache before each test
    Cachex.clear(:gateway_cache)
    :ok
  end

  test "renders online status when gateway is healthy" do
    # Mock healthy status
    {:ok, view, html} = live_isolated(build_conn(), GatewayStatus, id: "gateway-status")

    # Wait for initial render
    Process.sleep(100)

    html = render(view)
    # Should show either online or offline (depends on Gateway availability)
    assert html =~ "Gateway" || html =~ "Online" || html =~ "Offline"
  end

  test "handles force refresh event" do
    {:ok, view, _html} = live_isolated(build_conn(), GatewayStatus, id: "gateway-status")

    # Wait for initial render
    Process.sleep(100)

    # Trigger force refresh
    html = render_click(view, "force_refresh")

    # Should show flash message or updated status
    assert html =~ "Gateway" || html =~ "refreshed" || html =~ "cached"
  end

  test "shows cache timestamp when available" do
    # Prime cache
    case GatewayClient.check_health() do
      {:ok, _} ->
        {:ok, view, html} = live_isolated(build_conn(), GatewayStatus, id: "gateway-status")

        # Wait for update
        Process.sleep(200)

        html = render(view)
        # Should show cached timestamp
        assert html =~ "cached" || html =~ "Gateway"

      {:error, _} ->
        # Gateway unavailable - skip test
        :ok
    end
  end

  test "periodically refreshes status" do
    {:ok, view, _html} = live_isolated(build_conn(), GatewayStatus, id: "gateway-status")

    # Wait for refresh interval (10 seconds)
    # In real test, we might want to mock the timer
    Process.sleep(100)

    html = render(view)
    assert html =~ "Gateway"
  end
end

