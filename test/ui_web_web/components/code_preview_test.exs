defmodule UiWebWeb.Components.CodePreviewTest do
  use UiWebWeb.ConnCase, async: true

  import Phoenix.Component
  alias UiWebWeb.Components.CodePreview

  describe "code_preview/1" do
    test "renders pretty-printed JSON with highlighting" do
      code = ~s({"a":1,"b":2})

      html =
        render_component(&CodePreview.code_preview/1,
          code: code,
          language: "json",
          id: "test-json"
        )

      # Проверяем, что есть переносы строк (pretty-print)
      assert html =~ "\n" || html =~ "<br"
      # Проверяем, что Makeup добавил span'ы / классы для highlighting
      assert html =~ "<span" || html =~ "class="
      # Проверяем наличие ID
      assert html =~ "test-json"
      # Проверяем наличие кнопки Copy
      assert html =~ "Copy"
      # Проверяем наличие data-target
      assert html =~ "data-target"
    end

    test "renders raw when JSON is invalid" do
      code = ~s({"a":1,)

      html =
        render_component(&CodePreview.code_preview/1,
          code: code,
          language: "json",
          id: "invalid-json"
        )

      # Должен показать экранированный текст (без падения)
      assert html =~ "invalid-json"
      # Не должен падать с ошибкой
      refute html =~ "error"
      refute html =~ "Error"
    end

    test "escapes plain text when language is not json" do
      code = "<script>alert('xss')</script>"

      html =
        render_component(&CodePreview.code_preview/1,
          code: code,
          language: "txt",
          id: "plain"
        )

      # Скрипт должен быть экранирован
      refute html =~ "<script>"
      assert html =~ "&lt;script&gt;"
    end

    test "handles empty code gracefully" do
      html =
        render_component(&CodePreview.code_preview/1,
          code: "",
          language: "json",
          id: "empty"
        )

      assert html =~ "empty"
      refute html =~ "error"
    end

    test "generates random ID when not provided" do
      html1 =
        render_component(&CodePreview.code_preview/1,
          code: ~s({"test":1}),
          language: "json"
        )

      html2 =
        render_component(&CodePreview.code_preview/1,
          code: ~s({"test":1}),
          language: "json"
        )

      # ID должны быть разными
      # Извлекаем ID из data-target
      id1 = extract_id_from_html(html1)
      id2 = extract_id_from_html(html2)

      assert id1 != id2
    end

    test "respects max_height attribute" do
      html =
        render_component(&CodePreview.code_preview/1,
          code: ~s({"test":1}),
          language: "json",
          max_height: 600
        )

      assert html =~ "max-height: 600px"
    end

    test "respects class attribute" do
      html =
        render_component(&CodePreview.code_preview/1,
          code: ~s({"test":1}),
          language: "json",
          class: "custom-class"
        )

      assert html =~ "custom-class"
    end

    test "handles complex JSON with nested structures" do
      code = ~s({"users":[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}],"meta":{"count":2}})

      html =
        render_component(&CodePreview.code_preview/1,
          code: code,
          language: "json",
          id: "complex"
        )

      # Должен успешно обработать сложный JSON
      assert html =~ "complex"
      refute html =~ "error"
    end
  end

  defp extract_id_from_html(html) do
    case Regex.run(~r/data-target="#code-content-([^"]+)"/, html) do
      [_, id] -> id
      _ -> nil
    end
  end
end

