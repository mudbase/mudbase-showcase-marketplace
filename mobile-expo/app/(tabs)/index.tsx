import { useMemo, useState } from "react";
import { FlatList, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { AppHeader } from "@/components/layout/AppHeader";
import { ListingCard } from "@/components/listings/ListingCard";
import { ListingFilters, type ListingFilterValues } from "@/components/listings/ListingFilters";
import { PaginationControls } from "@/components/shared/PaginationControls";
import { useDocuments, useSearch } from "@/hooks/useCollection";
import { useDebounce } from "@/hooks/useDebounce";
import { listingSchema, type Listing } from "@/api/schemas";
import { LISTINGS_COLLECTION_ID, LISTINGS_COLLECTION_SLUG } from "@/config/env";
import type { PaginationMeta } from "@/api/client";

const PAGE_SIZE = 10;
const EMPTY_FILTERS: ListingFilterValues = { search: "", category: "", minBudget: "", maxBudget: "" };

/** Client-side application of the category/budget filters - needed for the search branch below,
 * since the dedicated search endpoint (see api/client.ts's search()) only takes a keyword and
 * doesn't accept additional structured filters alongside it. Byte-for-byte port of
 * web/src/app/page.tsx's matchesFilters(). */
function matchesFilters(listing: Listing, filters: ListingFilterValues): boolean {
  if (filters.category && listing.category !== filters.category) return false;
  const min = filters.minBudget ? Number(filters.minBudget) : undefined;
  const max = filters.maxBudget ? Number(filters.maxBudget) : undefined;
  if (min !== undefined && listing.budget < min) return false;
  if (max !== undefined && listing.budget > max) return false;
  return true;
}

export default function BrowseScreen(): React.JSX.Element {
  const [filters, setFilters] = useState<ListingFilterValues>(EMPTY_FILTERS);
  const [page, setPage] = useState(1);
  const debouncedSearch = useDebounce(filters.search, 300);
  const isSearching = debouncedSearch.trim().length > 0;

  // Branch 1: no keyword - real server-side filter + pagination on category/budget.
  const filter = useMemo(() => {
    const built: Record<string, unknown> = {};
    if (filters.category) built.category = filters.category;
    const min = filters.minBudget ? Number(filters.minBudget) : undefined;
    const max = filters.maxBudget ? Number(filters.maxBudget) : undefined;
    if (min !== undefined || max !== undefined) {
      built.budget = { ...(min !== undefined && { $gte: min }), ...(max !== undefined && { $lte: max }) };
    }
    return built;
  }, [filters.category, filters.minBudget, filters.maxBudget]);

  const browseQuery = useDocuments(
    listingSchema,
    LISTINGS_COLLECTION_ID,
    { filter, sort: "-createdAt", page, limit: PAGE_SIZE },
    { enabled: !isSearching },
  );

  // Branch 2: a keyword was typed - use the dedicated search endpoint (server-side regex over
  // title/description isn't reachable through the collection-data `filter` param, see
  // api/client.ts's search() for why), then apply category/budget and pagination client-side
  // over the returned batch.
  const searchQuery = useSearch(listingSchema, LISTINGS_COLLECTION_SLUG, debouncedSearch, {
    limit: 50,
    enabled: isSearching,
  });

  const searchedListings = useMemo(() => {
    const all = searchQuery.data?.results[0]?.results ?? [];
    return all.filter((listing) => matchesFilters(listing, filters));
  }, [searchQuery.data, filters]);

  const searchPagination = useMemo<PaginationMeta>(() => {
    const total = searchedListings.length;
    const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
    return { page, limit: PAGE_SIZE, total, totalPages, hasMore: page < totalPages };
  }, [searchedListings.length, page]);

  const listings = isSearching
    ? searchedListings.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)
    : (browseQuery.data?.data ?? []);
  const pagination = isSearching ? searchPagination : browseQuery.data?.pagination;
  const isLoading = isSearching ? searchQuery.isLoading : browseQuery.isLoading;
  const isError = isSearching ? searchQuery.isError : browseQuery.isError;

  // A lightweight, unfiltered sample used only to populate the category picker - avoids a
  // dedicated "distinct categories" endpoint that Mudbase's data API doesn't expose.
  const { data: categorySample } = useDocuments(listingSchema, LISTINGS_COLLECTION_ID, { limit: 100 });
  const categories = useMemo(() => {
    const set = new Set<string>();
    for (const listing of categorySample?.data ?? []) {
      if (listing.category) set.add(listing.category);
    }
    return Array.from(set).sort();
  }, [categorySample]);

  const handleFiltersChange = (next: ListingFilterValues): void => {
    setFilters(next);
    setPage(1);
  };

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top"]}>
      <FlatList
        data={listings}
        keyExtractor={(item) => item._id}
        renderItem={({ item }) => <ListingCard listing={item} />}
        contentContainerClassName="gap-3 px-4 pb-6"
        ListHeaderComponent={
          <View className="gap-4 pb-4">
            <AppHeader title="Marketplace" />
            <ListingFilters values={filters} categories={categories} onChange={handleFiltersChange} />
            {isLoading && <Text className="text-sm text-muted-foreground">Loading listings…</Text>}
            {isError && <Text className="text-sm text-destructive">Couldn&apos;t load listings. Please try again.</Text>}
            {!isLoading && !isError && listings.length === 0 && (
              <Text className="text-sm text-muted-foreground">No listings match your filters.</Text>
            )}
          </View>
        }
        ListFooterComponent={<PaginationControls pagination={pagination} onPageChange={setPage} />}
        keyboardShouldPersistTaps="handled"
      />
    </SafeAreaView>
  );
}
