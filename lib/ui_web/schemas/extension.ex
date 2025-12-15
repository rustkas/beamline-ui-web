defmodule UiWeb.Schemas.Extension do
  @moduledoc """
  Extension schema with validation for NATS subject, version, and health endpoint.
  Uses Ecto.Changeset for validation without requiring Ecto.Schema.
  """
  import Ecto.Changeset

  @types ~w(provider validator pre post)
  @nats_subject_regex ~r/^beamline\.extensions\.(provider|validator|pre|post)\.[a-z0-9-]+\.v\d+(alpha|beta)?$/

  @required_fields [:name, :type, :nats_subject, :version]
  @optional_fields [:description, :health_endpoint, :enabled, :id]

  defstruct [
    :id,
    :name,
    :type,
    :description,
    :nats_subject,
    :version,
    :health_endpoint,
    :enabled,
    metadata: %{author: nil, tags: [], docs_url: nil},
    config: %{timeout_ms: 30000, max_retries: 3}
  ]

  def changeset(extension \\ %__MODULE__{}, attrs \\ %{}) do
    extension
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> cast_metadata(attrs)
    |> cast_config(attrs)
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, @types)
    |> validate_nats_subject()
    |> validate_version_format()
    |> validate_name_format()
    |> validate_health_endpoint()
  end

  defp cast_metadata(changeset, attrs) do
    case attrs["metadata"] || attrs[:metadata] do
      nil -> changeset
      metadata when is_map(metadata) ->
        # Validate metadata fields
        metadata_validated =
          metadata
          |> Map.put("author", metadata["author"] || metadata[:author])
          |> Map.put("tags", normalize_tags(metadata["tags"] || metadata[:tags] || []))
          |> Map.put("docs_url", metadata["docs_url"] || metadata[:docs_url])

        # Validate docs_url if present
        metadata_validated =
          if metadata_validated["docs_url"] && metadata_validated["docs_url"] != "" do
            if Regex.match?(~r/^https?:\/\//, metadata_validated["docs_url"]) do
              metadata_validated
            else
              add_error(changeset, :metadata, "docs_url must be valid URL")
              metadata_validated
            end
          else
            metadata_validated
          end

        put_change(changeset, :metadata, metadata_validated)
      _ -> changeset
    end
  end

  defp cast_config(changeset, attrs) do
    case attrs["config"] || attrs[:config] do
      nil -> changeset
      config when is_map(config) ->
        timeout_ms = config["timeout_ms"] || config[:timeout_ms] || 30000
        max_retries = config["max_retries"] || config[:max_retries] || 3

        changeset =
          if timeout_ms <= 0 || timeout_ms >= 300_000 do
            add_error(changeset, :config, "timeout_ms must be between 1 and 300000")
          else
            changeset
          end

        changeset =
          if max_retries < 0 || max_retries >= 10 do
            add_error(changeset, :config, "max_retries must be between 0 and 9")
          else
            changeset
          end

        put_change(changeset, :config, %{
          "timeout_ms" => timeout_ms,
          "max_retries" => max_retries
        })
      _ -> changeset
    end
  end

  defp normalize_tags(nil), do: []
  defp normalize_tags(tags) when is_list(tags), do: tags
  defp normalize_tags(tags) when is_binary(tags) do
    tags
    |> String.split(~r/,\s*/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
  defp normalize_tags(_), do: []

  defp validate_nats_subject(changeset) do
    validate_change(changeset, :nats_subject, fn :nats_subject, subject ->
      cond do
        !Regex.match?(@nats_subject_regex, subject) ->
          [nats_subject: "must match pattern: beamline.extensions.{type}.{name}.v{N}"]

        !subject_matches_type?(changeset, subject) ->
          [nats_subject: "subject type must match extension type"]

        true ->
          []
      end
    end)
  end

  defp subject_matches_type?(changeset, subject) do
    type = get_field(changeset, :type)
    type && String.contains?(subject, ".#{type}.")
  end

  defp validate_version_format(changeset) do
    validate_format(changeset, :version, ~r/^\d+\.\d+\.\d+$/,
      message: "must be semantic version (e.g., 1.0.0)")
  end

  defp validate_name_format(changeset) do
    validate_format(changeset, :name, ~r/^[a-z0-9-]+$/,
      message: "must be lowercase alphanumeric with hyphens")
  end

  defp validate_health_endpoint(changeset) do
    case get_change(changeset, :health_endpoint) do
      nil -> changeset
      "" -> changeset
      endpoint ->
        validate_change(changeset, :health_endpoint, fn _, _ ->
          case check_health_reachable(endpoint) do
            :ok -> []
            {:error, reason} -> [health_endpoint: "not reachable: #{reason}"]
          end
        end)
    end
  end

  defp check_health_reachable(endpoint) do
    case Req.get(endpoint, receive_timeout: 5_000) do
      {:ok, %Req.Response{status: status}} when status in 200..299 -> :ok
      {:ok, %Req.Response{status: status}} -> {:error, "returned #{status}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  rescue
    _ -> {:error, "invalid URL or connection failed"}
  end


  # Helper to convert from API response to attrs for changeset
  def from_api(api_data) when is_map(api_data) do
    base = %{
      "id" => api_data["id"],
      "name" => api_data["name"],
      "type" => api_data["type"],
      "description" => api_data["description"],
      "nats_subject" => api_data["nats_subject"],
      "version" => api_data["version"],
      "health_endpoint" => api_data["health_endpoint"],
      "enabled" => api_data["enabled"] || false
    }

    base =
      if api_data["metadata"] do
        Map.put(base, "metadata", %{
          "author" => api_data["metadata"]["author"],
          "tags" => api_data["metadata"]["tags"] || [],
          "docs_url" => api_data["metadata"]["docs_url"]
        })
      else
        base
      end

    if api_data["config"] do
      Map.put(base, "config", %{
        "timeout_ms" => api_data["config"]["timeout_ms"] || 30000,
        "max_retries" => api_data["config"]["max_retries"] || 3
      })
    else
      base
    end
  end
end

