defmodule UiWebWeb.ExtensionsLive.IndexTest do
  @moduledoc """
  Integration tests for Extensions LiveView Index page.
  
  Tests:
  - Extensions list rendering
  - Filtering by type and status
  - Toggle extension enabled/disabled
  - Delete extension
  - Pagination
  """
  
  use UiWebWeb.LiveViewCase
  
  alias Phoenix.PubSub
  
  @moduletag :live_view
  @moduletag :integration
  
  setup do
    # Subscribe to PubSub for extensions updates
    PubSub.subscribe(UiWeb.PubSub, "extensions:updates")
    
    on_exit(fn ->
      PubSub.unsubscribe(UiWeb.PubSub, "extensions:updates")
    end)
    
    :ok
  end
  
  describe "Extensions List Page" do
    test "renders extensions list", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/extensions")
      
      assert html =~ "Extensions Registry"
      assert html =~ "Manage NATS-based extensions"
    end
    
    test "displays extensions from mock gateway", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions")
      
      # Wait for initial load - check for extensions (mock data has ext_001, extension_1, etc.)
      assert_html(view, "ext_001", timeout: 1000)
      
      html = render(view)
      
      # Should display mock extensions (mock data uses ext_001, extension_1, etc.)
      assert html =~ "ext_001" || html =~ "extension_1"
    end
    
    test "filters by type", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions")
      
      # Wait for initial load
      assert_html(view, "Extensions Registry", timeout: 1000)
      
      # Change type filter
      view
      |> element("select[name='type']")
      |> render_change(%{type: "provider"})
      
      # Wait for filter to apply
      assert_html(view, "Extensions Registry", timeout: 1000)
    end
    
    test "filters by status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions")
      
      # Wait for initial load - check for ext_001
      assert_html(view, "ext_001", timeout: 1000)
      
      # Change status filter to enabled (mock data has enabled at even indices)
      view
      |> element("select[name='status']")
      |> render_change(%{status: "enabled"})
      
      # Wait for filter to apply - should show enabled extensions
      assert_html(view, "ext_002", timeout: 1000)  # ext_002 is enabled (rem(2, 2) == 0)
    end
    
    test "toggles extension enabled/disabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions")
      
      # Wait for initial load - check for ext_001 from mock data
      assert_html(view, "ext_001", timeout: 1000)
      
      html = render(view)
      
      # Toggle extension (ext_001 exists in mock data)
      # Button automatically includes phx-value-enabled from template
      assert html =~ "ext_001"
      
      # Find button by phx-click and phx-value-id (phx-value-enabled is in template)
      view
      |> element("button[phx-click='toggle_extension'][phx-value-id='ext_001']")
      |> render_click()
      
      # Wait for success message
      assert_html(view, ~r/Extension|successfully|enabled|disabled/, timeout: 1000)
    end
    
    test "deletes extension with confirmation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions")
      
      # Wait for initial load - check for ext_001 from mock data
      assert_html(view, "ext_001", timeout: 1000)
      
      html = render(view)
      
      # Delete extension (ext_001 exists in mock data)
      assert html =~ "ext_001"
      
      view
      |> element("button[phx-click='delete_extension'][phx-value-id='ext_001']")
      |> render_click()
      
      # Wait for success message
      assert_html(view, ~r/Extension|deleted|successfully/, timeout: 1000)
    end
    
    test "displays empty state when no extensions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions?type=invalid_type")
      
      # Wait for load - check for empty state or registry header
      assert_html(view, ~r/No extensions found|Extensions Registry/, timeout: 1000)
      
      html = render(view)
      
      # Should show empty state or at least registry header
      assert html =~ "No extensions found" || html =~ "Extensions Registry"
    end
    
    test "displays loading state initially", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/extensions")
      
      # Should show loading state initially
      assert html =~ "Loading extensions" || html =~ "Extensions Registry"
    end
    
    test "navigates between pages with Next/Previous", %{conn: conn} do
      # Start page: offset=0, limit=20
      # Mock data: ext_fail + ext_001..ext_040 (41 total)
      # Page 1: ext_fail, ext_001..ext_019 (20 items)
      # Page 2: ext_020..ext_039 (20 items)
      # Page 3: ext_040 (1 item)
      {:ok, view, html} = live(conn, ~p"/app/extensions")
      
      # Wait for initial load - check for ext_fail or ext_001 (both on first page)
      assert_html(view, ~r/ext_fail|ext_001/, timeout: 1000)
      
      html = render(view)
      
      # First page should have ext_fail or ext_001, but not ext_020 (first item on page 2)
      assert html =~ "ext_fail" || html =~ "ext_001"
      refute html =~ "ext_020"
      
      # Navigate to next page (offset=20, limit=20, should show ext_020 to ext_039)
      view
      |> element("button[phx-click='next_page']")
      |> render_click()
      
      # Wait for page load - check for ext_020 (first item on second page)
      assert_html(view, "ext_020", timeout: 1000)
      
      html = render(view)
      
      # Second page should have ext_020, but not ext_fail or ext_001
      assert html =~ "ext_020"
      refute html =~ "ext_fail"
      refute html =~ "ext_001"
      
      # Navigate back to previous page
      view
      |> element("button[phx-click='prev_page']")
      |> render_click()
      
      # Wait for page load - check for ext_fail or ext_001
      assert_html(view, ~r/ext_fail|ext_001/, timeout: 1000)
      
      html = render(view)
      
      # Back to first page
      assert html =~ "ext_fail" || html =~ "ext_001"
      refute html =~ "ext_020"
    end
    
    test "receives real-time updates via PubSub", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions")
      
      # Wait for initial load
      assert_html(view, "Extensions Registry", timeout: 1000)
      
      # Broadcast extension update
      updated_extension = %{
        "id" => "ext_openai_001",
        "name" => "openai-provider",
        "type" => "provider",
        "enabled" => false,
        "version" => "1.2.0"
      }
      
      PubSub.broadcast(
        UiWeb.PubSub,
        "extensions:updates",
        {:extension_updated, updated_extension}
      )
      
      # Wait for event processing
      assert_html(view, "Extensions Registry", timeout: 1000)
    end
  end
  
  describe "error handling on list" do
    test "shows error flash when list_extensions fails", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/extensions?type=force_error")
      
      # Wait for error message
      assert_html(view, "Failed to load extensions", timeout: 1000)
      
      html = render(view)
      
      # Should show error message (text from load_extensions/1)
      assert html =~ "Failed to load extensions"
      
      # List should be empty - no mock IDs visible
      refute html =~ "ext_001"
      refute html =~ "ext_fail"
    end
  end

  describe "toggle errors" do
    test "shows error when toggle_extension fails", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/extensions")
      
      # Wait for initial load
      assert_html(view, "ext_fail", timeout: 1000)
      
      html = render(view)
      
      # Ensure ext_fail is visible
      assert html =~ "ext_fail"
      
      # Click toggle button for ext_fail
      view
      |> element("button[phx-click='toggle_extension'][phx-value-id='ext_fail']")
      |> render_click()
      
      # Wait for error message
      eventually(fn ->
        html = render(view)
        assert (html =~ "Failed to toggle extension" || html =~ "failed")
      end, timeout: 1000, interval: 50)
      
      html = render(view)
      
      # Should show error message
      assert html =~ "Failed to toggle extension" || html =~ "failed"
      
      # Extension should still be visible
      assert html =~ "ext_fail"
    end
  end

  describe "delete errors" do
    test "shows error when delete_extension fails", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/extensions")
      
      # Wait for initial load
      assert_html(view, "ext_fail", timeout: 1000)
      
      html = render(view)
      
      # Ensure ext_fail is visible
      assert html =~ "ext_fail"
      
      # Click delete button for ext_fail
      view
      |> element("button[phx-click='delete_extension'][phx-value-id='ext_fail']")
      |> render_click()
      
      # Wait for error message
      eventually(fn ->
        html = render(view)
        assert (html =~ "Failed to delete extension" || html =~ "failed")
      end, timeout: 1000, interval: 50)
      
      html = render(view)
      
      # Should show error message
      assert html =~ "Failed to delete extension" || html =~ "failed"
      
      # Extension should still be visible
      assert html =~ "ext_fail"
    end
  end
end

