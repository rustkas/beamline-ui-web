defmodule UiWeb.Messages.PaginationLogicPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias UiWeb.Messages.PaginationLogic

  property "prev_offset never goes below 0" do
    check all offset <- integer(0..10_000),
              limit <- positive_integer() do
      result = PaginationLogic.prev_offset(offset, limit)

      assert result >= 0, "prev_offset must be non-negative, got: #{result}"
    end
  end

  property "next_offset increases by limit when has_more is true" do
    check all offset <- integer(0..10_000),
              limit <- positive_integer() do
      result = PaginationLogic.next_offset(offset, limit, true)

      assert result == offset + limit,
             "next_offset should be offset + limit when has_more=true, got: #{result}, expected: #{offset + limit}"
    end
  end

  property "next_offset stays the same when has_more is false" do
    check all offset <- integer(0..10_000),
              limit <- positive_integer() do
      result = PaginationLogic.next_offset(offset, limit, false)

      assert result == offset,
             "next_offset should equal offset when has_more=false, got: #{result}, expected: #{offset}"
    end
  end

  property "prev followed by next (with has_more) does not decrease offset" do
    check all offset <- integer(0..10_000),
              limit <- positive_integer() do
      prev = PaginationLogic.prev_offset(offset, limit)
      has_more = prev + limit < offset + limit
      next = PaginationLogic.next_offset(prev, limit, has_more)

      assert next >= offset - limit,
             "prev->next should not decrease offset too much, got: #{next}, offset was: #{offset}"
    end
  end

  property "from page 0, offset is always 0 or a multiple of limit" do
    check all total <- integer(1..1_000),
              limit <- integer(1..1_000),
              actions <- list_of(member_of([:next, :prev]), max_length: 100) do
      # Стартуем строго с первой страницы (offset = 0)
      final_offset =
        Enum.reduce(actions, 0, fn action, acc ->
          # Инварианты на каждом шаге
          assert acc >= 0, "offset must be non-negative, got: #{acc}"
          assert acc < total, "offset must be less than total, got: #{acc}, total: #{total}"
          # КЛЮЧЕВОЙ инвариант: offset всегда кратен limit
          assert rem(acc, limit) == 0 || acc == 0,
                 "offset must be multiple of limit or 0, got: #{acc}, limit: #{limit}"

          case action do
            :next ->
              has_more = acc + limit < total
              PaginationLogic.next_offset(acc, limit, has_more)

            :prev ->
              PaginationLogic.prev_offset(acc, limit)
          end
        end)

      # Финальные инварианты
      assert final_offset >= 0, "final offset must be non-negative, got: #{final_offset}"
      assert final_offset < total, "final offset must be less than total, got: #{final_offset}, total: #{total}"
      assert rem(final_offset, limit) == 0 || final_offset == 0,
             "final offset must be multiple of limit or 0, got: #{final_offset}, limit: #{limit}"
    end
  end

  property "sequence of next/prev keeps offset within [0, total)" do
    check all total <- integer(1..1_000),
              limit <- integer(1..1_000),
              initial_offset <- integer(0..1_000),
              actions <- list_of(member_of([:next, :prev]), max_length: 100) do
      # Нормализуем стартовый offset в диапазон [0, total)
      offset0 = rem(initial_offset, total)

      final_offset =
        Enum.reduce(actions, offset0, fn action, acc ->
          # Инварианты на каждом шаге
          assert acc >= 0, "offset must be non-negative, got: #{acc}"
          assert acc < total, "offset must be less than total, got: #{acc}, total: #{total}"

          case action do
            :next ->
              has_more = acc + limit < total
              PaginationLogic.next_offset(acc, limit, has_more)

            :prev ->
              PaginationLogic.prev_offset(acc, limit)
          end
        end)

      # Инварианты для финального значения
      assert final_offset >= 0, "final offset must be non-negative, got: #{final_offset}"
      assert final_offset < total, "final offset must be less than total, got: #{final_offset}, total: #{total}"
    end
  end
end

