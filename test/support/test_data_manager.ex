defmodule UiWeb.TestDataManager do
  @moduledoc """
  Comprehensive test data management system for integration tests.
  
  Provides:
  - Test data lifecycle management
  - Automatic cleanup strategies
  - Data isolation between test runs
  - Performance optimization for bulk operations
  - Audit trail for test data
  """
  
  use GenServer
  alias UiWeb.Services.GatewayClient
  require Logger
  
  @test_data_prefix "test_data_"
  @cleanup_batch_size 50
  @max_cleanup_time 30_000
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Creates test data with automatic cleanup registration.
  """
  def create_test_data(type, data \\ %{}, tenant \\ "test_tenant") do
    GenServer.call(__MODULE__, {:create, type, data, tenant})
  end
  
  @doc """
  Creates bulk test data with optimized batch processing.
  """
  def create_bulk_test_data(type, items, tenant \\ "test_tenant") do
    GenServer.call(__MODULE__, {:create_bulk, type, items, tenant})
  end
  
  @doc """
  Registers existing data for cleanup.
  """
  def register_test_data(type, id, tenant \\ "test_tenant") do
    GenServer.call(__MODULE__, {:register, type, id, tenant})
  end
  
  @doc """
  Gets all test data for a specific type and tenant.
  """
  def get_test_data(type, tenant \\ "test_tenant") do
    GenServer.call(__MODULE__, {:get_all, type, tenant})
  end
  
  @doc """
  Performs cleanup of all test data.
  """
  def cleanup_all_test_data do
    GenServer.call(__MODULE__, :cleanup_all, @max_cleanup_time)
  end
  
  @doc """
  Performs cleanup of test data for specific tenant.
  """
  def cleanup_tenant_test_data(tenant) do
    GenServer.call(__MODULE__, {:cleanup_tenant, tenant}, @max_cleanup_time)
  end
  
  @doc """
  Performs cleanup of specific test data type.
  """
  def cleanup_test_data_type(type, tenant \\ "test_tenant") do
    GenServer.call(__MODULE__, {:cleanup_type, type, tenant}, @max_cleanup_time)
  end
  
  @doc """
  Gets cleanup statistics.
  """
  def get_cleanup_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  @doc """
  Resets all test data tracking.
  """
  def reset_test_data do
    GenServer.call(__MODULE__, :reset)
  end
  
  # Server Implementation
  
  def init(_opts) do
    state = %{
      test_data: %{}, # %{type => %{tenant => [ids]}}
      cleanup_stats: %{
        total_created: 0,
        total_cleaned: 0,
        failed_cleanups: 0,
        last_cleanup: nil
      },
      audit_log: []
    }
    
    {:ok, state}
  end
  
  def handle_call({:create, type, data, tenant}, _from, state) do
    case create_test_item(type, data, tenant) do
      {:ok, id} ->
        new_state = register_created_item(state, type, id, tenant)
        audit_event(:created, type, id, tenant, :success)
        {:reply, {:ok, id}, new_state}
        
      {:error, reason} = error ->
        audit_event(:created, type, nil, tenant, {:failed, reason})
        {:reply, error, state}
    end
  end
  
  def handle_call({:create_bulk, type, items, tenant}, _from, state) do
    Logger.info("Creating bulk test data: #{length(items)} items of type #{type} for tenant #{tenant}")
    
    results = items
    |> Enum.chunk_every(@cleanup_batch_size)
    |> Enum.flat_map(fn chunk ->
      chunk
      |> Enum.map(&create_test_item_async(type, &1, tenant))
      |> Task.await_many(30_000)
    end)
    
    {successful, failed} = Enum.split_with(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    created_ids = Enum.map(successful, fn {:ok, id} -> id end)
    new_state = register_created_items(state, type, created_ids, tenant)
    
    # Audit results
    audit_event(:bulk_created, type, length(created_ids), tenant, :success)
    if length(failed) > 0 do
      audit_event(:bulk_created, type, length(failed), tenant, {:partial_failure, failed})
    end
    
    {:reply, {:ok, created_ids, length(failed)}, new_state}
  end
  
  def handle_call({:register, type, id, tenant}, _from, state) do
    new_state = register_created_item(state, type, id, tenant)
    audit_event(:registered, type, id, tenant, :success)
    {:reply, :ok, new_state}
  end
  
  def handle_call({:get_all, type, tenant}, _from, state) do
    ids = get_in(state.test_data, [type, tenant]) || []
    {:reply, {:ok, ids}, state}
  end
  
  def handle_call(:cleanup_all, _from, state) do
    Logger.info("Starting cleanup of all test data...")
    
    {results, new_state} = perform_comprehensive_cleanup(state)
    
    # Update stats
    total_cleaned = Enum.count(results, fn {status, _} -> status == :success end)
    total_failed = Enum.count(results, fn {status, _} -> status == :failed end)
    
    new_cleanup_stats = state.cleanup_stats
    |> Map.update!(:total_cleaned, &(&1 + total_cleaned))
    |> Map.update!(:failed_cleanups, &(&1 + total_failed))
    |> Map.put(:last_cleanup, DateTime.utc_now())
    
    result_status = if total_failed == 0, do: :success, else: {:partial_failure, total_failed}
    audit_event(:cleanup_all, :all, total_cleaned + total_failed, :all_tenants, result_status)
    
    final_state = %{new_state | cleanup_stats: new_cleanup_stats, test_data: %{}}
    
    {:reply, {:ok, total_cleaned, total_failed}, final_state}
  end
  
  def handle_call({:cleanup_tenant, tenant}, _from, state) do
    Logger.info("Starting cleanup of test data for tenant: #{tenant}")
    
    {results, new_state} = perform_tenant_cleanup(state, tenant)
    
    # Update stats
    total_cleaned = Enum.count(results, fn {status, _} -> status == :success end)
    total_failed = Enum.count(results, fn {status, _} -> status == :failed end)
    
    new_cleanup_stats = state.cleanup_stats
    |> Map.update!(:total_cleaned, &(&1 + total_cleaned))
    |> Map.update!(:failed_cleanups, &(&1 + total_failed))
    |> Map.put(:last_cleanup, DateTime.utc_now())
    
    result_status = if total_failed == 0, do: :success, else: {:partial_failure, total_failed}
    audit_event(:cleanup_tenant, :all, total_cleaned + total_failed, tenant, result_status)
    
    # Remove tenant data from tracking
    tenant_cleaned_state = remove_tenant_data(new_state, tenant)
    final_state = %{tenant_cleaned_state | cleanup_stats: new_cleanup_stats}
    
    {:reply, {:ok, total_cleaned, total_failed}, final_state}
  end
  
  def handle_call({:cleanup_type, type, tenant}, _from, state) do
    Logger.info("Starting cleanup of test data: #{type} for tenant: #{tenant}")
    
    ids = get_in(state.test_data, [type, tenant]) || []
    
    {results, new_state} = perform_type_cleanup(state, type, ids, tenant)
    
    # Update stats
    total_cleaned = Enum.count(results, fn {status, _} -> status == :success end)
    total_failed = Enum.count(results, fn {status, _} -> status == :failed end)
    
    new_cleanup_stats = state.cleanup_stats
    |> Map.update!(:total_cleaned, &(&1 + total_cleaned))
    |> Map.update!(:failed_cleanups, &(&1 + total_failed))
    |> Map.put(:last_cleanup, DateTime.utc_now())
    
    result_status = if total_failed == 0, do: :success, else: {:partial_failure, total_failed}
    audit_event(:cleanup_type, type, total_cleaned + total_failed, tenant, result_status)
    
    # Remove type data from tracking
    type_cleaned_state = remove_type_data(new_state, type, tenant)
    final_state = %{type_cleaned_state | cleanup_stats: new_cleanup_stats}
    
    {:reply, {:ok, total_cleaned, total_failed}, final_state}
  end
  
  def handle_call(:get_stats, _from, state) do
    {:reply, {:ok, state.cleanup_stats}, state}
  end
  
  def handle_call(:reset, _from, _state) do
    new_state = %{
      test_data: %{},
      cleanup_stats: %{
        total_created: 0,
        total_cleaned: 0,
        failed_cleanups: 0,
        last_cleanup: nil
      },
      audit_log: []
    }
    
    {:reply, :ok, new_state}
  end
  
  # Helper Functions
  
  defp create_test_item(type, data, tenant) do
    # Add test data prefix to distinguish from production data
    test_data = Map.put(data, "test_type", @test_data_prefix <> to_string(type))
    
    case type do
      "message" ->
        GatewayClient.post_json("/api/v1/messages", test_data)
        
      "user" ->
        # This would call user creation endpoint when available
        {:error, :user_creation_not_implemented}
        
      "tenant" ->
        # This would call tenant creation endpoint when available
        {:error, :tenant_creation_not_implemented}
        
      _ ->
        {:error, {:unknown_type, type}}
    end
  end
  
  defp create_test_item_async(type, data, tenant) do
    Task.async(fn -> create_test_item(type, data, tenant) end)
  end
  
  defp register_created_item(state, type, id, tenant) do
    update_in(state.test_data, fn test_data ->
      test_data
      |> Map.put_new(type, %{})
      |> put_in([type, tenant], [id | (get_in(test_data, [type, tenant]) || [])])
    end)
    |> Map.update!(:cleanup_stats, fn stats ->
      Map.update!(stats, :total_created, &(&1 + 1))
    end)
  end
  
  defp register_created_items(state, type, ids, tenant) do
    update_in(state.test_data, fn test_data ->
      test_data
      |> Map.put_new(type, %{})
      |> put_in([type, tenant], ids ++ (get_in(test_data, [type, tenant]) || []))
    end)
    |> Map.update!(:cleanup_stats, fn stats ->
      Map.update!(stats, :total_created, &(&1 + length(ids)))
    end)
  end
  
  defp perform_comprehensive_cleanup(state) do
    all_cleanup_tasks = 
      for {type, tenants} <- state.test_data,
          {tenant, ids} <- tenants,
          id <- ids do
        {type, id, tenant}
      end
    
    cleanup_results = perform_cleanup_batch(all_cleanup_tasks)
    
    {cleanup_results, %{state | test_data: %{}}}
  end
  
  defp perform_tenant_cleanup(state, tenant) do
    tenant_cleanup_tasks = 
      for {type, tenants} <- state.test_data,
          {^tenant, ids} <- [tenants],
          id <- ids do
        {type, id, tenant}
      end
    
    cleanup_results = perform_cleanup_batch(tenant_cleanup_tasks)
    
    {cleanup_results, state}
  end
  
  defp perform_type_cleanup(state, type, ids, tenant) do
    cleanup_tasks = Enum.map(ids, &{type, &1, tenant})
    cleanup_results = perform_cleanup_batch(cleanup_tasks)
    
    {cleanup_results, state}
  end
  
  defp perform_cleanup_batch(cleanup_tasks) do
    cleanup_tasks
    |> Enum.chunk_every(@cleanup_batch_size)
    |> Enum.flat_map(fn batch ->
      batch
      |> Enum.map(fn {type, id, tenant} ->
        Task.async(fn -> cleanup_item(type, id, tenant) end)
      end)
      |> Task.await_many(30_000)
    end)
  end
  
  defp cleanup_item(type, id, _tenant) do
    case type do
      "message" ->
        case GatewayClient.delete_json("/api/v1/messages/#{id}") do
          {:ok, _} -> {:success, id}
          {:error, _} = error -> {:failed, {id, error}}
        end
        
      _ ->
        {:failed, {id, {:unknown_cleanup_type, type}}}
    end
  end
  
  defp remove_tenant_data(state, tenant) do
    update_in(state.test_data, fn test_data ->
      Enum.reduce(test_data, %{}, fn {type, tenants}, acc ->
        filtered_tenants = Map.drop(tenants, [tenant])
        if map_size(filtered_tenants) > 0 do
          Map.put(acc, type, filtered_tenants)
        else
          acc
        end
      end)
    end)
  end
  
  defp remove_type_data(state, type, tenant) do
    update_in(state.test_data, fn test_data ->
      case test_data do
        %{^type => tenants} ->
          filtered_tenants = Map.drop(tenants, [tenant])
          if map_size(filtered_tenants) > 0 do
            %{test_data | type => filtered_tenants}
          else
            Map.drop(test_data, [type])
          end
        _ ->
          test_data
      end
    end)
  end
  
  defp audit_event(action, type, target, tenant, result) do
    event = %{
      timestamp: DateTime.utc_now(),
      action: action,
      type: type,
      target: target,
      tenant: tenant,
      result: result
    }
    
    # In a real implementation, this would be logged to persistent storage
    Logger.debug("Test data audit: #{inspect(event)}")
  end
  
  # Public utility functions (can be called without GenServer)
  
  @doc """
  Generates a unique test ID with timestamp.
  """
  def generate_test_id(prefix \\ "test") do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    unique = System.unique_integer([:positive])
    "#{prefix}_#{timestamp}_#{unique}"
  end
  
  @doc """
  Checks if data is test data based on test_type field.
  """
  def is_test_data?(data) when is_map(data) do
    case Map.get(data, "test_type") do
      nil -> false
      test_type -> String.starts_with?(test_type, @test_data_prefix)
    end
  end
  
  def is_test_data?(_), do: false
  
  @doc """
  Filters test data from a list of items.
  """
  def filter_test_data(items) when is_list(items) do
    Enum.filter(items, &is_test_data?/1)
  end
  
  @doc """
  Filters non-test data from a list of items.
  """
  def filter_non_test_data(items) when is_list(items) do
    Enum.reject(items, &is_test_data?/1)
  end
end