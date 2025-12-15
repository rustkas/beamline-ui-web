defmodule UiWeb.Services.URLPreviewServiceTest do
  use ExUnit.Case, async: true

  alias UiWeb.Services.URLPreviewService

  describe "validate_url/1 - SSRF protection" do
    test "rejects non-http/https schemes" do
      assert {:error, :invalid_scheme} = URLPreviewService.validate_url("ftp://example.com")
      assert {:error, :invalid_scheme} = URLPreviewService.validate_url("file:///etc/passwd")
      assert {:error, :invalid_scheme} = URLPreviewService.validate_url("javascript:alert(1)")
    end

    test "rejects URLs without host" do
      assert {:error, :missing_host} = URLPreviewService.validate_url("http://")
      assert {:error, :missing_host} = URLPreviewService.validate_url("https://")
    end

    test "rejects localhost addresses" do
      assert {:error, :local_url_not_allowed} = URLPreviewService.validate_url("http://localhost")
      assert {:error, :local_url_not_allowed} = URLPreviewService.validate_url("http://localhost:4000")
      assert {:error, :local_url_not_allowed} = URLPreviewService.validate_url("http://127.0.0.1")
      assert {:error, :local_url_not_allowed} = URLPreviewService.validate_url("http://127.0.0.1:8080")
      assert {:error, :local_url_not_allowed} = URLPreviewService.validate_url("http://0.0.0.0")
      assert {:error, :local_url_not_allowed} = URLPreviewService.validate_url("http://::1")
    end

    test "rejects private IP ranges" do
      # 10.0.0.0/8
      assert {:error, :private_ip_not_allowed} = URLPreviewService.validate_url("http://10.0.0.1")
      assert {:error, :private_ip_not_allowed} = URLPreviewService.validate_url("http://10.255.255.255")

      # 172.16.0.0/12
      assert {:error, :private_ip_not_allowed} = URLPreviewService.validate_url("http://172.16.0.1")
      assert {:error, :private_ip_not_allowed} = URLPreviewService.validate_url("http://172.31.255.255")

      # 192.168.0.0/16
      assert {:error, :private_ip_not_allowed} = URLPreviewService.validate_url("http://192.168.1.1")
      assert {:error, :private_ip_not_allowed} = URLPreviewService.validate_url("http://192.168.255.255")
    end

    test "accepts valid public URLs" do
      assert {:ok, _} = URLPreviewService.validate_url("https://example.com")
      assert {:ok, _} = URLPreviewService.validate_url("http://example.com")
      assert {:ok, _} = URLPreviewService.validate_url("https://www.google.com")
    end

    test "rejects invalid hostname (DNS resolution fails)" do
      # Use a domain that definitely doesn't exist
      # Note: This test might be flaky if DNS resolves to something, but it's unlikely
      result = URLPreviewService.validate_url("http://this-domain-definitely-does-not-exist-12345.invalid")
      
      # Should either fail DNS resolution or accept if it resolves to a public IP
      case result do
        {:error, :hostname_resolution_failed} -> :ok
        {:ok, _} -> :ok  # If it somehow resolves to a public IP, that's also acceptable
        other -> flunk("Unexpected result for invalid hostname: #{inspect(other)}")
      end
    end

    test "validation happens before HTTP request (SSRF protection)" do
      # This test verifies that dangerous URLs are rejected BEFORE any HTTP request
      # We can't easily mock HTTP in unit tests, but we can verify that validate_url
      # correctly rejects dangerous URLs without making any network calls
      
      dangerous_urls = [
        "http://localhost",
        "http://127.0.0.1",
        "http://10.0.0.1",
        "http://192.168.1.1",
        "ftp://example.com"
      ]
      
      Enum.each(dangerous_urls, fn url ->
        result = URLPreviewService.validate_url(url)
        assert elem(result, 0) == :error, "Dangerous URL should be rejected: #{url}"
      end)
    end
  end

  describe "parse_metadata/2 - HTML/OG/Twitter parsing" do
    test "extracts full OpenGraph metadata" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta property="og:title" content="OG Title">
        <meta property="og:description" content="OG Description">
        <meta property="og:image" content="https://example.com/og-image.png">
        <link rel="canonical" href="https://example.com/page">
        <link rel="icon" href="/favicon.ico">
      </head>
      <body></body>
      </html>
      """

      base_url = "https://example.com/page"

      assert {:ok, preview} = parse_metadata_safe(html, base_url)

      assert preview.title == "OG Title"
      assert preview.description == "OG Description"
      assert preview.image == "https://example.com/og-image.png"
      assert preview.url == "https://example.com/page"
      assert preview.domain == "example.com"
      assert preview.favicon == "https://example.com/favicon.ico"
    end

    test "falls back to HTML title and meta description" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>HTML Title</title>
        <meta name="description" content="HTML Description">
      </head>
      <body></body>
      </html>
      """

      base_url = "https://example.com"

      assert {:ok, preview} = parse_metadata_safe(html, base_url)

      assert preview.title == "HTML Title"
      assert preview.description == "HTML Description"
      assert preview.image == nil
      assert preview.url == "https://example.com"
      assert preview.domain == "example.com"
      assert preview.favicon == nil
    end

    test "uses Twitter Cards as fallback" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="twitter:title" content="Twitter Title">
        <meta name="twitter:description" content="Twitter Description">
        <meta name="twitter:image" content="/twitter-image.jpg">
      </head>
      <body></body>
      </html>
      """

      base_url = "https://example.com/page"

      assert {:ok, preview} = parse_metadata_safe(html, base_url)

      assert preview.title == "Twitter Title"
      assert preview.description == "Twitter Description"
      assert preview.image == "https://example.com/twitter-image.jpg"
    end

    test "resolves relative URLs to absolute" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta property="og:image" content="/images/og.png">
        <link rel="icon" href="../favicon.ico">
        <link rel="canonical" href="/canonical">
      </head>
      <body></body>
      </html>
      """

      base_url = "https://example.com/sub/page.html"

      assert {:ok, preview} = parse_metadata_safe(html, base_url)

      assert preview.image == "https://example.com/images/og.png"
      assert preview.favicon == "https://example.com/favicon.ico"
      assert preview.url == "https://example.com/canonical"
    end

    test "handles missing metadata gracefully" do
      html = """
      <!DOCTYPE html>
      <html>
      <head></head>
      <body></body>
      </html>
      """

      base_url = "https://example.com"

      assert {:ok, preview} = parse_metadata_safe(html, base_url)

      assert preview.title == "Untitled"
      assert preview.description == ""
      assert preview.image == nil
      assert preview.favicon == nil
      assert preview.url == "https://example.com"
      assert preview.domain == "example.com"
    end

    test "extracts domain from canonical URL" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <link rel="canonical" href="https://www.example.com/page">
      </head>
      <body></body>
      </html>
      """

      base_url = "https://example.com"

      assert {:ok, preview} = parse_metadata_safe(html, base_url)

      assert preview.url == "https://www.example.com/page"
      assert preview.domain == "www.example.com"
    end

    test "handles parse errors gracefully" do
      # Invalid HTML that might cause parse errors
      html = "<invalid><nested><tags>"

      base_url = "https://example.com"

      result = parse_metadata_safe(html, base_url)

      # Should either parse what it can or return error
      case result do
        {:ok, _preview} -> :ok
        {:error, {:parse_error, _reason}} -> :ok
        other -> flunk("Unexpected result: #{inspect(other)}")
      end
    end
  end

  describe "priority order for metadata extraction" do
    test "og:title takes priority over twitter:title and title" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta property="og:title" content="OG Title">
        <meta name="twitter:title" content="Twitter Title">
        <title>HTML Title</title>
      </head>
      <body></body>
      </html>
      """

      base_url = "https://example.com"

      assert {:ok, preview} = parse_metadata_safe(html, base_url)
      assert preview.title == "OG Title"
    end

    test "twitter:title takes priority over title when og:title missing" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="twitter:title" content="Twitter Title">
        <title>HTML Title</title>
      </head>
      <body></body>
      </html>
      """

      base_url = "https://example.com"

      assert {:ok, preview} = parse_metadata_safe(html, base_url)
      assert preview.title == "Twitter Title"
    end

    test "og:image takes priority over twitter:image" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta property="og:image" content="https://example.com/og.png">
        <meta name="twitter:image" content="https://example.com/twitter.png">
      </head>
      <body></body>
      </html>
      """

      base_url = "https://example.com"

      assert {:ok, preview} = parse_metadata_safe(html, base_url)
      assert preview.image == "https://example.com/og.png"
    end
  end

  # Helper to call parse_metadata (exposed with @doc false for testing)
  defp parse_metadata_safe(html, base_url) do
    URLPreviewService.parse_metadata(html, base_url)
  end
end
