package dev.mudbase.showcase.marketplace.web;

import dev.mudbase.showcase.marketplace.auth.AuthSession;
import dev.mudbase.showcase.marketplace.auth.SessionAuthService;
import dev.mudbase.showcase.marketplace.domain.Proposal;
import dev.mudbase.showcase.marketplace.mudbase.PageResult;
import dev.mudbase.showcase.marketplace.service.ListingService;
import dev.mudbase.showcase.marketplace.service.ProposalService;
import dev.mudbase.showcase.marketplace.support.ForbiddenActionException;
import dev.mudbase.showcase.marketplace.support.RoleSupport;
import dev.mudbase.showcase.marketplace.support.ViewModelHelper;
import dev.mudbase.showcase.marketplace.web.dto.ProposalFormRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * Proposal submission (freelancer), accept/reject (client), withdrawal (freelancer), and "my
 * proposals". Every mutation defers ownership enforcement to {@link ProposalService}, which
 * re-derives ownership from freshly fetched documents rather than trusting anything the request
 * itself asserts - see that class's javadoc, particularly {@code decide()}, for the exact
 * IDOR-hardening discipline the task explicitly required (never trust a hidden {@code listingId}
 * or the caller's claim to own the listing whose proposal is being accepted/rejected).
 */
@Controller
public class ProposalController {

  private static final int MY_PROPOSALS_PAGE_SIZE = 10;

  private final ProposalService proposalService;
  private final ListingService listingService;
  private final ViewModelHelper viewModelHelper;
  private final SessionAuthService sessionAuthService;

  public ProposalController(
      ProposalService proposalService,
      ListingService listingService,
      ViewModelHelper viewModelHelper,
      SessionAuthService sessionAuthService) {
    this.proposalService = proposalService;
    this.listingService = listingService;
    this.viewModelHelper = viewModelHelper;
    this.sessionAuthService = sessionAuthService;
  }

  @PostMapping("/listings/{id}/proposals")
  public String submit(
      @PathVariable String id,
      @Valid @ModelAttribute("proposalForm") ProposalFormRequest form,
      BindingResult bindingResult,
      HttpSession session,
      RedirectAttributes redirectAttributes) {
    AuthSession actor = currentUser(session);
    if (bindingResult.hasErrors()) {
      redirectAttributes.addFlashAttribute("formError", firstError(bindingResult));
      return "redirect:/listings/" + id;
    }
    try {
      proposalService.submit(actor, id, form.getCoverLetter().trim(), form.getProposedRate());
    } catch (ForbiddenActionException e) {
      redirectAttributes.addFlashAttribute("formError", e.getMessage());
    }
    return "redirect:/listings/" + id;
  }

  @PostMapping("/proposals/{id}/accept")
  public String accept(@PathVariable String id, HttpSession session) {
    // ProposalService#decide re-derives both the proposal's real listingId and that listing's
    // real clientId from fresh fetches before allowing the status change - see class javadoc.
    Proposal updated = proposalService.decide(currentUser(session), id, Proposal.STATUS_ACCEPTED);
    return "redirect:/listings/" + updated.getListingId();
  }

  @PostMapping("/proposals/{id}/reject")
  public String reject(@PathVariable String id, HttpSession session) {
    Proposal updated = proposalService.decide(currentUser(session), id, Proposal.STATUS_REJECTED);
    return "redirect:/listings/" + updated.getListingId();
  }

  @PostMapping("/proposals/{id}/withdraw")
  public String withdraw(@PathVariable String id, HttpSession session) {
    // ProposalService#withdraw re-derives ownership from the fetched proposal's freelancerId
    // before deleting anything.
    String listingId = proposalService.withdraw(currentUser(session), id);
    return "redirect:/listings/" + listingId;
  }

  @GetMapping("/proposals/mine")
  public String mine(@RequestParam(value = "page", defaultValue = "1") int page, Model model, HttpSession session) {
    AuthSession actor = currentUser(session);
    if (!RoleSupport.isFreelancer(actor.getRole())) {
      throw new ForbiddenActionException("Only a freelancer account can view its own proposals.");
    }
    viewModelHelper.addLayoutAttributes(model, session);
    PageResult<Proposal> result = proposalService.myProposals(actor, Math.max(page, 1), MY_PROPOSALS_PAGE_SIZE);
    List<String> listingIds = result.items().stream().map(Proposal::getListingId).distinct().toList();
    Map<String, String> listingTitles = listingService.titlesFor(actor, listingIds);
    model.addAttribute("proposals", result);
    model.addAttribute("listingTitles", listingTitles);
    return "proposals/mine";
  }

  private AuthSession currentUser(HttpSession session) {
    return sessionAuthService.current(session).orElseThrow(IllegalStateException::new);
  }

  private String firstError(BindingResult bindingResult) {
    return bindingResult.getFieldErrors().stream()
        .findFirst()
        .map(error -> error.getDefaultMessage())
        .orElse("Invalid input.");
  }
}
