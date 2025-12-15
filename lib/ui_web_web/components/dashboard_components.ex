defmodule UiWebWeb.DashboardComponents do
  @moduledoc """
  Reusable components for Dashboard LiveView.
  Includes health cards and metric cards.
  """
  use Phoenix.Component

  @doc """
  Health card component for displaying component status.
  
  ## Examples
  
      <.health_card
        name="C-Gateway"
        status="healthy"
        details="Version 1.0.0"
      />
  """
  attr :name, :string, required: true, doc: "Component name"
  attr :status, :string, required: true, doc: "Status: healthy, degraded, unhealthy, unknown"
  attr :details, :string, default: nil, doc: "Additional details (version, etc.)"
  attr :icon, :string, default: nil, doc: "Icon name (optional)"

  def health_card(assigns) do
    status_class = status_to_class(assigns.status)
    icon = assigns.icon || icon_for_component(assigns.name)

    assigns =
      assigns
      |> assign(:status_class, status_class)
      |> assign(:icon, icon)

    ~H"""
    <div class={"p-4 bg-white shadow rounded-lg border-l-4 #{status_border_class(@status)}"}>
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-3">
          <%= if @icon do %>
            <div class="text-2xl"><%= icon_emoji(@icon) %></div>
          <% end %>
          <div>
            <h3 class="font-semibold text-gray-900"><%= @name %></h3>
            <%= if @details do %>
              <p class="text-sm text-gray-500 mt-1"><%= @details %></p>
            <% end %>
          </div>
        </div>
        <div class="flex items-center space-x-2">
          <span class={"px-2 py-1 rounded text-xs font-medium #{@status_class}"}>
            <%= String.capitalize(@status || "unknown") %>
          </span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Metric card component for displaying real-time metrics.
  
  ## Examples
  
      <.metric_card
        label="Throughput"
        value="1,234"
        unit="req/s"
        trend="up"
      />
  """
  attr :label, :string, required: true, doc: "Metric label"
  attr :value, :any, required: true, doc: "Metric value (number or string)"
  attr :unit, :string, default: "", doc: "Unit of measurement"
  attr :trend, :string, default: nil, doc: "Trend: up, down, stable"
  attr :subvalue, :string, default: nil, doc: "Sub-value (e.g., 'p50 / p95')"

  def metric_card(assigns) do
    formatted_value = format_value(assigns.value)
    trend_icon = trend_icon(assigns.trend)
    trend_class = trend_class(assigns.trend)

    assigns =
      assigns
      |> assign(:formatted_value, formatted_value)
      |> assign(:trend_icon, trend_icon)
      |> assign(:trend_class, trend_class)

    ~H"""
    <div class="p-4 bg-white shadow rounded-lg">
      <div class="flex items-center justify-between mb-2">
        <p class="text-sm font-medium text-gray-600"><%= @label %></p>
        <%= if @trend_icon do %>
          <span class={"text-sm #{@trend_class}"}>
            <%= @trend_icon %>
          </span>
        <% end %>
      </div>
      <div class="flex items-baseline space-x-1">
        <p class="text-2xl font-bold text-gray-900">
          <%= @formatted_value %>
        </p>
        <%= if @unit != "" do %>
          <span class="text-sm text-gray-500"><%= @unit %></span>
        <% end %>
      </div>
      <%= if @subvalue do %>
        <p class="text-xs text-gray-500 mt-1"><%= @subvalue %></p>
      <% end %>
    </div>
    """
  end

  # Private helper functions

  defp status_to_class("healthy"), do: "bg-green-100 text-green-800"
  defp status_to_class("degraded"), do: "bg-yellow-100 text-yellow-800"
  defp status_to_class("unhealthy"), do: "bg-red-100 text-red-800"
  defp status_to_class(_), do: "bg-gray-100 text-gray-800"

  def status_border_class("healthy"), do: "border-green-500"
  def status_border_class("degraded"), do: "border-yellow-500"
  def status_border_class("unhealthy"), do: "border-red-500"
  def status_border_class(_), do: "border-gray-500"

  defp icon_for_component("C-Gateway"), do: "gateway"
  defp icon_for_component("Router"), do: "router"
  defp icon_for_component("Worker CAF"), do: "worker"
  defp icon_for_component("NATS"), do: "nats"
  defp icon_for_component(_), do: nil

  defp icon_emoji("gateway"), do: "🚪"
  defp icon_emoji("router"), do: "🔄"
  defp icon_emoji("worker"), do: "⚙️"
  defp icon_emoji("nats"), do: "📡"
  defp icon_emoji(_), do: "📦"

  defp format_value(nil), do: "-"
  defp format_value(value) when is_number(value) do
    # Convert to float for formatting
    float_value = value * 1.0
    
    cond do
      float_value >= 1_000_000 -> "#{:erlang.float_to_binary(float_value / 1_000_000, decimals: 2)}M"
      float_value >= 1_000 -> "#{:erlang.float_to_binary(float_value / 1_000, decimals: 2)}K"
      float_value >= 0 -> :erlang.float_to_binary(float_value, decimals: 2)
      true -> "-"
    end
  end
  defp format_value(value), do: to_string(value)

  defp trend_icon("up"), do: "↗"
  defp trend_icon("down"), do: "↘"
  defp trend_icon("stable"), do: "→"
  defp trend_icon(_), do: nil

  defp trend_class("up"), do: "text-green-600"
  defp trend_class("down"), do: "text-red-600"
  defp trend_class("stable"), do: "text-gray-600"
  defp trend_class(_), do: ""
end

