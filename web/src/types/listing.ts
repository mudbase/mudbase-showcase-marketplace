import type { Document } from "@/lib/mudbase"

export const LISTING_STATUSES = ["open", "in_progress", "completed"] as const
export type ListingStatus = (typeof LISTING_STATUSES)[number]

export interface Listing extends Document {
  title: string
  description: string
  budget: number
  category?: string
  status: ListingStatus
  clientId: string
  clientName: string
}

export function listingStatusLabel(status: ListingStatus): string {
  switch (status) {
    case "open":
      return "Open"
    case "in_progress":
      return "In progress"
    case "completed":
      return "Completed"
  }
}
