package dev.mudbase.showcase.marketplace.mudbase;

import java.util.List;

/** One page of a Mudbase collection list call, carrying the pagination metadata. */
public record PageResult<T>(List<T> items, int page, int limit, long total, boolean hasMore) {

  public static <T> PageResult<T> empty(int page, int limit) {
    return new PageResult<>(List.of(), page, limit, 0, false);
  }

  /** Total page count, at least 1 even for an empty result set - keeps pagination templates simple. */
  public int totalPages() {
    int safeLimit = Math.max(limit, 1);
    return (int) Math.max(1, Math.ceil(total / (double) safeLimit));
  }
}
