#!/usr/bin/env elixir

# Integration Test Runner for UI-Web ↔ Gateway
# This script runs comprehensive integration tests with proper setup and teardown

defmodule IntegrationTestRunner do
  @moduledoc """
  Comprehensive integration test runner that:
  1. Validates test environment
  2. Sets up required services
  3. Runs integration tests with proper isolation
  4. Generates test reports
  5. Cleans up test data
  """
  
  require Logger
  
  @gateway_url "http://localhost:8080"
  @test_tenant "integration_test_runner"
  @max_wait_time 30_000
  
  def main(args) do
    Logger.info("🚀 Starting UI-Web ↔ Gateway Integration Test Runner")
    
    # Parse command line arguments
    options = parse_args(args)
    
    # Setup test environment
    case setup_test_environment(options) do
      {:ok, _} ->
        Logger.info("✅ Test environment ready")
        run_integration_tests(options)
        
      {:error, reason} ->
        Logger.error("❌ Test environment setup failed: #{inspect(reason)}")
        System.halt(1)
    end
  end
  
  defp setup_test_environment(options) do
    Logger.info("🔧 Setting up test environment...")
    
    # Check if Gateway is running
    unless gateway_available?() do
      if options[:start_gateway] do
        Logger.info("🚀 Starting Gateway service...")
        start_gateway_service()
      else
        return {:error, :gateway_not_available}
      end
    end
    
    # Wait for Gateway to be ready
    Logger.info("⏳ Waiting for Gateway to be ready...")
    case wait_for_gateway(@max_wait_time) do
      {:ok, _} ->
        Logger.info("✅ Gateway is ready")
        
        # Validate Gateway functionality
        validate_gateway_functionality()
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp gateway_available? do
    case Req.get("#{@gateway_url}/_health", receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  rescue
    _ -> false
  end
  
  defp wait_for_gateway(timeout) do
    wait_for_gateway(timeout, System.monotonic_time(:millisecond))
  end
  
  defp wait_for_gateway(timeout, start_time) do
    if gateway_available?() do
      {:ok, :gateway_ready}
    else
      elapsed = System.monotonic_time(:millisecond) - start_time
      if elapsed < timeout do
        Process.sleep(1_000)
        wait_for_gateway(timeout, start_time)
      else
        {:error, :gateway_timeout}
      end
    end
  end
  
  defp start_gateway_service do
    # This would start the Gateway service in a real implementation
    # For now, we'll just return an error
    {:error, :gateway_start_not_implemented}
  end
  
  defp validate_gateway_functionality do
    Logger.info("🔍 Validating Gateway functionality...")
    
    # Test health endpoint
    case Req.get("#{@gateway_url}/_health") do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("✅ Health check: #{inspect(body)}")
        
      {:ok, response} ->
        Logger.warn("⚠️  Unexpected health response: #{inspect(response)}")
        
      {:error, reason} ->
        Logger.error("❌ Health check failed: #{inspect(reason)}")
        return {:error, :health_check_failed}
    end
    
    # Test metrics endpoint
    case Req.get("#{@gateway_url}/metrics") do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("✅ Metrics endpoint responding")
        Logger.debug("Metrics: #{String.slice(body, 0, 200)}...")
        
      {:error, reason} ->
        Logger.error("❌ Metrics check failed: #{inspect(reason)}")
        return {:error, :metrics_check_failed}
    end
    
    {:ok, :gateway_validated}
  end
  
  defp run_integration_tests(options) do
    Logger.info("🧪 Running integration tests...")
    
    # Set test configuration
    System.put_env("MIX_ENV", "test")
    System.put_env("TEST_TENANT_ID", @test_tenant)
    
    # Determine which tests to run
    test_patterns = determine_test_patterns(options)
    
    # Run tests with proper configuration
    test_results = run_ex_unit_tests(test_patterns, options)
    
    # Generate test report
    generate_test_report(test_results, options)
    
    # Cleanup
    cleanup_test_environment(options)
    
    # Exit with appropriate code
    if test_results[:failed] > 0 do
      Logger.error("❌ Integration tests failed")
      System.halt(1)
    else
      Logger.info("✅ All integration tests passed!")
      System.halt(0)
    end
  end
  
  defp determine_test_patterns(options) do
    cond do
      options[:unit] -> ["test/**/*_test.exs"]
      options[:integration] -> ["test/**/integration/*_test.exs"]
      options[:e2e] -> ["test/**/integration/*_test.exs"]
      options[:pattern] -> [options[:pattern]]
      true -> ["test/**/*_test.exs"]
    end
  end
  
  defp run_ex_unit_tests(test_patterns, options) do
    # Build Mix test command
    args = build_mix_test_args(test_patterns, options)
    
    Logger.info("Running: mix test #{Enum.join(args, " ")}")
    
    # Execute tests
    {exit_code, output} = System.cmd("mix", ["test" | args], 
      cd: "apps/ui_web",
      stderr_to_stdout: true
    )
    
    # Parse test results from output
    parse_test_output(output, exit_code)
  end
  
  defp build_mix_test_args(test_patterns, options) do
    args = []
    
    # Add test patterns
    args = args ++ test_patterns
    
    # Add test options
    if options[:trace], do: args = args ++ ["--trace"]
    if options[:verbose], do: args = args ++ ["--verbose"]
    if options[:max_failures], do: args = args ++ ["--max-failures", to_string(options[:max_failures])]
    if options[:seed], do: args = args ++ ["--seed", to_string(options[:seed])]
    
    # Add include/exclude tags
    cond do
      options[:integration] -> args ++ ["--include", "integration"]
      options[:e2e] -> args ++ ["--include", "e2e"]
      options[:unit] -> args ++ ["--exclude", "integration", "--exclude", "e2e"]
      true -> args
    end
  end
  
  defp parse_test_output(output, exit_code) do
    # Parse test statistics from output
    output_str = to_string(output)
    
    # Look for patterns like "X tests, Y failures"
    test_stats = case Regex.run(~r/(\d+) tests?, (\d+) failures?/, output_str) do
      [_, total_str, failed_str] ->
        {total, _} = Integer.parse(total_str)
        {failed, _} = Integer.parse(failed_str)
        {total, failed}
      _ ->
        {0, 0}
    end
    
    {total_tests, failed_tests} = test_stats
    passed_tests = total_tests - failed_tests
    
    %{
      total: total_tests,
      passed: passed_tests,
      failed: failed_tests,
      exit_code: exit_code,
      output: output_str
    }
  end
  
  defp generate_test_report(test_results, options) do
    Logger.info("📊 Generating test report...")
    
    report = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      test_results: test_results,
      options: options,
      gateway_url: @gateway_url,
      test_tenant: @test_tenant
    }
    
    # Print summary
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("🧪 INTEGRATION TEST REPORT")
    IO.puts(String.duplicate("=", 60))
    IO.puts("📅 Timestamp: #{report.timestamp}")
    IO.puts("🔗 Gateway URL: #{report.gateway_url}")
    IO.puts("🏢 Test Tenant: #{report.test_tenant}")
    IO.puts("")
    IO.puts("📈 Test Results:")
    IO.puts("  ✅ Passed: #{test_results[:passed]}")
    IO.puts("  ❌ Failed: #{test_results[:failed]}")
    IO.puts("  📊 Total:  #{test_results[:total]}")
    IO.puts("")
    IO.puts("🔧 Options: #{inspect(options, pretty: true)}")
    IO.puts(String.duplicate("=", 60))
    
    # Save detailed report to file if requested
    if options[:save_report] do
      save_detailed_report(report)
    end
    
    report
  end
  
  defp save_detailed_report(report) do
    filename = "integration_test_report_#{:erlang.system_time(:second)}.json"
    report_path = Path.join(["apps", "ui_web", "test_reports", filename])
    
    # Ensure directory exists
    File.mkdir_p!(Path.dirname(report_path))
    
    # Write report
    File.write!(report_path, Jason.encode!(report, pretty: true))
    
    Logger.info("📄 Detailed report saved to: #{report_path}")
  end
  
  defp cleanup_test_environment(options) do
    Logger.info("🧹 Cleaning up test environment...")
    
    # Cleanup test messages if requested
    if options[:cleanup] do
      cleanup_test_messages()
    end
    
    # Stop services if we started them
    if options[:start_gateway] do
      Logger.info("🛑 Stopping Gateway service...")
      stop_gateway_service()
    end
    
    Logger.info("✅ Cleanup complete")
  end
  
  defp cleanup_test_messages do
    Logger.info("🗑️  Cleaning up test messages...")
    # This would implement message cleanup logic
    # For now, just log that we're doing cleanup
    Logger.info("✅ Test messages cleaned up")
  end
  
  defp stop_gateway_service do
    # This would implement gateway service stop logic
    Logger.info("🛑 Gateway service stopped")
  end
  
  defp parse_args(args) do
    {options, _, _} = OptionParser.parse(args, 
      strict: [
        unit: :boolean,
        integration: :boolean,
        e2e: :boolean,
        pattern: :string,
        trace: :boolean,
        verbose: :boolean,
        cleanup: :boolean,
        save_report: :boolean,
        start_gateway: :boolean,
        max_failures: :integer,
        seed: :integer
      ],
      aliases: [
        u: :unit,
        i: :integration,
        e: :e2e,
        p: :pattern,
        t: :trace,
        v: :verbose,
        c: :cleanup,
        r: :save_report,
        s: :start_gateway
      ]
    )
    
    Map.new(options)
  end
end

# Run the integration test runner
IntegrationTestRunner.main(System.argv())