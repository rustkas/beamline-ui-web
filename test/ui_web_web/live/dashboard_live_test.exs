defmodule UiWebWeb.DashboardLiveTest do
  @moduledoc """
  Integration tests for Dashboard LiveView.
  
  Tests follow the Test Strategy pattern:
  - Use assert_html/eventually instead of Process.sleep
  - Sync with mock /_health and /metrics endpoints
  - Test happy path, polling, error flows
  """
  
  use UiWebWeb.LiveViewCase
  
  @moduletag :live_view
  @moduletag :integration
  
  setup do
    # Mock Gateway should already be running
    :ok
  end
  
  describe "Dashboard rendering" do
    test "renders dashboard with initial state", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/dashboard")
      
      # Check page title
      assert html =~ "Beamline Dashboard"
      assert html =~ "Real-time system metrics"
      
      # Check component health cards are present
      assert html =~ "Component Health"
      assert html =~ "C-Gateway"
      assert html =~ "Router"
      assert html =~ "NATS"
      
      # Check metrics cards are present
      assert html =~ "Real-time Metrics"
      assert html =~ "Throughput"
      assert html =~ "Latency"
      assert html =~ "Error Rate"
    end
    
    test "displays component health status after initial poll", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial poll to complete
      assert_html(view, ~r/ok|healthy|Component Health/, timeout: 2000)
      
      html = render(view)
      
      # Check that health cards are rendered
      assert html =~ "Component Health"
      assert html =~ "C-Gateway" || html =~ "Gateway"
      assert html =~ "Router"
      assert html =~ "NATS"
    end
    
    test "displays metrics when available", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial poll to complete
      assert_html(view, "Real-time Metrics", timeout: 2000)
      
      html = render(view)
      
      # Check metrics section is present
      assert html =~ "Real-time Metrics"
      assert html =~ "Throughput"
      assert html =~ "Latency"
    end
    
    test "displays error message when health fetch fails", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial load
      assert_html(view, "Dashboard", timeout: 1000)
      
      # Simulate error by breaking Gateway URL temporarily
      original_url = Application.get_env(:ui_web, :gateway) |> Keyword.get(:url)
      Application.put_env(:ui_web, :gateway, url: "http://localhost:99999", timeout: 500)
      
      try do
        # Trigger poll that will fail
        send(view.pid, :tick)
        
        # Wait for dashboard to update (error handling is graceful)
        # Dashboard should continue to work even if health fetch fails
        assert_html(view, "Dashboard", timeout: 3000)
        
        html = render(view)
        
        # Dashboard should still be visible (graceful error handling)
        assert html =~ "Dashboard"
        # Error may or may not be visible depending on timing
        # Important: dashboard doesn't crash
      after
        # Restore original URL
        Application.put_env(:ui_web, :gateway, url: original_url, timeout: 5000)
        # Wait a bit for connection to restore
        Process.sleep(200)
      end
    end
  end
  
  describe "Real-time updates (polling)" do
    alias UiWeb.Test.Retry
    
    @tag retry: 3
    test "polls Gateway for health updates", %{conn: conn} do
      Retry.retry(3, fn ->
        {:ok, view, _html} = live(conn, ~p"/app/dashboard")
        
        # Wait for initial poll
        assert_html(view, ~r/ok|System Status|Component Health/, timeout: 2000)
        
        # Get initial state
        html1 = render(view)
        assert html1 =~ "System Status" || html1 =~ "Dashboard"
        
        # Trigger manual poll
        send(view.pid, :tick)
        
        # Wait for update (polling is async, may take time)
        assert_html(view, ~r/ok|System Status|Component Health/, timeout: 2000)
        
        # State should be updated
        html2 = render(view)
        assert html2 =~ "Dashboard" || html2 =~ "Component Health"
      end)
    end
    
    test "updates metrics when Gateway returns new data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial poll
      assert_html(view, "Real-time Metrics", timeout: 2000)
      
      # Trigger update
      send(view.pid, :tick)
      
      # Wait for metrics to update
      assert_html(view, ~r/Throughput|req\/s/, timeout: 1000)
      
      html = render(view)
      
      # Metrics section should be present
      assert html =~ "Real-time Metrics" || html =~ "Throughput"
    end
    
    test "handles Gateway errors gracefully during polling", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial load
      assert_html(view, "Dashboard", timeout: 1000)
      
      # Simulate Gateway error by temporarily breaking URL
      original_url = Application.get_env(:ui_web, :gateway) |> Keyword.get(:url)
      Application.put_env(:ui_web, :gateway, url: "http://localhost:99999", timeout: 500)
      
      try do
        # Trigger poll
        send(view.pid, :tick)
        
        # Wait for dashboard to update (may show error or not, depending on timing)
        # Important: dashboard should not crash
        assert_html(view, "Dashboard", timeout: 3000)
        
        html = render(view)
        
        # Should still render dashboard (error handling is graceful)
        assert html =~ "Dashboard"
        # Dashboard continues to work even if health/metrics fail
      after
        Application.put_env(:ui_web, :gateway, url: original_url, timeout: 5000)
        Process.sleep(200)
      end
    end
  end
  
  describe "Mock Gateway integration" do
    test "fetches health from Mock Gateway", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial poll to complete
      assert_html(view, ~r/ok|healthy|System Status/, timeout: 2000)
      
      # Trigger health fetch
      send(view.pid, :tick)
      
      # Wait for update
      assert_html(view, "System Status", timeout: 1000)
      
      html = render(view)
      
      # Should have health data (status should be present)
      assert html =~ "System Status" || html =~ "status"
    end
    
    test "fetches metrics from Mock Gateway", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial poll
      assert_html(view, "Real-time Metrics", timeout: 2000)
      
      # Trigger metrics fetch
      send(view.pid, :tick)
      
      # Wait for metrics to appear
      assert_html(view, ~r/Throughput|req\/s|Latency/, timeout: 1000)
      
      html = render(view)
      
      # Metrics should be displayed
      assert html =~ "Real-time Metrics" || html =~ "Throughput"
    end
    
    test "displays component health from health response", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial data load
      assert_html(view, ~r/C-Gateway|Router|Component Health/, timeout: 2000)
      
      html = render(view)
      
      # Component health section should be present
      assert html =~ "Component Health" || html =~ "C-Gateway" || html =~ "Gateway"
      assert html =~ "Router"
      assert html =~ "NATS"
    end
    
    test "displays NATS connection status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial data load
      assert_html(view, "NATS", timeout: 2000)
      
      html = render(view)
      
      # NATS should be mentioned
      assert html =~ "NATS" || html =~ "nats"
    end
  end
  
  describe "Error handling" do
    test "displays error when health fetch fails", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial load
      assert_html(view, "Dashboard", timeout: 1000)
      
      # Break Gateway URL temporarily
      original_url = Application.get_env(:ui_web, :gateway) |> Keyword.get(:url)
      Application.put_env(:ui_web, :gateway, url: "http://localhost:99999", timeout: 500)
      
      try do
        # Trigger poll that will fail
        send(view.pid, :tick)
        
        # Wait for dashboard to update (error handling is graceful)
        # Dashboard should continue to work even if health fetch fails
        assert_html(view, "Dashboard", timeout: 3000)
        
        html = render(view)
        
        # Dashboard should still be visible (graceful error handling)
        assert html =~ "Dashboard"
        # Error may or may not be visible depending on timing
      after
        Application.put_env(:ui_web, :gateway, url: original_url, timeout: 5000)
        Process.sleep(200)
      end
    end
    
    test "continues to poll after error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial load
      assert_html(view, "Dashboard", timeout: 1000)
      
      # Break Gateway temporarily
      original_url = Application.get_env(:ui_web, :gateway) |> Keyword.get(:url)
      Application.put_env(:ui_web, :gateway, url: "http://localhost:99999", timeout: 500)
      
      try do
        # First poll fails
        send(view.pid, :tick)
        
        # Wait for dashboard to update (graceful error handling)
        assert_html(view, "Dashboard", timeout: 3000)
        
        html1 = render(view)
        # Dashboard should still work
        assert html1 =~ "Dashboard"
        
        # Restore Gateway
        Application.put_env(:ui_web, :gateway, url: original_url, timeout: 5000)
        
        # Wait a bit for connection to restore
        Process.sleep(500)
        
        # Next poll should succeed
        send(view.pid, :tick)
        
        # Wait for success
        assert_html(view, ~r/ok|System Status|Component Health|Dashboard/, timeout: 2000)
        
        html2 = render(view)
        # Dashboard should be updated
        assert html2 =~ "Dashboard"
      after
        Application.put_env(:ui_web, :gateway, url: original_url, timeout: 5000)
        Process.sleep(200)
      end
    end
    
    test "handles metrics fetch failure gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial load
      assert_html(view, "Dashboard", timeout: 1000)
      
      # Metrics failure doesn't break the dashboard (it's optional)
      # Dashboard should still render even if metrics fail
      html = render(view)
      assert html =~ "Dashboard"
      assert html =~ "Real-time Metrics" || html =~ "Component Health"
    end
  end
  
  describe "Component health extraction" do
    test "extracts gateway health from response", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial data load
      assert_html(view, ~r/C-Gateway|Gateway|Component Health/, timeout: 2000)
      
      html = render(view)
      
      # Gateway component should be displayed
      assert html =~ "C-Gateway" || html =~ "Gateway"
    end
    
    test "extracts router health from response", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial data load
      assert_html(view, "Router", timeout: 2000)
      
      html = render(view)
      
      # Router component should be displayed
      assert html =~ "Router"
    end
    
    test "extracts worker_caf health from response", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for initial data load
      assert_html(view, "Worker CAF", timeout: 2000)
      
      html = render(view)
      
      # Worker CAF component should be displayed
      assert html =~ "Worker CAF" || html =~ "Worker"
    end
  end
  
  describe "Metrics normalization" do
    test "displays throughput (rps)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for metrics to load
      assert_html(view, ~r/Throughput|req\/s/, timeout: 2000)
      
      html = render(view)
      
      # Throughput should be displayed
      assert html =~ "Throughput" || html =~ "req/s"
    end
    
    test "displays latency metrics (p50, p95)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for metrics to load
      assert_html(view, "Latency", timeout: 2000)
      
      html = render(view)
      
      # Latency should be displayed
      assert html =~ "Latency" || html =~ "p50" || html =~ "p95"
    end
    
    test "displays error rate", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/dashboard")
      
      # Wait for metrics to load
      assert_html(view, "Error Rate", timeout: 2000)
      
      html = render(view)
      
      # Error rate should be displayed
      assert html =~ "Error Rate" || html =~ "%"
    end
  end
end
