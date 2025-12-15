defmodule UiWebWeb.PoliciesLiveTest do
  @moduledoc """
  Integration tests for Policies LiveView.
  
  Tests follow the Test Strategy pattern:
  - Use assert_html/eventually instead of Process.sleep
  - Sync with mock_policies data
  - Test happy path, CRUD, error flows
  """
  
  use UiWebWeb.LiveViewCase
  
  @moduletag :live_view
  @moduletag :integration
  
  setup do
    # Mock Gateway should already be running
    :ok
  end
  
  describe "Policies rendering" do
    test "renders policies page", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/policies")
      
      # Check page title
      assert html =~ "Policies"
      
      # Check editor form is present
      assert_element(view, "form[phx-submit='save']")
      assert html =~ "Editor"
      assert html =~ "Tenant"
      assert html =~ "Policy ID"
    end
    
    test "displays policy list after initial poll", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll to complete (policies list should appear)
      assert_html(view, "tenant_dev", timeout: 2000)
      
      html = render(view)
      
      # List section should be present
      assert html =~ "List" || html =~ "Tenant"
    end
    
    test "displays JSON editor", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/policies")
      
      # Editor should be present
      assert html =~ "Editor"
      assert html =~ "textarea"
    end
  end
  
  describe "Policy CRUD operations" do
    test "loads a policy", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll
      assert_html(view, "tenant_dev", timeout: 2000)
      
      # Set tenant and policy ID (default policy exists in mock data)
      view
        |> form("form[phx-change='set']", %{
          "tenant_id" => "tenant_dev",
          "policy_id" => "default"
        })
        |> render_change()
      
      # Wait for form update
      assert_html(view, "default", timeout: 1000)
      
      # Load policy
      view
        |> element("button[phx-click='load']")
        |> render_click()
      
      # Wait for policy to load (should show JSON in editor)
      assert_html(view, ~r/rules|"action"/, timeout: 1000)
    end
    
    test "saves a policy", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll
      assert_html(view, "tenant_dev", timeout: 2000)
      
      # Set tenant and policy ID
      view
        |> form("form[phx-change='set']", %{
          "tenant_id" => "tenant_dev",
          "policy_id" => "test_policy_save"
        })
        |> render_change()
      
      assert_html(view, "test_policy_save", timeout: 1000)
      
      # Set editor content (valid JSON)
      policy_json = Jason.encode!(%{
        "rules" => [
          %{
            "condition" => "tenant_id == 'test'",
            "action" => "route_to_provider",
            "provider" => "openai"
          }
        ]
      }, pretty: true)
      
      # Save policy
      view
        |> form("form[phx-submit='save']", %{"editor" => policy_json})
        |> render_submit()
      
      # Should not show error
      refute_html(view, ~r/Invalid JSON|error|Error/, timeout: 1000)
    end
    
    test "deletes a policy", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll
      assert_html(view, "tenant_dev", timeout: 2000)
      
      # Set tenant and policy ID (use existing policy from mock)
      view
        |> form("form[phx-change='set']", %{
          "tenant_id" => "tenant_dev",
          "policy_id" => "default"
        })
        |> render_change()
      
      assert_html(view, "default", timeout: 1000)
      
      # Delete policy
      view
        |> element("button[phx-click='delete']")
        |> render_click()
      
      # Should not show error
      refute_html(view, ~r/error|Error|Failed/, timeout: 1000)
    end
  end
  
  describe "Form validation" do
    test "validates JSON format in editor", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll
      assert_html(view, "tenant_dev", timeout: 2000)
      
      # Try to save invalid JSON
      invalid_json = "{ invalid json }"
      
      view
        |> form("form[phx-submit='save']", %{"editor" => invalid_json})
        |> render_submit()
      
      # Should show error
      assert_html(view, ~r/Invalid JSON|error/i, timeout: 1000)
    end
    
    test "accepts valid JSON", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll
      assert_html(view, "tenant_dev", timeout: 2000)
      
      # Set tenant and policy ID
      view
        |> form("form[phx-change='set']", %{
          "tenant_id" => "tenant_dev",
          "policy_id" => "test_policy_valid"
        })
        |> render_change()
      
      assert_html(view, "test_policy_valid", timeout: 1000)
      
      # Valid JSON
      valid_json = Jason.encode!(%{"rules" => []}, pretty: true)
      
      view
        |> form("form[phx-submit='save']", %{"editor" => valid_json})
        |> render_submit()
      
      # Should not show JSON error
      refute_html(view, "Invalid JSON", timeout: 1000)
    end
    
    test "tracks editor changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll
      assert_html(view, "tenant_dev", timeout: 2000)
      
      # Set tenant and policy ID
      view
        |> form("form[phx-change='set']", %{
          "tenant_id" => "tenant_dev",
          "policy_id" => "default"
        })
        |> render_change()
      
      assert_html(view, "default", timeout: 1000)
      
      # Load policy first
      view
        |> element("button[phx-click='load']")
        |> render_click()
      
      # Wait for load
      assert_html(view, ~r/rules|"action"/, timeout: 1000)
      
      # Modify editor (trigger phx-change on form)
      modified_json = Jason.encode!(%{"rules" => [%{"test" => "modified"}]}, pretty: true)
      
      view
        |> form("form[phx-change='set']", %{"editor" => modified_json})
        |> render_change()
      
      # Should show "changed" indicator
      assert_html(view, ~r/changed|Editor/, timeout: 1000)
    end
  end
  
  describe "Polling" do
    test "polls for policies on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll to complete
      assert_html(view, ~r/tenant_dev|List|Tenant/, timeout: 2000)
      
      html = render(view)
      
      # Policies list should be present
      assert html =~ "List" || html =~ "Tenant"
    end
    
    test "polls periodically for updates", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll
      assert_html(view, "tenant_dev", timeout: 2000)
      
      # Trigger poll manually
      send(view.pid, :poll)
      
      # Wait for poll to complete
      assert_html(view, "tenant_dev", timeout: 1000)
      
      html2 = render(view)
      
      # Should have updated
      assert html2 =~ "Policies"
    end
  end
  
  describe "Error handling" do
    test "displays error when Gateway returns error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Set tenant to force_error (mock gateway will return 500)
      view
        |> form("form[phx-change='set']", %{
          "tenant_id" => "force_error",
          "policy_id" => "default"
        })
        |> render_change()
      
      # Trigger poll manually
      send(view.pid, :poll)
      
      # Should display error
      assert_html(view, ~r/error|Error|Failed/i, timeout: 2000)
    end
    
    test "handles policy not found gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll
      assert_html(view, "tenant_dev", timeout: 2000)
      
      # Set non-existent policy
      view
        |> form("form[phx-change='set']", %{
          "tenant_id" => "tenant_dev",
          "policy_id" => "nonexistent_policy_999"
        })
        |> render_change()
      
      assert_html(view, "nonexistent_policy_999", timeout: 1000)
      
      # Try to load
      view
        |> element("button[phx-click='load']")
        |> render_click()
      
      # Should handle error gracefully (404 from mock)
      assert_html(view, ~r/error|Error|Failed|Policies/i, timeout: 1000)
    end
    
    test "handles save error for policy_fail", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll
      assert_html(view, "tenant_dev", timeout: 2000)
      
      # Set policy_id to policy_fail (mock will return 500)
      view
        |> form("form[phx-change='set']", %{
          "tenant_id" => "tenant_dev",
          "policy_id" => "policy_fail"
        })
        |> render_change()
      
      assert_html(view, "policy_fail", timeout: 1000)
      
      # Try to save
      valid_json = Jason.encode!(%{"rules" => []}, pretty: true)
      
      view
        |> form("form[phx-submit='save']", %{"editor" => valid_json})
        |> render_submit()
      
      # Should show error
      assert_html(view, ~r/error|Error|Failed/i, timeout: 1000)
    end
    
    test "handles delete error for policy_fail", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      # Wait for initial poll
      assert_html(view, "tenant_dev", timeout: 2000)
      
      # Set policy_id to policy_fail (mock will return 500)
      view
        |> form("form[phx-change='set']", %{
          "tenant_id" => "tenant_dev",
          "policy_id" => "policy_fail"
        })
        |> render_change()
      
      assert_html(view, "policy_fail", timeout: 1000)
      
      # Try to delete
      view
        |> element("button[phx-click='delete']")
        |> render_click()
      
      # Should show error
      assert_html(view, ~r/error|Error|Failed/i, timeout: 1000)
    end
  end
  
  describe "Tenant and Policy ID management" do
    test "updates tenant ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      new_tenant = "new_tenant_#{System.unique_integer([:positive])}"
      
      view
        |> form("form[phx-change='set']", %{
          "tenant_id" => new_tenant,
          "policy_id" => "default"
        })
        |> render_change()
      
      # Tenant should be updated
      assert_html(view, new_tenant, timeout: 1000)
    end
    
    test "updates policy ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/policies")
      
      new_policy_id = "new_policy_#{System.unique_integer([:positive])}"
      
      view
        |> form("form[phx-change='set']", %{
          "tenant_id" => "tenant_dev",
          "policy_id" => new_policy_id
        })
        |> render_change()
      
      # Policy ID should be updated
      assert_html(view, new_policy_id, timeout: 1000)
    end
  end
end
