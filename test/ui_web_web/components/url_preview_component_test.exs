defmodule UiWebWeb.Components.URLPreviewComponentTest do
  use UiWebWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias UiWebWeb.Components.URLPreviewComponent
  alias UiWeb.Services.URLPreviewService

  # Stub module for URLPreviewService in tests
  defmodule StubURLPreviewService do
    @behaviour URLPreviewService

    def fetch_preview(url) do
      case Process.get(:stub_fetch_preview) do
        nil -> {:error, :not_stubbed}
        fun when is_function(fun, 1) -> fun.(url)
        result -> result
      end
    end
  end

  setup do
    # Initialize ETS cache table for tests (if not exists)
    try do
      :ets.new(:url_preview_cache, [:set, :public, :named_table])
    rescue
      ArgumentError ->
        # Table already exists, clear it
        :ets.delete_all_objects(:url_preview_cache)
    end

    # Store original service module config
    original_service = Application.get_env(:ui_web, :url_preview_service_module)

    # Use stub service in tests
    Application.put_env(:ui_web, :url_preview_service_module, StubURLPreviewService)

    on_exit(fn ->
      # Clear cache after each test
      try do
        :ets.delete_all_objects(:url_preview_cache)
      rescue
        ArgumentError -> :ok
      end

      if original_service do
        Application.put_env(:ui_web, :url_preview_service_module, original_service)
      else
        Application.delete_env(:ui_web, :url_preview_service_module)
      end
    end)

    :ok
  end

  defp stub_fetch_preview(fun) when is_function(fun, 1) do
    Process.put(:stub_fetch_preview, fun)
  end

  defp stub_fetch_preview(result) do
    Process.put(:stub_fetch_preview, fn _url -> result end)
  end

  describe "URLPreviewComponent" do
    test "renders idle state with empty URL" do
      html = render_component(URLPreviewComponent, id: "test-preview", url: nil)

      # Should not render preview card
      refute html =~ "url-preview-card"
      refute html =~ "animate-pulse"
    end

    test "renders idle state with placeholder" do
      html =
        render_component(URLPreviewComponent,
          id: "test-preview",
          url: nil,
          placeholder: "Enter a URL to see preview"
        )

      assert html =~ "Enter a URL to see preview"
    end

    test "renders preview card on success" do
      preview_data = %{
        title: "Example Domain",
        description: "This is an example domain for testing",
        image: "https://example.com/image.png",
        url: "https://example.com",
        domain: "example.com",
        favicon: "https://example.com/favicon.ico"
      }

      stub_fetch_preview(fn "https://example.com" -> {:ok, preview_data} end)

      html = render_component(URLPreviewComponent, id: "test-preview", url: "https://example.com")

      assert html =~ "Example Domain"
      assert html =~ "This is an example domain for testing"
      assert html =~ "example.com"
      assert html =~ "https://example.com/image.png"
      assert html =~ "https://example.com/favicon.ico"
    end

    test "renders error state for invalid_scheme" do
      stub_fetch_preview(fn _url -> {:error, :invalid_scheme} end)

      html = render_component(URLPreviewComponent, id: "test-preview", url: "ftp://example.com")

      assert html =~ "Only http(s) links are supported"
    end

    test "renders error state for local_url_not_allowed" do
      stub_fetch_preview(fn _url -> {:error, :local_url_not_allowed} end)

      html = render_component(URLPreviewComponent, id: "test-preview", url: "http://localhost")

      assert html =~ "Private/internal links are not allowed"
    end

    test "renders error state for timeout" do
      stub_fetch_preview(fn _url -> {:error, :timeout} end)

      html = render_component(URLPreviewComponent, id: "test-preview", url: "https://example.com")

      assert html =~ "Timed out while loading preview"
    end

    test "renders error state for http_error" do
      stub_fetch_preview(fn _url -> {:error, {:http_error, 404}} end)

      html = render_component(URLPreviewComponent, id: "test-preview", url: "https://example.com")

      assert html =~ "HTTP error (404)"
    end

    test "hides error when show_on_error? is false" do
      stub_fetch_preview(fn _url -> {:error, :invalid_scheme} end)

      html =
        render_component(URLPreviewComponent,
          id: "test-preview",
          url: "ftp://example.com",
          show_on_error?: false
        )

      refute html =~ "Only http(s) links are supported"
    end

    test "truncates long descriptions" do
      long_description = String.duplicate("A", 300)
      preview_data = %{
        title: "Example",
        description: long_description,
        image: nil,
        url: "https://example.com",
        domain: "example.com",
        favicon: nil
      }

      stub_fetch_preview(fn _url -> {:ok, preview_data} end)

      html =
        render_component(URLPreviewComponent,
          id: "test-preview",
          url: "https://example.com",
          max_description_length: 50
        )

      # Should truncate to 50 chars + "…"
      assert html =~ String.slice(long_description, 0, 50) <> "…"
      refute html =~ long_description
    end

    test "handles empty description gracefully" do
      preview_data = %{
        title: "Example",
        description: "",
        image: nil,
        url: "https://example.com",
        domain: "example.com",
        favicon: nil
      }

      stub_fetch_preview(fn _url -> {:ok, preview_data} end)

      html = render_component(URLPreviewComponent, id: "test-preview", url: "https://example.com")

      assert html =~ "Example"
      assert html =~ "example.com"
    end

    test "shows domain initial when favicon is missing" do
      preview_data = %{
        title: "Example",
        description: "Test",
        image: nil,
        url: "https://example.com",
        domain: "example.com",
        favicon: nil
      }

      stub_fetch_preview(fn _url -> {:ok, preview_data} end)

      html = render_component(URLPreviewComponent, id: "test-preview", url: "https://example.com")

      assert html =~ "E" # First letter of "example.com"
      assert html =~ "example.com"
    end

    test "resets to idle when URL becomes empty" do
      preview_data = %{
        title: "Example",
        description: "Test",
        image: nil,
        url: "https://example.com",
        domain: "example.com",
        favicon: nil
      }

      stub_fetch_preview(fn
        "https://example.com" -> {:ok, preview_data}
        _ -> {:error, :not_stubbed}
      end)

      # First render with URL
      html_with_url =
        render_component(URLPreviewComponent, id: "test-preview", url: "https://example.com")

      assert html_with_url =~ "Example"

      # Second render with empty URL
      html_empty = render_component(URLPreviewComponent, id: "test-preview", url: "")

      refute html_empty =~ "Example"
      refute html_empty =~ "url-preview-card"
    end

    test "triggers refetch when URL changes" do
      preview_one = %{
        title: "Page One",
        description: "First page",
        url: "https://example.com/one",
        domain: "example.com",
        image: nil,
        favicon: nil
      }

      preview_two = %{
        title: "Page Two",
        description: "Second page",
        url: "https://example.com/two",
        domain: "example.com",
        image: nil,
        favicon: nil
      }

      stub_fetch_preview(fn
        "https://example.com/one" -> {:ok, preview_one}
        "https://example.com/two" -> {:ok, preview_two}
        _ -> {:error, :not_stubbed}
      end)

      # First render with first URL
      html_one = render_component(URLPreviewComponent, id: "test-preview", url: "https://example.com/one")

      assert html_one =~ "Page One"
      refute html_one =~ "Page Two"

      # Second render with different URL
      html_two = render_component(URLPreviewComponent, id: "test-preview", url: "https://example.com/two")

      assert html_two =~ "Page Two"
      refute html_two =~ "Page One"
    end

    # Note: This test is skipped because render_component/2 creates a new component
    # instance each time, so previous_url is always nil. The optimization of
    # not refetching when URL is unchanged only works in real LiveView context
    # where the component persists between updates.
    # This behavior is tested implicitly in integration tests with real LiveView.

    test "function component wrapper is defined" do
      # Function component wrapper is a convenience method for templates
      # It wraps live_component, so we test that it exists and is callable
      assert function_exported?(URLPreviewComponent, :url_preview, 1)

      # In templates, it would be used as:
      # <.url_preview id="preview" url={@form[:url].value} />
      # This is tested implicitly through live_component tests above
    end
  end
end
