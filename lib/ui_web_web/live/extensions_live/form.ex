defmodule UiWebWeb.ExtensionsLive.Form do
  @moduledoc """
  Form LiveView for creating and editing Extensions.
  """
  use UiWebWeb, :live_view

  alias UiWeb.Schemas.Extension
  alias UiWeb.Services.ExtensionsClient
  alias UiWebWeb.GatewayErrorHelper

  @impl true
  def mount(params, _session, socket) do
    extension_id = Map.get(params, "id")

    socket =
      socket
      |> assign(:page_title, if(extension_id, do: "Edit Extension", else: "New Extension"))
      |> assign(:extension_id, extension_id)
      |> assign(:loading, extension_id != nil)
      |> load_extension(extension_id)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    extension_id = Map.get(params, "id")

    socket =
      socket
      |> assign(:extension_id, extension_id)
      |> assign(:page_title, if(extension_id, do: "Edit Extension", else: "New Extension"))
      |> assign(:loading, extension_id != nil)
      |> load_extension(extension_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"extension" => params}, socket) do
    # Convert tags string to array if present
    params = normalize_tags(params)

    changeset =
      %Extension{}
      |> Extension.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"extension" => params}, socket) do
    # Convert tags string to array if present
    params = normalize_tags(params)

    changeset = Extension.changeset(%Extension{}, params)

    if changeset.valid? do
      save_extension(socket, params)
    else
      {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("check_health", %{"endpoint" => endpoint}, socket) do
    case Req.get(endpoint, receive_timeout: 5_000) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:noreply, put_flash(socket, :info, "✓ Health endpoint reachable (#{status})")}

      {:ok, %Req.Response{status: status}} ->
        msg = GatewayErrorHelper.format_gateway_error({:http_error, status, %{}})
        {:noreply, put_flash(socket, :error, "✗ Health check failed. " <> msg)}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, put_flash(socket, :error, "✗ Health check failed. " <> msg)}
    end
  rescue
    e ->
      msg = GatewayErrorHelper.format_gateway_error(e)
      {:noreply, put_flash(socket, :error, "✗ Health check failed. " <> msg)}
  end

  @impl true
  def handle_event("generate_subject", %{"type" => type, "name" => name}, socket) do
    if name && name != "" && type && type != "" do
      # Normalize name: lowercase, replace spaces with hyphens
      normalized_name =
        name
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9-]/, "-")
        |> String.replace(~r/-+/, "-")
        |> String.trim("-")

      subject = "beamline.extensions.#{type}.#{normalized_name}.v1"

      # Update changeset with generated subject
      changeset =
        socket.assigns.changeset
        |> Ecto.Changeset.put_change(:nats_subject, subject)

      {:noreply, assign(socket, :changeset, changeset)}
    else
      {:noreply, put_flash(socket, :error, "Please enter name and type first")}
    end
  end

  defp load_extension(socket, nil) do
    changeset = Extension.changeset(%Extension{}, %{})
    assign(socket, changeset: changeset, loading: false)
  end

  defp load_extension(socket, extension_id) do
    case ExtensionsClient.get_extension(extension_id) do
      {:ok, extension} ->
        # Convert API response to attrs for changeset
        attrs = Extension.from_api(extension)
        changeset = Extension.changeset(%Extension{}, attrs)
        assign(socket, changeset: changeset, loading: false)

      {:error, _reason} ->
        socket
        |> put_flash(:error, "Extension not found")
        |> push_navigate(to: ~p"/app/#{socket.assigns.tenant_id}/extensions")
    end
  end

  defp save_extension(socket, params) do
    result =
      if socket.assigns.extension_id do
        ExtensionsClient.update_extension(socket.assigns.extension_id, params)
      else
        ExtensionsClient.create_extension(params)
      end

    case result do
      {:ok, _extension} ->
        socket
        |> put_flash(:info, "Extension #{if socket.assigns.extension_id, do: "updated", else: "created"} successfully")
        |> push_navigate(to: ~p"/app/#{socket.assigns.tenant_id}/extensions")
        |> then(&{:noreply, &1})

      {:error, {:http_error, 422, %{"errors" => errors}}} ->
        changeset =
          %Extension{}
          |> Extension.changeset(params)
          |> add_server_errors(errors)

        {:noreply, assign(socket, :changeset, changeset)}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, put_flash(socket, :error, "Failed to save. " <> msg)}
    end
  end

  defp add_server_errors(changeset, errors) do
    Enum.reduce(errors, changeset, fn {field, messages}, acc ->
      Enum.reduce(messages, acc, fn message, acc2 ->
        Ecto.Changeset.add_error(acc2, String.to_atom(field), message)
      end)
    end)
  end

  # Helper functions for template
  def format_tags_for_input(nil), do: ""
  def format_tags_for_input([]), do: ""
  def format_tags_for_input(tags) when is_list(tags) do
    Enum.join(tags, ", ")
  end
  def format_tags_for_input(_), do: ""

  def get_metadata_tags(changeset) do
    case get_in(changeset.changes, [:metadata]) do
      %{tags: tags} when is_list(tags) -> tags
      _ ->
        case get_in(changeset.data, [:metadata]) do
          %{tags: tags} when is_list(tags) -> tags
          _ -> []
        end
    end
  end

  def get_metadata_field(changeset, field) do
    case get_in(changeset.changes, [:metadata]) do
      %{^field => value} when not is_nil(value) -> value || ""
      _ ->
        case get_in(changeset.data, [:metadata]) do
          %{^field => value} -> value || ""
          _ -> ""
        end
    end
  end

  def get_config_field(changeset, field, default) do
    case get_in(changeset.changes, [:config]) do
      %{^field => value} when not is_nil(value) -> value
      _ ->
        case get_in(changeset.data, [:config]) do
          %{^field => value} -> value
          _ -> default
        end
    end
  end

  defp normalize_tags(params) do
    case get_in(params, ["metadata", "tags"]) do
      tags when is_binary(tags) ->
        tags_list =
          tags
          |> String.split(~r/,\s*/)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        put_in(params, ["metadata", "tags"], tags_list)

      _ ->
        params
    end
  end

  @impl true
  def handle_info({:tags_updated, "extension-tags", tags}, socket) do
    # Update changeset with new tags
    current_metadata = get_in(socket.assigns.changeset.data, [:metadata]) || %{}

    changeset =
      socket.assigns.changeset
      |> Ecto.Changeset.put_change(:metadata, %{
        author: Map.get(current_metadata, :author),
        tags: tags,
        docs_url: Map.get(current_metadata, :docs_url)
      })

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_info({:preview_result, component_id, result}, socket) do
    # Forward preview result to component
    send_update(UiWebWeb.Components.URLPreview,
      id: component_id,
      preview_result: result
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
