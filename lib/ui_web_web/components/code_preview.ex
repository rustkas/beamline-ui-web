defmodule UiWebWeb.Components.CodePreview do
  @moduledoc """
  Renders code with optional syntax highlighting using Makeup.

  ## Attributes

    * `:code` - исходный текст (строка)
    * `:language` - "json" (по умолчанию), можно расширять в будущем
    * `:max_height` - высота области (по умолчанию 400px)
    * `:class` - доп. CSS классы обертки
    * `:id` - уникальный ID для элемента (генерируется автоматически если не указан)
  """
  use Phoenix.Component
  import Phoenix.HTML

  alias Makeup.Lexers.JSONLexer
  alias Makeup.Formatters.HTML.HTMLFormatter

  attr :code, :string, required: true
  attr :language, :string, default: "json"
  attr :max_height, :integer, default: 400
  attr :class, :string, default: ""
  attr :id, :string, default: nil

  def code_preview(assigns) do
    id = assigns.id || random_id()

    highlighted =
      case String.downcase(assigns.language) do
        "json" -> highlight_json(assigns.code)
        _ -> escape_plain(assigns.code)
      end

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:highlighted, raw(highlighted))

    ~H"""
    <div class={["code-preview rounded-lg border border-gray-300", @class]}>
      <div class="bg-gray-50 px-4 py-2 border-b border-gray-300 flex justify-between items-center">
        <span class="text-xs font-medium text-gray-600">
          <%= String.upcase(@language) %> preview
        </span>
        <button
          type="button"
          id={"copy-btn-#{@id}"}
          phx-hook="ClipboardCopy"
          data-target={"#code-content-#{@id}"}
          class="text-xs text-indigo-600 hover:text-indigo-900"
        >
          Copy
        </button>
      </div>

      <div
        id={"code-content-#{@id}"}
        class="overflow-auto p-4 bg-gray-900 text-gray-100 font-mono text-xs"
        style={"max-height: #{@max_height}px"}
        phx-update="ignore"
      >
        <%= @highlighted %>
      </div>
    </div>
    """
  end

  defp random_id do
    :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
  end

  defp highlight_json(code) when is_binary(code) do
    json_string =
      case Jason.decode(code) do
        {:ok, decoded} ->
          Jason.encode!(decoded, pretty: true)

        {:error, _} ->
          # некорректный JSON – показываем как есть
          code
      end

    try do
      json_string
      |> JSONLexer.lex()
      |> HTMLFormatter.format_as_iodata([])
      |> IO.iodata_to_binary()
    rescue
      _ ->
        escape_plain(json_string)
    end
  end

  defp escape_plain(code) do
    html_escape(code) |> safe_to_string()
  end
end

