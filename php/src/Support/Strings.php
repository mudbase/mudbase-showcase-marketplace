<?php

declare(strict_types=1);

namespace App\Support;

/** Small string helpers shared across views. Mirrors the reference app's `initials()` (src/lib/utils.ts). */
final class Strings
{
    public static function initials(string $name): string
    {
        $parts = array_values(array_filter(preg_split('/\s+/', trim($name)) ?: []));
        if ($parts === []) {
            return '?';
        }
        $first = mb_substr($parts[0], 0, 1);
        $last = count($parts) > 1 ? mb_substr($parts[count($parts) - 1], 0, 1) : '';
        return mb_strtoupper($first . $last);
    }
}
