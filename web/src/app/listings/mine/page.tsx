"use client"

import { useMemo, useState } from "react"
import Link from "next/link"
import { useAuth } from "@/hooks/useAuth"
import { useDocuments } from "@/hooks/useCollection"
import { LISTINGS_COLLECTION_ID, PROPOSALS_COLLECTION_ID } from "@/lib/config"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { PaginationControls } from "@/components/shared/PaginationControls"
import { formatCurrency, formatRelativeTime, isObjectId } from "@/lib/utils"
import { listingStatusLabel, type Listing } from "@/types/listing"
import type { Proposal } from "@/types/proposal"

const PAGE_SIZE = 10

export default function MyListingsPage(): React.JSX.Element {
  const { user, role, isAuthenticated, loading } = useAuth()
  const [page, setPage] = useState(1)

  const clientId = user?.id
  const { data, isLoading, isError } = useDocuments<Listing>(
    LISTINGS_COLLECTION_ID,
    { filter: { clientId }, sort: "-createdAt", page, limit: PAGE_SIZE },
    { enabled: isObjectId(clientId) },
  )
  const listings = useMemo(() => data?.data ?? [], [data])
  const listingIds = useMemo(() => listings.map((l) => l._id), [listings])

  // One batched query for proposal counts across every listing on this page, instead of an
  // N+1 query per listing.
  const { data: proposalData } = useDocuments<Proposal>(
    PROPOSALS_COLLECTION_ID,
    { filter: { listingId: { $in: listingIds } }, limit: 100, fields: ["listingId"] },
    { enabled: listingIds.length > 0 },
  )
  const proposalCounts = useMemo(() => {
    const counts = new Map<string, number>()
    for (const proposal of proposalData?.data ?? []) {
      counts.set(proposal.listingId, (counts.get(proposal.listingId) ?? 0) + 1)
    }
    return counts
  }, [proposalData])

  if (loading) {
    return <p className="container py-8 text-sm text-muted-foreground">Loading…</p>
  }

  if (!isAuthenticated || role !== "client") {
    return (
      <div className="container max-w-md py-16 text-center">
        <p className="mb-4 text-muted-foreground">Sign in with a client account to view your listings.</p>
        <Button asChild>
          <Link href="/login">Sign in</Link>
        </Button>
      </div>
    )
  }

  return (
    <div className="container space-y-6 py-8">
      <div className="flex items-center justify-between">
        <h1 className="font-display text-3xl font-semibold tracking-tight">My listings</h1>
        <Button asChild>
          <Link href="/listings/new">Post a listing</Link>
        </Button>
      </div>

      {isLoading && <p className="text-sm text-muted-foreground">Loading listings…</p>}
      {isError && <p className="text-sm text-destructive">Couldn&apos;t load your listings.</p>}
      {!isLoading && !isError && listings.length === 0 && (
        <p className="text-sm text-muted-foreground">You haven&apos;t posted any listings yet.</p>
      )}

      <div className="space-y-3">
        {listings.map((listing) => (
          <Link key={listing._id} href={`/listings/${listing._id}`}>
            <Card className="transition-colors hover:border-primary/50">
              <CardHeader className="flex-row items-center justify-between space-y-0">
                <CardTitle className="text-base">{listing.title}</CardTitle>
                <Badge variant="outline">{listingStatusLabel(listing.status)}</Badge>
              </CardHeader>
              <CardContent className="flex items-center justify-between text-sm text-muted-foreground">
                <span>{formatCurrency(listing.budget)}</span>
                <span>
                  {proposalCounts.get(listing._id) ?? 0} proposal{(proposalCounts.get(listing._id) ?? 0) === 1 ? "" : "s"}
                </span>
                <span>{formatRelativeTime(listing.createdAt)}</span>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>

      <PaginationControls pagination={data?.pagination} onPageChange={setPage} />
    </div>
  )
}
