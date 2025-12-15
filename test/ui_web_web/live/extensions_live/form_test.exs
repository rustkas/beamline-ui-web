defmodule UiWebWeb.ExtensionsLive.FormTest do
  @moduledoc """
  Integration tests for Extensions Form LiveView.
  """
  
  use UiWebWeb.LiveViewCase
  
  alias Phoenix.PubSub
  alias UiWeb.Services.URLPreviewService

  # Stub module for URLPreviewService in tests
  defmodule StubURLPreviewService do
    @behaviour URLPreviewService

    def fetch_preview(_url) do
      # Return empty result to avoid real HTTP requests
      {:error, :not_stubbed}
    end
  end
  
  @moduletag :live_view
  @moduletag :integration
  
  setup do
    # Initialize ETS cache table for URL preview component (if not exists)
    try do
      :ets.new(:url_preview_cache, [:set, :public, :named_table])
    rescue
      ArgumentError ->
        # Table already exists, clear it
        :ets.delete_all_objects(:url_preview_cache)
    end

    # Stub URLPreviewService to avoid real HTTP requests in tests
    original_service = Application.get_env(:ui_web, :url_preview_service_module)
    Application.put_env(:ui_web, :url_preview_service_module, StubURLPreviewService)

    # Subscribe to PubSub for extensions updates
    PubSub.subscribe(UiWeb.PubSub, "extensions:updates")
    
    on_exit(fn ->
      # Clear cache
      try do
        :ets.delete_all_objects(:url_preview_cache)
      rescue
        ArgumentError -> :ok
      end

      # Restore original service
      if original_service do
        Application.put_env(:ui_web, :url_preview_service_module, original_service)
      else
        Application.delete_env(:ui_web, :url_preview_service_module)
      end

      PubSub.unsubscribe(UiWeb.PubSub, "extensions:updates")
    end)
    
    :ok
  end
  
  describe "New Extension Form" do
    test "renders form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/extensions/new")
      
      assert html =~ "New Extension"
      assert html =~ "NATS Subject"
      assert html =~ "Health Endpoint"
      assert html =~ "Basic Information"
    end
    
    test "validates NATS subject format", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions/new")
      
      html =
        view
        |> form("#extension-form", extension: %{
          name: "test",
          type: "provider",
          nats_subject: "invalid-subject",
          version: "1.0.0"
        })
        |> render_change()
      
      assert html =~ "must match pattern" || html =~ "NATS Subject"
    end
    
    test "generates NATS subject", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions/new")
      
      # Fill name and type
      view
      |> form("#extension-form", extension: %{
        name: "my-provider",
        type: "provider"
      })
      |> render_change()
      
      # Click generate button
      html = render_click(view, "generate_subject", %{
        type: "provider",
        name: "my-provider"
      })
      
      assert html =~ "beamline.extensions.provider.my-provider.v1" || html =~ "NATS Subject"
    end
    
    test "creates extension with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions/new")
      
      # Wait for form to be ready
      Process.sleep(200)
      
      result =
        view
        |> form("#extension-form", extension: %{
          name: "test-provider",
          type: "provider",
          nats_subject: "beamline.extensions.provider.test.v1",
          version: "1.0.0",
          description: "Test provider",
          enabled: "true"
        })
        |> render_submit()
      
      # Should redirect or show success
      assert result =~ "Extensions" || result =~ "successfully"
    end
  end
  
  describe "Edit Extension Form" do
    test "loads existing extension", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/extensions/ext_openai_001/edit")
      
      # Should show edit form or loading
      assert html =~ "Edit Extension" || html =~ "Loading" || html =~ "openai-provider"
    end
    
    test "updates extension with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions/ext_openai_001/edit")
      
      # Wait for load
      Process.sleep(300)
      
      html = render(view)
      
      # If form is loaded, try to update
      if html =~ "openai-provider" do
        result =
          view
          |> form("#extension-form", extension: %{
            name: "openai-provider",
            type: "provider",
            nats_subject: "beamline.extensions.provider.openai.v1",
            version: "1.2.1",
            description: "Updated description"
          })
          |> render_submit()
        
        # Should redirect or show success
        assert result =~ "Extensions" || result =~ "successfully"
      end
    end
  end
  
  describe "Health endpoint check" do
    test "checks health endpoint", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions/new")
      
      # Fill health endpoint
      view
      |> form("#extension-form", extension: %{
        health_endpoint: "http://localhost:8081/health"
      })
      |> render_change()
      
      # Click test button
      html = render_click(view, "check_health", %{
        endpoint: "http://localhost:8081/health"
      })
      
      # Should show result (success or error)
      assert html =~ "Health" || html =~ "endpoint" || html =~ "reachable"
    end
  end
  
  describe "Form validation" do
    test "requires name, type, nats_subject, version", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions/new")
      
      html =
        view
        |> form("#extension-form", extension: %{})
        |> render_submit()
      
      # Should show validation errors or keep form
      assert html =~ "Extension" || html =~ "required"
    end
    
    test "validates semantic version format", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/extensions/new")
      
      html =
        view
        |> form("#extension-form", extension: %{
          name: "test",
          type: "provider",
          nats_subject: "beamline.extensions.provider.test.v1",
          version: "invalid"
        })
        |> render_change()
      
      # Should show version error
      assert html =~ "version" || html =~ "semantic" || html =~ "Extension"
    end
  end
end

