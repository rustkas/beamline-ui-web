defmodule UiWeb.Services.URLPreviewService do
  @moduledoc """
  Safe URL preview service with SSRF protection.
  
  Fetches HTML from URLs, parses OpenGraph/Twitter metadata,
  and returns normalized preview objects.
  
  ## Security
  
  - Validates URL scheme (http/https only)
  - Blocks localhost and private IP addresses
  - DNS resolution before HTTP request
  - Timeout and redirect limits
  
  ## Usage
  
      {:ok, preview} = URLPreviewService.fetch_preview("https://example.com")
      # => {:ok, %{title: "...", description: "...", image: "...", ...}}
  """

  require Logger

  @timeout 5_000
  @max_redirects 3
  @user_agent "BeamlineDocsPreview/1.0"

  @doc """
  Fetch URL preview with metadata extraction.
  
  ## Examples
  
      iex> URLPreviewService.fetch_preview("https://example.com")
      {:ok, %{title: "Example", description: "...", ...}}
      
      iex> URLPreviewService.fetch_preview("http://localhost")
      {:error, :local_url_not_allowed}
  """
  @spec fetch_preview(String.t()) :: {:ok, map()} | {:error, term()}
  def fetch_preview(url) when is_binary(url) do
    with {:ok, normalized_url} <- validate_url(url),
         {:ok, %{status: status, body: body}} when status in 200..299 <- fetch_html(normalized_url),
         {:ok, preview} <- parse_metadata(body, normalized_url) do
      {:ok, preview}
    else
      {:error, reason} -> {:error, reason}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      other -> {:error, other}
    end
  end

  # SSRF-safe URL validation

  @doc false
  @spec validate_url(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def validate_url(url) do
    with {:ok, uri} <- parse_uri(url),
         :ok <- validate_scheme(uri),
         :ok <- validate_host(uri),
         :ok <- validate_local_hosts(uri.host),
         :ok <- validate_private_ips(uri.host) do
      {:ok, normalize_url(uri)}
    end
  end

  defp parse_uri(url) do
    case URI.parse(url) do
      %URI{scheme: nil} -> {:error, :invalid_scheme}
      uri -> {:ok, uri}
    end
  end

  defp validate_scheme(%URI{scheme: scheme}) when scheme in ["http", "https"], do: :ok
  defp validate_scheme(_), do: {:error, :invalid_scheme}

  defp validate_host(%URI{host: nil, authority: authority}) when is_binary(authority) and authority != "" do
    # IPv6 address without brackets (e.g., "::1") ends up in authority, not host
    # Check if it's a localhost IPv6 address
    normalized = String.downcase(authority)
    if normalized == "::1" do
      {:error, :local_url_not_allowed}
    else
      :ok
    end
  end
  defp validate_host(%URI{host: nil}), do: {:error, :missing_host}
  defp validate_host(%URI{host: host}) when is_binary(host) and host != "", do: :ok
  defp validate_host(_), do: {:error, :missing_host}

  defp validate_local_hosts(host) when is_binary(host) do
    normalized = String.downcase(host)
    
    # Check for localhost hostnames and IPv4/IPv6 addresses
    local_hosts = ["localhost", "127.0.0.1", "0.0.0.0", "::1", "[::1]"]
    
    # Remove brackets for comparison
    normalized_no_brackets = String.replace(normalized, ~r/^\[|\]$/, "")
    
    is_localhost = 
      normalized in local_hosts or
      normalized_no_brackets == "::1"
    
    if is_localhost do
      {:error, :local_url_not_allowed}
    else
      :ok
    end
  end
  defp validate_local_hosts(_), do: :ok

  defp validate_private_ips(host) do
    case resolve_hostname(host) do
      {:ok, ip_addresses} ->
        if Enum.any?(ip_addresses, &is_private_ip?/1) do
          {:error, :private_ip_not_allowed}
        else
          :ok
        end

      {:error, _reason} ->
        {:error, :hostname_resolution_failed}
    end
  end

  defp resolve_hostname(host) do
    case :inet.gethostbyname(String.to_charlist(host)) do
      {:ok, {:hostent, _name, _aliases, _addrtype, _length, addresses}} ->
        {:ok, addresses}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp is_private_ip?({a, b, c, d}) when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d) do
    # 10.0.0.0/8
    (a == 10) or
      # 172.16.0.0/12
      (a == 172 and b >= 16 and b <= 31) or
      # 192.168.0.0/16
      (a == 192 and b == 168) or
      # 127.0.0.0/8 (loopback)
      (a == 127) or
      # 0.0.0.0
      (a == 0 and b == 0 and c == 0 and d == 0)
  end

  defp is_private_ip?(_), do: false

  defp normalize_url(%URI{} = uri) do
    URI.to_string(uri)
  end

  # HTTP fetch

  defp fetch_html(url) do
    req_opts = [
      receive_timeout: @timeout,
      max_redirects: @max_redirects,
      decode_body: false,
      headers: [
        {"User-Agent", @user_agent}
      ]
    ]

    case Req.get(url, req_opts) do
      {:ok, %Req.Response{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, %{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, reason} ->
        # Check if it's a timeout error by pattern matching on reason
        case reason do
          %{reason: :timeout} -> {:error, :timeout}
          %Req.TransportError{reason: :timeout} -> {:error, :timeout}
          _ ->
            Logger.error("URLPreviewService: HTTP fetch failed for #{url}: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  # HTML parsing

  @doc false
  # Exposed for testing - parse metadata from HTML without HTTP request
  def parse_metadata(html, base_url) when is_binary(html) and is_binary(base_url) do
    try do
      {:ok, doc} = Floki.parse_document(html)
      
      preview = %{
        title: extract_title(doc),
        description: extract_description(doc),
        image: extract_image(doc, base_url),
        url: extract_canonical_url(doc, base_url),
        domain: extract_domain(extract_canonical_url(doc, base_url)),
        favicon: extract_favicon(doc, base_url)
      }

      {:ok, preview}
    rescue
      error ->
        Logger.error("URLPreviewService: Parse error for #{base_url}: #{inspect(error)}")
        {:error, {:parse_error, Exception.message(error)}}
    end
  end

  defp extract_title(doc) do
    # Priority: og:title > twitter:title > <title>
    case Floki.find(doc, ~s(meta[property="og:title"])) do
      [] ->
        case Floki.find(doc, ~s(meta[name="twitter:title"])) do
          [] ->
            case Floki.find(doc, "title") do
              [] -> "Untitled"
              [title_elem] -> Floki.text(title_elem) |> String.trim()
            end

          [meta_elem] ->
            Floki.attribute(meta_elem, "content")
            |> List.first()
            |> case do
              nil -> "Untitled"
              content -> String.trim(content)
            end
        end

      [meta_elem] ->
        Floki.attribute(meta_elem, "content")
        |> List.first()
        |> case do
          nil -> "Untitled"
          content -> String.trim(content)
        end
    end
  end

  defp extract_description(doc) do
    # Priority: og:description > twitter:description > meta[name="description"]
    case Floki.find(doc, ~s(meta[property="og:description"])) do
      [] ->
        case Floki.find(doc, ~s(meta[name="twitter:description"])) do
          [] ->
            case Floki.find(doc, ~s(meta[name="description"])) do
              [] -> ""
              [meta_elem] ->
                Floki.attribute(meta_elem, "content")
                |> List.first()
                |> case do
                  nil -> ""
                  content -> String.trim(content)
                end
            end

          [meta_elem] ->
            Floki.attribute(meta_elem, "content")
            |> List.first()
            |> case do
              nil -> ""
              content -> String.trim(content)
            end
        end

      [meta_elem] ->
        Floki.attribute(meta_elem, "content")
        |> List.first()
        |> case do
          nil -> ""
          content -> String.trim(content)
        end
    end
  end

  defp extract_image(doc, base_url) do
    # Priority: og:image > twitter:image
    image_url =
      case Floki.find(doc, ~s(meta[property="og:image"])) do
        [] ->
          case Floki.find(doc, ~s(meta[name="twitter:image"])) do
            [] -> nil
            [meta_elem] -> Floki.attribute(meta_elem, "content") |> List.first()
          end

        [meta_elem] ->
          Floki.attribute(meta_elem, "content") |> List.first()
      end

    case image_url do
      nil -> nil
      url -> resolve_url(url, base_url)
    end
  end

  defp extract_canonical_url(doc, base_url) do
    case Floki.find(doc, ~s(link[rel="canonical"])) do
      [] -> base_url
      [link_elem] ->
        case Floki.attribute(link_elem, "href") |> List.first() do
          nil -> base_url
          href -> resolve_url(href, base_url)
        end
    end
  end

  defp extract_domain(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> ""
    end
  end

  defp extract_favicon(doc, base_url) do
    # Try link[rel="icon"] first, then link[rel="shortcut icon"]
    favicon_url =
      case Floki.find(doc, ~s(link[rel="icon"])) do
        [] ->
          case Floki.find(doc, ~s(link[rel="shortcut icon"])) do
            [] -> nil
            [link_elem] -> Floki.attribute(link_elem, "href") |> List.first()
          end

        [link_elem] ->
          Floki.attribute(link_elem, "href") |> List.first()
      end

    case favicon_url do
      nil -> nil
      url -> resolve_url(url, base_url)
    end
  end

  # URL resolution (relative -> absolute)

  defp resolve_url(url, base_url) when is_binary(url) and is_binary(base_url) do
    case URI.parse(url) do
      %URI{scheme: nil} ->
        # Relative URL - resolve against base_url
        case URI.parse(base_url) do
          %URI{} = base_uri ->
            resolved = URI.merge(base_uri, url)
            URI.to_string(resolved)

          _ ->
            url
        end

      %URI{} = absolute_uri ->
        # Already absolute
        URI.to_string(absolute_uri)
    end
  end
end

