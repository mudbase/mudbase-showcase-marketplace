package dev.mudbase.showcase.marketplace.domain;

import dev.mudbase.showcase.marketplace.mudbase.DocumentMapper;
import java.util.Map;

/** Mirrors one row of the `proposals` collection - see ../../../web/plan/build-plan.md. */
public class Proposal {

  public static final String STATUS_PENDING = "pending";
  public static final String STATUS_ACCEPTED = "accepted";
  public static final String STATUS_REJECTED = "rejected";

  private final String id;
  private final String listingId;
  private final String freelancerId;
  private final String freelancerName;
  private final String coverLetter;
  private final double proposedRate;
  private final String status;
  private final String createdAt;

  private Proposal(
      String id,
      String listingId,
      String freelancerId,
      String freelancerName,
      String coverLetter,
      double proposedRate,
      String status,
      String createdAt) {
    this.id = id;
    this.listingId = listingId;
    this.freelancerId = freelancerId;
    this.freelancerName = freelancerName;
    this.coverLetter = coverLetter;
    this.proposedRate = proposedRate;
    this.status = status;
    this.createdAt = createdAt;
  }

  public static Proposal fromDocument(Map<String, Object> doc) {
    return new Proposal(
        DocumentMapper.getId(doc),
        DocumentMapper.getString(doc, "listingId"),
        DocumentMapper.getString(doc, "freelancerId"),
        DocumentMapper.getString(doc, "freelancerName", "Someone"),
        DocumentMapper.getString(doc, "coverLetter", ""),
        DocumentMapper.getDouble(doc, "proposedRate", 0),
        DocumentMapper.getString(doc, "status", STATUS_PENDING),
        DocumentMapper.getString(doc, "createdAt"));
  }

  public String getId() {
    return id;
  }

  public String getListingId() {
    return listingId;
  }

  public String getFreelancerId() {
    return freelancerId;
  }

  public String getFreelancerName() {
    return freelancerName;
  }

  public String getCoverLetter() {
    return coverLetter;
  }

  public double getProposedRate() {
    return proposedRate;
  }

  public String getStatus() {
    return status;
  }

  public String getStatusLabel() {
    if (STATUS_ACCEPTED.equals(status)) {
      return "Accepted";
    }
    if (STATUS_REJECTED.equals(status)) {
      return "Rejected";
    }
    return "Pending";
  }

  public boolean isPending() {
    return STATUS_PENDING.equals(status);
  }

  public String getCreatedAt() {
    return createdAt;
  }
}
