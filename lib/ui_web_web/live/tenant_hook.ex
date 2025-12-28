defmodule UiWebWeb.Live.TenantHook do
  import Phoenix.Component

  def on_mount(:default, params, _session, socket) do
    tenant_id = params["tenant_id"] || "tenant_dev"
    
    socket = 
      socket
      |> assign(:tenant_id, tenant_id)
      
    {:cont, socket}
  end
end
