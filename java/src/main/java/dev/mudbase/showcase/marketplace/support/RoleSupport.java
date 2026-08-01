package dev.mudbase.showcase.marketplace.support;

/**
 * Server-side mirror of the RBAC matrix Mudbase's own collection permissions only partially
 * enforce (collection-level, not document-level - see ../../web/plan/build-plan.md "RBAC
 * matrix"). Used both to hide/disable controls a role cannot use in the templates, and (via
 * {@link ForbiddenActionException}, thrown from the service layer) as this Java app's own
 * independent server-side check before a mutating Mudbase call is even attempted - and, most
 * importantly per this task's explicit instruction, combined with a re-derived ownership check
 * (fetch the document, compare its {@code clientId}/{@code freelancerId} against the acting
 * session's own user id) rather than ever trusting a hidden form field for who owns what. Mirrors
 * ../../web/src/lib/mudbase.ts's RBAC comments and ../../web/plan/build-plan.md exactly.
 */
public final class RoleSupport {

  public static final String CLIENT = "client";
  public static final String FREELANCER = "freelancer";

  private RoleSupport() {}

  public static boolean isClient(String role) {
    return CLIENT.equals(role);
  }

  public static boolean isFreelancer(String role) {
    return FREELANCER.equals(role);
  }

  public static String roleLabel(String role) {
    if (CLIENT.equals(role)) {
      return "Client";
    }
    if (FREELANCER.equals(role)) {
      return "Freelancer";
    }
    return "Unknown";
  }
}
