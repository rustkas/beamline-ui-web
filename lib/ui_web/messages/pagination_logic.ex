defmodule UiWeb.Messages.PaginationLogic do
  @moduledoc """
  Pure functions for pagination offset calculations.
  
  These functions are used by MessagesLive.Index to ensure consistent
  pagination behavior and are covered by property-based tests.
  """

  @doc """
  Calculates next page offset.
  
  ## Examples
  
      iex> PaginationLogic.next_offset(0, 50, true)
      50
      
      iex> PaginationLogic.next_offset(50, 50, false)
      50
  """
  @spec next_offset(non_neg_integer(), pos_integer(), boolean()) :: non_neg_integer()
  def next_offset(offset, limit, has_more) when offset >= 0 and limit > 0 do
    if has_more do
      offset + limit
    else
      offset
    end
  end

  @doc """
  Calculates previous page offset.
  
  Never returns negative values - clamps to 0.
  
  ## Examples
  
      iex> PaginationLogic.prev_offset(50, 50)
      0
      
      iex> PaginationLogic.prev_offset(0, 50)
      0
      
      iex> PaginationLogic.prev_offset(25, 50)
      0
  """
  @spec prev_offset(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def prev_offset(offset, limit) when offset >= 0 and limit > 0 do
    new_offset = offset - limit

    if new_offset < 0 do
      0
    else
      new_offset
    end
  end
end

