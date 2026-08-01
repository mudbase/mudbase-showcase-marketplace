"use client"

import { use } from "react"
import { useRouter } from "next/navigation"
import Link from "next/link"
import { useAuth } from "@/hooks/useAuth"
import { useDocument, useUpdateDocument } from "@/hooks/useCollection"
import { LISTINGS_COLLECTION_ID } from "@/lib/config"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { ListingForm, type ListingFormValues } from "@/components/listings/ListingForm"
import type { Listing } from "@/types/listing"

export default function EditListingPage({ params }: { params: Promise<{ id: string }> }): React.JSX.Element {
  const { id } = use(params)
  const router = useRouter()
  const { user, role, isAuthenticated, loading: authLoading } = useAuth()
  const { data: listing, isLoading, isError } = useDocument<Listing>(LISTINGS_COLLECTION_ID, id)
  const updateListing = useUpdateDocument<Listing>(LISTINGS_COLLECTION_ID)

  if (isLoading || authLoading) {
    return <p className="container py-8 text-sm text-muted-foreground">Loading…</p>
  }

  if (isError || !listing) {
    return (
      <div className="container py-16 text-center">
        <p className="text-muted-foreground">This listing couldn&apos;t be found.</p>
      </div>
    )
  }

  const isOwner = isAuthenticated && role === "client" && !!user && listing.clientId === user.id
  if (!isOwner) {
    return (
      <div className="container max-w-md py-16 text-center">
        <p className="mb-4 text-muted-foreground">Only the client who posted this listing can edit it.</p>
        <Button asChild variant="outline">
          <Link href={`/listings/${id}`}>Back to listing</Link>
        </Button>
      </div>
    )
  }

  const handleSubmit = async (values: ListingFormValues): Promise<void> => {
    await updateListing.mutateAsync({
      documentId: id,
      data: {
        title: values.title,
        description: values.description,
        budget: values.budget,
        category: values.category || undefined,
        status: values.status ?? listing.status,
      },
    })
    router.push(`/listings/${id}`)
  }

  return (
    <div className="container max-w-2xl py-8">
      <Card>
        <CardHeader>
          <CardTitle>Edit listing</CardTitle>
          <CardDescription>Update the details or change its status.</CardDescription>
        </CardHeader>
        <CardContent>
          <ListingForm
            mode="edit"
            initialValues={{
              title: listing.title,
              description: listing.description,
              budget: listing.budget,
              category: listing.category ?? "",
              status: listing.status,
            }}
            submitting={updateListing.isPending}
            submitLabel="Save changes"
            onSubmit={handleSubmit}
          />
        </CardContent>
      </Card>
    </div>
  )
}
