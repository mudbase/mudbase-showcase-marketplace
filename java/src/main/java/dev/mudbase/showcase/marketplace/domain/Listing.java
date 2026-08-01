package dev.mudbase.showcase.marketplace.domain;

import dev.mudbase.showcase.marketplace.mudbase.DocumentMapper;
import java.util.Map;
import java.util.Set;

/** Mirrors one row of the `listings` collection - see ../../../web/plan/build-plan.md. */
public class Listing {

  public static final String STATUS_OPEN = "open";
  public static final String STATUS_IN_PROGRESS = "in_progress";
  public static final String STATUS_COMPLETED = "completed";
  public static final Set<String> STATUSES = Set.of(STATUS_OPEN, STATUS_IN_PROGRESS, STATUS_COMPLETED);

  private final String id;
  private final String title;
  private final String description;
  private final double budget;
  private final String category;
  private final String status;
  private final String clientId;
  private final String clientName;
  private final String createdAt;

  private Listing(
      String id,
      String title,
      String description,
      double budget,
      String category,
      String status,
      String clientId,
      String clientName,
      String createdAt) {
    this.id = id;
    this.title = title;
    this.description = description;
    this.budget = budget;
    this.category = category;
    this.status = status;
    this.clientId = clientId;
    this.clientName = clientName;
    this.createdAt = createdAt;
  }

  public static Listing fromDocument(Map<String, Object> doc) {
    return new Listing(
        DocumentMapper.getId(doc),
        DocumentMapper.getString(doc, "title", "Untitled"),
        DocumentMapper.getString(doc, "description", ""),
        DocumentMapper.getDouble(doc, "budget", 0),
        DocumentMapper.getString(doc, "category"),
        DocumentMapper.getString(doc, "status", STATUS_OPEN),
        DocumentMapper.getString(doc, "clientId"),
        DocumentMapper.getString(doc, "clientName", "Someone"),
        DocumentMapper.getString(doc, "createdAt"));
  }

  public String getId() {
    return id;
  }

  public String getTitle() {
    return title;
  }

  public String getDescription() {
    return description;
  }

  public double getBudget() {
    return budget;
  }

  public String getCategory() {
    return category;
  }

  public boolean isHasCategory() {
    return category != null && !category.isBlank();
  }

  public String getStatus() {
    return status;
  }

  public String getStatusLabel() {
    if (STATUS_IN_PROGRESS.equals(status)) {
      return "In progress";
    }
    if (STATUS_COMPLETED.equals(status)) {
      return "Completed";
    }
    return "Open";
  }

  public String getClientId() {
    return clientId;
  }

  public String getClientName() {
    return clientName;
  }

  public String getCreatedAt() {
    return createdAt;
  }
}
