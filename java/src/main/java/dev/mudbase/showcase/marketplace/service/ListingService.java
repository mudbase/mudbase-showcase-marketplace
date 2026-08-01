package dev.mudbase.showcase.marketplace.service;

import dev.mudbase.showcase.marketplace.auth.AuthSession;
import dev.mudbase.showcase.marketplace.config.MudbaseProperties;
import dev.mudbase.showcase.marketplace.domain.Listing;
import dev.mudbase.showcase.marketplace.mudbase.DocumentMapper;
import dev.mudbase.showcase.marketplace.mudbase.MudbaseDataClient;
import dev.mudbase.showcase.marketplace.mudbase.PageResult;
import dev.mudbase.showcase.marketplace.support.ForbiddenActionException;
import dev.mudbase.showcase.marketplace.support.RoleSupport;
import dev.mudbase.showcase.marketplace.web.dto.ListingFormRequest;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;

/**
 * Reads and writes the `listings` collection. Every mutation re-derives ownership from a freshly
 * fetched document ({@code clientId}) before touching Mudbase - never from a hidden form field or
 * path parameter alone - per this task's explicit IDOR-hardening instruction (the same class of
 * bug just found and fixed in the sibling C# Events port's booking-cancellation handler).
 */
@Service
public class ListingService {

  private static final int CATEGORY_SAMPLE_LIMIT = 100;
  private static final String SEARCH_COLLECTION_SLUG = "listings";
  private static final int SEARCH_BATCH_LIMIT = 50;

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;

  public ListingService(MudbaseDataClient dataClient, MudbaseProperties properties) {
    this.dataClient = dataClient;
    this.properties = properties;
  }

  /**
   * Browse listings. When {@code search} is a non-blank keyword, uses the dedicated search
   * endpoint (server-side regex over title/description - the collection-data `filter` param
   * cannot do substring search, see MudbaseDataClient#search) and applies the category/budget
   * filters plus pagination client-side over the returned batch, mirroring the reference web
   * app's `matchesFilters` + manual slicing exactly (see ../../../web/src/app/page.tsx). Otherwise
   * uses a real server-side `filter` + pagination on category/budget.
   */
  public PageResult<Listing> browse(
      AuthSession actor, String search, String category, Double minBudget, Double maxBudget, int page, int limit) {
    String query = search == null ? "" : search.trim();
    if (!query.isEmpty()) {
      return searchBrowse(actor, query, category, minBudget, maxBudget, page, limit);
    }
    Map<String, Object> filter = new LinkedHashMap<>();
    if (category != null && !category.isBlank()) {
      filter.put("category", category);
    }
    Map<String, Object> budgetRange = new LinkedHashMap<>();
    if (minBudget != null) {
      budgetRange.put("$gte", minBudget);
    }
    if (maxBudget != null) {
      budgetRange.put("$lte", maxBudget);
    }
    if (!budgetRange.isEmpty()) {
      filter.put("budget", budgetRange);
    }
    PageResult<Map<String, Object>> raw =
        dataClient.listPage(actor.getToken(), properties.getListingsCollectionId(), filter, "-createdAt", page, limit);
    return new PageResult<>(
        raw.items().stream().map(Listing::fromDocument).toList(), raw.page(), raw.limit(), raw.total(), raw.hasMore());
  }

  private PageResult<Listing> searchBrowse(
      AuthSession actor, String query, String category, Double minBudget, Double maxBudget, int page, int limit) {
    List<Listing> matched =
        dataClient.search(actor.getToken(), query, SEARCH_COLLECTION_SLUG, SEARCH_BATCH_LIMIT).stream()
            .map(Listing::fromDocument)
            .filter(listing -> matchesClientSideFilters(listing, category, minBudget, maxBudget))
            .toList();
    int total = matched.size();
    int safeLimit = Math.max(limit, 1);
    int totalPages = Math.max(1, (int) Math.ceil(total / (double) safeLimit));
    int safePage = Math.min(Math.max(page, 1), totalPages);
    int from = Math.min((safePage - 1) * safeLimit, matched.size());
    int to = Math.min(from + safeLimit, matched.size());
    return new PageResult<>(matched.subList(from, to), safePage, limit, total, safePage < totalPages);
  }

  private boolean matchesClientSideFilters(Listing listing, String category, Double minBudget, Double maxBudget) {
    if (category != null && !category.isBlank() && !category.equals(listing.getCategory())) {
      return false;
    }
    if (minBudget != null && listing.getBudget() < minBudget) {
      return false;
    }
    return maxBudget == null || !(listing.getBudget() > maxBudget);
  }

