defmodule UiWebWeb.ExtensionsPipelineLiveTest do
  use UiWebWeb.ConnCase
  import Phoenix.LiveViewTest

  # Import test helpers
  alias UiWeb.Test.MockGateway

  alias UiWeb.Test.MockGateway

  setup %{conn: conn} do
    # Start mock gateway
    {:ok, _} = Plug.Cowboy.http(MockGateway, [], port: 8080)
    Process.sleep(100) # Wait for server to start

    on_exit(fn ->
      # Cleanup if needed
    end)

    {:ok, conn: conn}
  end

  describe "Extensions Pipeline LiveView" do
    test "renders pipeline inspector page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/app/extensions/pipeline")

      assert has_element?(view, "h2", "Extensions Pipeline Inspector")
      assert has_element?(view, "form[phx-submit='set_tenant_policy']")
      assert has_element?(view, "form[phx-submit='run_dry_run']")
    end

    test "loads policy and displays pipeline structure", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/app/extensions/pipeline")

      # Set tenant and policy
      view
      |> element("form[phx-submit='set_tenant_policy']")
      |> render_submit(%{
        "tenant_id" => "tenant_dev",
        "policy_id" => "default"
      })

      # Wait for policy to load
      Process.sleep(100)

      # Check that policy structure is displayed
      html = render(view)
      assert html =~ "Pipeline Structure"
    end

    test "loads extensions registry", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/app/extensions/pipeline")

      # Wait for extensions to load
      Process.sleep(100)

      html = render(view)
      assert html =~ "Extensions Registry"
      assert html =~ "normalize_text"
    end

    test "loads extension health metrics", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/app/extensions/pipeline")

      # Wait for health to load
      Process.sleep(100)

      html = render(view)
      assert html =~ "healthy"
    end

    test "loads circuit breaker states", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/app/extensions/pipeline")

      # Wait for circuit breakers to load
      Process.sleep(100)

      html = render(view)
      assert html =~ "closed"
    end

    test "runs dry-run pipeline", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/app/extensions/pipeline")

      # Update payload
      view
      |> element("textarea[name='payload']")
      |> render_change(%{"payload" => %{"value" => ~s({"message": "test"})}})

      # Run dry-run
      view
      |> element("form[phx-submit='run_dry_run']")
      |> render_submit()

      # Wait for result
      Process.sleep(100)

      html = render(view)
      assert html =~ "Dry Run Result"
      assert html =~ "executed_extensions"
    end

    test "displays extension health badges", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/app/extensions/pipeline")

      # Wait for health to load
      Process.sleep(100)

      html = render(view)
      # Check for health badge classes
      assert html =~ "bg-green-100" || html =~ "healthy"
    end

    test "displays circuit breaker badges", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/app/extensions/pipeline")

      # Wait for circuit breakers to load
      Process.sleep(100)

      html = render(view)
      # Check for circuit breaker badge classes
      assert html =~ "bg-green-100" || html =~ "closed"
    end

    test "handles errors gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/app/extensions/pipeline")

      # Try to load invalid policy
      view
      |> element("form[phx-submit='set_tenant_policy']")
      |> render_submit(%{
        "tenant_id" => "invalid_tenant",
        "policy_id" => "invalid_policy"
      })

      # Wait for error
      Process.sleep(100)

      html = render(view)
      # Error should be displayed
      assert html =~ "error" || html =~ "Failed"
    end
  end
end

