import { Badge, type BadgeVariant } from "@/components/ui/Badge";
import { proposalStatusLabel, type ProposalStatus } from "@/api/schemas";

const STATUS_VARIANT: Record<ProposalStatus, BadgeVariant> = {
  accepted: "success",
  pending: "warning",
  rejected: "destructive",
};

export function ProposalStatusBadge({ status }: { status: ProposalStatus }): React.JSX.Element {
  return <Badge variant={STATUS_VARIANT[status]}>{proposalStatusLabel(status)}</Badge>;
}
