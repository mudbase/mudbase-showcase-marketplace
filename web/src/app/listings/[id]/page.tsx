"use client"

import { use } from "react"
import Link from "next/link"
import { useAuth } from "@/hooks/useAuth"
import { useDocument, useDocuments, useCreateDocument } from "@/hooks/useCollection"
import { LISTINGS_COLLECTION_ID, PROPOSALS_COLLECTION_ID } from "@/lib/config"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import { ProposalForm, type ProposalFormValues } from "@/components/proposals/ProposalForm"
import { ProposalList } from "@/components/proposals/ProposalList"
import { ProposalStatusBadge } from "@/components/proposals/ProposalStatusBadge"
import { MessageThread } from "@/components/messages/MessageThread"
import { formatCurrency, formatRelativeTime, isObjectId } from "@/lib/utils"
import { listingStatusLabel, type Listing } from "@/types/listing"
import type { Proposal } from "@/types/proposal"

export default function ListingDetailPage({ params }: { params: Promise<{ id: string }> }): React.JSX.Element {
  const { id } = use(params)
  const { user, role, isAuthenticated, loading: authLoading } = useAuth()

  const { data: listing, isLoading, isError } = useDocument<Listing>(LISTINGS_COLLECTION_ID, id)

  const isOwningClient = isAuthenticated && role === "client" && !!listing && !!user && listing.clientId === user.id
  const isFreelancer = isAuthenticated && role === "freelancer" && !!user

  // A freelancer's own proposal on this listing, if any - determines whether to show the
  // submission form or their existing status.
  const { data: ownProposalData, isLoading: ownProposalLoading } = useDocuments<Proposal>(
    PROPOSALS_COLLECTION_ID,
    { filter: { listingId: id, freelancerId: user?.id }, limit: 1 },
    { enabled: isFreelancer && isObjectId(id) && isObjectId(user?.id) },
  )
  const ownProposal = ownProposalData?.data[0]

  // Whichever proposal (if any) has been accepted on this listing - decides who besides the
  // client can see and use the message thread. See plan/build-plan.md "Messaging visibility".
  const { data: acceptedProposalData } = useDocuments<Proposal>(
    PROPOSALS_COLLECTION_ID,
    { filter: { listingId: id, status: "accepted" }, limit: 1, fields: ["freelancerId"] },
    { enabled: isAuthenticated && isObjectId(id) },
  )
  const acceptedFreelancerId = acceptedProposalData?.data[0]?.freelancerId

  const createProposal = useCreateDocument<Proposal>(PROPOSALS_COLLECTION_ID)

  const canMessage =
    isAuthenticated &&
    !!user &&
    !!listing &&
    (listing.clientId === user.id || (isFreelancer && acceptedFreelancerId === user.id))

  if (isLoading || authLoading) {
    return <p className="container py-8 text-sm text-muted-foreground">Loading listing…</p>
  }

  if (isError || !listing) {
    return (
      <div className="container py-16 text-center">
        <p className="text-muted-foreground">This listing couldn&apos;t be found.</p>
        <Button asChild variant="outline" className="mt-4">
          <Link href="/">Back to listings</Link>
        </Button>
      </div>
    )
  }

  const handleSubmitProposal = async (values: ProposalFormValues): Promise<void> => {
    if (!user) return
    await createProposal.mutateAsync({
      listingId: id,
      freelancerId: user.id,
      freelancerName: `${user.firstName} ${user.lastName}`,
      coverLetter: values.coverLetter,
      proposedRate: values.proposedRate,
      status: "pending",
    })
  }

  return (
    <div className="container max-w-3xl space-y-6 py-8">
      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-3">
            <div>
              <CardTitle className="text-2xl">{listing.title}</CardTitle>
              <CardDescription>
                Posted by {listing.clientName} · {formatRelativeTime(listing.createdAt)}
              </CardDescription>
            </div>
            <Badge variant="outline">{listingStatusLabel(listing.status)}</Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="whitespace-pre-wrap text-sm">{listing.description}</p>
          <div className="flex flex-wrap items-center gap-3 text-sm">
            <span className="font-semibold text-primary">{formatCurrency(listing.budget)}</span>
            {listing.category && <Badge variant="secondary">{listing.category}</Badge>}
          </div>
          {isOwningClient && (
            <Button asChild variant="outline" size="sm">
              <Link href={`/listings/${listing._id}/edit`}>Edit listing</Link>
            </Button>
          )}
        </CardContent>
      </Card>

      {isFreelancer && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Your proposal</CardTitle>
          </CardHeader>
          <CardContent>
            {ownProposalLoading ? (
              <p className="text-sm text-muted-foreground">Checking your proposal status…</p>
            ) : ownProposal ? (
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Your proposed rate: {formatCurrency(ownProposal.proposedRate)}</span>
                  <ProposalStatusBadge status={ownProposal.status} />
                </div>
                <p className="whitespace-pre-wrap text-sm">{ownProposal.coverLetter}</p>
              </div>
            ) : (
              <ProposalForm submitting={createProposal.isPending} onSubmit={handleSubmitProposal} />
            )}
          </CardContent>
        </Card>
      )}

      {isOwningClient && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Proposals received</CardTitle>
          </CardHeader>
          <CardContent>
            <ProposalList listingId={id} />
          </CardContent>
        </Card>
      )}

      {canMessage && user && (
        <>
          <Separator />
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Messages</CardTitle>
              <CardDescription>Visible to the client and the accepted freelancer.</CardDescription>
            </CardHeader>
            <CardContent>
              <MessageThread listingId={id} currentUserId={user.id} currentUserName={`${user.firstName} ${user.lastName}`} />
            </CardContent>
          </Card>
        </>
      )}

      {!isAuthenticated && (
        <p className="text-center text-sm text-muted-foreground">
          <Link href="/login" className="underline underline-offset-4">
            Sign in
          </Link>{" "}
          to submit a proposal or message about this listing.
        </p>
      )}
    </div>
  )
}
