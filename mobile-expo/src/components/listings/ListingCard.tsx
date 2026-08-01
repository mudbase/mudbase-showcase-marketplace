import { Pressable, Text, View } from "react-native";
import { router } from "expo-router";
import { Card } from "@/components/ui/Card";
import { Badge, type BadgeVariant } from "@/components/ui/Badge";
import { formatCurrency, formatRelativeTime } from "@/lib/format";
import { listingStatusLabel, type Listing, type ListingStatus } from "@/api/schemas";

const STATUS_VARIANT: Record<ListingStatus, BadgeVariant> = {
  open: "success",
  in_progress: "warning",
  completed: "secondary",
};

export function ListingCard({ listing }: { listing: Listing }): React.JSX.Element {
  return (
    <Pressable accessibilityRole="button" onPress={() => router.push(`/listings/${listing._id}`)}>
      <Card className="gap-3">
        <View className="flex-row items-start justify-between gap-2">
          <Text className="flex-1 text-base font-semibold text-foreground" numberOfLines={2}>
            {listing.title}
          </Text>
          <Badge variant={STATUS_VARIANT[listing.status]}>{listingStatusLabel(listing.status)}</Badge>
        </View>
        <Text className="text-sm text-muted-foreground" numberOfLines={3}>
          {listing.description}
        </Text>
        <View className="flex-row items-center justify-between">
          <Text className="text-sm font-semibold text-primary">{formatCurrency(listing.budget)}</Text>
          <View className="flex-row items-center gap-2">
            {listing.category && <Badge variant="outline">{listing.category}</Badge>}
            <Text className="text-xs text-muted-foreground">{formatRelativeTime(listing.createdAt)}</Text>
          </View>
        </View>
      </Card>
    </Pressable>
  );
}
