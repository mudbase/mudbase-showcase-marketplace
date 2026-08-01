import { Badge } from "@/components/ui/badge"
import { proposalStatusLabel, type ProposalStatus } from "@/types/proposal"

const STATUS_VARIANT: Record<ProposalStatus, "success" | "warning" | "destructive"> = {
  accepted: "success",
  pending: "warning",
  rejected: "destructive",
}

export function ProposalStatusBadge({ status }: { status: ProposalStatus }): React.JSX.Element {
  return <Badge variant={STATUS_VARIANT[status]}>{proposalStatusLabel(status)}</Badge>
}
