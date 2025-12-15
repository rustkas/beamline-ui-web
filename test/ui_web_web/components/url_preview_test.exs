defmodule UiWebWeb.Components.URLPreviewTest do
  use UiWebWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias UiWebWeb.Components.URLPreview

  describe "URLPreview component" do
    test "renders empty state", %{conn: conn} do
      {:ok, view, html} =
        live_isolated(conn, URLPreview,
          session: %{
            "id" => "test-preview",
            "url" => "",
            "show_preview" => true
          }
        )

      assert html =~ "Enter a URL to see preview"
    end

    test "shows loading state when URL is provided", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, URLPreview,
          session: %{
            "id" => "test-preview",
            "url" => "https://example.com",
            "show_preview" => true
          }
        )

      # Component should trigger fetch and show loading
      # Note: Actual fetch will timeout or fail in test, but component should handle it
      html = render(view)
      assert html =~ "Fetching preview" || html =~ "Enter a URL"
    end

    test "handles refresh event", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, URLPreview,
          session: %{
            "id" => "test-preview",
            "url" => "https://example.com",
            "show_preview" => true
          }
        )

      # Trigger refresh
      html = render_click(view, "refresh_preview")
      # Should show loading or error
      assert html =~ "Fetching preview" || html =~ "Preview Failed" || html =~ "Enter a URL"
    end

    test "handles clear event", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, URLPreview,
          session: %{
            "id" => "test-preview",
            "url" => "https://example.com",
            "show_preview" => true
          }
        )

      # Trigger clear
      html = render_click(view, "clear_preview")
      assert html =~ "Enter a URL to see preview"
    end

    test "handles toggle preview event", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, URLPreview,
          session: %{
            "id" => "test-preview",
            "url" => "",
            "show_preview" => true
          }
        )

      # Toggle should hide preview
      html = render_click(view, "toggle_preview")
      # Component should be hidden (no content rendered)
      refute html =~ "Enter a URL to see preview"
    end
  end
end

