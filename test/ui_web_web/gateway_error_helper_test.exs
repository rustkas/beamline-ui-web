defmodule UiWebWeb.GatewayErrorHelperTest do
  use ExUnit.Case, async: true

  alias UiWebWeb.GatewayErrorHelper

  describe "format_gateway_error/1" do
    test "formats HTTP 500 error" do
      result = GatewayErrorHelper.format_gateway_error({:http_error, 500, %{}})
      assert result =~ "temporarily unavailable"
      assert result =~ "HTTP 500"
      assert result =~ "Please try again later"
    end

    test "formats HTTP 404 error" do
      result = GatewayErrorHelper.format_gateway_error({:http_error, 404, %{}})
      assert result =~ "Resource not found"
      assert result =~ "404"
      assert result =~ "deleted or never existed"
    end

    test "formats HTTP 429 rate limit error" do
      result = GatewayErrorHelper.format_gateway_error({:http_error, 429, %{}})
      assert result =~ "rate limiting"
      assert result =~ "try again in a moment"
    end

    test "formats HTTP 4xx client errors" do
      result = GatewayErrorHelper.format_gateway_error({:http_error, 400, %{}})
      assert result =~ "Gateway request failed"
      assert result =~ "HTTP 400"
      assert result =~ "check your input"
    end

    test "formats HTTP 5xx server errors" do
      result = GatewayErrorHelper.format_gateway_error({:http_error, 503, %{}})
      assert result =~ "temporarily unavailable"
      assert result =~ "HTTP 503"
    end

    test "formats timeout error" do
      result = GatewayErrorHelper.format_gateway_error(:timeout)
      assert result =~ "did not respond in time"
      assert result =~ "timeout"
      assert result =~ "try again later"
    end

    test "formats nxdomain error" do
      result = GatewayErrorHelper.format_gateway_error(:nxdomain)
      assert result =~ "host name could not be resolved"
      assert result =~ "check your Gateway URL configuration"
    end

    test "formats econnrefused error" do
      result = GatewayErrorHelper.format_gateway_error(:econnrefused)
      assert result =~ "Connection to Gateway was refused"
      assert result =~ "C-Gateway is running on port 8080"
    end

    test "formats enotfound error" do
      result = GatewayErrorHelper.format_gateway_error(:enotfound)
      assert result =~ "host not found"
      assert result =~ "check your Gateway URL configuration"
    end

    test "formats Req.TransportError" do
      error = %Req.TransportError{reason: :timeout}
      result = GatewayErrorHelper.format_gateway_error(error)
      assert result =~ "timeout"
    end

    test "formats Req.Error" do
      error = %Req.Error{reason: :econnrefused}
      result = GatewayErrorHelper.format_gateway_error(error)
      assert result =~ "Connection to Gateway was refused"
    end

    test "formats generic atom error" do
      result = GatewayErrorHelper.format_gateway_error(:enoent)
      assert result =~ "Gateway request failed"
    end

    test "formats unexpected error format" do
      result = GatewayErrorHelper.format_gateway_error("unexpected string")
      assert result =~ "Unexpected Gateway error occurred"
    end

    test "formats nested Req error" do
      error = {:req, %{reason: :timeout}}
      result = GatewayErrorHelper.format_gateway_error(error)
      assert result =~ "timeout"
    end
  end
end

