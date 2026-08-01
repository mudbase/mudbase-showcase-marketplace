import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { formatCurrency, formatRelativeTime } from "@/lib/utils"
import { listingStatusLabel, type Listing } from "@/types/listing"

const STATUS_VARIANT: Record<Listing["status"], "success" | "warning" | "secondary"> = {
  open: "success",
  in_progress: "warning",
  completed: "secondary",
}

export function ListingCard({ listing }: { listing: Listing }): React.JSX.Element {
  return (
    <Link href={`/listings/${listing._id}`}>
      <Card className="h-full transition-colors hover:border-primary/50">
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <CardTitle className="line-clamp-2">{listing.title}</CardTitle>
            <Badge variant={STATUS_VARIANT[listing.status]} className="shrink-0">
              {listingStatusLabel(listing.status)}
            </Badge>
          </div>
          <CardDescription className="line-clamp-3">{listing.description}</CardDescription>
        </CardHeader>
        <CardContent className="flex items-center justify-between text-sm">
          <span className="font-semibold text-primary">{formatCurrency(listing.budget)}</span>
          <div className="flex items-center gap-2 text-muted-foreground">
            {listing.category && <Badge variant="outline">{listing.category}</Badge>}
            <span>{formatRelativeTime(listing.createdAt)}</span>
          </div>
        </CardContent>
      </Card>
    </Link>
  )
}
