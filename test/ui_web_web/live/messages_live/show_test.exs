defmodule UiWebWeb.MessagesLive.ShowTest do
  use UiWebWeb.LiveViewCase

  @moduletag :live_view

  describe "show message" do
    test "renders message details on success", %{conn: conn} do
      message_id = "msg_001"

      {:ok, _view, html} = live(conn, ~p"/app/messages/#{message_id}")

      # Wait for message to load
      Process.sleep(300)

      # Check that message details are displayed
      assert html =~ message_id
      assert html =~ "Message"
      # Check for type and status (from mock_messages)
      assert html =~ "code" || html =~ "chat"
      # Check for Content section
      assert html =~ "Content" || html =~ "content"
    end

    test "redirects with error flash when get_message fails", %{conn: conn} do
      # Use a non-existent ID that will trigger 404
      # When redirect happens, live() returns {:error, {:live_redirect, ...}}
      result = live(conn, ~p"/app/messages/nonexistent")

      # Should redirect to messages list with error flash
      case result do
        {:error, {:live_redirect, %{to: path, flash: flash}}} ->
          assert path == "/app/messages"
          assert Map.has_key?(flash, "error")
          assert flash["error"] =~ "Failed to load message"

        {:ok, view, _html} ->
          # If no redirect happened immediately, wait and check
          Process.sleep(300)
          # push_navigate doesn't create a patch, so we check the flash instead
          html = render(view)
          assert html =~ "Failed to load message" || html =~ "error"
      end
    end

    test "handles Gateway error gracefully", %{conn: conn} do
      # Use a non-existent ID that will trigger 404
      result = live(conn, ~p"/app/messages/bad_id_404")

      # Should redirect with error message
      case result do
        {:error, {:live_redirect, %{to: path, flash: flash}}} ->
          assert path == "/app/messages"
          assert Map.has_key?(flash, "error")

        {:ok, view, _html} ->
          Process.sleep(300)
          # push_navigate doesn't create a patch, so we check the flash instead
          html = render(view)
          assert html =~ "Failed to load message" || html =~ "error"
      end
    end
  end
end

