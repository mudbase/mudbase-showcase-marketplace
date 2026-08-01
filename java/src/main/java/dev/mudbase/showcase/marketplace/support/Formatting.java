package dev.mudbase.showcase.marketplace.support;

import java.text.NumberFormat;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Locale;

/** Formatting helpers shared by domain objects and templates - mirrors ../../web/src/lib/utils.ts. */
public final class Formatting {

  private static final DateTimeFormatter DISPLAY_DATE = DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.US);
  private static final DateTimeFormatter DISPLAY_DATETIME =
      DateTimeFormatter.ofPattern("MMM d, yyyy 'at' h:mm a", Locale.US);

  private Formatting() {}

  /** USD, no decimal places - mirrors the reference web app's `formatCurrency`. */
  public static String formatCurrency(double amount) {
    NumberFormat format = NumberFormat.getCurrencyInstance(Locale.US);
    format.setMaximumFractionDigits(0);
    return format.format(amount);
  }

  /**
   * A short relative timestamp ("3m", "5h", "2d") for recent listings/proposals, falling back to
   * an absolute date once something is more than a week old - mirrors the reference web app's
   * `formatRelativeTime`.
   */
  public static String formatRelativeTime(String iso) {
    if (iso == null || iso.isBlank()) {
      return "";
    }
    try {
      OffsetDateTime parsed = OffsetDateTime.parse(iso);
      long diffSeconds = Duration.between(parsed.toInstant(), Instant.now()).getSeconds();
      if (diffSeconds < 0) {
        return parsed.format(DISPLAY_DATE);
      }
      if (diffSeconds < 5) {
        return "just now";
      }
      if (diffSeconds < 60) {
        return diffSeconds + "s";
      }
      long diffMinutes = Math.round(diffSeconds / 60.0);
      if (diffMinutes < 60) {
        return diffMinutes + "m";
      }
      long diffHours = Math.round(diffMinutes / 60.0);
      if (diffHours < 24) {
        return diffHours + "h";
      }
      long diffDays = Math.round(diffHours / 24.0);
      if (diffDays < 7) {
        return diffDays + "d";
      }
      return parsed.format(DISPLAY_DATE);
    } catch (DateTimeParseException e) {
      return iso;
    }
  }

  /** Full date + time, used for message timestamps - mirrors `formatDateTime`. */
  public static String formatDateTime(String iso) {
    if (iso == null || iso.isBlank()) {
      return "";
    }
    try {
      return OffsetDateTime.parse(iso).format(DISPLAY_DATETIME);
    } catch (DateTimeParseException e) {
      return iso;
    }
  }

  /** Up to two initials from a display name, for the message-thread avatar chip. */
  public static String initials(String name) {
    if (name == null || name.isBlank()) {
      return "?";
    }
    String[] parts = name.trim().split("\\s+");
    String first = parts.length > 0 && !parts[0].isEmpty() ? parts[0].substring(0, 1) : "";
    String last = parts.length > 1 && !parts[parts.length - 1].isEmpty() ? parts[parts.length - 1].substring(0, 1) : "";
    String result = (first + last).toUpperCase(Locale.ROOT);
    return result.isBlank() ? "?" : result;
  }
}
