package dev.mudbase.showcase.marketplace.service;

import dev.mudbase.showcase.marketplace.auth.AuthSession;
import dev.mudbase.showcase.marketplace.config.MudbaseProperties;
import dev.mudbase.showcase.marketplace.domain.Message;
import dev.mudbase.showcase.marketplace.mudbase.DocumentMapper;
import dev.mudbase.showcase.marketplace.mudbase.MudbaseDataClient;
import dev.mudbase.showcase.marketplace.support.ForbiddenActionException;
import dev.mudbase.showcase.marketplace.support.RoleSupport;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;

/**
 * Reads and writes the `messages` collection.
 *
 * <p><b>Messaging visibility (design decision, see ../../../web/plan/build-plan.md).</b> A
 * listing's message thread is visible only to the listing's client and the ONE freelancer whose
 * proposal on that listing has been accepted - not every freelancer who applied. {@link
 * #canAccessThread} re-derives both halves of that check from freshly fetched data every time:
 * the listing document's own {@code clientId} (never a hidden field), and - for a freelancer -
 * a live query for whether an accepted proposal on this listing belongs to the caller. This is
 * checked on both read (the controller only renders the thread when this returns true) and write
 * ({@link #send} refuses to post a message otherwise), so bypassing the UI's own gating buys an
 * attacker nothing.
 */
@Service
public class MessageService {

  private static final int MAX_MESSAGES = 200;

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;
  private final ProposalService proposalService;

  public MessageService(MudbaseDataClient dataClient, MudbaseProperties properties, ProposalService proposalService) {
    this.dataClient = dataClient;
    this.properties = properties;
    this.proposalService = proposalService;
  }

  public boolean canAccessThread(AuthSession actor, Map<String, Object> listingDoc) {
    String clientId = DocumentMapper.getString(listingDoc, "clientId");
    if (clientId != null && clientId.equals(actor.getUserId())) {
      return true;
    }
    if (!RoleSupport.isFreelancer(actor.getRole())) {
      return false;
    }
    String listingId = DocumentMapper.getId(listingDoc);
    return proposalService.acceptedFreelancerId(actor, listingId).map(id -> id.equals(actor.getUserId())).orElse(false);
  }

  public List<Message> forListing(AuthSession actor, String listingId) {
    return dataClient
        .list(actor.getToken(), properties.getMessagesCollectionId(), Map.of("listingId", listingId), "createdAt", 1, MAX_MESSAGES)
        .stream()
        .map(Message::fromDocument)
        .toList();
  }

  public void send(AuthSession actor, Map<String, Object> listingDoc, String content) {
    if (!canAccessThread(actor, listingDoc)) {
      throw new ForbiddenActionException("You don't have access to this listing's messages.");
    }
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("listingId", DocumentMapper.getId(listingDoc));
    body.put("senderId", actor.getUserId());
    body.put("senderName", actor.getDisplayName());
    body.put("content", content);
    dataClient.create(actor.getToken(), properties.getMessagesCollectionId(), body);
  }
}
