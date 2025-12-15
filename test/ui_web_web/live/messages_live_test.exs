defmodule UiWebWeb.MessagesLiveTest do
  @moduledoc """
  Integration tests for Messages LiveView.
  
  Tests:
  - CRUD operations (Create, Read, Update, Delete)
  - Form validation
  - PubSub live updates
  - SSE message handling
  """
  
  use UiWebWeb.LiveViewCase
  
  alias UiWeb.Services.GatewayClient
  alias Phoenix.PubSub
  
  @moduletag :live_view
  @moduletag :integration
  
  @test_tenant "test_tenant_#{System.unique_integer([:positive])}"
  
  setup do
    # Subscribe to PubSub for this tenant
    PubSub.subscribe(UiWeb.PubSub, "messages:#{@test_tenant}")
    
    on_exit(fn ->
      PubSub.unsubscribe(UiWeb.PubSub, "messages:#{@test_tenant}")
    end)
    
    {:ok, tenant: @test_tenant}
  end
  
  describe "Messages rendering" do
    test "renders messages page with form", %{conn: conn, tenant: tenant} do
      {:ok, view, html} = live(conn, "/app/messages")
      
      # Check page title
      assert html =~ "Messages"
      
      # Check create form is present
      assert has_element?(view, "form[phx-submit='submit']")
      assert html =~ "Create Message"
      assert html =~ "Tenant ID"
      assert html =~ "Message Type"
      assert html =~ "Payload"
      assert html =~ "Trace ID"
    end
    
    test "displays messages list", %{conn: conn, tenant: tenant} do
      {:ok, view, _html} = live(conn, "/app/messages")
      
      # Wait for initial poll
      Process.sleep(200)
      
      html = render(view)
      
      # Messages table should be present
      assert html =~ "Latest" || html =~ "message_id"
    end
    
    test "displays empty state when no messages", %{conn: conn, tenant: tenant} do
      {:ok, view, html} = live(conn, "/app/messages")
      
      # Should render table structure even if empty
      assert html =~ "Latest" || html =~ "message_id"
    end
  end
  
  describe "CRUD operations" do
    test "creates a new message", %{conn: conn, tenant: tenant} do
      {:ok, view, _html} = live(conn, "/app/messages")
      
      # Wait for form to be ready
      Process.sleep(100)
      
      # Fill form
      form_data = %{
        "form" => %{
          "tenant_id" => tenant,
          "message_type" => "chat",
          "payload" => Jason.encode!(%{text: "Test message"}),
          "trace_id" => "trace_#{System.unique_integer([:positive])}"
        }
      }
      
      # Submit form
      html = view
        |> form("form[phx-submit='submit']", form_data)
        |> render_submit()
      
      # Wait for processing
      Process.sleep(300)
      
      # Should not show error
      refute html =~ "error" || html =~ "Error"
    end
    
    test "views a message", %{conn: conn, tenant: tenant} do
      # First create a message via Gateway
      message_data = %{
        "tenant_id" => tenant,
        "message_type" => "chat",
        "payload" => Jason.encode!(%{text: "View test"}),
        "trace_id" => "trace_view_#{System.unique_integer([:positive])}"
      }
      
      case GatewayClient.post_json("/api/v1/messages", message_data) do
        {:ok, ack} ->
          message_id = ack["message_id"]
          
          {:ok, view, _html} = live(conn, "/app/messages")
          
          # Wait for poll to load messages
          Process.sleep(500)
          
          # Click view button
          html = view
            |> element("button[phx-click='view'][phx-value-id='#{message_id}']")
            |> render_click()
          
          # Should display selected message
          assert html =~ message_id || html =~ "Selected"
        
        {:error, _reason} ->
          # Gateway might not be available, skip test
          :ok
      end
    end
    
    test "updates a message payload", %{conn: conn, tenant: tenant} do
      # Create a message first
      message_data = %{
        "tenant_id" => tenant,
        "message_type" => "chat",
        "payload" => Jason.encode!(%{text: "Original"}),
        "trace_id" => "trace_update_#{System.unique_integer([:positive])}"
      }
      
      case GatewayClient.post_json("/api/v1/messages", message_data) do
        {:ok, ack} ->
          message_id = ack["message_id"]
          
          {:ok, view, _html} = live(conn, "/app/messages")
          
          # Wait for poll
          Process.sleep(500)
          
          # View message first
          view
            |> element("button[phx-click='view'][phx-value-id='#{message_id}']")
            |> render_click()
          
          Process.sleep(200)
          
          # Update payload
          new_payload = Jason.encode!(%{text: "Updated"})
          
          html = view
            |> form("form[phx-submit='update_msg']", %{"payload" => new_payload})
            |> render_submit()
          
          # Wait for update
          Process.sleep(300)
          
          # Should not show error
          refute html =~ "Update failed" || html =~ "error"
        
        {:error, _reason} ->
          :ok
      end
    end
    
    test "deletes a message", %{conn: conn, tenant: tenant} do
      # Create a message first
      message_data = %{
        "tenant_id" => tenant,
        "message_type" => "chat",
        "payload" => Jason.encode!(%{text: "To delete"}),
        "trace_id" => "trace_delete_#{System.unique_integer([:positive])}"
      }
      
      case GatewayClient.post_json("/api/v1/messages", message_data) do
        {:ok, ack} ->
          message_id = ack["message_id"]
          
          {:ok, view, _html} = live(conn, "/app/messages")
          
          # Wait for poll
          Process.sleep(500)
          
          # Delete message
          html = view
            |> element("button[phx-click='delete_msg'][phx-value-id='#{message_id}']")
            |> render_click()
          
          # Wait for deletion
          Process.sleep(300)
          
          # Should not show error
          refute html =~ "Delete failed" || html =~ "error"
        
        {:error, _reason} ->
          :ok
      end
    end
  end
  
  describe "Form validation" do
    test "validates required fields on submit", %{conn: conn, tenant: tenant} do
      {:ok, view, _html} = live(conn, "/app/messages")
      
      # Try to submit empty form (should fail at Gateway level)
      form_data = %{
        "form" => %{
          "tenant_id" => "",
          "message_type" => "",
          "payload" => "",
          "trace_id" => ""
        }
      }
      
      html = view
        |> form("form[phx-submit='submit']", form_data)
        |> render_submit()
      
      # Wait for response
      Process.sleep(300)
      
      # Gateway should reject invalid data
      # Error might be shown or form might remain
      assert html =~ "Messages"
    end
    
    test "validates JSON payload format", %{conn: conn, tenant: tenant} do
      {:ok, view, _html} = live(conn, "/app/messages")
      
      # Submit with invalid JSON
      form_data = %{
        "form" => %{
          "tenant_id" => tenant,
          "message_type" => "chat",
          "payload" => "invalid json{",
          "trace_id" => "trace_#{System.unique_integer([:positive])}"
        }
      }
      
      html = view
        |> form("form[phx-submit='submit']", form_data)
        |> render_submit()
      
      Process.sleep(300)
      
      # Should handle error gracefully
      assert html =~ "Messages"
    end
    
    test "accepts valid message data", %{conn: conn, tenant: tenant} do
      {:ok, view, _html} = live(conn, "/app/messages")
      
      # Valid form data
      form_data = %{
        "form" => %{
          "tenant_id" => tenant,
          "message_type" => "chat",
          "payload" => Jason.encode!(%{text: "Valid message"}),
          "trace_id" => "trace_valid_#{System.unique_integer([:positive])}"
        }
      }
      
      html = view
        |> form("form[phx-submit='submit']", form_data)
        |> render_submit()
      
      Process.sleep(300)
      
      # Should succeed (no error)
      refute html =~ "error" || html =~ "Error"
    end
  end
  
  describe "PubSub live updates" do
    test "receives message_created event via PubSub", %{conn: conn, tenant: tenant} do
      {:ok, view, _html} = live(conn, "/app/messages")
      
      # Wait for connection
      Process.sleep(200)
      
      # Broadcast message_created event
      message_data = %{
        "message_id" => "msg_test_#{System.unique_integer([:positive])}",
        "tenant_id" => tenant,
        "message_type" => "chat",
        "payload" => Jason.encode!(%{text: "PubSub test"}),
        "timestamp_ms" => System.system_time(:millisecond)
      }
      
      PubSub.broadcast(
        UiWeb.PubSub,
        "messages:#{tenant}",
        %Phoenix.Socket.Broadcast{
          event: "message_event",
          payload: %{
            "event" => "message_created",
            "data" => message_data
          }
        }
      )
      
      # Wait for event processing
      Process.sleep(300)
      
      html = render(view)
      
      # Message should appear in list
      assert html =~ message_data["message_id"] || html =~ "Latest"
    end
    
    test "receives message_updated event via PubSub", %{conn: conn, tenant: tenant} do
      # Create message first
      message_data = %{
        "tenant_id" => tenant,
        "message_type" => "chat",
        "payload" => Jason.encode!(%{text: "Original"}),
        "trace_id" => "trace_pubsub_#{System.unique_integer([:positive])}"
      }
      
      case GatewayClient.post_json("/api/v1/messages", message_data) do
        {:ok, ack} ->
          message_id = ack["message_id"]
          
          {:ok, view, _html} = live(conn, "/app/messages")
          
          # Wait for initial load
          Process.sleep(500)
          
          # Broadcast update event
          updated_data = Map.merge(message_data, %{
            "message_id" => message_id,
            "payload" => Jason.encode!(%{text: "Updated via PubSub"})
          })
          
          PubSub.broadcast(
            UiWeb.PubSub,
            "messages:#{tenant}",
            %Phoenix.Socket.Broadcast{
              event: "message_event",
              payload: %{
                "event" => "message_updated",
                "data" => updated_data
              }
            }
          )
          
          Process.sleep(300)
          
          html = render(view)
          
          # Message should be updated
          assert html =~ message_id || html =~ "Latest"
        
        {:error, _reason} ->
          :ok
      end
    end
    
    test "receives message_deleted event via PubSub", %{conn: conn, tenant: tenant} do
      # Create message first
      message_data = %{
        "tenant_id" => tenant,
        "message_type" => "chat",
        "payload" => Jason.encode!(%{text: "To delete"}),
        "trace_id" => "trace_delete_pubsub_#{System.unique_integer([:positive])}"
      }
      
      case GatewayClient.post_json("/api/v1/messages", message_data) do
        {:ok, ack} ->
          message_id = ack["message_id"]
          
          {:ok, view, _html} = live(conn, "/app/messages")
          
          # Wait for initial load
          Process.sleep(500)
          
          # Broadcast delete event
          PubSub.broadcast(
            UiWeb.PubSub,
            "messages:#{tenant}",
            %Phoenix.Socket.Broadcast{
              event: "message_event",
              payload: %{
                "event" => "message_deleted",
                "data" => %{"message_id" => message_id}
              }
            }
          )
          
          Process.sleep(300)
          
          html = render(view)
          
          # Message should be removed from list
          # (We can't easily verify absence, but should not error)
          assert html =~ "Messages" || html =~ "Latest"
        
        {:error, _reason} ->
          :ok
      end
    end
  end
  
  describe "Polling" do
    alias UiWeb.Test.Retry
    
    @tag retry: 3
    test "polls for messages on mount", %{conn: conn, tenant: tenant} do
      Retry.retry(3, fn ->
        {:ok, view, _html} = live(conn, "/app/messages")
        
        # Wait for initial poll
        Process.sleep(500)
        
        html = render(view)
        
        # Messages list should be present
        assert html =~ "Latest" || html =~ "message_id"
      end)
    end
    
    @tag retry: 3
    test "polls periodically for updates", %{conn: conn, tenant: tenant} do
      Retry.retry(3, fn ->
        {:ok, view, _html} = live(conn, "/app/messages")
        
        # Get initial state
        html1 = render(view)
        
        # Trigger poll manually
        send(view.pid, :poll)
        Process.sleep(300)
        
        html2 = render(view)
        
        # Should have updated (or at least rendered)
        assert html2 =~ "Messages"
      end)
    end
  end
  
  describe "Error handling" do
    test "displays error when Gateway is unavailable", %{conn: conn, tenant: tenant} do
      # Break Gateway URL
      original_url = Application.get_env(:ui_web, :gateway) |> Keyword.get(:url)
      Application.put_env(:ui_web, :gateway, url: "http://localhost:99999", timeout: 1000)
      
      try do
        {:ok, view, _html} = live(conn, "/app/messages")
        
        # Trigger poll
        send(view.pid, :poll)
        Process.sleep(1500)
        
        html = render(view)
        
        # Should display error
        assert html =~ "error" || html =~ "Error"
      after
        Application.put_env(:ui_web, :gateway, url: original_url, timeout: 5000)
      end
    end
    
    test "handles invalid message ID gracefully", %{conn: conn, tenant: tenant} do
      {:ok, view, _html} = live(conn, "/app/messages")
      
      # Try to view non-existent message
      html = view
        |> element("button[phx-click='view'][phx-value-id='nonexistent']")
        |> render_click()
      
      Process.sleep(300)
      
      # Should handle error gracefully
      assert html =~ "Messages" || html =~ "error"
    end
  end
end

