<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Mudbase's query sanitizer rejects (and security-alerts on) any top-level filter field ending in
 * "Id" that isn't a real 24-character hex ObjectId — confirmed live behavior, documented in the
 * reference web app's plan/build-plan.md. This guard is checked before building any filter on
 * `clientId`/`freelancerId`/`listingId` so a malformed or attacker-supplied id string never reaches
 * a query. A PHP port of the reference app's `isObjectId()` (src/lib/utils.ts).
 */
final class ObjectId
{
    private const PATTERN = '/^[a-f0-9]{24}$/i';

    public static function isValid(?string $value): bool
    {
        return is_string($value) && $value !== '' && preg_match(self::PATTERN, $value) === 1;
    }
}
