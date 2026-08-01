<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Client-side mirror of the RBAC matrix Mudbase's own collection permissions partially enforce
 * server-side (see plan/build-plan.md "RBAC matrix"). Used purely to hide/disable controls a role
 * cannot use and to show a clear reason why — it is NOT the security boundary for document-level
 * ownership (a client can only manage *their own* listing, a freelancer only *their own*
 * proposal). That boundary is re-derived from the fetched document in every controller action
 * that mutates one — see each controller's docblock. A PHP port of the reference app's
 * `src/lib/rbac.ts`-equivalent role checks (inlined across its hooks/components in the reference
 * app; centralized here to match the kanban PHP port's structure).
 */
final class Rbac
{
    public static function canPostListing(?string $role): bool
    {
        return $role === 'client';
    }

    public static function canSubmitProposal(?string $role): bool
    {
        return $role === 'freelancer';
    }

    public static function roleLabel(?string $role): string
    {
        return match ($role) {
            'client' => 'Client',
            'freelancer' => 'Freelancer',
            default => 'Guest',
        };
    }
}
