package dev.mudbase.showcase.marketplace.service;

import dev.mudbase.showcase.marketplace.auth.AuthSession;
import dev.mudbase.showcase.marketplace.config.MudbaseProperties;
import dev.mudbase.showcase.marketplace.domain.Proposal;
import dev.mudbase.showcase.marketplace.mudbase.DocumentMapper;
import dev.mudbase.showcase.marketplace.mudbase.MudbaseDataClient;
import dev.mudbase.showcase.marketplace.mudbase.PageResult;
import dev.mudbase.showcase.marketplace.support.ForbiddenActionException;
import dev.mudbase.showcase.marketplace.support.RoleSupport;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.stereotype.Service;

/**
 * Reads and writes the `proposals` collection.
 *
 * <p><b>Critical IDOR fix (per this task's explicit instruction).</b> {@link #decide} - the
 * accept/reject handler - never trusts a hidden {@code listingId} form field or the caller's
 * claim of ownership. It fetches the proposal itself first (so {@code listingId} comes from the
 * database, not the request), then fetches THAT listing and compares its {@code clientId} to the
 * acting session's own user id. Only if that freshly re-derived chain confirms "this proposal
 * belongs to a listing owned by the caller" does the status update proceed. This mirrors the
 * exact fix just made in the sibling C# Events port, whose booking-cancellation handler had
 * trusted a hidden form field for ownership instead of re-deriving it from the fetched booking
 * document. {@link #withdraw} applies the same discipline to a freelancer's own proposal.
 */
@Service
public class ProposalService {

  private static final int MAX_PROPOSALS = 200;

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;

  public ProposalService(MudbaseDataClient dataClient, MudbaseProperties properties) {
    this.dataClient = dataClient;
    this.properties = properties;
  }

  /** Freelancer-only: submits a new proposal on a listing, refusing a second proposal on the same listing. */
  public Proposal submit(AuthSession actor, String listingId, String coverLetter, double proposedRate) {
    requireFreelancer(actor, "submit a proposal");
    if (ownProposalForListing(actor, listingId).isPresent()) {
      throw new ForbiddenActionException("You've already submitted a proposal for this listing.");
    }
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("listingId", listingId);
    body.put("freelancerId", actor.getUserId());
    body.put("freelancerName", actor.getDisplayName());
    body.put("coverLetter", coverLetter);
    body.put("proposedRate", proposedRate);
    body.put("status", Proposal.STATUS_PENDING);
    return Proposal.fromDocument(dataClient.create(actor.getToken(), properties.getProposalsCollectionId(), body));
  }

  /** Every proposal on a listing, newest first - for the owning client's "proposals received" view. */
  public List<Proposal> forListing(AuthSession actor, String listingId) {
    return dataClient
        .list(actor.getToken(), properties.getProposalsCollectionId(), Map.of("listingId", listingId), "-createdAt", 1, MAX_PROPOSALS)
        .stream()
        .map(Proposal::fromDocument)
        .toList();
  }

  /** The acting freelancer's own proposal on a listing, if any. */
  public Optional<Proposal> ownProposalForListing(AuthSession actor, String listingId) {
    return dataClient
        .list(
            actor.getToken(),
            properties.getProposalsCollectionId(),
            Map.of("listingId", listingId, "freelancerId", actor.getUserId()),
            null,
            1,
            1)
        .stream()
        .findFirst()
        .map(Proposal::fromDocument);
  }

  /** The freelancer id of the (at most one) accepted proposal on a listing - see MessageService "messaging visibility". */
  public Optional<String> acceptedFreelancerId(AuthSession actor, String listingId) {
    return dataClient
        .list(
            actor.getToken(),
            properties.getProposalsCollectionId(),
            Map.of("listingId", listingId, "status", Proposal.STATUS_ACCEPTED),
            null,
            1,
            1)
        .stream()
        .findFirst()
        .map(doc -> DocumentMapper.getString(doc, "freelancerId"));
  }

