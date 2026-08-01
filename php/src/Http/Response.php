<?php

declare(strict_types=1);

namespace App\Http;

/** Tiny response helper shared by every controller — redirects. Ported from the kanban PHP port. */
final class Response
{
    public static function redirect(string $path): never
    {
        header('Location: ' . $path, true, 303);
        exit;
    }

    /**
     * Redirects to a caller-supplied `redirectTo` value (e.g. so a login lands the visitor back
     * on whichever page they were bounced from) only if it is a safe same-site path; otherwise
     * falls back to `$fallback`. Guards against an open redirect: rejects anything that isn't a
     * bare `/`-rooted path (no scheme, no protocol-relative `//host` form).
     */
    public static function redirectToSafe(?string $submitted, string $fallback): never
    {
        $isSafe = is_string($submitted)
            && $submitted !== ''
            && str_starts_with($submitted, '/')
            && !str_starts_with($submitted, '//')
            && !str_contains($submitted, '://');

        self::redirect($isSafe ? $submitted : $fallback);
    }
}
