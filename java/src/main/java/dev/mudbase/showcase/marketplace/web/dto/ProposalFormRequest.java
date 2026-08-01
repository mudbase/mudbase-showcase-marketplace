package dev.mudbase.showcase.marketplace.web.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/** Cover letter + proposed rate - limits match the reference web app's zod schema exactly. */
public class ProposalFormRequest {

  @NotBlank(message = "Cover letter is required")
  @Size(min = 20, max = 5000, message = "Cover letter must be at least 20 characters")
  private String coverLetter = "";

  @NotNull(message = "Proposed rate is required")
  @Positive(message = "Proposed rate must be greater than 0")
  private Double proposedRate;

  public String getCoverLetter() {
    return coverLetter;
  }

  public void setCoverLetter(String coverLetter) {
    this.coverLetter = coverLetter;
  }

  public Double getProposedRate() {
    return proposedRate;
  }

  public void setProposedRate(Double proposedRate) {
    this.proposedRate = proposedRate;
  }
}
