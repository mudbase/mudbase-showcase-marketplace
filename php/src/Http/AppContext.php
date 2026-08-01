<?php

declare(strict_types=1);

namespace App\Http;

use App\Mudbase\MudbaseClient;

/**
 * Per-request registry handed to every controller and view: the authenticated Mudbase client and
 * the current session user (or null) — the server-rendered counterpart of the reference app's
 * React `useMudbase()` context (src/lib/mudbase-provider.tsx). One instance per request; built
 * once in bootstrap.php right after the session handshake.
 *
 * Unlike the kanban PHP port, this app *does* have an anonymous/guest session (see
 * plan/build-plan.md "Auth Model") — the listings feed is publicly browsable, mirroring the
 * reference Next.js app's MudbaseProvider, which establishes an anonymous session on mount so
 * `GET /api/data/.../data` (an "authenticated"-role-gated read) resolves without forcing signup.
 * `$user` is therefore non-null far more often here than in the kanban port: it holds the
 * anonymous guest identity when nobody has signed in, and a real client/freelancer account once
 * they do. `isSignedIn()` is the one method that tells those two apart.
 */
final class AppContext
{
    private static ?self $instance = null;

    /** @param array<string, mixed>|null $user */
    public function __construct(
        public readonly MudbaseClient $mudbase,
        public readonly ?array $user,
        public readonly string $listingsCollectionId,
        public readonly string $proposalsCollectionId,
        public readonly string $messagesCollectionId,
        public readonly string $listingsCollectionSlug,
        public readonly string $mudbaseUrl,
    ) {
    }

    public static function set(self $context): void
    {
        self::$instance = $context;
    }

    public static function current(): self
    {
        if (self::$instance === null) {
            throw new \RuntimeException('AppContext accessed before bootstrap set it.');
        }
        return self::$instance;
    }

    /**
     * A real, role-carrying account — distinct from the always-present anonymous guest session
     * that lets `/` render for anyone. `GET /api/auth/local/session` does not reliably return an
     * `isAnonymous` key at all in practice (confirmed against the live API on the sibling PHP
     * ports — the key is simply absent from the response body for a real account), so a bare
     * `($this->user['isAnonymous'] ?? false) !== true` check treats a missing key as "not
     * anonymous" and would wrongly call an anonymous session signed in if that were the only
     * check. `customRole` is the reliable signal instead: Mudbase only ever assigns one of this
     * project's role slugs (client/freelancer) to a real registered account.
     */
    public function isSignedIn(): bool
    {
        return $this->user !== null
            && ($this->user['isAnonymous'] ?? false) !== true
            && ($this->user['customRole'] ?? null) !== null;
    }

    /** True for any established session at all, including the anonymous guest one. */
    public function hasSession(): bool
    {
        return $this->user !== null;
    }

    /**
     * Redirects an unauthenticated visitor to `/login`, carrying the originally-requested path
     * back through `?redirect=` so they land where they meant to go after signing in. Called by
     * every write action (post/edit listing, submit proposal, accept/reject, send message) —
     * browsing the listings feed itself does not require this (see plan/build-plan.md "Auth
     * Model").
     */
    public function requireSignIn(string $requestedPath): void
    {
        if (!$this->isSignedIn()) {
            Response::redirect('/login?redirect=' . urlencode($requestedPath));
        }
    }

    /**
     * Redirects with a flash error when the signed-in user doesn't hold the required app role.
     * This is a UI-level convenience only (matching plan/build-plan.md's documented RBAC
     * limitation) — it is never the sole authorization check for a mutation. Every controller
     * action that mutates a specific document additionally re-fetches that document and verifies
     * the ownership field on the fetched record itself before writing (see each controller's
     * docblock) so a forged hidden-form field can never substitute for real ownership.
     */
    public function requireRole(string $role, string $redirectPath, string $message): void
    {
        $this->requireSignIn($redirectPath);
        if ($this->role() !== $role) {
            Flash::set('error', $message);
            Response::redirect($redirectPath);
        }
    }

    public function userId(): ?string
    {
        $id = $this->user['id'] ?? $this->user['_id'] ?? null;
        return is_string($id) ? $id : null;
    }

    /** One of "client"/"freelancer", or null if not signed in / role unset (including anonymous guests). */
    public function role(): ?string
    {
        $role = $this->user['customRole'] ?? null;
        return is_string($role) && $role !== '' ? $role : null;
    }

    public function isClient(): bool
    {
        return $this->isSignedIn() && $this->role() === 'client';
    }

    public function isFreelancer(): bool
    {
        return $this->isSignedIn() && $this->role() === 'freelancer';
    }

    /** `"{firstName} {lastName}"`, trimmed — the denormalized name every write stores (clientName/freelancerName/senderName). */
    public function displayName(): ?string
    {
        if ($this->user === null) {
            return null;
        }
        $first = is_string($this->user['firstName'] ?? null) ? $this->user['firstName'] : '';
        $last = is_string($this->user['lastName'] ?? null) ? $this->user['lastName'] : '';
        $name = trim("{$first} {$last}");
        return $name !== '' ? $name : null;
    }
}
