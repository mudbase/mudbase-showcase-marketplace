import { z } from "zod";

/**
 * Runtime validation for every Mudbase response shape this app touches.
 *
 * The generated `mudbase-sdk`'s auth response models (e.g. `LoginLocalUser200ResponseUser`,
 * `CreateAnonymousSession200ResponseUser`) omit `customRole` — even though the live API includes
 * it on every project-scoped session response, and this app's entire RBAC gating depends on it —
 * the same gap the sibling `mudbase-showcase-kanban/mobile-expo` port's `schemas.ts` documents
 * against the same generated SDK. `GetLocalSession200Response.user` is typed as a bare `object`
 * for the same reason. Rather than casting past the generated types with `as`, every SDK response
 * is widened to `unknown` (always assignable, no cast needed) and parsed through one of these
 * schemas instead.
 *
 * The SDK's `SearchResponse`/`SearchResponseData`/`SearchResult` models are a more serious
 * mismatch, not just an omission: they describe `results[].item` as `{ _id, score }` only (no
 * document fields at all) and `results[].collection` as a plain string. The web reference's own
 * live smoke test (see ../../web/plan/build-plan.md) already verified the real deployed shape is
 * `{ results: [{ collection: {id,name,slug}, results: T[], pagination }], query, totalResults,
 * executionTime }` — a completely different structure. This is the same class of "generated type
 * under/mis-describes the real payload" gap, just at the response-shape level instead of a single
 * missing field, so it gets the identical treatment: widen to `unknown`, parse with
 * `searchResponseSchema` below instead of trusting the SDK's own `SearchResponse` type.
 */

// ─── Auth / User ────────────────────────────────────────────────────────────

/** Role slugs this project's multi-role auth is configured with — see plan/build-plan.md. */
export const appRoleSchema = z.enum(["client", "freelancer"]);
export type AppRole = z.infer<typeof appRoleSchema>;

export const mudbaseUserSchema = z.object({
  id: z.string(),
  email: z.string(),
  firstName: z.string(),
  lastName: z.string(),
  customRole: z.string().nullable().optional(),
  emailVerified: z.boolean().optional(),
  /** True only for the always-present guest session established at boot for public browsing —
   * distinct from a real, role-carrying signed-in account. See useAuth.isAuthenticated. */
  isAnonymous: z.boolean().optional(),
});
export type MudbaseUser = z.infer<typeof mudbaseUserSchema>;

export const authResultSchema = z.object({
  message: z.string().optional(),
  token: z.string().optional(),
  refreshToken: z.string().optional(),
  expiresIn: z.number().optional(),
  requireVerification: z.boolean().optional(),
  user: mudbaseUserSchema.optional(),
});
export type AuthResult = z.infer<typeof authResultSchema>;

// ─── Documents (Collections) ───────────────────────────────────────────────

export const documentBaseSchema = z.object({
  _id: z.string(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export const LISTING_STATUSES = ["open", "in_progress", "completed"] as const;
export const listingStatusSchema = z.enum(LISTING_STATUSES);
export type ListingStatus = z.infer<typeof listingStatusSchema>;

export const listingSchema = documentBaseSchema.extend({
  title: z.string(),
  description: z.string(),
  budget: z.number(),
  category: z.string().optional(),
  status: listingStatusSchema,
  clientId: z.string(),
  clientName: z.string(),
});
export type Listing = z.infer<typeof listingSchema>;

export function listingStatusLabel(status: ListingStatus): string {
  switch (status) {
    case "open":
      return "Open";
    case "in_progress":
      return "In progress";
    case "completed":
      return "Completed";
  }
}

export const PROPOSAL_STATUSES = ["pending", "accepted", "rejected"] as const;
export const proposalStatusSchema = z.enum(PROPOSAL_STATUSES);
export type ProposalStatus = z.infer<typeof proposalStatusSchema>;

export const proposalSchema = documentBaseSchema.extend({
  listingId: z.string(),
  freelancerId: z.string(),
  freelancerName: z.string(),
  coverLetter: z.string(),
  proposedRate: z.number(),
  status: proposalStatusSchema,
});
export type Proposal = z.infer<typeof proposalSchema>;

export function proposalStatusLabel(status: ProposalStatus): string {
  switch (status) {
    case "pending":
      return "Pending";
    case "accepted":
      return "Accepted";
    case "rejected":
      return "Rejected";
  }
}

export const messageSchema = documentBaseSchema.extend({
  listingId: z.string(),
  senderId: z.string(),
  senderName: z.string(),
  content: z.string(),
});
export type Message = z.infer<typeof messageSchema>;

// ─── Search (dedicated endpoint response — see the file-level doc comment) ────────────────────

const searchPaginationSchema = z.object({
  page: z.number(),
  limit: z.number(),
  total: z.number(),
  totalPages: z.number(),
});

export function searchResponseSchema<T extends z.ZodTypeAny>(itemSchema: T) {
  return z.object({
    results: z.array(
      z.object({
        collection: z.object({ id: z.string(), name: z.string(), slug: z.string() }),
        results: z.array(itemSchema),
        pagination: searchPaginationSchema,
      }),
    ),
    query: z.string(),
    totalResults: z.number(),
    executionTime: z.number(),
  });
}
export type SearchResponse<T> = {
  results: Array<{
    collection: { id: string; name: string; slug: string };
    results: T[];
    pagination: z.infer<typeof searchPaginationSchema>;
  }>;
  query: string;
  totalResults: number;
  executionTime: number;
};