  /**
   * Client-only: accepts or rejects a proposal on one of the caller's OWN listings. Ownership is
   * re-derived twice, both times from a fresh fetch, never from anything the request itself
   * asserts: first the proposal (to learn its real {@code listingId}), then that listing (to
   * learn its real {@code clientId}) - see class javadoc.
   */
  public Proposal decide(AuthSession actor, String proposalId, String newStatus) {
    requireClient(actor, "review a proposal");
    Map<String, Object> proposalDoc = dataClient.get(actor.getToken(), properties.getProposalsCollectionId(), proposalId);
    String listingId = DocumentMapper.getString(proposalDoc, "listingId");
    String currentStatus = DocumentMapper.getString(proposalDoc, "status", Proposal.STATUS_PENDING);

    Map<String, Object> listingDoc = dataClient.get(actor.getToken(), properties.getListingsCollectionId(), listingId);
    String listingOwnerId = DocumentMapper.getString(listingDoc, "clientId");
    if (listingOwnerId == null || !listingOwnerId.equals(actor.getUserId())) {
      throw new ForbiddenActionException("Only the client who posted this listing can review its proposals.");
    }
    if (!Proposal.STATUS_PENDING.equals(currentStatus)) {
      throw new ForbiddenActionException("This proposal has already been decided.");
    }

    Map<String, Object> updated =
        dataClient.update(actor.getToken(), properties.getProposalsCollectionId(), proposalId, Map.of("status", newStatus));
    return Proposal.fromDocument(updated);
  }

  /**
   * Freelancer-only: withdraws (deletes) the caller's own pending proposal. Ownership is
   * re-derived from the freshly fetched proposal's {@code freelancerId} - never from a hidden
   * form field - per this task's explicit IDOR-hardening instruction. Returns the proposal's
   * {@code listingId} so the controller can redirect back to the right listing page.
   */
  public String withdraw(AuthSession actor, String proposalId) {
    requireFreelancer(actor, "withdraw a proposal");
    Map<String, Object> proposalDoc = dataClient.get(actor.getToken(), properties.getProposalsCollectionId(), proposalId);
    String ownerId = DocumentMapper.getString(proposalDoc, "freelancerId");
    if (ownerId == null || !ownerId.equals(actor.getUserId())) {
      throw new ForbiddenActionException("You can only withdraw your own proposal.");
    }
    String listingId = DocumentMapper.getString(proposalDoc, "listingId");
    dataClient.delete(actor.getToken(), properties.getProposalsCollectionId(), proposalId);
    return listingId;
  }

  public PageResult<Proposal> myProposals(AuthSession actor, int page, int limit) {
    PageResult<Map<String, Object>> raw =
        dataClient.listPage(
            actor.getToken(),
            properties.getProposalsCollectionId(),
            Map.of("freelancerId", actor.getUserId()),
            "-createdAt",
            page,
            limit);
    return new PageResult<>(
        raw.items().stream().map(Proposal::fromDocument).toList(), raw.page(), raw.limit(), raw.total(), raw.hasMore());
  }

  /** Batched proposal counts per listing for `/listings/mine`, avoiding an N+1 query per listing. */
  public Map<String, Long> countsForListings(AuthSession actor, List<String> listingIds) {
    if (listingIds.isEmpty()) {
      return Map.of();
    }
    List<Map<String, Object>> raw =
        dataClient.list(
            actor.getToken(),
            properties.getProposalsCollectionId(),
            Map.of("listingId", Map.of("$in", listingIds)),
            null,
            1,
            MAX_PROPOSALS);
    Map<String, Long> counts = new LinkedHashMap<>();
    for (Map<String, Object> doc : raw) {
      String listingId = DocumentMapper.getString(doc, "listingId");
      counts.merge(listingId, 1L, Long::sum);
    }
    return counts;
  }

  private void requireClient(AuthSession actor, String action) {
    if (!RoleSupport.isClient(actor.getRole())) {
      throw new ForbiddenActionException("Only a client account can " + action + ".");
    }
  }

  private void requireFreelancer(AuthSession actor, String action) {
    if (!RoleSupport.isFreelancer(actor.getRole())) {
      throw new ForbiddenActionException("Only a freelancer account can " + action + ".");
    }
  }
}
