"use client"

import Link from "next/link"
import { LogOut, Briefcase, FileText, PlusCircle } from "lucide-react"
import { useAuth } from "@/hooks/useAuth"
import { Button } from "@/components/ui/button"

export function Header(): React.JSX.Element {
  const { user, isAuthenticated, role, logout } = useAuth()

  return (
    <header className="sticky top-0 z-40 border-b border-border bg-background/95 backdrop-blur">
      <div className="container flex h-16 items-center justify-between">
        <Link href="/" className="font-display text-xl font-semibold tracking-tight">
          Mudbase Marketplace
        </Link>

        <nav className="flex items-center gap-2">
          {isAuthenticated && role === "client" && (
            <>
              <Button asChild variant="ghost" size="sm">
                <Link href="/listings/mine">
                  <Briefcase className="mr-2 h-4 w-4" />
                  My listings
                </Link>
              </Button>
              <Button asChild size="sm">
                <Link href="/listings/new">
                  <PlusCircle className="mr-2 h-4 w-4" />
                  Post a listing
                </Link>
              </Button>
            </>
          )}

          {isAuthenticated && role === "freelancer" && (
            <Button asChild variant="ghost" size="sm">
              <Link href="/proposals">
                <FileText className="mr-2 h-4 w-4" />
                My proposals
              </Link>
            </Button>
          )}

          {isAuthenticated && user && (
            <span className="hidden text-sm text-muted-foreground sm:inline">
              {user.firstName} · {role}
            </span>
          )}

          {isAuthenticated ? (
            <Button variant="outline" size="sm" onClick={() => void logout()}>
              <LogOut className="mr-2 h-4 w-4" />
              Sign out
            </Button>
          ) : (
            <>
              <Button asChild variant="ghost" size="sm">
                <Link href="/login">Sign in</Link>
              </Button>
              <Button asChild size="sm">
                <Link href="/register">Sign up</Link>
              </Button>
            </>
          )}
        </nav>
      </div>
    </header>
  )
}
