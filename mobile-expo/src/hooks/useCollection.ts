import { useQuery, useMutation, useQueryClient, type UseQueryOptions } from "@tanstack/react-query";
import { z } from "zod";
import { mudbaseClient, type PaginationMeta } from "@/api/client";
import { useAuth } from "@/hooks/useAuth";
import type { SearchResponse } from "@/api/schemas";

export interface QueryParams {
  filter?: Record<string, unknown>;
  sort?: string;
  page?: number;
  limit?: number;
}

/**
 * Generic, zod-typed collection query/mutation hooks - the RN equivalent of
 * web/src/hooks/useCollection.ts, adapted to this app's schema-per-call-site `MudbaseClient`
 * (see src/api/client.ts) instead of the web client's untyped `Document` shape. One generic
 * wrapper per collection, rather than one bespoke hook file per domain, mirrors the web
 * reference's own architecture most closely for these three simple-CRUD collections.
 */
export function useDocuments<T>(
  schema: z.ZodType<T>,
  collectionId: string,
  query?: QueryParams,
  options?: { enabled?: boolean } & Omit<UseQueryOptions<{ data: T[]; pagination: PaginationMeta }>, "queryKey" | "queryFn" | "enabled">,
) {
  const { isInitializing } = useAuth();
  const { enabled: enabledOption, ...queryOptions } = options ?? {};
  const enabled = (enabledOption ?? true) && !isInitializing;
  const result = useQuery({
    queryKey: ["collection", collectionId, query],
    queryFn: () => mudbaseClient.listDocuments(schema, collectionId, query ?? {}),
    enabled,
    ...queryOptions,
  });
  // While the boot-time session bootstrap (real session restore or anonymous fallback) is still
  // running, isFetching is false because the query is disabled - folding isInitializing in here
  // avoids a flash of "nothing here" before the very first real fetch ever runs.
  return { ...result, isLoading: result.isLoading || (isInitializing && !result.data) };
}

export function useDocument<T>(
  schema: z.ZodType<T>,
  collectionId: string,
  documentId: string | null | undefined,
  options?: { enabled?: boolean },
) {
  const enabled = (options?.enabled ?? true) && !!documentId;
  return useQuery({
    queryKey: ["collection", collectionId, "doc", documentId],
    queryFn: () => {
      if (!documentId) throw new Error("useDocument called without a documentId");
      return mudbaseClient.getDocument(schema, collectionId, documentId);
    },
    enabled,
  });
}

/** Server-side keyword search - see MudbaseClient.search() for why this exists instead of a
 * `$regex` filter. `collectionSlug` is the collection's slug (not its collection `_id`). */
export function useSearch<T>(
  schema: z.ZodType<T>,
  collectionSlug: string,
  q: string,
  options?: { limit?: number; enabled?: boolean },
) {
  const query = q.trim();
  return useQuery<SearchResponse<T>>({
    queryKey: ["search", collectionSlug, query, options?.limit],
    queryFn: () => mudbaseClient.search(schema, { q: query, collections: collectionSlug, limit: options?.limit ?? 50 }),
    enabled: query.length > 0 && (options?.enabled ?? true),
  });
}

export function useCreateDocument<T>(schema: z.ZodType<T>, collectionId: string) {
  const queryClient = useQueryClient();
  return useMutation<T, Error, Record<string, unknown>>({
    mutationFn: (data) => mudbaseClient.createDocument(schema, collectionId, data),
    onSuccess: (created) => {
      void queryClient.invalidateQueries({ queryKey: ["collection", collectionId] });
      const id = (created as { _id?: string })._id;
      if (id) queryClient.setQueryData(["collection", collectionId, "doc", id], created);
    },
  });
}

export function useUpdateDocument<T>(schema: z.ZodType<T>, collectionId: string) {
  const queryClient = useQueryClient();
  return useMutation<T, Error, { documentId: string; data: Record<string, unknown> }>({
    mutationFn: ({ documentId, data }) => mudbaseClient.updateDocument(schema, collectionId, documentId, data),
    onSuccess: (updated, { documentId }) => {
      queryClient.setQueryData(["collection", collectionId, "doc", documentId], updated);
      void queryClient.invalidateQueries({ queryKey: ["collection", collectionId] });
    },
  });
}
