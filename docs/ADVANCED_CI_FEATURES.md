# Advanced CI/CD Features

This document describes the advanced CI/CD features implemented for UI-Web testing infrastructure.

## Implemented Features

### 1. Unified QA Dashboard

**Status:** ✅ Implemented

**What:** HTML dashboard aggregating all QA metrics in one place.

**Features:**
- Code coverage metrics
- Property test results with seeds
- E2E test results
- Visual regression status
- Links to all artifacts
- Real-time metrics display

**Usage:**
```bash
# Generate dashboard locally
bash scripts/generate_qa_dashboard.sh

# Or with custom output
bash scripts/generate_qa_dashboard.sh --output reports/custom-dashboard.html
```

**CI Integration:**
- Automatically generated after test workflows complete
- Available as `qa-dashboard` artifact
- Updated on every test run

**Dashboard Sections:**
1. **Metrics Grid** - Key metrics at a glance
2. **Artifacts & Reports** - Links to all test artifacts
3. **Quick Links** - GitHub Actions, PRs, documentation

### 2. Auto-Labeling PRs

**Status:** ✅ Implemented

**What:** Automatic PR labeling based on file changes.

**Labels Applied:**
- `type:tests` - Changes in test files
- `type:ui` - Changes in UI/templates
- `type:docs` - Documentation changes
- `type:ci` - CI/CD changes
- `needs:mock-sync` - Requires mock gateway updates
- `needs:visual-update` - May need visual baseline updates

**Pattern Matching:**
- Test files: `test/**/*.exs`, `test/**/*.spec.js`
- UI files: `lib/**/live/**/*.ex`, `lib/**/templates/**/*.heex`
- Documentation: `docs/**/*.md`, `README.md`
- CI/CD: `.github/workflows/**/*.yml`, `scripts/**/*.sh`
- Mock gateway: `test/support/mock*.ex`

**Usage:**
- Automatic on PR open/update
- No manual action required
- Labels help reviewers understand PR scope

### 3. Flaky Test Detector

**Status:** ✅ Implemented

**What:** Detects flaky tests by running them multiple times.

**Features:**
- Runs tests up to 3 times (configurable)
- Tracks pass/fail patterns
- Identifies inconsistent tests
- Generates detailed reports

**Usage:**
```bash
# Manual trigger via GitHub Actions
# Or scheduled nightly at 2 AM UTC
```

**Configuration:**
- `test_path` - Test file to check
- `max_retries` - Number of retries (default: 3)

**Output:**
- JSON analysis file
- Summary in workflow
- Artifact with all run results

**Detection Logic:**
- Test is flaky if it both passes and fails across runs
- Reports pass/fail counts
- Helps prioritize test stability fixes

### 4. Matrix Testing

**Status:** ✅ Implemented

**What:** Tests across multiple Elixir/OTP versions and browsers.

**Matrix Configurations:**

#### Unit Tests Matrix
- Elixir: `1.15`, `1.16`
- OTP: `26`, `27`
- Total combinations: 4

#### E2E Tests Matrix
- Browsers: `chromium`, `firefox`, `webkit`
- Total combinations: 3

**Benefits:**
- Catch version-specific bugs
- Ensure cross-browser compatibility
- Validate on latest and previous versions

**Strategy:**
- `fail-fast: false` - All combinations run even if one fails
- Parallel execution for speed
- Individual artifacts per combination

### 5. Mermaid Lint

**Status:** ✅ Implemented

**What:** Validates Mermaid diagram syntax before PDF generation.

**Features:**
- Syntax validation
- Error reporting
- Prevents broken diagrams in documentation
- Integrated with PDF generation

**Usage:**
```bash
# Lint specific file
bash scripts/lint_mermaid.sh apps/ui_web/docs/MESSAGES_LIVE_EVENT_FLOWS.md

# Lint all diagrams
bash scripts/lint_mermaid.sh
```

**CI Integration:**
- Runs on push/PR to docs
- Blocks PDF generation if errors found
- Reports errors in workflow summary

**Validation:**
- Extracts all Mermaid code blocks
- Validates each diagram
- Reports syntax errors with context

## Workflow Dependencies

### QA Dashboard
- Depends on: Property Tests, E2E Visual, Test Coverage
- Triggers: After test workflows complete
- Generates: Unified HTML dashboard

### Auto-Labeling
- Triggers: PR open/update
- No dependencies
- Applies labels immediately

### Flaky Test Detector
- Triggers: Manual or scheduled (nightly)
- Depends on: Test infrastructure
- Generates: Flaky test analysis

### Matrix Testing
- Triggers: Push/PR
- No dependencies
- Runs in parallel

### Mermaid Lint
- Triggers: Push/PR to docs
- No dependencies
- Validates before PDF generation

## Best Practices

### Using QA Dashboard

1. **Check after each PR** - Review dashboard for overall health
2. **Monitor trends** - Track metrics over time
3. **Download artifacts** - Keep dashboard for historical reference

### Using Auto-Labeling

1. **Review labels** - Ensure correct categorization
2. **Remove incorrect labels** - Manually adjust if needed
3. **Use labels for filtering** - Filter PRs by type

### Using Flaky Test Detector

1. **Run on suspicious tests** - When tests fail intermittently
2. **Review nightly reports** - Check for new flaky tests
3. **Fix flaky tests** - Prioritize stability improvements

### Using Matrix Testing

1. **Monitor all combinations** - Check all matrix results
2. **Version-specific fixes** - Address version-specific issues
3. **Browser compatibility** - Ensure cross-browser support

### Using Mermaid Lint

1. **Run before commits** - Validate diagrams locally
2. **Fix syntax errors** - Address lint errors immediately
3. **Update diagrams** - Keep diagrams in sync with code

## Troubleshooting

### QA Dashboard Not Generated

**Problem:** Dashboard not appearing
**Solution:**
1. Check test workflows completed successfully
2. Verify artifacts were uploaded
3. Check workflow dependencies

### Labels Not Applied

**Problem:** PR not getting labels
**Solution:**
1. Check workflow permissions
2. Verify file patterns match
3. Check workflow logs for errors

### Flaky Tests Not Detected

**Problem:** Flaky tests not identified
**Solution:**
1. Increase retry count
2. Check test execution logs
3. Verify analysis script ran

### Matrix Tests Failing

**Problem:** Tests fail on specific versions
**Solution:**
1. Check version-specific issues
2. Review test compatibility
3. Update test code if needed

### Mermaid Lint Errors

**Problem:** Diagrams fail validation
**Solution:**
1. Check Mermaid syntax
2. Validate diagram structure
3. Test locally before committing

## Future Enhancements

### Planned

1. **Dashboard trends** - Historical metrics graphs
2. **Smart labeling** - ML-based label suggestions
3. **Flaky test auto-fix** - Automatic retry logic
4. **Matrix optimization** - Skip unnecessary combinations
5. **Diagram auto-fix** - Suggest syntax fixes

### Under Consideration

1. **Real-time dashboard** - Live metrics updates
2. **PR preview** - Dashboard preview in PR comments
3. **Test impact analysis** - Show affected tests
4. **Version compatibility matrix** - Track compatibility over time

## References

- [GitHub Actions Workflows](.github/workflows/)
- [QA Dashboard Script](scripts/generate_qa_dashboard.sh)
- [Mermaid Lint Script](scripts/lint_mermaid.sh)
- [CI Improvements Documentation](CI_IMPROVEMENTS.md)

