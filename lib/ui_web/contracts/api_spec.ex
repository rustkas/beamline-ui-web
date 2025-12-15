defmodule UiWeb.Contracts.ApiSpec do
  @moduledoc """
  API Specification extracted from Mock Gateway.
  
  This module defines the contract between UI-Web and C-Gateway backend.
  Mock Gateway implements this contract for testing, and this spec serves
  as the source of truth for API contracts.
  """

  @doc """
  Get all API endpoint specifications.
  
  Returns a map of endpoint paths to their specifications.
  """
  @spec endpoints() :: map()
  def endpoints do
    %{
      # Health endpoints
      "GET /health" => health_spec(),
      "GET /_health" => health_detailed_spec(),
      "GET /metrics" => metrics_spec(),
      
      # Messages API
      "GET /api/v1/messages" => messages_list_spec(),
      "POST /api/v1/messages" => messages_create_spec(),
      "GET /api/v1/messages/:id" => messages_get_spec(),
      "PUT /api/v1/messages/:id" => messages_update_spec(),
      "DELETE /api/v1/messages/:id" => messages_delete_spec(),
      "POST /api/v1/messages/bulk_delete" => messages_bulk_delete_spec(),
      "POST /api/v1/messages/export" => messages_export_spec(),
      
      # Extensions API
      "GET /api/v1/extensions" => extensions_list_spec(),
      "POST /api/v1/extensions" => extensions_create_spec(),
      "GET /api/v1/extensions/:id" => extensions_get_spec(),
      "PUT /api/v1/extensions/:id" => extensions_update_spec(),
      "PATCH /api/v1/extensions/:id" => extensions_patch_spec(),
      "DELETE /api/v1/extensions/:id" => extensions_delete_spec(),
      
      # Policies API
      "GET /api/v1/policies/:tenant_id" => policies_list_spec(),
      "GET /api/v1/policies/:tenant_id/:policy_id" => policies_get_spec(),
      "PUT /api/v1/policies/:tenant_id/:policy_id" => policies_update_spec(),
      "DELETE /api/v1/policies/:tenant_id/:policy_id" => policies_delete_spec()
    }
  end

  # Health endpoints

  defp health_spec do
    %{
      method: "GET",
      path: "/health",
      description: "Basic health check endpoint",
      request: %{
        query_params: %{}
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "status" => "string (ok)",
            "nats" => %{
              "connected" => "boolean"
            },
            "timestamp_ms" => "integer"
          }
        },
        errors: [
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp health_detailed_spec do
    %{
      method: "GET",
      path: "/_health",
      description: "Detailed health check with component status",
      request: %{
        query_params: %{
          "status" => "string (optional, 'force_error' for testing)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "status" => "string (ok)",
            "version" => "string",
            "service" => "string (gateway)",
            "nats" => %{
              "connected" => "boolean"
            },
            "router" => %{
              "status" => "string (healthy)",
              "version" => "string"
            },
            "worker_caf" => %{
              "status" => "string (healthy)"
            },
            "timestamp_ms" => "integer",
            "timestamp" => "string (ISO8601)"
          }
        },
        errors: [
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp metrics_spec do
    %{
      method: "GET",
      path: "/metrics",
      description: "System metrics endpoint",
      request: %{
        query_params: %{
          "status" => "string (optional, 'force_error' for testing)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "rps" => "number",
            "latency" => %{
              "p50" => "number",
              "p95" => "number",
              "p99" => "number"
            },
            "error_rate" => "number",
            "nats" => %{
              "connected" => "boolean"
            }
          }
        },
        errors: [
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  # Messages API specs

  defp messages_list_spec do
    %{
      method: "GET",
      path: "/api/v1/messages",
      description: "List messages with filters and pagination",
      request: %{
        query_params: %{
          "status" => "string (optional, filter by status)",
          "type" => "string (optional, filter by type)",
          "search" => "string (optional, search query)",
          "limit" => "integer (optional, default: 20)",
          "offset" => "integer (optional, default: 0)",
          "sort" => "string (optional, sort field)",
          "order" => "string (optional, asc/desc)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "data" => "array of message objects",
            "pagination" => %{
              "total" => "integer",
              "limit" => "integer",
              "offset" => "integer",
              "has_more" => "boolean"
            }
          }
        },
        errors: [
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp messages_create_spec do
    %{
      method: "POST",
      path: "/api/v1/messages",
      description: "Create a new message",
      request: %{
        body: %{
          "type" => "string (required)",
          "status" => "string (required)",
          "prompt" => "string (required, max 8k)",
          "response" => "string (optional)",
            "model" => "string (optional)",
            "temperature" => "number (optional, 0.0-2.0)",
            "user_id" => "string (optional)",
            "session_id" => "string (optional)",
            "tenant" => "string (optional)",
            "tags" => "array of strings (optional)"
        }
      },
      response: %{
        success: %{
          status: 201,
          schema: %{
            "id" => "string",
            "type" => "string",
            "status" => "string",
            "created_at" => "string (ISO8601)"
          }
        },
        errors: [
          %{status: 400, body: %{"error" => "string", "validation_errors" => "object"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp messages_get_spec do
    %{
      method: "GET",
      path: "/api/v1/messages/:id",
      description: "Get a single message by ID",
      request: %{
        path_params: %{
          "id" => "string (required, message ID)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "id" => "string",
            "type" => "string",
            "status" => "string",
            "prompt" => "string",
            "response" => "string",
            "created_at" => "string (ISO8601)",
            "updated_at" => "string (ISO8601)"
          }
        },
        errors: [
          %{status: 404, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp messages_update_spec do
    %{
      method: "PUT",
      path: "/api/v1/messages/:id",
      description: "Update an existing message",
      request: %{
        path_params: %{
          "id" => "string (required, message ID)"
        },
        body: %{
          "type" => "string (optional)",
          "status" => "string (optional)",
          "prompt" => "string (optional)",
          "response" => "string (optional)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "id" => "string",
            "updated_at" => "string (ISO8601)"
          }
        },
        errors: [
          %{status: 404, body: %{"error" => "string"}},
          %{status: 400, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp messages_delete_spec do
    %{
      method: "DELETE",
      path: "/api/v1/messages/:id",
      description: "Delete a message",
      request: %{
        path_params: %{
          "id" => "string (required, message ID)"
        }
      },
      response: %{
        success: %{
          status: 204,
          body: "empty"
        },
        errors: [
          %{status: 404, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp messages_bulk_delete_spec do
    %{
      method: "POST",
      path: "/api/v1/messages/bulk_delete",
      description: "Delete multiple messages in bulk",
      request: %{
        body: %{
          "message_ids" => "array of strings (required)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "deleted_count" => "integer",
            "failed" => "array of strings (IDs that failed to delete)"
          }
        },
        errors: [
          %{status: 400, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp messages_export_spec do
    %{
      method: "POST",
      path: "/api/v1/messages/export",
      description: "Export messages to JSON or CSV",
      request: %{
        body: %{
          "message_ids" => "array of strings (required)",
          "format" => "string (required, 'json' or 'csv')"
        }
      },
      response: %{
        success: %{
          status: 200,
          content_type: "application/json or text/csv",
          body: "binary (file content)"
        },
        errors: [
          %{status: 400, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  # Extensions API specs

  defp extensions_list_spec do
    %{
      method: "GET",
      path: "/api/v1/extensions",
      description: "List extensions with filters",
      request: %{
        query_params: %{
          "type" => "string (optional, filter by type)",
          "status" => "string (optional, filter by status)",
          "limit" => "integer (optional, default: 20)",
          "offset" => "integer (optional, default: 0)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "data" => "array of extension objects",
            "pagination" => %{
              "total" => "integer",
              "limit" => "integer",
              "offset" => "integer",
              "has_more" => "boolean"
            }
          }
        },
        errors: [
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp extensions_create_spec do
    %{
      method: "POST",
      path: "/api/v1/extensions",
      description: "Create a new extension",
      request: %{
        body: %{
          "name" => "string (required)",
          "type" => "string (required)",
          "nats_subject" => "string (required)",
          "health_check_url" => "string (optional)",
          "metadata" => "object (optional)",
          "tags" => "array of strings (optional)"
        }
      },
      response: %{
        success: %{
          status: 201,
          schema: %{
            "id" => "string",
            "name" => "string",
            "created_at" => "string (ISO8601)"
          }
        },
        errors: [
          %{status: 400, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp extensions_get_spec do
    %{
      method: "GET",
      path: "/api/v1/extensions/:id",
      description: "Get a single extension by ID",
      request: %{
        path_params: %{
          "id" => "string (required, extension ID)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "id" => "string",
            "name" => "string",
            "type" => "string",
            "enabled" => "boolean",
            "created_at" => "string (ISO8601)"
          }
        },
        errors: [
          %{status: 404, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp extensions_update_spec do
    %{
      method: "PUT",
      path: "/api/v1/extensions/:id",
      description: "Update an existing extension",
      request: %{
        path_params: %{
          "id" => "string (required, extension ID)"
        },
        body: %{
          "name" => "string (optional)",
          "nats_subject" => "string (optional)",
          "health_check_url" => "string (optional)",
          "metadata" => "object (optional)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "id" => "string",
            "updated_at" => "string (ISO8601)"
          }
        },
        errors: [
          %{status: 404, body: %{"error" => "string"}},
          %{status: 400, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp extensions_patch_spec do
    %{
      method: "PATCH",
      path: "/api/v1/extensions/:id",
      description: "Partially update an extension (e.g., toggle enabled/disabled)",
      request: %{
        path_params: %{
          "id" => "string (required, extension ID)"
        },
        body: %{
          "enabled" => "boolean (optional)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "id" => "string",
            "enabled" => "boolean",
            "updated_at" => "string (ISO8601)"
          }
        },
        errors: [
          %{status: 404, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp extensions_delete_spec do
    %{
      method: "DELETE",
      path: "/api/v1/extensions/:id",
      description: "Delete an extension",
      request: %{
        path_params: %{
          "id" => "string (required, extension ID)"
        }
      },
      response: %{
        success: %{
          status: 204,
          body: "empty"
        },
        errors: [
          %{status: 404, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  # Policies API specs

  defp policies_list_spec do
    %{
      method: "GET",
      path: "/api/v1/policies/:tenant_id",
      description: "List policies for a tenant",
      request: %{
        path_params: %{
          "tenant_id" => "string (required, tenant ID)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "items" => "array of policy objects"
          }
        },
        errors: [
          %{status: 404, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp policies_get_spec do
    %{
      method: "GET",
      path: "/api/v1/policies/:tenant_id/:policy_id",
      description: "Get a single policy",
      request: %{
        path_params: %{
          "tenant_id" => "string (required)",
          "policy_id" => "string (required)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "tenant_id" => "string",
            "policy_id" => "string",
            "rules" => "array of rule objects",
            "created_at" => "string (ISO8601)"
          }
        },
        errors: [
          %{status: 404, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp policies_update_spec do
    %{
      method: "PUT",
      path: "/api/v1/policies/:tenant_id/:policy_id",
      description: "Update a policy",
      request: %{
        path_params: %{
          "tenant_id" => "string (required)",
          "policy_id" => "string (required)"
        },
        body: %{
          "rules" => "array of rule objects (required)"
        }
      },
      response: %{
        success: %{
          status: 200,
          schema: %{
            "tenant_id" => "string",
            "policy_id" => "string",
            "updated_at" => "string (ISO8601)"
          }
        },
        errors: [
          %{status: 404, body: %{"error" => "string"}},
          %{status: 400, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  defp policies_delete_spec do
    %{
      method: "DELETE",
      path: "/api/v1/policies/:tenant_id/:policy_id",
      description: "Delete a policy",
      request: %{
        path_params: %{
          "tenant_id" => "string (required)",
          "policy_id" => "string (required)"
        }
      },
      response: %{
        success: %{
          status: 204,
          body: "empty"
        },
        errors: [
          %{status: 404, body: %{"error" => "string"}},
          %{status: 500, body: %{"error" => "string"}}
        ]
      }
    }
  end

  @doc """
  Export API specification to JSON Schema format.
  """
  @spec to_json_schema() :: map()
  def to_json_schema do
    endpoints()
    |> Enum.map(fn {key, spec} ->
      {key, build_json_schema(spec)}
    end)
    |> Map.new()
  end

  defp build_json_schema(spec) do
    %{
      "method" => spec.method,
      "path" => spec.path,
      "description" => spec.description,
      "request" => build_request_schema(spec.request),
      "response" => build_response_schema(spec.response)
    }
  end

  defp build_request_schema(request) when is_map(request) do
    %{
      "query_params" => Map.get(request, :query_params) || Map.get(request, "query_params") || %{},
      "path_params" => Map.get(request, :path_params) || Map.get(request, "path_params") || %{},
      "body" => Map.get(request, :body) || Map.get(request, "body") || %{}
    }
  end

  defp build_response_schema(response) when is_map(response) do
    %{
      "success" => Map.get(response, :success) || Map.get(response, "success") || %{},
      "errors" => Map.get(response, :errors) || Map.get(response, "errors") || []
    }
  end
end

