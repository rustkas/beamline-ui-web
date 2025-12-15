# Property-Based Tests CI Integration

This document describes the CI integration for property-based tests in UI-Web.

## Overview

Property-based tests use StreamData to generate random inputs and verify invariants. The CI workflow ensures reproducible test runs with seed tracking and shrinking reports.

## Workflow

The workflow `.github/workflows/ui-web-property-tests.yml` runs property tests with:

- **Seed tracking**: Each run uses a deterministic seed (GitHub run ID or provided seed)
- **Shrinking reports**: Failed properties include minimal failing examples
- **Generator coverage**: Analysis of which generators are used
- **Reproducible failures**: Failed tests can be reproduced locally using the reported seed

## Running Locally

### Basic Run

```bash
cd apps/ui_web
mix test test/ui_web_web/live/messages_live/index_property_test.exs
```

### With Specific Seed

```bash
mix test test/ui_web_web/live/messages_live/index_property_test.exs --seed 12345
```

### With Custom Max Runs

```bash
mix test test/ui_web_web/live/messages_live/index_property_test.exs --max-cases 200
```

### With Trace Output

```bash
mix test test/ui_web_web/live/messages_live/index_property_test.exs --trace
```

## CI Configuration

### Automatic Runs

Property tests run automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Changes to `apps/ui_web/**` or workflow file

### Manual Runs

Trigger manually via GitHub Actions UI:
1. Go to Actions → UI-Web Property Tests
2. Click "Run workflow"
3. Optionally provide:
   - **Seed**: Random seed for reproducible run
   - **Max Runs**: Maximum number of property test runs (default: 100)

## Seed Management

### Why Seeds Matter

Property tests use random generation. Seeds ensure:
- **Reproducibility**: Same seed = same test inputs
- **Debugging**: Failed tests can be reproduced exactly
- **Regression detection**: CI failures can be investigated locally

### CI Seed Strategy

1. **Default**: Uses GitHub `run_id` as seed (unique per run)
2. **Manual**: Can provide custom seed via workflow dispatch
3. **Failure**: Failed tests report the seed used

### Reproducing CI Failures

When CI fails:

1. Check the workflow summary for the seed:
   ```
   Seed: 1234567890
   ```

2. Reproduce locally:
   ```bash
   cd apps/ui_web
   mix test test/ui_web_web/live/messages_live/index_property_test.exs --seed 1234567890
   ```

3. Investigate the failure with the exact inputs that caused it

## Shrinking

### What is Shrinking?

When a property fails, StreamData automatically "shrinks" the failing input to find the minimal example that still fails.

### Shrinking Reports

CI captures shrinking information:
- Minimal failing input
- Generator that produced it
- Assertion that failed

### Example Shrinking Output

```
1) property pagination offset is always non-negative (UiWebWeb.MessagesLive.IndexPropertyTest)
   code: check all(
     offset <- StreamData.positive_integer(),
     limit <- StreamData.positive_integer()
   )
   
   Shrunk 5 times:
   * Clause:    offset <- StreamData.positive_integer()
     Generated:  1
   
   * Clause:    limit <- StreamData.positive_integer()
     Generated:  1
   
   Final offset -1 should be non-negative
```

## Generator Coverage

### Available Generators

Property tests use these StreamData generators:

- `StreamData.non_negative_integer()` - Non-negative integers (0, 1, 2, ...)
- `StreamData.positive_integer()` - Positive integers (1, 2, 3, ...)
- `StreamData.member_of([...])` - Enumeration values (e.g., ["all", "completed", "failed"])
- `StreamData.list_of(...)` - Lists of generated values
- `StreamData.constant(value)` - Fixed values

### Generator Analysis

CI workflow includes a job that analyzes:
- Total number of properties
- Types of generators used
- Test execution summary

## Artifacts

### Test Output

CI uploads:
- `property-test-output.txt` - Full test output with seeds and failures
- `property-test-shrinking/` - Detailed shrinking reports (on failure)

### Retention

Artifacts are retained for 30 days.

## Best Practices

### Writing Property Tests

1. **Use meaningful generators**: Choose generators that match your domain
2. **Test invariants**: Focus on properties that should always hold
3. **Keep tests fast**: Property tests run many iterations
4. **Document properties**: Use clear property names and descriptions

### Debugging Failures

1. **Reproduce with seed**: Always use the reported seed
2. **Check shrinking**: Minimal examples are easier to understand
3. **Verify invariants**: Ensure your property actually tests what you think
4. **Add edge cases**: Consider boundary conditions

### CI Integration

1. **Monitor seed usage**: Track which seeds cause failures
2. **Review shrinking reports**: Understand minimal failing cases
3. **Update properties**: Fix properties when invariants change
4. **Document changes**: Update property tests when behavior changes

## References

- [StreamData Documentation](https://hexdocs.pm/stream_data/)
- [ExUnitProperties Documentation](https://hexdocs.pm/ex_unit_properties/)
- `apps/ui_web/test/ui_web_web/live/messages_live/index_property_test.exs` - Property test implementation
- `.github/workflows/ui-web-property-tests.yml` - CI workflow

