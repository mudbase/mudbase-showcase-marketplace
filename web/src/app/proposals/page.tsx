"use client"

import { useMemo, useState } from "react"
import Link from "next/link"
import { useAuth } from "@/hooks/useAuth"
import { useDocuments } from "@/hooks/useCollection"
import { LISTINGS_COLLECTION_ID, PROPOSALS_COLLECTION_ID } from "@/lib/config"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { ProposalStatusBadge } from "@/components/proposals/ProposalStatusBadge"
import { PaginationControls } from "@/components/shared/PaginationControls"
import { formatCurrency, formatRelativeTime, isObjectId } from "@/lib/utils"
import type { Proposal } from "@/types/proposal"
import type { Listing } from "@/types/listing"

const PAGE_SIZE = 10

export default function MyProposalsPage(): React.JSX.Element {
  const { user, role, isAuthenticated, loading } = useAuth()
  const [page, setPage] = useState(1)

  const freelancerId = user?.id
  const { data, isLoading, isError } = useDocuments<Proposal>(
    PROPOSALS_COLLECTION_ID,
    { filter: { freelancerId }, sort: "-createdAt", page, limit: PAGE_SIZE },
    { enabled: isObjectId(freelancerId) },
  )
  const proposals = useMemo(() => data?.data ?? [], [data])
  const listingIds = useMemo(() => Array.from(new Set(proposals.map((p) => p.listingId))), [proposals])

  // One batched query for the listing titles referenced on this page, instead of an N+1 query
  // per proposal.
  const { data: listingData } = useDocuments<Listing>(
    LISTINGS_COLLECTION_ID,
    { filter: { _id: { $in: listingIds } }, limit: 100 },
    { enabled: listingIds.length > 0 },
  )
  const listingsById = useMemo(() => {
    const map = new Map<string, Listing>()
    for (const listing of listingData?.data ?? []) map.set(listing._id, listing)
    return map
  }, [listingData])

  if (loading) {
    return <p className="container py-8 text-sm text-muted-foreground">Loading…</p>
  }

  if (!isAuthenticated || role !== "freelancer") {
    return (
      <div className="container max-w-md py-16 text-center">
        <p className="mb-4 text-muted-foreground">Sign in with a freelancer account to view your proposals.</p>
        <Button asChild>
          <Link href="/login">Sign in</Link>
        </Button>
      </div>
    )
  }

  return (
    <div className="container space-y-6 py-8">
      <div>
        <h1 className="font-display text-3xl font-semibold tracking-tight">My proposals</h1>
        <p className="text-muted-foreground">Every proposal you&apos;ve submitted, across all listings.</p>
      </div>

      {isLoading && <p className="text-sm text-muted-foreground">Loading proposals…</p>}
      {isError && <p className="text-sm text-destructive">Couldn&apos;t load your proposals.</p>}
      {!isLoading && !isError && proposals.length === 0 && (
        <p className="text-sm text-muted-foreground">
          You haven&apos;t submitted any proposals yet.{" "}
          <Link href="/" className="underline underline-offset-4">
            Browse listings
          </Link>
          .
        </p>
      )}

      <div className="space-y-3">
        {proposals.map((proposal) => {
          const listing = listingsById.get(proposal.listingId)
          return (
            <Link key={proposal._id} href={`/listings/${proposal.listingId}`}>
              <Card className="transition-colors hover:border-primary/50">
                <CardHeader className="flex-row items-center justify-between space-y-0">
                  <CardTitle className="text-base">{listing?.title ?? "Listing"}</CardTitle>
                  <ProposalStatusBadge status={proposal.status} />
                </CardHeader>
                <CardContent className="flex items-center justify-between text-sm text-muted-foreground">
                  <span>Your rate: {formatCurrency(proposal.proposedRate)}</span>
                  <span>{formatRelativeTime(proposal.createdAt)}</span>
                </CardContent>
              </Card>
            </Link>
          )
        })}
      </div>

      <PaginationControls pagination={data?.pagination} onPageChange={setPage} />
    </div>
  )
}
