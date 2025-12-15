defmodule UiWeb.Test.MockGateway do
  @moduledoc """
  Mock Gateway server for testing UI-Web without real C-Gateway.
  
  Implements all required Gateway endpoints:
  - GET /health - Health check
  - GET /metrics - Metrics endpoint
  - GET /api/v1/messages - List messages
  - POST /api/v1/messages - Create message
  - GET /api/v1/messages/:id - Get message by ID
  """
  
  use Plug.Router
  
  @ets_table :mock_gateway_deleted_ids
  
  # Initialize ETS table for storing deleted message IDs (shared across processes)
  def init(opts) do
    # Create ETS table if it doesn't exist
    case :ets.whereis(@ets_table) do
      :undefined ->
        :ets.new(@ets_table, [:set, :public, :named_table])
      _ ->
        :ok
    end
    opts
  end
  
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    json_decoder: Jason
  
  plug :match
  plug :dispatch
  
  # Health endpoint
  get "/health" do
    json_response(conn, 200, %{
      status: "ok",
      nats: %{connected: true},
      timestamp_ms: System.system_time(:millisecond)
    })
  end
  
  # Alternative health endpoint (used by DashboardLive)
  get "/_health" do
    query = conn.query_params
    
    # Force error for testing error handling
    case Map.get(query, "status") do
      "force_error" ->
        json_response(conn, 500, %{"error" => "forced_error"})
      
      _ ->
        json_response(conn, 200, %{
          status: "ok",
          version: "1.0.0",
          service: "gateway",
          nats: %{connected: true},
          router: %{
            status: "healthy",
            version: "1.2.0"
          },
          worker_caf: %{
            status: "healthy"
          },
          timestamp_ms: System.system_time(:millisecond),
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end
  
  # Metrics endpoint (used by DashboardLive)
  get "/metrics" do
    query = conn.query_params
    
    # Force error for testing error handling
    case Map.get(query, "status") do
      "force_error" ->
        json_response(conn, 500, %{"error" => "forced_error"})
      
      _ ->
        json_response(conn, 200, %{
          rps: 100,
          latency: %{p50: 10, p95: 50, p99: 100},
          error_rate: 0.01,
          nats: %{connected: true}
        })
    end
  end
  
  # List messages endpoint
  get "/api/v1/messages" do
    query = conn.query_params
    
    # Force error for testing error handling
    case Map.get(query, "status") do
      "force_error" ->
        json_response(conn, 500, %{"error" => "forced_error"})
      
      "empty_test" ->
        # Return empty list for empty state testing
        json_response(conn, 200, %{
          data: [],
          pagination: %{
            total: 0,
            limit: to_int_default(Map.get(query, "limit"), 50),
            offset: to_int_default(Map.get(query, "offset"), 0) |> max(0),
            has_more: false
          }
        })
      
      _ ->
        limit = to_int_default(Map.get(query, "limit"), 50)
        offset = to_int_default(Map.get(query, "offset"), 0) |> max(0)
        status = Map.get(query, "status")
        type = Map.get(query, "type")
        search = Map.get(query, "search")
        sort = Map.get(query, "sort", "created_at")
        order = Map.get(query, "order", "desc")
        
        # Filter messages based on query params
        messages = get_all_mock_messages()
          |> filter_messages_by_status(status)
          |> filter_messages_by_type(type)
          |> filter_messages_by_search(search)
          |> sort_messages(sort, order)
        
        total = length(messages)
        paginated = messages
          |> Enum.drop(offset)
          |> Enum.take(limit)
        
        json_response(conn, 200, %{
          data: paginated,
          pagination: %{
            total: total,
            limit: limit,
            offset: offset,
            has_more: offset + limit < total
          }
        })
    end
  end
  
  # Create message endpoint
  post "/api/v1/messages" do
    params = conn.body_params
    
    # Support both old format (tenant_id, message_type, payload) and new format (type, content, metadata)
    case params do
      %{"type" => _type, "content" => _content} = data ->
        # New format from MessageForm
        message_id = "msg_#{System.system_time(:millisecond)}"
        message = Map.merge(data, %{
          "id" => message_id,
          "status" => Map.get(data, "status", "pending"),
          "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        })
        
        # Store message in process dictionary
        store_mock_message(message_id, message)
        
        json_response(conn, 201, message)
      
      %{"tenant_id" => _tenant_id, "message_type" => _msg_type, "payload" => _payload} = data ->
        # Old format (for backward compatibility)
        message_id = "msg_#{System.system_time(:millisecond)}"
        
        # Store message in process dictionary (for test isolation, use ETS in production mock)
        store_mock_message(message_id, Map.merge(data, %{"message_id" => message_id}))
        
        json_response(conn, 200, %{
          message_id: message_id,
          ack_timestamp_ms: System.system_time(:millisecond),
          status: "published"
        })
      
      _ ->
        json_response(conn, 400, %{
          error: "Invalid request",
          message: "Missing required fields: type and content (or tenant_id, message_type, payload)"
        })
    end
  end
  
  # Get message by ID endpoint
  get "/api/v1/messages/:id" do
    case get_mock_message(id) do
      nil ->
        json_response(conn, 404, %{error: "Message not found"})
      
      message ->
        response = Map.merge(message, %{
          "status" => message["status"] || "completed",
          "created_at" => message["created_at"] || (DateTime.utc_now() |> DateTime.to_iso8601()),
          "trace_id" => Map.get(message, "trace_id")
        })
        
        json_response(conn, 200, response)
    end
  end
  
  # Update message endpoint
  put "/api/v1/messages/:id" do
    id = conn.path_params["id"]
    params = conn.body_params
    
    # Special ID that always fails for testing
    if id == "msg_fail" do
      json_response(conn, 500, %{"error" => "update_failed"})
    else
      case get_mock_message(id) do
        nil ->
          json_response(conn, 404, %{"error" => "Message not found"})
        
        message ->
          updated = Map.merge(message, params)
            |> Map.put("updated_at", DateTime.utc_now() |> DateTime.to_iso8601())
            |> Map.put("id", id)  # Ensure id is preserved
          
          # Update stored message
          store_mock_message(id, updated)
          
          json_response(conn, 200, updated)
      end
    end
  end

  # Delete message endpoint
  delete "/api/v1/messages/:id" do
    # Special ID that always fails for testing
    if id == "msg_fail" do
      json_response(conn, 500, %{"error" => "delete_failed"})
    else
      case delete_mock_message(id) do
        :ok ->
          send_resp(conn, 204, "")  # 204 No Content - no body
        
        :not_found ->
          json_response(conn, 404, %{error: "Message not found"})
      end
    end
  end

  # Bulk delete messages endpoint
  post "/api/v1/messages/bulk_delete" do
    # Plug.Parsers already decoded JSON into conn.body_params
    %{"message_ids" => ids} = conn.body_params
    
    # Split failed (msg_fail) and successful deletions
    {failed, to_delete} = Enum.split_with(ids, &(&1 == "msg_fail"))
    
    deleted_count = Enum.count(to_delete, fn id ->
      case delete_mock_message(id) do
        :ok -> true
        :not_found -> false
      end
    end)
    
    # If there are failed IDs, return error
    if failed != [] do
      json_response(conn, 500, %{
        deleted_count: deleted_count,
        failed: failed
      })
    else
      json_response(conn, 200, %{
        deleted_count: deleted_count,
        failed: []
      })
    end
  end

  # Export messages endpoint
  post "/api/v1/messages/export" do
    # Plug.Parsers already decoded JSON into conn.body_params
    %{"message_ids" => ids, "format" => format} = conn.body_params
    
    # Force error if msg_fail or msg_fail_export is in the list
    if "msg_fail" in ids || "msg_fail_export" in ids do
      json_response(conn, 500, %{"error" => "export_failed"})
    else
      messages = Enum.map(ids, fn id ->
        case get_mock_message(id) do
          nil -> nil
          msg -> msg
        end
      end)
      |> Enum.filter(&(&1 != nil))
      
      {content, content_type} = case format do
        "json" ->
          {Jason.encode!(messages, pretty: true), "application/json"}
        
        "csv" ->
          # Simple CSV export
          headers = ["id", "type", "status", "created_at"]
          rows = Enum.map(messages, fn msg ->
            [msg["id"], msg["type"] || "", msg["status"] || "", msg["created_at"] || ""]
          end)
          content = ([headers | rows]
            |> Enum.map(&Enum.join(&1, ","))
            |> Enum.join("\n"))
          {content, "text/csv"}
        
        _ ->
          {Jason.encode!(messages), "application/json"}
      end
      
      conn
      |> put_resp_content_type(content_type)
      |> send_resp(200, content)
    end
  end

  # Extensions endpoints

  # GET /api/v1/extensions
  get "/api/v1/extensions" do
    query = conn.query_params
    
    # Force error for testing error handling
    case Map.get(query, "type") do
      "force_error" ->
        json_response(conn, 500, %{"error" => "forced_error"})
      
      _ ->
        type = Map.get(query, "type")
        status = Map.get(query, "status")
        limit = to_int_default(Map.get(query, "limit"), 20)
        offset = to_int_default(Map.get(query, "offset"), 0) |> max(0)

        extensions = mock_extensions()
          |> filter_by_type(type)
          |> filter_by_status(status)

        total = length(extensions)
        paginated = extensions
          |> Enum.drop(offset)
          |> Enum.take(limit)

        json_response(conn, 200, %{
          data: paginated,
          pagination: %{
            total: total,
            limit: limit,
            offset: offset,
            has_more: offset + limit < total
          }
        })
    end
  end

  # PATCH /api/v1/extensions/:id
  patch "/api/v1/extensions/:id" do
    # Plug.Parsers already decoded JSON into conn.body_params
    params = conn.body_params

    # Special ID that always fails for testing
    if id == "ext_fail" do
      json_response(conn, 500, %{"error" => "toggle_failed"})
    else
      # Update extension in mock storage
      case update_mock_extension(id, params) do
        {:ok, updated} ->
          json_response(conn, 200, %{
            id: id,
            enabled: updated["enabled"],
            updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
          })

        :not_found ->
          json_response(conn, 404, %{error: "Extension not found"})
      end
    end
  end

  # DELETE /api/v1/extensions/:id
  delete "/api/v1/extensions/:id" do
    # Special ID that always fails for testing
    if id == "ext_fail" do
      json_response(conn, 500, %{"error" => "delete_failed"})
    else
      case delete_mock_extension(id) do
        :ok ->
          send_resp(conn, 204, "")  # 204 No Content - no body

        :not_found ->
          json_response(conn, 404, %{error: "Extension not found"})
      end
    end
  end

  # POST /api/v1/extensions
  post "/api/v1/extensions" do
    params = conn.body_params

    # Validate NATS subject
    case validate_nats_subject(params["nats_subject"], params["type"]) do
      :ok ->
        extension = Map.put(params, "id", "ext_#{:rand.uniform(999_999)}")
        json_response(conn, 201, extension)

      {:error, message} ->
        json_response(conn, 422, %{
          "errors" => %{"nats_subject" => [message]}
        })
    end
  end

  # GET /api/v1/extensions/:id
  get "/api/v1/extensions/:id" do
    extension = Enum.find(mock_extensions(), fn ext -> ext["id"] == id end)

    case extension do
      nil -> json_response(conn, 404, %{"error" => "Not found"})
      ext -> json_response(conn, 200, ext)
    end
  end

  # GET /api/v1/extensions/health
  get "/api/v1/extensions/health" do
    json_response(conn, 200, %{
      "normalize_text" => %{
        "extension_id" => "normalize_text",
        "status" => "healthy",
        "success_rate" => 0.995,
        "avg_latency_ms" => 15.5,
        "p50_latency_ms" => 12.0,
        "p95_latency_ms" => 25.0,
        "p99_latency_ms" => 35.0,
        "last_success" => "2025-01-27T12:00:00Z",
        "last_failure" => nil
      },
      "pii_guard" => %{
        "extension_id" => "pii_guard",
        "status" => "healthy",
        "success_rate" => 0.98,
        "avg_latency_ms" => 20.0,
        "p50_latency_ms" => 18.0,
        "p95_latency_ms" => 30.0,
        "p99_latency_ms" => 40.0,
        "last_success" => "2025-01-27T12:00:00Z",
        "last_failure" => nil
      }
    })
  end

  # GET /api/v1/extensions/circuit-breakers
  get "/api/v1/extensions/circuit-breakers" do
    json_response(conn, 200, %{
      "normalize_text" => %{
        "extension_id" => "normalize_text",
        "state" => "closed",
        "opened_at" => nil,
        "failure_count" => 0,
        "error_rate" => 0.0
      },
      "pii_guard" => %{
        "extension_id" => "pii_guard",
        "state" => "closed",
        "opened_at" => nil,
        "failure_count" => 0,
        "error_rate" => 0.0
      }
    })
  end

  # GET /api/v1/policies/:tenant_id/:policy_id/complexity
  get "/api/v1/policies/:tenant_id/:policy_id/complexity" do
    tenant_id = conn.path_params["tenant_id"]
    policy_id = conn.path_params["policy_id"]

    # Mock complexity response
    complexity = %{
      "total_extensions" => 3,
      "pre_count" => 1,
      "validators_count" => 1,
      "post_count" => 1,
      "complexity_score" => 45,
      "complexity_level" => "medium",
      "estimated_latency_ms" => 90,
      "recommended_limits" => %{
        "max_total" => 4,
        "max_pre" => 2,
        "max_validators" => 2,
        "max_post" => 2
      },
      "warnings" => [],
      "recommendations" => []
    }

    json_response(conn, 200, %{"complexity" => complexity})
  end

  # POST /api/v1/policies/dry-run
  post "/api/v1/policies/dry-run" do
    %{"tenant_id" => tenant_id, "policy_id" => policy_id, "payload" => payload} = conn.body_params

    # Mock dry-run result
    result = %{
      "ok" => true,
      "result" => %{
        "executed_extensions" => [
          %{
            "extension_id" => "normalize_text",
            "type" => "pre",
            "status" => "success",
            "latency_ms" => 12.5,
            "output" => %{
              "payload" => "TEST"
            }
          }
        ],
        "blocked_by" => nil,
        "final_payload" => payload,
        "provider_selected" => "openai",
        "post_processors_executed" => [
          %{
            "extension_id" => "mask_pii",
            "type" => "post",
            "status" => "success",
            "latency_ms" => 8.3
          }
        ]
      }
    }

    json_response(conn, 200, result)
  end

  # PUT /api/v1/extensions/:id
  put "/api/v1/extensions/:id" do
    params = conn.body_params

    # Validate NATS subject
    case validate_nats_subject(params["nats_subject"], params["type"]) do
      :ok ->
        updated = Map.put(params, "id", id)
        json_response(conn, 200, updated)

      {:error, message} ->
        json_response(conn, 422, %{
          "errors" => %{"nats_subject" => [message]}
        })
    end
  end
  
  # Policies endpoints
  
  # GET /api/v1/policies/:tenant_id - List policies for tenant
  get "/api/v1/policies/:tenant_id" do
    tenant_id = conn.path_params["tenant_id"]
    
    # Force error for testing error handling
    case tenant_id do
      "force_error" ->
        json_response(conn, 500, %{"error" => "forced_error"})
      
      _ ->
        policies = mock_policies()
          |> Enum.filter(fn p -> p["tenant_id"] == tenant_id end)
        
        # Return as list or wrapped in "items" key (PoliciesLive handles both)
        json_response(conn, 200, %{"items" => policies})
    end
  end
  
  # GET /api/v1/policies/:tenant_id/:policy_id - Get specific policy
  get "/api/v1/policies/:tenant_id/:policy_id" do
    tenant_id = conn.path_params["tenant_id"]
    policy_id = conn.path_params["policy_id"]
    
    policy = mock_policies()
      |> Enum.find(fn p -> p["tenant_id"] == tenant_id && p["policy_id"] == policy_id end)
    
    case policy do
      nil -> json_response(conn, 404, %{"error" => "Policy not found"})
      p -> json_response(conn, 200, p)
    end
  end
  
  # PUT /api/v1/policies/:tenant_id/:policy_id - Create or update policy
  put "/api/v1/policies/:tenant_id/:policy_id" do
    tenant_id = conn.path_params["tenant_id"]
    policy_id = conn.path_params["policy_id"]
    body = conn.body_params
    
    # Force error for specific policy ID
    case policy_id do
      "policy_fail" ->
        json_response(conn, 500, %{"error" => "save_failed"})
      
      _ ->
        # Store policy (in real implementation, would use ETS/Agent)
        updated = Map.merge(body, %{
          "tenant_id" => tenant_id,
          "policy_id" => policy_id
        })
        
        json_response(conn, 200, updated)
    end
  end
  
  # DELETE /api/v1/policies/:tenant_id/:policy_id - Delete policy
  delete "/api/v1/policies/:tenant_id/:policy_id" do
    tenant_id = conn.path_params["tenant_id"]
    policy_id = conn.path_params["policy_id"]
    
    # Force error for specific policy ID
    case policy_id do
      "policy_fail" ->
        json_response(conn, 500, %{"error" => "delete_failed"})
      
      _ ->
        # In real implementation, would remove from storage
        json_response(conn, 200, %{"deleted" => true})
    end
  end
  
  # Catch-all for undefined routes
  match _ do
    json_response(conn, 404, %{error: "Not Found"})
  end
  
  # Private helper functions
  
  defp get_mock_messages(tenant_id, status, page, limit) do
    # Simple in-memory storage for tests
    # In production mock, use ETS or Agent
    all_messages = get_all_mock_messages()
    
    filtered = 
      all_messages
      |> Enum.filter(fn msg ->
        (is_nil(tenant_id) or msg["tenant_id"] == tenant_id) and
        (is_nil(status) or msg["status"] == status)
      end)
    
    filtered
    |> Enum.slice((page - 1) * limit, limit)
  end
  
  defp get_mock_message(id) do
    # First check stored messages (from POST)
    stored = case Process.get({:mock_message, id}) do
      nil -> nil
      msg -> msg
    end
    
    if stored do
      stored
    else
      # Fall back to get_all_mock_messages() for pre-generated test data (respects deletions)
      get_all_mock_messages()
      |> Enum.find(fn msg -> (msg["id"] || msg["message_id"]) == id end)
    end
  end
  
  defp store_mock_message(id, message) do
    # Store in process dictionary (test isolation)
    # In production mock, use ETS or Agent
    Process.put({:mock_message, id}, message)
  end
  
  defp delete_mock_message(id) do
    messages = mock_messages()
    case Enum.find(messages, fn msg -> msg["id"] == id end) do
      nil -> :not_found
      _ ->
        # Store deleted ID in ETS table (shared across processes)
        :ets.insert(@ets_table, {id, true})
        :ok
    end
  end
  
  defp get_all_mock_messages do
    # Get all messages from mock_messages() and filter out deleted ones
    all_messages = mock_messages()
    deleted_ids = :ets.tab2list(@ets_table) |> Enum.map(&elem(&1, 0)) |> MapSet.new()
    
    Enum.reject(all_messages, fn msg -> MapSet.member?(deleted_ids, msg["id"]) end)
  end

  # Extensions mock helpers

  defp mock_extensions do
    # Generate 40 extensions for pagination testing
    base_extensions =
      for i <- 1..40 do
        type =
          case rem(i, 4) do
            0 -> "provider"
            1 -> "validator"
            2 -> "pre"
            3 -> "post"
          end

        %{
          "id" => "ext_#{i |> Integer.to_string() |> String.pad_leading(3, "0")}",
          "name" => "extension_#{i}",
          "type" => type,
          "description" => "Test extension #{i}",
          "nats_subject" => "beamline.extensions.#{type}.ext#{i}.v1",
          "version" => "1.0.#{rem(i, 5)}",
          "enabled" => rem(i, 2) == 0,
          "health" => %{
            "status" =>
              case rem(i, 3) do
                0 -> "healthy"
                1 -> "degraded"
                2 -> "down"
              end,
            "last_check" => DateTime.utc_now() |> DateTime.to_iso8601(),
            "latency_ms" => 10 * i,
            "error_rate" => i / 100.0
          },
          "metadata" => %{
            "author" => "Beamline Team",
            "tags" => ["test"],
            "docs_url" => "https://docs.beamline.io/extensions/ext#{i}"
          },
          "created_at" => "2025-11-20T08:00:00Z",
          "updated_at" => "2025-11-23T09:15:00Z"
        }
      end

    # Add ext_fail for error testing (should be first in list for easier access)
    [%{
      "id" => "ext_fail",
      "name" => "failing-extension",
      "type" => "provider",
      "description" => "This extension will fail on toggle/delete",
      "nats_subject" => "beamline.extensions.provider.fail.v1",
      "version" => "1.0.0",
      "enabled" => true,
      "health" => %{
        "status" => "healthy",
        "last_check" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "latency_ms" => 50,
        "error_rate" => 0.0
      },
      "metadata" => %{
        "author" => "Test",
        "tags" => ["test"],
        "docs_url" => "https://docs.beamline.io/extensions/fail"
      },
      "created_at" => "2025-11-20T08:00:00Z",
      "updated_at" => "2025-11-23T09:15:00Z"
    } | base_extensions]
  end

  defp filter_by_type(extensions, nil), do: extensions
  defp filter_by_type(extensions, "all"), do: extensions
  defp filter_by_type(extensions, type) do
    Enum.filter(extensions, fn ext -> ext["type"] == type end)
  end

  defp filter_by_status(extensions, nil), do: extensions
  defp filter_by_status(extensions, "all"), do: extensions
  defp filter_by_status(extensions, status) do
    case status do
      "enabled" -> Enum.filter(extensions, fn ext -> ext["enabled"] == true end)
      "disabled" -> Enum.filter(extensions, fn ext -> ext["enabled"] == false end)
      _ -> extensions
    end
  end

  defp update_mock_extension(id, params) do
    extensions = mock_extensions()
    case Enum.find(extensions, fn ext -> ext["id"] == id end) do
      nil -> :not_found
      ext ->
        # Convert enabled to boolean if it's a string
        enabled = case Map.get(params, "enabled") do
          true -> true
          false -> false
          "true" -> true
          "false" -> false
          _ -> ext["enabled"]
        end
        updated = Map.merge(ext, %{"enabled" => enabled})
        Process.put({:mock_extension, id}, updated)
        {:ok, updated}
    end
  end

  defp delete_mock_extension(id) do
    extensions = mock_extensions()
    case Enum.find(extensions, fn ext -> ext["id"] == id end) do
      nil -> :not_found
      _ ->
        Process.delete({:mock_extension, id})
        :ok
    end
  end

  defp validate_nats_subject(subject, type) do
    pattern = ~r/^beamline\.extensions\.(provider|validator|pre|post)\.[a-z0-9-]+\.v\d+(alpha|beta)?$/

    cond do
      !subject || !Regex.match?(pattern, subject) ->
        {:error, "must match pattern: beamline.extensions.{type}.{name}.v{N}"}

      !String.contains?(subject, ".#{type}.") ->
        {:error, "subject type must match extension type"}

      true ->
        :ok
    end
  end

  # Policies mock helpers

  defp mock_policies do
    # Generate policies for different tenants
    base_policies =
      for i <- 1..20 do
        tenant_id = if rem(i, 3) == 0, do: "tenant_dev", else: "tenant_#{div(i, 3) + 1}"
        
        %{
          "tenant_id" => tenant_id,
          "policy_id" => "policy_#{i |> Integer.to_string() |> String.pad_leading(3, "0")}",
          "rules" => [
            %{
              "condition" => "tenant_id == '#{tenant_id}'",
              "action" => "route_to_provider",
              "provider" => Enum.at(~w(openai anthropic custom), rem(i, 3))
            }
          ],
          "metadata" => %{
            "version" => "1.0.#{rem(i, 5)}",
            "created_by" => "user_#{div(i, 5)}",
            "tags" => ["test", "auto"]
          },
          "created_at" => "2025-11-20T08:00:00Z",
          "updated_at" => "2025-11-23T09:15:00Z"
        }
      end

    # Add default policy for tenant_dev
    [%{
      "tenant_id" => "tenant_dev",
      "policy_id" => "default",
      "rules" => [
        %{
          "condition" => "true",
          "action" => "allow",
          "provider" => "openai"
        }
      ],
      "metadata" => %{
        "version" => "1.0.0",
        "created_by" => "system",
        "tags" => ["default"]
      },
      "created_at" => "2025-11-20T08:00:00Z",
      "updated_at" => "2025-11-20T08:00:00Z"
    } | base_policies]
  end

  # Messages mock helpers

  defp mock_messages do
    # Generate 60 messages for pagination testing
    base_messages =
      for i <- 1..60 do
        %{
          "id" => "msg_#{i |> Integer.to_string() |> String.pad_leading(3, "0")}",
          "type" => if(rem(i, 2) == 0, do: "chat", else: "code"),
          "status" => Enum.at(~w(pending processing completed failed), rem(i, 4)),
          "content" => %{
            "prompt" => "Prompt #{i}",
            "response" => "Response #{i}",
            "model" => "gpt-4"
          },
          "metadata" => %{
            "user_id" => "user_#{div(i, 10)}",
            "tags" => ["test"]
          },
          "created_at" => "2025-11-23T14:00:00Z",
          "updated_at" => "2025-11-23T14:00:05Z",
          "processing_time_ms" => 1000 + i
        }
      end

    # Add msg_fail and msg_fail_export for error testing (should be first in list for easier access)
    [%{
      "id" => "msg_fail",
      "type" => "chat",
      "status" => "pending",
      "content" => %{
        "prompt" => "This message will fail on delete",
        "model" => "gpt-4"
      },
      "metadata" => %{"user_id" => "user_test"},
      "created_at" => "2025-11-23T14:00:00Z",
      "updated_at" => "2025-11-23T14:00:00Z",
      "processing_time_ms" => 500
    },
    %{
      "id" => "msg_fail_export",
      "type" => "chat",
      "status" => "pending",
      "content" => %{
        "prompt" => "This message will fail on export",
        "model" => "gpt-4"
      },
      "metadata" => %{"user_id" => "user_test"},
      "created_at" => "2025-11-23T14:00:00Z",
      "updated_at" => "2025-11-23T14:00:00Z",
      "processing_time_ms" => 500
    } | base_messages]
  end

  defp filter_messages_by_status(messages, nil), do: messages
  defp filter_messages_by_status(messages, "all"), do: messages
  defp filter_messages_by_status(messages, status) do
    Enum.filter(messages, fn msg -> msg["status"] == status end)
  end

  defp filter_messages_by_type(messages, nil), do: messages
  defp filter_messages_by_type(messages, "all"), do: messages
  defp filter_messages_by_type(messages, type) do
    Enum.filter(messages, fn msg -> msg["type"] == type end)
  end

  defp filter_messages_by_search(messages, nil), do: messages
  defp filter_messages_by_search(messages, ""), do: messages
  defp filter_messages_by_search(messages, search) do
    search_lower = String.downcase(search)
    Enum.filter(messages, fn msg ->
      content_str = Jason.encode!(msg["content"] || %{})
      metadata_str = Jason.encode!(msg["metadata"] || %{})
      String.contains?(String.downcase(content_str), search_lower) ||
        String.contains?(String.downcase(metadata_str), search_lower)
    end)
  end

  defp sort_messages(messages, sort_field, order) do
    Enum.sort_by(messages, fn msg ->
      case sort_field do
        "created_at" -> msg["created_at"] || ""
        "updated_at" -> msg["updated_at"] || ""
        "status" -> msg["status"] || ""
        _ -> msg["created_at"] || ""
      end
    end, if(order == "asc", do: :asc, else: :desc))
  end

  # Helper to convert string to integer with default
  defp to_int_default(nil, default), do: default
  defp to_int_default(string, default) when is_binary(string) do
    case Integer.parse(string) do
      {int, _} -> int
      :error -> default
    end
  end
  defp to_int_default(int, _default) when is_integer(int), do: int
  defp to_int_default(_, default), do: default

  # Helper for JSON responses
  defp json_response(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end

  # Public API for resetting mock state (used by Mix task)
  @doc """
  Resets all mock gateway state (ETS tables, etc.).
  Useful for test cleanup and development.
  """
  def reset do
    table = :mock_gateway_deleted_ids
    case :ets.whereis(table) do
      :undefined -> :ok
      _ -> :ets.delete_all_objects(table)
    end
    :ok
  end
end

