package dev.mudbase.showcase.marketplace.support;

/**
 * Thrown by the service layer ({@code ListingService}/{@code ProposalService}/{@code
 * MessageService}) when the acting user fails a {@link RoleSupport} role check OR - the critical
 * case this task explicitly called out - fails a re-derived ownership check against a freshly
 * fetched document (a proposal's {@code freelancerId}, a listing's {@code clientId}). Every
 * accept/reject/edit/delete/withdraw handler fetches the target document first and compares its
 * ownership field to {@code actor.getUserId()} before mutating anything; a hidden form field or
 * path parameter is never trusted as proof of ownership on its own. This is this Java app's own
 * independent server-side enforcement of the RBAC matrix in ../../web/plan/build-plan.md: it runs
 * before any mutating call to Mudbase is attempted, so a raw POST to one of this app's own routes
 * that bypasses the Thymeleaf UI's hidden buttons is rejected here - not merely by Mudbase's own
 * collection permissions one layer further down (which are collection-level, not document-level,
 * and so would NOT catch a cross-account IDOR attempt on their own). Handled by {@code
 * dev.mudbase.showcase.marketplace.web.GlobalExceptionHandler}, which renders a 403 error page.
 */
public class ForbiddenActionException extends RuntimeException {

  private static final long serialVersionUID = 1L;

  public ForbiddenActionException(String message) {
    super(message);
  }
}
