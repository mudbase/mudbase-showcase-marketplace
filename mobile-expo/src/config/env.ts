/**
 * All values here are read from EXPO_PUBLIC_* env vars - Expo's convention for anything safe
 * to bundle into the client binary. A project/collection id is not a secret (see .env.example)
 * - every request this app makes authenticates with a JWT, either a real signed-in user's or an
 * anonymous guest session's (see plan/build-plan.md "Auth flow"), never a static key. There is
 * no server-only credential anywhere in this app, so nothing needs to live outside EXPO_PUBLIC_*.
 */
function requireEnv(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(
      `Missing required environment variable: ${name}. Copy .env.example to .env and fill in your provisioned Mudbase project's IDs.`,
    );
  }
  return value;
}

export const MUDBASE_URL = process.env.EXPO_PUBLIC_MUDBASE_URL ?? "https://cloud.mudbase.dev";

export const MUDBASE_PROJECT_ID = requireEnv(
  "EXPO_PUBLIC_MUDBASE_PROJECT_ID",
  process.env.EXPO_PUBLIC_MUDBASE_PROJECT_ID,
);

export const LISTINGS_COLLECTION_ID = requireEnv(
  "EXPO_PUBLIC_LISTINGS_COLLECTION_ID",
  process.env.EXPO_PUBLIC_LISTINGS_COLLECTION_ID,
);
// The collection's slug, distinct from its _id above - the search endpoint's `collections`
// query param matches on slug, not _id (see MudbaseClient.search()).
export const LISTINGS_COLLECTION_SLUG = "listings";

export const PROPOSALS_COLLECTION_ID = requireEnv(
  "EXPO_PUBLIC_PROPOSALS_COLLECTION_ID",
  process.env.EXPO_PUBLIC_PROPOSALS_COLLECTION_ID,
);

export const MESSAGES_COLLECTION_ID = requireEnv(
  "EXPO_PUBLIC_MESSAGES_COLLECTION_ID",
  process.env.EXPO_PUBLIC_MESSAGES_COLLECTION_ID,
);
