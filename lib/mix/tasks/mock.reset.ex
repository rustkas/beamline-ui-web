defmodule Mix.Tasks.Mock.Reset do
  @moduledoc """
  Resets mock gateway state (ETS tables, process dictionary, etc.).
  
  Useful for:
  - Clearing state between test runs
  - Resetting mock data in development
  - CI/CD cleanup
  
  ## Usage
  
      mix mock.reset
  """
  
  use Mix.Task

  @shortdoc "Resets mock gateway state (ETS tables, deleted IDs, etc.)"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    
    table = :mock_gateway_deleted_ids
    
    case :ets.whereis(table) do
      :undefined ->
        Mix.shell().info("Mock gateway ETS table not found (already clean)")
      
      _ ->
        :ets.delete_all_objects(table)
        Mix.shell().info("✓ Mock gateway state reset (ETS table cleared)")
    end
    
    :ok
  end
end

