import { Text, View } from "react-native";
import { ChevronLeft, ChevronRight } from "lucide-react-native";
import { Button } from "@/components/ui/Button";
import type { PaginationMeta } from "@/api/client";

interface PaginationControlsProps {
  pagination: PaginationMeta | undefined;
  onPageChange: (page: number) => void;
}

export function PaginationControls({ pagination, onPageChange }: PaginationControlsProps): React.JSX.Element | null {
  if (!pagination || pagination.totalPages <= 1) return null;

  return (
    <View className="flex-row items-center justify-between border-t border-border pt-4">
      <Text className="text-sm text-muted-foreground">
        Page {pagination.page} of {pagination.totalPages} · {pagination.total} total
      </Text>
      <View className="flex-row gap-2">
        <Button
          variant="outline"
          size="sm"
          icon={<ChevronLeft size={16} color="#181d25" />}
          disabled={pagination.page <= 1}
          onPress={() => onPageChange(pagination.page - 1)}
        >
          Prev
        </Button>
        <Button
          variant="outline"
          size="sm"
          icon={<ChevronRight size={16} color="#181d25" />}
          disabled={!pagination.hasMore}
          onPress={() => onPageChange(pagination.page + 1)}
        >
          Next
        </Button>
      </View>
    </View>
  );
}
