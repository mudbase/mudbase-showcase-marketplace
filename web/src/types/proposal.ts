import type { Document } from "@/lib/mudbase"

export const PROPOSAL_STATUSES = ["pending", "accepted", "rejected"] as const
export type ProposalStatus = (typeof PROPOSAL_STATUSES)[number]

export interface Proposal extends Document {
  listingId: string
  freelancerId: string
  freelancerName: string
  coverLetter: string
  proposedRate: number
  status: ProposalStatus
}

export function proposalStatusLabel(status: ProposalStatus): string {
  switch (status) {
    case "pending":
      return "Pending"
    case "accepted":
      return "Accepted"
    case "rejected":
      return "Rejected"
  }
}
