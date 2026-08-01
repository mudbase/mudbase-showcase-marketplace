"use client"

import { useRouter } from "next/navigation"
import Link from "next/link"
import { useAuth } from "@/hooks/useAuth"
import { useCreateDocument } from "@/hooks/useCollection"
import { LISTINGS_COLLECTION_ID } from "@/lib/config"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { ListingForm, type ListingFormValues } from "@/components/listings/ListingForm"
import type { Listing } from "@/types/listing"

export default function NewListingPage(): React.JSX.Element {
  const { user, role, isAuthenticated, loading } = useAuth()
  const router = useRouter()
  const createListing = useCreateDocument<Listing>(LISTINGS_COLLECTION_ID)

  if (loading) {
    return <p className="container py-8 text-sm text-muted-foreground">Loading…</p>
  }

  if (!isAuthenticated || role !== "client" || !user) {
    return (
      <div className="container max-w-md py-16 text-center">
        <p className="mb-4 text-muted-foreground">Sign in with a client account to post a listing.</p>
        <Button asChild>
          <Link href="/login">Sign in</Link>
        </Button>
      </div>
    )
  }

  const handleSubmit = async (values: ListingFormValues): Promise<void> => {
    const created = await createListing.mutateAsync({
      title: values.title,
      description: values.description,
      budget: values.budget,
      category: values.category || undefined,
      status: "open",
      clientId: user.id,
      clientName: `${user.firstName} ${user.lastName}`,
    })
    router.push(`/listings/${created._id}`)
  }

  return (
    <div className="container max-w-2xl py-8">
      <Card>
        <CardHeader>
          <CardTitle>Post a new listing</CardTitle>
          <CardDescription>Freelancers will be able to browse and submit proposals immediately.</CardDescription>
        </CardHeader>
        <CardContent>
          <ListingForm mode="create" submitting={createListing.isPending} submitLabel="Post listing" onSubmit={handleSubmit} />
        </CardContent>
      </Card>
    </div>
  )
}
