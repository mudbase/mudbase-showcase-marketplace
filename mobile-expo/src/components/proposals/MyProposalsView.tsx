import { useMemo, useState } from "react";
import { FlatList, Pressable, Text, View } from "react-native";
import { router } from "expo-router";
import { Card } from "@/components/ui/Card";
import { PaginationControls } from "@/components/shared/PaginationControls";
import { ProposalStatusBadge } from "@/components/proposals/ProposalStatusBadge";
import { useDocuments } from "@/hooks/useCollection";
import { useAuth } from "@/hooks/useAuth";
import { listingSchema, proposalSchema, type Listing } from "@/api/schemas";
import { LISTINGS_COLLECTION_ID, PROPOSALS_COLLECTION_ID } from "@/config/env";
import { formatCurrency, formatRelativeTime, isObjectId } from "@/lib/format";

const PAGE_SIZE = 10;

/** Freelancer-only dashboard — the RN equivalent of web/src/app/proposals/page.tsx. */
export function MyProposalsView(): React.JSX.Element {
  const { user } = useAuth();
  const [page, setPage] = useState(1);

  const freelancerId = user?.id;
  const { data, isLoading, isError } = useDocuments(
    proposalSchema,
    PROPOSALS_COLLECTION_ID,
    { filter: { freelancerId }, sort: "-createdAt", page, limit: PAGE_SIZE },
    { enabled: isObjectId(freelancerId) },
  );
  const proposals = useMemo(() => data?.data ?? [], [data]);
  const listingIds = useMemo(() => Array.from(new Set(proposals.map((p) => p.listingId))), [proposals]);

  // One batched query for the listing titles referenced on this page, instead of an N+1 query
  // per proposal.
  const { data: listingData } = useDocuments(
    listingSchema,
    LISTINGS_COLLECTION_ID,
    { filter: { _id: { $in: listingIds } }, limit: 100 },
    { enabled: listingIds.length > 0 },
  );
  const listingsById = useMemo(() => {
    const map = new Map<string, Listing>();
    for (const listing of listingData?.data ?? []) map.set(listing._id, listing);
    return map;
  }, [listingData]);

  return (
    <FlatList
      data={proposals}
      keyExtractor={(item) => item._id}
      contentContainerClassName="gap-3 px-4 pb-6"
      ListHeaderComponent={
        <View className="gap-3 pb-2">
          {isLoading && <Text className="text-sm text-muted-foreground">Loading proposals…</Text>}
          {isError && <Text className="text-sm text-destructive">Couldn&apos;t load your proposals.</Text>}
          {!isLoading && !isError && proposals.length === 0 && (
            <Text className="text-sm text-muted-foreground">
              You haven&apos;t submitted any proposals yet. Browse listings to get started.
            </Text>
          )}
        </View>
      }
      renderItem={({ item: proposal }) => {
        const listing = listingsById.get(proposal.listingId);
        return (
          <Pressable accessibilityRole="button" onPress={() => router.push(`/listings/${proposal.listingId}`)}>
            <Card className="gap-2">
              <View className="flex-row items-center justify-between gap-2">
                <Text className="flex-1 text-base font-semibold text-foreground" numberOfLines={1}>
                  {listing?.title ?? "Listing"}
                </Text>
                <ProposalStatusBadge status={proposal.status} />
              </View>
              <View className="flex-row items-center justify-between">
                <Text className="text-sm text-muted-foreground">Your rate: {formatCurrency(proposal.proposedRate)}</Text>
                <Text className="text-sm text-muted-foreground">{formatRelativeTime(proposal.createdAt)}</Text>
              </View>
            </Card>
          </Pressable>
        );
      }}
      ListFooterComponent={<PaginationControls pagination={data?.pagination} onPageChange={setPage} />}
    />
  );
}
