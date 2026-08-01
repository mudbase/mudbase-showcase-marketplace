package server

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

// formatDate parses an RFC3339 timestamp (as returned by Mudbase's createdAt/updatedAt fields) and
// renders it in a medium, readable form. Malformed or empty input renders as "-" rather than
// panicking or leaking a raw parse error into the page.
func formatDate(iso string) string {
	t, err := time.Parse(time.RFC3339, iso)
	if err != nil {
		return "-"
	}
	return t.Local().Format("Jan 2, 2006, 3:04 PM")
}

// formatRelativeTime renders iso as a short "just now" / "5m ago" / "3d ago" style relative
// timestamp, falling back to formatDate once the gap exceeds about a month - mirrors the reference
// web app's src/lib/utils.ts (formatRelativeTime).
func formatRelativeTime(iso string) string {
	t, err := time.Parse(time.RFC3339, iso)
	if err != nil {
		return "-"
	}
	diff := time.Since(t)
	switch {
	case diff < time.Minute:
		return "just now"
	case diff < time.Hour:
		return fmt.Sprintf("%dm ago", int(diff/time.Minute))
	case diff < 24*time.Hour:
		return fmt.Sprintf("%dh ago", int(diff/time.Hour))
	case diff < 30*24*time.Hour:
		return fmt.Sprintf("%dd ago", int(diff/(24*time.Hour)))
	default:
		return formatDate(iso)
	}
}

// formatCurrency renders a budget/rate as a whole-dollar USD amount, e.g. 1200.5 -> "$1,201" -
// mirrors the reference web app's src/lib/utils.ts (formatCurrency).
func formatCurrency(amount float64) string {
	rounded := int64(amount + 0.5)
	return "$" + groupThousands(rounded)
}

func groupThousands(n int64) string {
	s := strconv.FormatInt(n, 10)
	neg := strings.HasPrefix(s, "-")
	if neg {
		s = s[1:]
	}
	var groups []string
	for len(s) > 3 {
		groups = append([]string{s[len(s)-3:]}, groups...)
		s = s[:len(s)-3]
	}
	groups = append([]string{s}, groups...)
	out := strings.Join(groups, ",")
	if neg {
		out = "-" + out
	}
	return out
}

// initials renders up to two uppercase letters from name for the avatar-circle fallback this app
// uses everywhere a real profile photo would go. Ported from the reference web app's
// src/lib/utils.ts (initials).
func initials(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return "?"
	}
	fields := strings.Fields(name)
	if len(fields) == 1 {
		runes := []rune(fields[0])
		if len(runes) == 1 {
			return strings.ToUpper(string(runes[0]))
		}
		return strings.ToUpper(string(runes[:2]))
	}
	first := []rune(fields[0])[0]
	last := []rune(fields[len(fields)-1])[0]
	return strings.ToUpper(string(first) + string(last))
}
