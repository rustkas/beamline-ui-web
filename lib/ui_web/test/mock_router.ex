defmodule UiWeb.Test.MockRouter do
  @moduledoc """
  Mock Router for E2E tests.
  
  Provides a stable NATS responder that generates predictable RouteDecision responses.
  This allows testing end-to-end CP1 flows without requiring a real Router instance.
  
  ## Usage
  
  Start the mock router:
  
      {:ok, _pid} = UiWeb.Test.MockRouter.start()
  
  Stop the mock router:
  
      UiWeb.Test.MockRouter.stop()
  
  ## Configuration
  
  The mock router subscribes to `beamline.router.v1.decide` and responds with
  predictable RouteDecision based on the request.
  
  ## RouteDecision Generation Rules
  
  - Default provider: `"openai:gpt-4o"`
  - Default priority: `50`
  - Default latency: `850` ms
  - Default cost: `0.012`
  - Default reason: `"best_score"`
  
  Special cases:
  - If `task.type` contains `"fail"`, returns error response
  - If `tenant_id` is `"slow_tenant"`, latency is `2000` ms
  - If `tenant_id` is `"expensive_tenant"`, cost is `0.05`
  """
  
  use GenServer
  require Logger
  
  alias Gnat.ConnectionSupervisor
  
  @nats_subject "beamline.router.v1.decide"
  @default_nats_url "nats://localhost:4222"
  
  # Default RouteDecision values
  @default_provider "openai:gpt-4o"
  @default_priority 50
  @default_latency_ms 850
  @default_cost 0.012
  @default_reason "best_score"
  
  # State
  defstruct [
    :conn,
    :sub,
    :nats_url
  ]
  
  ## Public API
  
  @doc """
  Start the Mock Router.
  
  ## Options
  
    * `:nats_url` - NATS server URL (default: "nats://localhost:4222")
  
  ## Examples
  
      {:ok, pid} = UiWeb.Test.MockRouter.start()
      {:ok, pid} = UiWeb.Test.MockRouter.start(nats_url: "nats://nats:4222")
  """
  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    nats_url = Keyword.get(opts, :nats_url, @default_nats_url)
    
    case GenServer.start(__MODULE__, %{nats_url: nats_url}, name: __MODULE__) do
      {:ok, pid} ->
        Logger.info("Mock Router started", nats_url: nats_url, subject: @nats_subject)
        {:ok, pid}
      
      {:error, {:already_started, pid}} ->
        Logger.warn("Mock Router already running", pid: pid)
        {:ok, pid}
      
      error ->
        error
    end
  end
  
  @doc """
  Stop the Mock Router.
  """
  @spec stop() :: :ok
  def stop do
    if Process.whereis(__MODULE__) do
      GenServer.stop(__MODULE__)
    else
      :ok
    end
  end
  
  @doc """
  Check if Mock Router is running.
  """
  @spec running?() :: boolean()
  def running? do
    Process.whereis(__MODULE__) != nil
  end
  
  ## GenServer Callbacks
  
  @impl true
  def init(%{nats_url: nats_url}) do
    case connect_to_nats(nats_url) do
      {:ok, conn} ->
        case subscribe_to_decide(conn) do
          {:ok, sub} ->
            state = %__MODULE__{
              conn: conn,
              sub: sub,
              nats_url: nats_url
            }
            {:ok, state}
          
          {:error, reason} ->
            Logger.error("Failed to subscribe to NATS subject", 
              subject: @nats_subject, 
              reason: reason
            )
            {:stop, reason}
        end
      
      {:error, reason} ->
        Logger.error("Failed to connect to NATS", url: nats_url, reason: reason)
        # Don't fail if NATS is not available (for tests that don't need it)
        Logger.warn("Mock Router will not respond to NATS requests", 
          url: nats_url, 
          reason: reason
        )
        {:ok, %__MODULE__{conn: nil, sub: nil, nats_url: nats_url}}
    end
  end
  
  @impl true
  def handle_info({:msg, %{topic: topic, body: body, reply_to: reply_to}}, state) do
    Logger.debug("Mock Router received request", topic: topic, reply_to: reply_to)
    
    case handle_decide_request(body, reply_to, state) do
      :ok ->
        {:noreply, state}
      
      {:error, reason} ->
        Logger.error("Failed to handle decide request", reason: reason)
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.debug("Mock Router received unknown message", message: msg)
    {:noreply, state}
  end
  
  @impl true
  def terminate(_reason, state) do
    if state.conn do
      Logger.info("Mock Router stopping", nats_url: state.nats_url)
      # Gnat will handle cleanup
    end
    :ok
  end
  
  ## Private Helpers
  
  defp connect_to_nats(nats_url) do
    case Gnat.start_link(%{name: :mock_router_gnat, connection_settings: [url: nats_url]}) do
      {:ok, pid} ->
        # Wait a bit for connection to establish
        Process.sleep(100)
        {:ok, pid}
      
      {:error, {:already_started, pid}} ->
        {:ok, pid}
      
      error ->
        error
    end
  end
  
  defp subscribe_to_decide(conn) do
    case Gnat.sub(conn, self(), @nats_subject) do
      {:ok, sub} ->
        Logger.info("Mock Router subscribed", subject: @nats_subject, subscription: sub)
        {:ok, sub}
      
      error ->
        error
    end
  end
  
  defp handle_decide_request(body, reply_to, state) when is_binary(reply_to) and is_binary(body) do
    case Jason.decode(body) do
      {:ok, request} ->
        response = generate_route_decision(request)
        response_json = Jason.encode!(response)
        
        if state.conn do
          case Gnat.pub(state.conn, reply_to, response_json) do
            :ok ->
              Logger.debug("Mock Router sent response", 
                reply_to: reply_to, 
                response: response
              )
              :ok
            
            error ->
              Logger.error("Failed to send response", reply_to: reply_to, error: error)
              {:error, error}
          end
        else
          Logger.warn("Mock Router not connected to NATS, cannot send response", reply_to: reply_to)
          {:error, :not_connected}
        end
      
      {:error, reason} ->
        Logger.error("Failed to parse request", body: body, reason: reason)
        # Build error response with minimal request info
        error_response = build_error_response(%{}, "invalid_request", "Failed to parse JSON")
        error_json = Jason.encode!(error_response)
        
        if state.conn do
          Gnat.pub(state.conn, reply_to, error_json)
        end
        {:error, reason}
    end
  end
  
  defp handle_decide_request(_body, _reply_to, _state) do
    Logger.warn("Mock Router received request without reply_to")
    :ok
  end
  
  defp generate_route_decision(request) do
    # Extract fields from request
    tenant_id = get_in(request, ["tenant_id"])
    task = get_in(request, ["task"]) || %{}
    task_type = get_in(task, ["type"]) || ""
    request_id = get_in(request, ["request_id"])
    trace_id = get_in(request, ["trace_id"])
    
    # Check for error cases
    if String.contains?(task_type, "fail") do
      build_error_response(request, "routing_failed", "Task type indicates failure")
    else
      # Generate decision based on request
      provider_id = determine_provider(tenant_id, task)
      priority = determine_priority(tenant_id, task)
      latency_ms = determine_latency(tenant_id, task)
      cost = determine_cost(tenant_id, task)
      reason = determine_reason(tenant_id, task)
      
      decision = %{
        "provider_id" => provider_id,
        "priority" => priority,
        "expected_latency_ms" => latency_ms,
        "expected_cost" => cost,
        "reason" => reason
      }
      
      context = %{}
      context = if request_id, do: Map.put(context, "request_id", request_id), else: context
      context = if trace_id, do: Map.put(context, "trace_id", trace_id), else: context
      
      %{
        "ok" => true,
        "decision" => decision,
        "context" => context
      }
    end
  end
  
  defp determine_provider(tenant_id, _task) do
    case tenant_id do
      "tenant_anthropic" -> "anthropic:claude-3-opus"
      "tenant_google" -> "google:gemini-pro"
      _ -> @default_provider
    end
  end
  
  defp determine_priority(_tenant_id, _task), do: @default_priority
  
  defp determine_latency(tenant_id, _task) do
    case tenant_id do
      "slow_tenant" -> 2000
      "fast_tenant" -> 300
      _ -> @default_latency_ms
    end
  end
  
  defp determine_cost(tenant_id, _task) do
    case tenant_id do
      "expensive_tenant" -> 0.05
      "cheap_tenant" -> 0.001
      _ -> @default_cost
    end
  end
  
  defp determine_reason(_tenant_id, _task), do: @default_reason
  
  defp build_error_response(request, error_code, error_message) do
    request_id = get_in(request, ["request_id"])
    trace_id = get_in(request, ["trace_id"])
    
    context = %{}
    context = if request_id, do: Map.put(context, "request_id", request_id), else: context
    context = if trace_id, do: Map.put(context, "trace_id", trace_id), else: context
    
    %{
      "ok" => false,
      "error" => %{
        "code" => error_code,
        "message" => error_message,
        "details" => %{
          "tenant_id" => get_in(request, ["tenant_id"])
        }
      },
      "context" => context
    }
  end
end

