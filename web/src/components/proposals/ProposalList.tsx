"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { ProposalStatusBadge } from "./ProposalStatusBadge"
import { useDocuments, useUpdateDocument } from "@/hooks/useCollection"
import { PROPOSALS_COLLECTION_ID } from "@/lib/config"
import { formatCurrency, formatRelativeTime, isObjectId } from "@/lib/utils"
import type { Proposal } from "@/types/proposal"

interface ProposalListProps {
  listingId: string
}

export function ProposalList({ listingId }: ProposalListProps): React.JSX.Element {
  const [actioningId, setActioningId] = useState<string | null>(null)
  const { data, isLoading, isError } = useDocuments<Proposal>(
    PROPOSALS_COLLECTION_ID,
    { filter: { listingId }, sort: "-createdAt", limit: 100 },
    { enabled: isObjectId(listingId) },
  )
  const updateProposal = useUpdateDocument<Proposal>(PROPOSALS_COLLECTION_ID)

  const setStatus = async (proposalId: string, status: "accepted" | "rejected"): Promise<void> => {
    setActioningId(proposalId)
    try {
      await updateProposal.mutateAsync({ documentId: proposalId, data: { status } })
    } finally {
      setActioningId(null)
    }
  }

  if (isLoading) return <p className="text-sm text-muted-foreground">Loading proposals…</p>
  if (isError) return <p className="text-sm text-destructive">Couldn&apos;t load proposals.</p>

  const proposals = data?.data ?? []
  if (proposals.length === 0) {
    return <p className="text-sm text-muted-foreground">No proposals yet.</p>
  }

  return (
    <div className="space-y-3">
      {proposals.map((proposal) => (
        <Card key={proposal._id}>
          <CardHeader className="flex-row items-start justify-between space-y-0">
            <div>
              <CardTitle className="text-base">{proposal.freelancerName}</CardTitle>
              <p className="text-sm text-muted-foreground">
                {formatCurrency(proposal.proposedRate)} · {formatRelativeTime(proposal.createdAt)}
              </p>
            </div>
            <ProposalStatusBadge status={proposal.status} />
          </CardHeader>
          <CardContent className="space-y-3">
            <p className="whitespace-pre-wrap text-sm">{proposal.coverLetter}</p>
            {proposal.status === "pending" && (
              <div className="flex gap-2">
                <Button
                  size="sm"
                  disabled={actioningId === proposal._id}
                  onClick={() => void setStatus(proposal._id, "accepted")}
                >
                  Accept
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  disabled={actioningId === proposal._id}
                  onClick={() => void setStatus(proposal._id, "rejected")}
                >
                  Reject
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      ))}
    </div>
  )
}
