import type { Document } from "@/lib/mudbase"

export interface Message extends Document {
  listingId: string
  senderId: string
  senderName: string
  content: string
}
