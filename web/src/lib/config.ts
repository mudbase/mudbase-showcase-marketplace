function requireEnv(name: string, value: string | undefined): string {
  if (!value) throw new Error(`Missing required environment variable: ${name}`)
  return value
}

export const MUDBASE_PROJECT_ID = requireEnv(
  "NEXT_PUBLIC_MUDBASE_PROJECT_ID",
  process.env.NEXT_PUBLIC_MUDBASE_PROJECT_ID,
)
export const MUDBASE_URL = process.env.NEXT_PUBLIC_MUDBASE_URL ?? "https://cloud.mudbase.dev"

// Project publishable key - not currently sent on any request (collection access is authorized
// by the user's bearer JWT), kept for parity with the platform dashboard and forward-compatibility.
export const MUDBASE_API_KEY = process.env.NEXT_PUBLIC_MUDBASE_API_KEY ?? ""

export const LISTINGS_COLLECTION_ID = requireEnv(
  "NEXT_PUBLIC_LISTINGS_COLLECTION_ID",
  process.env.NEXT_PUBLIC_LISTINGS_COLLECTION_ID,
)
// The collection's slug, distinct from its _id above - the search endpoint's `collections`
// param matches on slug (see MudbaseClient.search()).
export const LISTINGS_COLLECTION_SLUG = "listings"
export const PROPOSALS_COLLECTION_ID = requireEnv(
  "NEXT_PUBLIC_PROPOSALS_COLLECTION_ID",
  process.env.NEXT_PUBLIC_PROPOSALS_COLLECTION_ID,
)
export const MESSAGES_COLLECTION_ID = requireEnv(
  "NEXT_PUBLIC_MESSAGES_COLLECTION_ID",
  process.env.NEXT_PUBLIC_MESSAGES_COLLECTION_ID,
)
