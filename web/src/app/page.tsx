"use client"

import { useMemo, useState } from "react"
import { ListingCard } from "@/components/listings/ListingCard"
import { ListingFilters, type ListingFilterValues } from "@/components/listings/ListingFilters"
import { PaginationControls } from "@/components/shared/PaginationControls"
import { useDocuments, useSearch } from "@/hooks/useCollection"
import { useDebounce } from "@/hooks/useDebounce"
import { LISTINGS_COLLECTION_ID, LISTINGS_COLLECTION_SLUG } from "@/lib/config"
import type { Listing } from "@/types/listing"
import type { MongoFilter, PaginationMeta } from "@/lib/mudbase"

const PAGE_SIZE = 12
const EMPTY_FILTERS: ListingFilterValues = { search: "", category: "", minBudget: "", maxBudget: "" }

/** Client-side application of the category/budget filters - needed for the search branch below,
 * since the dedicated search endpoint (see lib/mudbase.ts search()) only takes a keyword and
 * doesn't accept additional structured filters alongside it. */
function matchesFilters(listing: Listing, filters: ListingFilterValues): boolean {
  if (filters.category && listing.category !== filters.category) return false
  const min = filters.minBudget ? Number(filters.minBudget) : undefined
  const max = filters.maxBudget ? Number(filters.maxBudget) : undefined
  if (min !== undefined && listing.budget < min) return false
  if (max !== undefined && listing.budget > max) return false
  return true
}

export default function HomePage(): React.JSX.Element {
  const [filters, setFilters] = useState<ListingFilterValues>(EMPTY_FILTERS)
  const [page, setPage] = useState(1)
  const debouncedSearch = useDebounce(filters.search, 300)
  const isSearching = debouncedSearch.trim().length > 0

  // Branch 1: no keyword - real server-side filter + pagination on category/budget.
  const filter = useMemo<MongoFilter>(() => {
    const built: MongoFilter = {}
    if (filters.category) built.category = filters.category
    const min = filters.minBudget ? Number(filters.minBudget) : undefined
    const max = filters.maxBudget ? Number(filters.maxBudget) : undefined
    if (min !== undefined || max !== undefined) {
      built.budget = { ...(min !== undefined && { $gte: min }), ...(max !== undefined && { $lte: max }) }
    }
    return built
  }, [filters.category, filters.minBudget, filters.maxBudget])

  const browseQuery = useDocuments<Listing>(
    LISTINGS_COLLECTION_ID,
    { filter, sort: "-createdAt", page, limit: PAGE_SIZE },
    { enabled: !isSearching },
  )

  // Branch 2: a keyword was typed - use the dedicated search endpoint (server-side regex over
  // title/description isn't reachable through the collection-data `filter` param - see
  // lib/mudbase.ts search() for why), then apply category/budget and pagination client-side
  // over the returned batch.
  const searchQuery = useSearch<Listing>(LISTINGS_COLLECTION_SLUG, debouncedSearch, { limit: 50, enabled: isSearching })

  const searchedListings = useMemo(() => {
    const all = searchQuery.data?.results[0]?.results ?? []
    return all.filter((listing) => matchesFilters(listing, filters))
  }, [searchQuery.data, filters])

  const searchPagination = useMemo<PaginationMeta>(() => {
    const total = searchedListings.length
    const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))
    return { page, limit: PAGE_SIZE, total, totalPages, hasMore: page < totalPages }
  }, [searchedListings.length, page])

  const listings = isSearching ? searchedListings.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE) : (browseQuery.data?.data ?? [])
  const pagination = isSearching ? searchPagination : browseQuery.data?.pagination
  const isLoading = isSearching ? searchQuery.isLoading : browseQuery.isLoading
  const isError = isSearching ? searchQuery.isError : browseQuery.isError

  // A lightweight, unfiltered sample used only to populate the category dropdown - avoids a
  // dedicated "distinct categories" endpoint that Mudbase's data API doesn't expose.
  const { data: categorySample } = useDocuments<Listing>(LISTINGS_COLLECTION_ID, {
    fields: ["category"],
    limit: 100,
  })
  const categories = useMemo(() => {
    const set = new Set<string>()
    for (const listing of categorySample?.data ?? []) {
      if (listing.category) set.add(listing.category)
    }
    return Array.from(set).sort()
  }, [categorySample])

  const handleFiltersChange = (next: ListingFilterValues): void => {
    setFilters(next)
    setPage(1)
  }

  return (
    <div className="container space-y-6 py-8">
      <div>
        <h1 className="font-display text-3xl font-semibold tracking-tight">Find your next project</h1>
        <p className="text-muted-foreground">Browse open listings posted by clients looking for freelancers.</p>
      </div>

      <ListingFilters values={filters} categories={categories} onChange={handleFiltersChange} />

      {isLoading && <p className="text-sm text-muted-foreground">Loading listings…</p>}
      {isError && <p className="text-sm text-destructive">Couldn&apos;t load listings. Please try again.</p>}

      {!isLoading && !isError && listings.length === 0 && (
        <p className="text-sm text-muted-foreground">No listings match your filters.</p>
      )}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {listings.map((listing) => (
          <ListingCard key={listing._id} listing={listing} />
        ))}
      </div>

      <PaginationControls pagination={pagination} onPageChange={setPage} />
    </div>
  )
}
