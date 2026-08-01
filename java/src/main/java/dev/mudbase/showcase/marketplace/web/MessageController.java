package dev.mudbase.showcase.marketplace.web;

import dev.mudbase.showcase.marketplace.auth.AuthSession;
import dev.mudbase.showcase.marketplace.auth.SessionAuthService;
import dev.mudbase.showcase.marketplace.service.ListingService;
import dev.mudbase.showcase.marketplace.service.MessageService;
import dev.mudbase.showcase.marketplace.support.ForbiddenActionException;
import dev.mudbase.showcase.marketplace.web.dto.MessageFormRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.stereotype.Controller;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * Sends a message in a listing's thread. {@link MessageService#send} re-derives thread access
 * from the freshly fetched listing document (owning client, or the freelancer with an accepted
 * proposal on it) before allowing the write - never from anything the request itself asserts.
 * See {@link MessageService} class javadoc for the "messaging visibility" design decision this
 * enforces.
 */
@Controller
public class MessageController {

  private final MessageService messageService;
  private final ListingService listingService;
  private final SessionAuthService sessionAuthService;

  public MessageController(MessageService messageService, ListingService listingService, SessionAuthService sessionAuthService) {
    this.messageService = messageService;
    this.listingService = listingService;
    this.sessionAuthService = sessionAuthService;
  }

  @PostMapping("/listings/{id}/messages")
  public String send(
      @PathVariable String id,
      @Valid @ModelAttribute("messageForm") MessageFormRequest form,
      BindingResult bindingResult,
      HttpSession session,
      RedirectAttributes redirectAttributes) {
    AuthSession actor = currentUser(session);
    if (bindingResult.hasErrors()) {
      redirectAttributes.addFlashAttribute("formError", firstError(bindingResult));
      return "redirect:/listings/" + id;
    }
    Map<String, Object> listingDoc = listingService.getDocument(actor, id);
    try {
      messageService.send(actor, listingDoc, form.getContent().trim());
    } catch (ForbiddenActionException e) {
      redirectAttributes.addFlashAttribute("formError", e.getMessage());
    }
    return "redirect:/listings/" + id;
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
