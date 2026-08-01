<?php

declare(strict_types=1);

namespace App\Support;

/** Mirrors the reference app's `formatRelativeTime`/`formatDateTime`/`formatCurrency` (src/lib/utils.ts) closely enough for a demo. */
final class TimeFormat
{
    public static function relative(?string $isoDate): string
    {
        if ($isoDate === null || $isoDate === '') {
            return '';
        }

        $timestamp = strtotime($isoDate);
        if ($timestamp === false) {
            return '';
        }

        $diffSeconds = time() - $timestamp;
        if ($diffSeconds < 60) {
            return 'just now';
        }
        if ($diffSeconds < 3600) {
            $minutes = intdiv($diffSeconds, 60);
            return $minutes === 1 ? '1 minute ago' : "{$minutes} minutes ago";
        }
        if ($diffSeconds < 86400) {
            $hours = intdiv($diffSeconds, 3600);
            return $hours === 1 ? '1 hour ago' : "{$hours} hours ago";
        }
        if ($diffSeconds < 604800) {
            $days = intdiv($diffSeconds, 86400);
            return $days === 1 ? '1 day ago' : "{$days} days ago";
        }

        return date('M j, Y', $timestamp);
    }

    public static function datetime(?string $isoDate): string
    {
        if ($isoDate === null || $isoDate === '') {
            return '';
        }
        $timestamp = strtotime($isoDate);
        if ($timestamp === false) {
            return '';
        }
        return date('M j, Y g:i A', $timestamp);
    }

    public static function currency(float $amount): string
    {
        return '$' . number_format($amount, 0);
    }
}
