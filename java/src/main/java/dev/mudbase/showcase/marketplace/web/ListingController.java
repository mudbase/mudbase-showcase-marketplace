package dev.mudbase.showcase.marketplace.web;

import dev.mudbase.showcase.marketplace.auth.AuthSession;
import dev.mudbase.showcase.marketplace.auth.SessionAuthService;
import dev.mudbase.showcase.marketplace.domain.Listing;
import dev.mudbase.showcase.marketplace.domain.Proposal;
import dev.mudbase.showcase.marketplace.mudbase.PageResult;
import dev.mudbase.showcase.marketplace.service.ListingService;
import dev.mudbase.showcase.marketplace.service.MessageService;
import dev.mudbase.showcase.marketplace.service.ProposalService;
import dev.mudbase.showcase.marketplace.support.ForbiddenActionException;
import dev.mudbase.showcase.marketplace.support.RoleSupport;
import dev.mudbase.showcase.marketplace.support.ViewModelHelper;
import dev.mudbase.showcase.marketplace.web.dto.ListingFormRequest;
import dev.mudbase.showcase.marketplace.web.dto.MessageFormRequest;
import dev.mudbase.showcase.marketplace.web.dto.ProposalFormRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

/**
 * Listing browse, detail, post, edit, delete, and "my listings". Proposal decisions and message
 * sending live in {@link ProposalController}/{@link MessageController}; this controller only
 * assembles the listing-centric read models and owns listing CRUD. Every mutating handler defers
 * ownership enforcement to {@link ListingService}, which re-derives ownership from a freshly
 * fetched document rather than trusting anything the request itself asserts (see that class's
 * javadoc for why - this is the IDOR-hardening discipline the task explicitly required).
 */
@Controller
public class ListingController {

  private static final int PAGE_SIZE = 12;
  private static final int MY_LISTINGS_PAGE_SIZE = 10;

  private final ListingService listingService;
  private final ProposalService proposalService;
  private final MessageService messageService;
  private final ViewModelHelper viewModelHelper;
  private final SessionAuthService sessionAuthService;

  public ListingController(
      ListingService listingService,
      ProposalService proposalService,
      MessageService messageService,
      ViewModelHelper viewModelHelper,
      SessionAuthService sessionAuthService) {
    this.listingService = listingService;
    this.proposalService = proposalService;
    this.messageService = messageService;
    this.viewModelHelper = viewModelHelper;
    this.sessionAuthService = sessionAuthService;
  }

  @GetMapping("/")
  public String browse(
      @RequestParam(value = "q", required = false) String q,
      @RequestParam(value = "category", required = false) String category,
      @RequestParam(value = "minBudget", required = false) Double minBudget,
      @RequestParam(value = "maxBudget", required = false) Double maxBudget,
      @RequestParam(value = "page", defaultValue = "1") int page,
      Model model,
      HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    AuthSession actor = currentUser(session);

    PageResult<Listing> result = listingService.browse(actor, q, category, minBudget, maxBudget, Math.max(page, 1), PAGE_SIZE);
    model.addAttribute("listings", result);
    model.addAttribute("categories", listingService.categories(actor));
    model.addAttribute("q", q);
    model.addAttribute("category", category);
    model.addAttribute("minBudget", minBudget);
    model.addAttribute("maxBudget", maxBudget);
    return "index";
  }

  @GetMapping("/listings/new")
  public String newForm(Model model, HttpSession session) {
    AuthSession actor = currentUser(session);
    if (!RoleSupport.isClient(actor.getRole())) {
      throw new ForbiddenActionException("Only a client account can post a listing.");
    }
    viewModelHelper.addLayoutAttributes(model, session);
    if (!model.containsAttribute("listingForm")) {
      model.addAttribute("listingForm", new ListingFormRequest());
    }
    model.addAttribute("formMode", "create");
    return "listings/form";
  }

  @PostMapping("/listings")
  public String create(
      @Valid @ModelAttribute("listingForm") ListingFormRequest form, BindingResult bindingResult, HttpSession session, Model model) {
    AuthSession actor = currentUser(session);
    if (bindingResult.hasErrors()) {
      viewModelHelper.addLayoutAttributes(model, session);
      model.addAttribute("formMode", "create");
      return "listings/form";
    }
    Listing created = listingService.create(actor, form);
    return "redirect:/listings/" + created.getId();
  }

