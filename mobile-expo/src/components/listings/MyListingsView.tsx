import { useMemo, useState } from "react";
import { FlatList, Pressable, Text, View } from "react-native";
import { router } from "expo-router";
import { Card } from "@/components/ui/Card";
import { Badge, type BadgeVariant } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { PaginationControls } from "@/components/shared/PaginationControls";
import { useDocuments } from "@/hooks/useCollection";
import { useAuth } from "@/hooks/useAuth";
import { listingSchema, proposalSchema, listingStatusLabel, type ListingStatus } from "@/api/schemas";
import { LISTINGS_COLLECTION_ID, PROPOSALS_COLLECTION_ID } from "@/config/env";
import { formatCurrency, formatRelativeTime, isObjectId } from "@/lib/format";

const PAGE_SIZE = 10;
const STATUS_VARIANT: Record<ListingStatus, BadgeVariant> = {
  open: "success",
  in_progress: "warning",
  completed: "secondary",
};

/** Client-only dashboard - the RN equivalent of web/src/app/listings/mine/page.tsx. */
export function MyListingsView(): React.JSX.Element {
  const { user } = useAuth();
  const [page, setPage] = useState(1);

  const clientId = user?.id;
  const { data, isLoading, isError } = useDocuments(
    listingSchema,
    LISTINGS_COLLECTION_ID,
    { filter: { clientId }, sort: "-createdAt", page, limit: PAGE_SIZE },
    { enabled: isObjectId(clientId) },
  );
  const listings = useMemo(() => data?.data ?? [], [data]);
  const listingIds = useMemo(() => listings.map((l) => l._id), [listings]);

  // One batched query for proposal counts across every listing on this page, instead of an N+1
  // query per listing.
  const { data: proposalData } = useDocuments(
    proposalSchema,
    PROPOSALS_COLLECTION_ID,
    { filter: { listingId: { $in: listingIds } }, limit: 100 },
    { enabled: listingIds.length > 0 },
  );
  const proposalCounts = useMemo(() => {
    const counts = new Map<string, number>();
    for (const proposal of proposalData?.data ?? []) {
      counts.set(proposal.listingId, (counts.get(proposal.listingId) ?? 0) + 1);
    }
    return counts;
  }, [proposalData]);

  return (
    <FlatList
      data={listings}
      keyExtractor={(item) => item._id}
      contentContainerClassName="gap-3 px-4 pb-6"
      ListHeaderComponent={
        <View className="gap-3 pb-2">
          <Button onPress={() => router.push("/listings/new")}>Post a listing</Button>
          {isLoading && <Text className="text-sm text-muted-foreground">Loading listings…</Text>}
          {isError && <Text className="text-sm text-destructive">Couldn&apos;t load your listings.</Text>}
          {!isLoading && !isError && listings.length === 0 && (
            <Text className="text-sm text-muted-foreground">You haven&apos;t posted any listings yet.</Text>
          )}
        </View>
      }
      renderItem={({ item: listing }) => {
        const count = proposalCounts.get(listing._id) ?? 0;
        return (
          <Pressable accessibilityRole="button" onPress={() => router.push(`/listings/${listing._id}`)}>
            <Card className="gap-2">
              <View className="flex-row items-center justify-between gap-2">
                <Text className="flex-1 text-base font-semibold text-foreground" numberOfLines={1}>
                  {listing.title}
                </Text>
                <Badge variant={STATUS_VARIANT[listing.status]}>{listingStatusLabel(listing.status)}</Badge>
              </View>
              <View className="flex-row items-center justify-between">
                <Text className="text-sm text-muted-foreground">{formatCurrency(listing.budget)}</Text>
                <Text className="text-sm text-muted-foreground">
                  {count} proposal{count === 1 ? "" : "s"}
                </Text>
                <Text className="text-sm text-muted-foreground">{formatRelativeTime(listing.createdAt)}</Text>
              </View>
            </Card>
          </Pressable>
        );
      }}
      ListFooterComponent={<PaginationControls pagination={data?.pagination} onPageChange={setPage} />}
    />
  );
}
