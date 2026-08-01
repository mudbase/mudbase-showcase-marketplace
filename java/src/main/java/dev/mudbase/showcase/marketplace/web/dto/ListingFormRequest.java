package dev.mudbase.showcase.marketplace.web.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/**
 * Shared shape for both "post listing" and "edit listing" forms - limits match the reference web
 * app's zod schema exactly (title 3-120, description min 20, budget positive, category max 60).
 * {@code status} is only rendered/submitted on the edit form; {@code clientId}/{@code clientName}
 * are never part of this form - they are set from the signed-in session server-side on create,
 * and never accepted from the client on update (see {@code ListingService#update}), precisely
 * because this task calls out never trusting a hidden field for ownership.
 */
public class ListingFormRequest {

  @NotBlank(message = "Title is required")
  @Size(min = 3, max = 120, message = "Title must be between 3 and 120 characters")
  private String title = "";

  @NotBlank(message = "Description is required")
  @Size(min = 20, max = 5000, message = "Description must be at least 20 characters")
  private String description = "";

  @NotNull(message = "Budget is required")
  @Positive(message = "Budget must be greater than 0")
  private Double budget;

  @Size(max = 60, message = "Category is too long")
  private String category = "";

  /** Only meaningful on the edit form - validated against {@code Listing.STATUSES} in the service. */
  private String status = "open";

  public String getTitle() {
    return title;
  }

  public void setTitle(String title) {
    this.title = title;
  }

  public String getDescription() {
    return description;
  }

  public void setDescription(String description) {
    this.description = description;
  }

  public Double getBudget() {
    return budget;
  }

  public void setBudget(Double budget) {
    this.budget = budget;
  }

  public String getCategory() {
    return category;
  }

  public void setCategory(String category) {
    this.category = category;
  }

  public String getStatus() {
    return status;
  }

  public void setStatus(String status) {
    this.status = status;
  }
}
