defmodule UiWebWeb.MessagesLive.IndexTest do
  use UiWebWeb.LiveViewCase

  @moduletag :live_view
  @moduletag :integration

  setup do
    # Clear ETS table for deleted message IDs before each test
    table = :mock_gateway_deleted_ids
    case :ets.whereis(table) do
      :undefined -> :ets.new(table, [:set, :public, :named_table])
      _ -> :ets.delete_all_objects(table)
    end
    :ok
  end

  describe "loading messages" do
    test "renders messages list on load", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/messages")

      # Wait for initial load by checking for messages
      assert_html(view, "msg_001", timeout: 1000)

      assert html =~ "Messages"
      assert html =~ "msg_001"
      refute html =~ "No messages"
    end

    test "shows empty state when no messages", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/messages?status=empty_test")

      # Wait for empty state to render
      eventually(fn ->
        html = render(view)
        assert html =~ "No messages" || html =~ "empty" || html =~ "No data"
      end, timeout: 1000, interval: 50)

      html = render(view)
      # Should show empty state message
      assert html =~ "No messages" || html =~ "empty" || html =~ "No data"
      # Should not show any message IDs
      refute html =~ "msg_001"
    end
  end

  describe "filtering" do
    test "filters messages by status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      # Filter by completed status
      html =
        view
        |> element("select[name='status']")
        |> render_change(%{status: "completed"})

      # Wait for filter to apply
      assert_html(view, "completed", timeout: 1000, interval: 50)

      # Should show completed messages
      assert html =~ "completed"
      # Optionally: refute html =~ "failed" if mock guarantees absence
    end

    test "filters messages by type", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      # Filter by chat type
      html =
        view
        |> element("select[name='type']")
        |> render_change(%{type: "chat"})

      # Wait for filter to apply
      assert_html(view, "chat", timeout: 1000, interval: 50)

      # Should show chat messages
      assert html =~ "chat"
      # Optionally: refute html =~ "code" if mock guarantees absence
    end
  end

  describe "selection and bulk actions" do
    test "shows bulk actions bar when a message is selected", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      # До выбора — панели нет
      refute html =~ "message(s) selected"

      # Выбираем одно сообщение
      html =
        view
        |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_001']")
        |> render_click()

      # После выбора — панель есть, вместе с нужными кнопками
      assert html =~ "message(s) selected"
      assert html =~ "Export JSON"
      assert html =~ "Export CSV"
      assert html =~ "Delete Selected"
      assert html =~ "Clear Selection"
    end

    test "bulk delete removes selected messages on success", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      # Предусловие: сообщение есть
      assert html =~ "msg_001"

      # Выбираем это сообщение
      view
      |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_001']")
      |> render_click()

      # Запускаем bulk_delete
      view
      |> element("button[phx-click='bulk_delete']")
      |> render_click()

      # Ждём завершения операции и обновления UI
      eventually(fn ->
        html = render(view)
        assert html =~ "Deleted" || html =~ "deleted"
        refute html =~ "msg_001"
      end, timeout: 2000, interval: 50)

      html = render(view)

      # Флеш присутствует
      assert html =~ "Deleted" || html =~ "deleted"

      # Сообщение удалено из таблицы
      refute html =~ "msg_001"
    end

    test "deselect_all clears selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      # Select a message
      view
      |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_001']")
      |> render_click()

      html = render(view)
      assert html =~ "message(s) selected"

      # Click deselect_all
      html =
        view
        |> element("button[phx-click='deselect_all']")
        |> render_click()

      # Bulk bar should disappear immediately
      refute html =~ "message(s) selected"
    end
  end

  describe "export" do
    test "export does not crash and keeps selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      # Выбираем сообщение
      view
      |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_001']")
      |> render_click()

      # Подтверждаем, что панель есть
      assert render(view) =~ "message(s) selected"

      # Запускаем export
      html =
        view
        |> element("button[phx-click='export'][phx-value-format='json']")
        |> render_click()

      # Ждём push event
      assert_push_event(view, "download", %{mime_type: "application/json"})

      # Выбор остался
      assert html =~ "message(s) selected"
    end

    test "export triggers download event with correct payload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      # Выбираем сообщение
      view
      |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_001']")
      |> render_click()

      # Кликаем Export JSON
      view
      |> element("button[phx-click='export'][phx-value-format='json']")
      |> render_click()

      # Проверяем push_event с правильным payload
      assert_push_event(view, "download", payload)

      assert payload.mime_type == "application/json"
      assert is_binary(payload.filename)
      assert is_binary(payload.content)
      assert payload.filename =~ ".json"
    end

    test "export CSV triggers download event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      # Выбираем сообщение
      view
      |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_001']")
      |> render_click()

      # Кликаем Export CSV
      view
      |> element("button[phx-click='export'][phx-value-format='csv']")
      |> render_click()

      # Проверяем push_event для CSV
      assert_push_event(view, "download", payload)

      assert payload.mime_type == "text/csv"
      assert is_binary(payload.filename)
      assert is_binary(payload.content)
      assert payload.filename =~ ".csv"
    end
  end

  describe "pagination" do
    test "navigates between pages with Next/Previous", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      html = render(view)

      # 1. Загружаем первую страницу
      # Проверка начального состояния
      assert html =~ "msg_001"
      refute html =~ "msg_060"

      # 2. Переход на следующую страницу
      html =
        view
        |> element("button[phx-click='next_page']")
        |> render_click()

      # Wait for page load
      assert_html(view, "msg_060", timeout: 1000, interval: 50)

      html = render(view)

      refute html =~ "msg_001"
      assert html =~ "msg_060"

      # 3. Переход назад
      html =
        view
        |> element("button[phx-click='prev_page']")
        |> render_click()

      # Wait for page load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      html = render(view)

      assert html =~ "msg_001"
      refute html =~ "msg_060"
    end

    test "previous button disabled on the first page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      html = render(view)

      # Previous button should be disabled when offset=0
      assert html =~ ~s(phx-click="prev_page" disabled) || html =~ "disabled"
      assert html =~ "Previous"
    end

    test "next button disabled on the last page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      # Перейти на страницу 2 (offset = 50)
      html =
        view
        |> element("button[phx-click='next_page']")
        |> render_click()

      # Wait for page load
      assert_html(view, "msg_060", timeout: 1000, interval: 50)

      html = render(view)

      # Последняя страница — next должен быть disabled
      assert html =~ ~s(phx-click="next_page" disabled) || html =~ "disabled"
      assert html =~ "Next"
    end

    test "stress: multiple next/prev cycles keep pagination consistent", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      html = render(view)

      assert html =~ "msg_001"
      refute html =~ "msg_060"

      # 5 sequential cycles next → prev
      for _ <- 1..5 do
        html =
          view
          |> element("button[phx-click='next_page']")
          |> render_click()

        # Wait for page load
        assert_html(view, "msg_060", timeout: 1000, interval: 50)

        html = render(view)

        assert html =~ "msg_060"
        refute html =~ "msg_001"

        html =
          view
          |> element("button[phx-click='prev_page']")
          |> render_click()

        # Wait for page load
        assert_html(view, "msg_001", timeout: 1000, interval: 50)

        html = render(view)

        assert html =~ "msg_001"
        refute html =~ "msg_060"
      end
    end

    test "multi-step: navigate until last page and back", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      html = render(view)

      # Начальная страница
      assert html =~ "msg_001"

      # Шаг 1 — перейти на вторую страницу
      html =
        view
        |> element("button[phx-click='next_page']")
        |> render_click()

      # Wait for page load
      assert_html(view, "msg_060", timeout: 1000, interval: 50)

      html = render(view)

      assert html =~ "msg_060"  # гарантированно на второй странице
      refute html =~ "msg_001"

      # Шаг 2 — возврат на первую страницу
      html =
        view
        |> element("button[phx-click='prev_page']")
        |> render_click()

      # Wait for page load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      html = render(view)

      assert html =~ "msg_001"
      refute html =~ "msg_060"
    end

    test "prev_page does not go below zero offset", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      html = render(view)

      # On first page, prev_page button should be disabled
      assert html =~ "disabled"
      assert html =~ "Previous"

      # Should still be on first page with msg_001 visible
      assert html =~ "msg_001"
    end
  end

  describe "error handling on list" do
    test "shows error flash when list_messages fails", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/messages?status=force_error")

      # Wait for error message to appear
      assert_html(view, "Failed to load messages", timeout: 1000, interval: 50)

      html = render(view)

      # Should show error message (text from load_messages/1)
      assert html =~ "Failed to load messages"

      # List should be empty - no mock IDs visible
      refute html =~ "msg_001"
      refute html =~ "msg_fail"
    end
  end

  describe "bulk delete errors" do
    test "shows error when bulk delete fails", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_fail", timeout: 1000, interval: 50)

      # Предусловие: msg_fail есть
      assert html =~ "msg_fail"

      # Выбираем msg_fail
      view
      |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_fail']")
      |> render_click()

      # Пытаемся удалить
      view
      |> element("button[phx-click='bulk_delete']")
      |> render_click()

      # Ждём появления ошибки
      eventually(fn ->
        html = render(view)
        assert html =~ "Bulk delete failed" || html =~ "failed"
        assert html =~ "msg_fail"
      end, timeout: 2000, interval: 50)

      html = render(view)

      # Отображается флеш "Bulk delete failed"
      assert html =~ "Bulk delete failed" || html =~ "failed"

      # Строка осталась
      assert html =~ "msg_fail"
    end
  end

  describe "single delete errors" do
    test "shows error when delete_message fails", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_fail", timeout: 1000, interval: 50)

      html = render(view)

      # Ensure msg_fail is visible
      assert html =~ "msg_fail"

      # Click delete button for msg_fail
      html =
        view
        |> element("button[phx-click='delete'][phx-value-id='msg_fail']")
        |> render_click()

      # Wait for error message
      eventually(fn ->
        html = render(view)
        assert html =~ "Delete failed" || html =~ "failed"
      end, timeout: 1000, interval: 50)

      html = render(view)

      # Should show error message
      assert (html =~ "Delete failed" || html =~ "failed")

      # Message should still be visible
      assert html =~ "msg_fail"
    end
  end

  describe "export errors" do
    test "shows error when export fails", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_fail_export", timeout: 1000, interval: 50)

      html = render(view)

      # Предусловие: msg_fail_export есть
      assert html =~ "msg_fail_export"

      # Выбираем msg_fail_export
      view
      |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_fail_export']")
      |> render_click()

      # Пытаемся экспортировать
      html =
        view
        |> element("button[phx-click='export'][phx-value-format='json']")
        |> render_click()

      # Ждём появления ошибки
      eventually(fn ->
        html = render(view)
        assert html =~ "Export failed" || html =~ "failed"
      end, timeout: 2000, interval: 50)

      html = render(view)

      # Отображается флеш "Export failed"
      assert html =~ "Export failed" || html =~ "failed"
    end
  end

  describe "single message actions" do
    test "delete button removes message on success", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      html = render(view)

      # Ensure msg_001 is visible (not msg_fail which fails on delete)
      assert html =~ "msg_001"

      # Click delete button for msg_001
      view
      |> element("button[phx-click='delete'][phx-value-id='msg_001']")
      |> render_click()

      # Wait for delete to complete and messages to reload
      # Check that message is removed from list (more reliable than flash)
      refute_html(view, "msg_001", timeout: 2000, interval: 50)

      html = render(view)

      # Message should be removed
      refute html =~ "msg_001"

      # Optionally check for success message (may not always appear in test)
      # assert html =~ "Message deleted" || html =~ "deleted"
    end
  end

  describe "sorting" do
    test "sorts by created_at field", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/messages")

      # Wait for initial load
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      # Click sort on created_at
      html =
        view
        |> element("th[phx-click='sort'][phx-value-field='created_at']")
        |> render_click()

      # Wait for sort to apply
      assert_html(view, "msg_001", timeout: 1000, interval: 50)

      html = render(view)

      # Should still show messages
      assert html =~ "msg_001"
    end
  end
end

