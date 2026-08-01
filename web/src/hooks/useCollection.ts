"use client"

import { useQuery, useMutation, useQueryClient, type UseQueryOptions } from "@tanstack/react-query"
import { useMudbase } from "@/lib/mudbase-provider"
import type { Document, ListResponse, QueryParams, SearchResponse } from "@/lib/mudbase"

export function useDocuments<T extends Document = Document>(
  collectionId: string,
  query?: QueryParams,
  options?: Omit<UseQueryOptions<ListResponse<T>>, "queryKey" | "queryFn">,
) {
  const { client, session, loading: sessionLoading } = useMudbase()
  const result = useQuery<ListResponse<T>>({
    queryKey: ["collection", collectionId, query],
    queryFn: () => client.getDocuments<T>(collectionId, query),
    enabled: !!session,
    ...options,
  })
  // TanStack Query v5's isLoading is isPending && isFetching - while this query sits disabled
  // (enabled: !!session, before the guest/anonymous session finishes establishing on first page
  // load), isFetching is false, so isLoading reports false too, even though no data has ever been
  // fetched. Folding in the provider's own session-establishment flag keeps isLoading true for
  // that whole window, avoiding a flash of "nothing here" before the real query ever runs.
  return { ...result, isLoading: result.isLoading || (sessionLoading && !result.data) }
}

/**
 * Server-side keyword search - see MudbaseClient.search() for why this exists instead of a
 * `$regex` filter. `collectionSlug` is the collection's slug (not its collection _id).
 */
export function useSearch<T extends Document = Document>(
  collectionSlug: string,
  q: string,
  options?: { limit?: number; enabled?: boolean },
) {
  const { client, session } = useMudbase()
  const query = q.trim()
  return useQuery<SearchResponse<T>>({
    queryKey: ["search", collectionSlug, query, options?.limit],
    queryFn: () => client.search<T>({ q: query, collections: collectionSlug, limit: options?.limit ?? 50 }),
    enabled: !!session && query.length > 0 && (options?.enabled ?? true),
  })
}

export function useDocument<T extends Document = Document>(
  collectionId: string,
  documentId: string | null | undefined,
  options?: Omit<UseQueryOptions<T>, "queryKey" | "queryFn">,
) {
  const { client } = useMudbase()
  return useQuery<T>({
    queryKey: ["collection", collectionId, "doc", documentId],
    queryFn: () => {
      if (!documentId) throw new Error("useDocument called without a documentId")
      return client.getDocument<T>(collectionId, documentId)
    },
    enabled: !!documentId,
    ...options,
  })
}

export function useCreateDocument<T extends Document = Document>(collectionId: string) {
  const { client } = useMudbase()
  const queryClient = useQueryClient()
  return useMutation<T, Error, Record<string, unknown>>({
    mutationFn: (data) => client.createDocument<T>(collectionId, data),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ["collection", collectionId] })
      queryClient.setQueryData(["collection", collectionId, "doc", created._id], created)
    },
  })
}

export function useUpdateDocument<T extends Document = Document>(collectionId: string) {
  const { client } = useMudbase()
  const queryClient = useQueryClient()
  return useMutation<T, Error, { documentId: string; data: Record<string, unknown> }>({
    mutationFn: ({ documentId, data }) => client.updateDocument<T>(collectionId, documentId, data),
    onSuccess: (updated, { documentId }) => {
      queryClient.setQueryData(["collection", collectionId, "doc", documentId], updated)
      queryClient.invalidateQueries({ queryKey: ["collection", collectionId] })
    },
  })
}

export function useDeleteDocument(collectionId: string) {
  const { client } = useMudbase()
  const queryClient = useQueryClient()
  return useMutation<void, Error, string>({
    mutationFn: (documentId) => client.deleteDocument(collectionId, documentId),
    onSuccess: (_data, documentId) => {
      queryClient.removeQueries({ queryKey: ["collection", collectionId, "doc", documentId] })
      queryClient.invalidateQueries({ queryKey: ["collection", collectionId] })
    },
  })
}
