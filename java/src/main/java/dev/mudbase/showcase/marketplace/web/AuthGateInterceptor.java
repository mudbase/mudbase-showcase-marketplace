package dev.mudbase.showcase.marketplace.web;

import dev.mudbase.showcase.marketplace.auth.SessionAuthService;
import dev.mudbase.showcase.marketplace.support.RedirectSupport;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * This app has no anonymous/guest session and no public read at all - every user (client or
 * freelancer) must sign in before seeing anything past the login page, because Mudbase's own
 * collection permissions 401 an unauthenticated request even for read-only listing browse. This
 * is a deliberate simplification vs. the reference web app, which establishes an anonymous
 * session so guests can browse without signing in first - see README.md "What deliberately
 * differs" for why, matching the same simplification the sibling kanban Java port already made.
 * Registered against every route except `/login` and static assets in {@link WebConfig};
 * redirects to `/login?redirect=...` with the original destination preserved so the user lands
 * back where they intended after signing in.
 */
@Component
public class AuthGateInterceptor implements HandlerInterceptor {

  private final SessionAuthService sessionAuthService;

  public AuthGateInterceptor(SessionAuthService sessionAuthService) {
    this.sessionAuthService = sessionAuthService;
  }

  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
    HttpSession session = request.getSession(true);
    if (sessionAuthService.current(session).isPresent()) {
      return true;
    }
    String query = request.getQueryString();
    String destination = query != null ? request.getRequestURI() + "?" + query : request.getRequestURI();
    response.sendRedirect(RedirectSupport.loginRedirectTo(destination));
    return false;
  }
}
