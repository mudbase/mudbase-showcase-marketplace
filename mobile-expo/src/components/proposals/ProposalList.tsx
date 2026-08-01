import { useState } from "react";
import { Text, View } from "react-native";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProposalStatusBadge } from "./ProposalStatusBadge";
import { useDocuments, useUpdateDocument } from "@/hooks/useCollection";
import { proposalSchema, type Proposal } from "@/api/schemas";
import { PROPOSALS_COLLECTION_ID } from "@/config/env";
import { formatCurrency, formatRelativeTime, isObjectId } from "@/lib/format";

interface ProposalListProps {
  listingId: string;
}

export function ProposalList({ listingId }: ProposalListProps): React.JSX.Element {
  const [actioningId, setActioningId] = useState<string | null>(null);
  const { data, isLoading, isError } = useDocuments(
    proposalSchema,
    PROPOSALS_COLLECTION_ID,
    { filter: { listingId }, sort: "-createdAt", limit: 100 },
    { enabled: isObjectId(listingId) },
  );
  const updateProposal = useUpdateDocument<Proposal>(proposalSchema, PROPOSALS_COLLECTION_ID);

  const setStatus = async (proposalId: string, status: "accepted" | "rejected"): Promise<void> => {
    setActioningId(proposalId);
    try {
      await updateProposal.mutateAsync({ documentId: proposalId, data: { status } });
    } finally {
      setActioningId(null);
    }
  };

  if (isLoading) return <Text className="text-sm text-muted-foreground">Loading proposals…</Text>;
  if (isError) return <Text className="text-sm text-destructive">Couldn&apos;t load proposals.</Text>;

  const proposals = data?.data ?? [];
  if (proposals.length === 0) {
    return <Text className="text-sm text-muted-foreground">No proposals yet.</Text>;
  }

  return (
    <View className="gap-3">
      {proposals.map((proposal) => (
        <Card key={proposal._id} className="gap-3">
          <View className="flex-row items-start justify-between gap-2">
            <View className="flex-1 gap-0.5">
              <Text className="text-base font-semibold text-foreground">{proposal.freelancerName}</Text>
              <Text className="text-sm text-muted-foreground">
                {formatCurrency(proposal.proposedRate)} · {formatRelativeTime(proposal.createdAt)}
              </Text>
            </View>
            <ProposalStatusBadge status={proposal.status} />
          </View>
          <Text className="text-sm text-foreground">{proposal.coverLetter}</Text>
          {proposal.status === "pending" && (
            <View className="flex-row gap-2">
              <Button
                size="sm"
                className="flex-1"
                disabled={actioningId === proposal._id}
                onPress={() => void setStatus(proposal._id, "accepted")}
              >
                Accept
              </Button>
              <Button
                size="sm"
                variant="outline"
                className="flex-1"
                disabled={actioningId === proposal._id}
                onPress={() => void setStatus(proposal._id, "rejected")}
              >
                Reject
              </Button>
            </View>
          )}
        </Card>
      ))}
    </View>
  );
}
