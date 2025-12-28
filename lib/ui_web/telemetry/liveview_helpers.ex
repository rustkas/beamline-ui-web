defmodule UiWeb.Telemetry.LiveViewHelpers do
  @moduledoc """
  Helper functions for emitting Telemetry events from LiveView.
  
  Provides:
  - `emit_action/3` - Emit LiveView action event
  - `get_context/1` - Extract tenant_id, user_id, request_id from socket
  """
  
  @doc """
  Emit LiveView action event for Telemetry.
  
  ## Examples
  
      emit_action(socket, "bulk_delete", %{selection_count: 5})
  
  """
  def emit_action(socket, event, metadata \\ %{}) do
    context = get_context(socket)
    
    action_metadata = Map.merge(context, %{
      liveview: socket.view || __MODULE__,
      event: event
    })
    |> Map.merge(metadata)
    
    :telemetry.execute(
      [:ui_web, :live, :action],
      %{},
      action_metadata
    )
  end
  
  @doc """
  Extract context (tenant_id, user_id, request_id) from socket.
  
  Returns map with:
  - `tenant_id` - from socket.assigns.current_user.tenant_id or assigns.tenant_id
  - `user_id` - from socket.assigns.current_user.id or assigns.user_id
  - `request_id` - from Logger.metadata()[:request_id]
  """
  def get_context(socket) do
    %{
      tenant_id: get_tenant_id(socket),
      user_id: get_user_id(socket),
      request_id: Logger.metadata()[:request_id]
    }
    |> Enum.filter(fn {_k, v} -> v != nil end)
    |> Map.new()
  end
  
  defp get_tenant_id(socket) do
    cond do
      Map.has_key?(socket.assigns, :tenant_id) ->
        socket.assigns.tenant_id

      Map.has_key?(socket.assigns, :current_user) and 
        is_map(socket.assigns.current_user) and 
        Map.has_key?(socket.assigns.current_user, :tenant_id) ->
        socket.assigns.current_user.tenant_id
      
      true ->
        nil
    end
  end
  
  defp get_user_id(socket) do
    cond do
      Map.has_key?(socket.assigns, :current_user) and 
        is_map(socket.assigns.current_user) and 
        Map.has_key?(socket.assigns.current_user, :id) ->
        socket.assigns.current_user.id
      
      Map.has_key?(socket.assigns, :user_id) ->
        socket.assigns.user_id
      
      true ->
        nil
    end
  end
end