  @GetMapping("/listings/{id}")
  public String detail(@PathVariable String id, Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    AuthSession actor = currentUser(session);
    Map<String, Object> listingDoc = listingService.getDocument(actor, id);
    Listing listing = Listing.fromDocument(listingDoc);

    boolean isOwningClient = RoleSupport.isClient(actor.getRole()) && actor.getUserId().equals(listing.getClientId());
    boolean isFreelancer = RoleSupport.isFreelancer(actor.getRole());
    model.addAttribute("listing", listing);
    model.addAttribute("isOwningClient", isOwningClient);
    model.addAttribute("isFreelancer", isFreelancer);

    if (isFreelancer) {
      Optional<Proposal> ownProposal = proposalService.ownProposalForListing(actor, id);
      model.addAttribute("ownProposal", ownProposal.orElse(null));
      if (ownProposal.isEmpty() && !model.containsAttribute("proposalForm")) {
        model.addAttribute("proposalForm", new ProposalFormRequest());
      }
    }
    if (isOwningClient) {
      model.addAttribute("proposals", proposalService.forListing(actor, id));
    }

    boolean canMessage = messageService.canAccessThread(actor, listingDoc);
    model.addAttribute("canMessage", canMessage);
    if (canMessage) {
      model.addAttribute("messages", messageService.forListing(actor, id));
      if (!model.containsAttribute("messageForm")) {
        model.addAttribute("messageForm", new MessageFormRequest());
      }
    }
    return "listings/detail";
  }

  @GetMapping("/listings/{id}/edit")
  public String editForm(@PathVariable String id, Model model, HttpSession session) {
    AuthSession actor = currentUser(session);
    Listing listing = listingService.get(actor, id);
    // Ownership is checked again, server-side, in ListingService#update before any write - this
    // check here only controls whether the edit form itself is shown.
    if (!RoleSupport.isClient(actor.getRole()) || !actor.getUserId().equals(listing.getClientId())) {
      throw new ForbiddenActionException("Only the client who posted this listing can edit it.");
    }
    viewModelHelper.addLayoutAttributes(model, session);
    if (!model.containsAttribute("listingForm")) {
      ListingFormRequest form = new ListingFormRequest();
      form.setTitle(listing.getTitle());
      form.setDescription(listing.getDescription());
      form.setBudget(listing.getBudget());
      form.setCategory(listing.getCategory() != null ? listing.getCategory() : "");
      form.setStatus(listing.getStatus());
      model.addAttribute("listingForm", form);
    }
    model.addAttribute("formMode", "edit");
    model.addAttribute("listingId", id);
    return "listings/form";
  }

  @PostMapping("/listings/{id}/edit")
  public String edit(
      @PathVariable String id,
      @Valid @ModelAttribute("listingForm") ListingFormRequest form,
      BindingResult bindingResult,
      HttpSession session,
      Model model) {
    AuthSession actor = currentUser(session);
    if (bindingResult.hasErrors()) {
      viewModelHelper.addLayoutAttributes(model, session);
      model.addAttribute("formMode", "edit");
      model.addAttribute("listingId", id);
      return "listings/form";
    }
    // ListingService#update re-derives ownership from the fetched document's clientId - the id
    // path variable never determines authorization on its own.
    listingService.update(actor, id, form);
    return "redirect:/listings/" + id;
  }

  @PostMapping("/listings/{id}/delete")
  public String delete(@PathVariable String id, HttpSession session) {
    // ListingService#delete re-derives ownership from the fetched document's clientId before
    // deleting anything.
    listingService.delete(currentUser(session), id);
    return "redirect:/listings/mine";
  }

  @GetMapping("/listings/mine")
  public String mine(@RequestParam(value = "page", defaultValue = "1") int page, Model model, HttpSession session) {
    AuthSession actor = currentUser(session);
    if (!RoleSupport.isClient(actor.getRole())) {
      throw new ForbiddenActionException("Only a client account can view its own listings.");
    }
    viewModelHelper.addLayoutAttributes(model, session);
    PageResult<Listing> result = listingService.myListings(actor, Math.max(page, 1), MY_LISTINGS_PAGE_SIZE);
    List<String> listingIds = result.items().stream().map(Listing::getId).toList();
    model.addAttribute("listings", result);
    model.addAttribute("proposalCounts", proposalService.countsForListings(actor, listingIds));
    return "listings/mine";
  }

  private AuthSession currentUser(HttpSession session) {
    return sessionAuthService.current(session).orElseThrow(IllegalStateException::new);
  }
}