  /** Distinct categories from a sample of listings, to populate the filter dropdown. */
  public List<String> categories(AuthSession actor) {
    List<Map<String, Object>> sample =
        dataClient.list(actor.getToken(), properties.getListingsCollectionId(), Map.of(), null, 1, CATEGORY_SAMPLE_LIMIT);
    Set<String> categories = new LinkedHashSet<>();
    for (Map<String, Object> doc : sample) {
      String category = DocumentMapper.getString(doc, "category");
      if (category != null && !category.isBlank()) {
        categories.add(category);
      }
    }
    return categories.stream().sorted().toList();
  }

  public Map<String, Object> getDocument(AuthSession actor, String id) {
    return dataClient.get(actor.getToken(), properties.getListingsCollectionId(), id);
  }

  public Listing get(AuthSession actor, String id) {
    return Listing.fromDocument(getDocument(actor, id));
  }

  public PageResult<Listing> myListings(AuthSession actor, int page, int limit) {
    PageResult<Map<String, Object>> raw =
        dataClient.listPage(
            actor.getToken(),
            properties.getListingsCollectionId(),
            Map.of("clientId", actor.getUserId()),
            "-createdAt",
            page,
            limit);
    return new PageResult<>(
        raw.items().stream().map(Listing::fromDocument).toList(), raw.page(), raw.limit(), raw.total(), raw.hasMore());
  }

  /** Client-only: posts a new listing, always `status=open`, `clientId`/`clientName` from the session. */
  public Listing create(AuthSession actor, ListingFormRequest form) {
    requireClient(actor, "post a listing");
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("title", form.getTitle().trim());
    body.put("description", form.getDescription().trim());
    body.put("budget", form.getBudget());
    if (form.getCategory() != null && !form.getCategory().isBlank()) {
      body.put("category", form.getCategory().trim());
    }
    body.put("status", Listing.STATUS_OPEN);
    body.put("clientId", actor.getUserId());
    body.put("clientName", actor.getDisplayName());
    return Listing.fromDocument(dataClient.create(actor.getToken(), properties.getListingsCollectionId(), body));
  }

  /**
   * Client-only, owner-only: edits a listing's title/description/budget/category/status.
   * Ownership is re-derived from the freshly fetched document's {@code clientId} - never from a
   * hidden form field - per this task's explicit IDOR-hardening instruction.
   */
  public Listing update(AuthSession actor, String id, ListingFormRequest form) {
    requireClient(actor, "edit a listing");
    Map<String, Object> existing = getDocument(actor, id);
    requireOwnListing(actor, existing);
    if (!Listing.STATUSES.contains(form.getStatus())) {
      throw new IllegalArgumentException("Unknown listing status: " + form.getStatus());
    }

    Map<String, Object> body = new LinkedHashMap<>();
    body.put("title", form.getTitle().trim());
    body.put("description", form.getDescription().trim());
    body.put("budget", form.getBudget());
    if (form.getCategory() != null && !form.getCategory().isBlank()) {
      body.put("category", form.getCategory().trim());
    }
    body.put("status", form.getStatus());
    return Listing.fromDocument(dataClient.update(actor.getToken(), properties.getListingsCollectionId(), id, body));
  }

  /**
   * Client-only, owner-only: deletes a listing. Ownership is re-derived from the freshly fetched
   * document's {@code clientId} - never from a hidden form field - per this task's explicit
   * IDOR-hardening instruction (the exact class of bug just found and fixed in the sibling C#
   * Events port's booking-cancellation handler).
   */
  public void delete(AuthSession actor, String id) {
    requireClient(actor, "delete a listing");
    Map<String, Object> existing = getDocument(actor, id);
    requireOwnListing(actor, existing);
    dataClient.delete(actor.getToken(), properties.getListingsCollectionId(), id);
  }

  /** Batched listing-title lookup for `/proposals/mine`, avoiding an N+1 query per proposal. */
  public Map<String, String> titlesFor(AuthSession actor, List<String> listingIds) {
    if (listingIds.isEmpty()) {
      return Map.of();
    }
    List<Map<String, Object>> raw =
        dataClient.list(
            actor.getToken(),
            properties.getListingsCollectionId(),
            Map.of("_id", Map.of("$in", listingIds)),
            null,
            1,
            listingIds.size());
    Map<String, String> titles = new LinkedHashMap<>();
    for (Map<String, Object> doc : raw) {
      titles.put(DocumentMapper.getId(doc), DocumentMapper.getString(doc, "title", "Untitled"));
    }
    return titles;
  }

  private void requireOwnListing(AuthSession actor, Map<String, Object> listingDoc) {
    String ownerId = DocumentMapper.getString(listingDoc, "clientId");
    if (ownerId == null || !ownerId.equals(actor.getUserId())) {
      throw new ForbiddenActionException("Only the client who posted this listing can manage it.");
    }
  }

  private void requireClient(AuthSession actor, String action) {
    if (!RoleSupport.isClient(actor.getRole())) {
      throw new ForbiddenActionException("Only a client account can " + action + ".");
    }
  }
}
