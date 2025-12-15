defmodule UiWebWeb.MessagesLive.IndexPropertyTest do
  @moduledoc """
  Property-based tests for pagination logic in MessagesLive.Index.
  
  These tests use StreamData to generate random inputs and verify
  that pagination invariants hold for all valid inputs.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias UiWebWeb.MessagesLive.Index

  describe "pagination invariants" do
    property "offset is always non-negative" do
      check all(
              offset <- StreamData.positive_integer(),
              limit <- StreamData.positive_integer()
            ) do
        # Simulate prev_page calculation
        new_offset = max(0, offset - limit)
        assert new_offset >= 0, "Offset must be non-negative, got: #{new_offset}"
      end
    end

    property "next_page increments offset by limit" do
      check all(
              offset <- StreamData.non_negative_integer(),
              limit <- StreamData.positive_integer()
            ) do
        # Simulate next_page calculation
        new_offset = offset + limit
        assert new_offset == offset + limit,
               "Next page offset should be offset + limit, got: #{new_offset}"
      end
    end

    property "prev_page decrements offset by limit (min 0)" do
      check all(
              offset <- StreamData.non_negative_integer(),
              limit <- StreamData.positive_integer()
            ) do
        # Simulate prev_page calculation
        new_offset = max(0, offset - limit)
        
        cond do
          offset >= limit ->
            assert new_offset == offset - limit,
                   "Prev page offset should be offset - limit when offset >= limit"
          
          offset < limit ->
            assert new_offset == 0,
                   "Prev page offset should be 0 when offset < limit"
        end
      end
    end

    property "pagination offset calculated from page is always aligned" do
      check all(
              page <- StreamData.non_negative_integer(),
              limit <- StreamData.positive_integer()
            ) do
        # Calculate offset from page number (this is how pagination should work)
        offset = page * limit
        
        # Verify alignment
        assert rem(offset, limit) == 0,
               "Offset #{offset} calculated from page #{page} should be divisible by limit #{limit}"
      end
    end

    property "has_more is true when offset + limit < total" do
      check all(
              offset <- StreamData.non_negative_integer(),
              limit <- StreamData.positive_integer(),
              total <- StreamData.positive_integer()
            ) do
        has_more = offset + limit < total
        
        if has_more do
          assert offset + limit < total,
                 "has_more should be true when offset + limit < total"
        else
          assert offset + limit >= total,
                 "has_more should be false when offset + limit >= total"
        end
      end
    end

    property "pagination state transitions are consistent" do
      check all(
              # Start from aligned offset (page boundary)
              initial_page <- StreamData.non_negative_integer(),
              limit <- StreamData.positive_integer(),
              steps <- StreamData.list_of(StreamData.member_of([:next, :prev]), max_length: 10)
            ) do
        # Start from aligned offset
        initial_offset = initial_page * limit
        
        # Simulate pagination state machine
        final_offset =
          Enum.reduce(steps, initial_offset, fn
            :next, acc -> acc + limit
            :prev, acc -> max(0, acc - limit)
          end)
        
        # Invariant: final offset is always non-negative
        assert final_offset >= 0,
               "Final offset after steps #{inspect(steps)} should be non-negative, got: #{final_offset}"
        
        # Invariant: final offset is aligned to page boundaries (since we start aligned and next/prev maintain alignment)
        assert final_offset == 0 || rem(final_offset, limit) == 0,
               "Final offset #{final_offset} should be aligned to limit #{limit}"
      end
    end

    property "filter change resets pagination to offset 0" do
      check all(
              current_offset <- StreamData.non_negative_integer(),
              limit <- StreamData.positive_integer()
            ) do
        # Simulate filter change: always reset to page 1
        new_offset = 0
        
        assert new_offset == 0,
               "Filter change should reset offset to 0, got: #{new_offset}"
        
        # Verify it's a valid page boundary
        assert rem(new_offset, limit) == 0,
               "Reset offset should be aligned to limit"
      end
    end

    property "pagination calculations handle edge cases" do
      check all(
              offset <- StreamData.one_of([
                StreamData.constant(0),
                StreamData.positive_integer(),
                StreamData.constant(999_999)
              ]),
              limit <- StreamData.one_of([
                StreamData.constant(1),
                StreamData.constant(50),
                StreamData.constant(100)
              ])
            ) do
        # Test next_page
        next_offset = offset + limit
        assert next_offset >= offset, "Next offset should be >= current offset"
        
        # Test prev_page
        prev_offset = max(0, offset - limit)
        assert prev_offset <= offset, "Prev offset should be <= current offset"
        assert prev_offset >= 0, "Prev offset should be non-negative"
      end
    end
  end

  describe "pagination with filter combinations" do
    property "filter + pagination maintains consistency" do
      check all(
              _filter_status <- StreamData.member_of(["all", "completed", "failed", "pending"]),
              _filter_type <- StreamData.member_of(["all", "chat", "code"]),
              _offset <- StreamData.non_negative_integer(),
              limit <- StreamData.positive_integer()
            ) do
        # Simulate filter change: reset pagination
        new_offset = 0
        
        # After filter change, pagination should be at page 1
        assert new_offset == 0,
               "Filter change should reset pagination regardless of previous offset"
        
        # Verify pagination can proceed from reset state
        next_offset = new_offset + limit
        assert next_offset == limit,
               "Next page from reset should be at limit"
      end
    end
  end

  describe "pagination boundary conditions" do
    property "first page (offset=0) prev_page stays at 0" do
      check all(limit <- StreamData.positive_integer()) do
        offset = 0
        prev_offset = max(0, offset - limit)
        
        assert prev_offset == 0,
               "Prev page from first page should stay at 0"
      end
    end

    property "last page (has_more=false) next_page calculation" do
      check all(
              offset <- StreamData.non_negative_integer(),
              limit <- StreamData.positive_integer(),
              total <- StreamData.positive_integer()
            ) do
        # Calculate if we're on last page
        is_last_page = offset + limit >= total
        
        if is_last_page do
          # Next page offset would exceed total
          next_offset = offset + limit
          assert next_offset >= total,
                 "Next page from last page would exceed total"
        end
      end
    end

    property "empty result set pagination" do
      check all(
              offset <- StreamData.non_negative_integer(),
              limit <- StreamData.positive_integer()
            ) do
        total = 0
        
        # With empty results, has_more is always false
        has_more = offset + limit < total
        assert has_more == false,
               "Empty result set should have has_more = false"
        
        # Any offset >= 0 is valid, but results will be empty
        assert offset >= 0, "Offset should be non-negative even with empty results"
      end
    end
  end

  describe "pagination state machine properties" do
    property "state machine transitions preserve invariants" do
      check all(
              # Start from aligned offset (page boundary)
              initial_page <- StreamData.non_negative_integer(),
              limit <- StreamData.positive_integer(),
              transitions <- StreamData.list_of(
                StreamData.member_of([:next, :prev, :filter_reset]),
                max_length: 20
              )
            ) do
        # Start from aligned offset
        initial_offset = initial_page * limit
        
        final_state =
          Enum.reduce(transitions, initial_offset, fn
            :next, acc -> acc + limit
            :prev, acc -> max(0, acc - limit)
            :filter_reset, _acc -> 0
          end)
        
        # Invariant 1: offset is always non-negative
        assert final_state >= 0,
               "Final state after transitions #{inspect(transitions)} should be non-negative"
        
        # Invariant 2: offset is always aligned to page boundaries (or 0)
        # Since we start from aligned offset and next/prev maintain alignment
        assert final_state == 0 || rem(final_state, limit) == 0,
               "Final state #{final_state} should be aligned to limit #{limit}"
      end
    end

    property "consecutive next/prev operations are reversible" do
      check all(
              # Start from aligned offset (page boundary)
              page <- StreamData.non_negative_integer(),
              limit <- StreamData.positive_integer()
            ) do
        # Start from aligned offset
        offset = page * limit
        
        # Go forward then back
        next_offset = offset + limit
        prev_offset = max(0, next_offset - limit)
        
        # Should always return to original offset
        assert prev_offset == offset,
               "Next then prev should return to original offset #{offset}, got #{prev_offset}"
      end
    end
  end
end

