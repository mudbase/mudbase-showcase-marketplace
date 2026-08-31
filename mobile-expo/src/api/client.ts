import axios, { isAxiosError, type AxiosResponse } from "axios";
import { AuthenticationApi, Configuration, DataApi, SearchApi } from "mudbase-sdk";
import { z } from "zod";
import { MUDBASE_PROJECT_ID, MUDBASE_URL } from "@/config/env";
import { secureStorage, STORAGE_KEYS } from "./secureStorage";
import {
  authResultSchema,
  mudbaseUserSchema,
  searchResponseSchema,
  type AppRole,
  type AuthResult,
  type MudbaseUser,
  type SearchResponse,
} from "./schemas";

/**
 * Thin, typed wrapper around the real generated `mudbase-sdk` - same mechanism the sibling
 * `mudbase-showcase-kanban/mobile-expo` port uses: real generated `*Api` class instances
 * (`AuthenticationApi`/`DataApi`/`SearchApi`), not a unified client the SDK doesn't ship. Every
 * generated method takes a single `requestParameters` object (e.g.
 * `loginLocalUser({ loginLocalUserRequest: {...} })`), NOT positional arguments - calling
 * positionally throws a client-side `RequiredError` before any request reaches the network.
 *
 * Unlike the kanban port, this app DOES have an anonymous/guest session (`loginAnonymous()`) -
 * this project's `listings` collection grants public read to any authenticated-or-anonymous
 * session, matching the web reference's `MudbaseProvider` bootstrap (see
 * plan/build-plan.md "Auth flow"). Posting listings, submitting proposals, and messaging still
 * require a real, role-carrying `client`/`freelancer` account.
 *
 * `register()` bypasses the generated SDK entirely and calls the REST endpoint directly with a
 * plain `axios` request. The SDK's `AuthenticationApi.registerLocalUser` posts to the generic
 * `/api/auth/local/register` with a body typed `{ email, password, firstName, lastName,
 * projectId }` - no `role` and no `agreedToTerms` field exist on that generated request type at
 * all. This app (like the web reference) needs the role-specific `/api/auth/local/signup/{role}`
 * endpoint with `agreedToTerms` in the body (the signup validator rejects requests missing it) -
 * a real, verified gap in the generated SDK's coverage, not a bug in this client. This is the same
 * class of "generated SDK under-describes the real API" gap already documented in schemas.ts, just
 * surfacing as a missing operation instead of a missing response field.
 */

export class MudbaseApiError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
    public readonly code?: string,
  ) {
    super(message);
    this.name = "MudbaseApiError";
  }
}

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasMore: boolean;
}

interface ListDocumentsOptions {
  filter?: Record<string, unknown>;
  sort?: string;
  page?: number;
  limit?: number;
}

export interface RegisterParams {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  role: AppRole;
  /** Required by Mudbase's registration validator - a direct API call without it is rejected. */
  agreedToTerms: boolean;
}

function toApiError(err: unknown): MudbaseApiError {
  if (isAxiosError(err)) {
    const status = err.response?.status ?? 0;
    const body = err.response?.data as { error?: string; message?: string; code?: string } | undefined;
    return new MudbaseApiError(body?.error ?? body?.message ?? err.message, status, body?.code);
  }
  if (err instanceof Error) return new MudbaseApiError(err.message, 0);
  return new MudbaseApiError("Unknown error", 0);
}

class MudbaseClient {
  private token: string | null = null;
  private refreshTokenValue: string | null = null;
  private refreshing: Promise<void> | null = null;

  private readonly configuration = new Configuration({
    basePath: MUDBASE_URL,
    accessToken: async (): Promise<string> => this.token ?? "",
  });

  private readonly authApi = new AuthenticationApi(this.configuration);
  private readonly dataApi = new DataApi(this.configuration);
  private readonly searchApi = new SearchApi(this.configuration);

  isAuthenticated(): boolean {
    return this.token !== null;
  }

  /** Loads any persisted tokens from SecureStore at app boot. Call once, before getSession(). */
  async restoreTokens(): Promise<boolean> {
    const [token, refreshTokenValue] = await Promise.all([
      secureStorage.get(STORAGE_KEYS.ACCESS_TOKEN),
      secureStorage.get(STORAGE_KEYS.REFRESH_TOKEN),
    ]);
    if (!token || !refreshTokenValue) return false;
    this.token = token;
    this.refreshTokenValue = refreshTokenValue;
    return true;
  }

  getToken(): string | null {
    return this.token;
  }

  getProjectId(): string {
    return MUDBASE_PROJECT_ID;
  }

  private async persistTokens(token: string, refreshTokenValue: string): Promise<void> {
    this.token = token;
    this.refreshTokenValue = refreshTokenValue;
    await Promise.all([
      secureStorage.set(STORAGE_KEYS.ACCESS_TOKEN, token),
      secureStorage.set(STORAGE_KEYS.REFRESH_TOKEN, refreshTokenValue),
    ]);
  }

  private async clearTokens(): Promise<void> {
    this.token = null;
    this.refreshTokenValue = null;
    await Promise.all([
      secureStorage.delete(STORAGE_KEYS.ACCESS_TOKEN),
      secureStorage.delete(STORAGE_KEYS.REFRESH_TOKEN),
    ]);
  }

  /**
   * Refresh tokens rotate on every use and a reused one revokes the session (platform reuse-
   * detection) - this in-flight promise is shared across concurrent 401s to guarantee at most one
   * refresh call per expiry, never a stampede that would trip reuse-detection itself. Faithful
   * port of web/src/lib/mudbase.ts's `refreshAccessToken()` / `refreshInFlight`.
   */
  private async refreshSession(): Promise<void> {
    if (!this.refreshTokenValue) {
      throw new MudbaseApiError("No refresh token available - sign in again.", 401);
    }
    if (!this.refreshing) {
      this.refreshing = (async (): Promise<void> => {
        const res = await this.authApi.refreshToken({
          refreshTokenRequest: { refreshToken: this.refreshTokenValue as string },
        });
        const { token, refreshToken: nextRefreshToken } = res.data;
        if (!token || !nextRefreshToken) {
          throw new MudbaseApiError("Refresh response was missing new tokens.", 500);
        }
        await this.persistTokens(token, nextRefreshToken);
      })().finally(() => {
        this.refreshing = null;
      });
    }
    return this.refreshing;
  }

  private async withAuthRetry<T>(fn: () => Promise<AxiosResponse<T>>): Promise<T> {
    try {
      const res = await fn();
      return res.data;
    } catch (err) {
      if (isAxiosError(err) && err.response?.status === 401 && this.refreshTokenValue) {
        await this.refreshSession();
        const retried = await fn();
        return retried.data;
      }
      throw toApiError(err);
    }
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  /** Real, role-carrying signup. Bypasses the generated SDK - see the file-level doc comment. */
  async register(params: RegisterParams): Promise<MudbaseUser> {
    const { role, ...body } = params;
    try {
      // The signup validator explicitly rejects `role`/`customRole` in the request body
      // (`.unknown(false)`, a deliberate anti-role-injection control, ported forward from
      // web/src/lib/mudbase.ts) - the role is taken only from the URL path segment, so it must
      // not be spread into the body too.
      const res = await axios.post<AuthResult>(
        `${MUDBASE_URL}/api/auth/local/signup/${role}`,
        { ...body, projectId: MUDBASE_PROJECT_ID },
        { headers: { "Content-Type": "application/json" } },
      );
      const parsed = authResultSchema.parse(res.data as unknown);
      if (!parsed.token || !parsed.refreshToken || !parsed.user) {
        throw new MudbaseApiError(
          parsed.requireVerification
            ? "Account created - check your email to verify before signing in."
            : "Registration response was missing tokens.",
          parsed.requireVerification ? 201 : 500,
        );
      }
      await this.persistTokens(parsed.token, parsed.refreshToken);
      return mudbaseUserSchema.parse(parsed.user);
    } catch (err) {
      if (err instanceof MudbaseApiError) throw err;
      throw toApiError(err);
    }
  }

  async login(email: string, password: string): Promise<MudbaseUser> {
    try {
      const res = await this.authApi.loginLocalUser({
        loginLocalUserRequest: { email, password, projectId: MUDBASE_PROJECT_ID },
      });
      const { token, refreshToken: refreshTokenValue } = res.data;
      if (!token || !refreshTokenValue) {
        throw new MudbaseApiError("Login response was missing tokens.", 500);
      }
      const user = mudbaseUserSchema.parse(res.data.user as unknown);
      await this.persistTokens(token, refreshTokenValue);
      return user;
    } catch (err) {
      if (err instanceof MudbaseApiError) throw err;
      if (isAxiosError(err) && err.response?.status === 403) {
        const body = err.response.data as { code?: string; error?: string } | undefined;
        if (body?.code === "EMAIL_VERIFICATION_REQUIRED") {
          throw new MudbaseApiError("Please verify your email before signing in.", 403, body.code);
        }
      }
      throw toApiError(err);
    }
  }

  /** Guest browsing: lets the public listings feed's "authenticated" read permission resolve
   * without forcing signup - see plan/build-plan.md "Auth flow". Ported from
   * web/src/lib/mudbase-provider.tsx's own anonymous bootstrap. */
  async loginAnonymous(): Promise<MudbaseUser> {
    try {
      const res = await this.authApi.createAnonymousSession({
        createAnonymousSessionRequest: { projectId: MUDBASE_PROJECT_ID },
      });
      const { token, refreshToken: refreshTokenValue } = res.data;
      if (!token || !refreshTokenValue) {
        throw new MudbaseApiError("Anonymous session response was missing tokens.", 500);
      }
      const user = mudbaseUserSchema.parse({ ...(res.data.user as object), isAnonymous: true });
      await this.persistTokens(token, refreshTokenValue);
      return user;
    } catch (err) {
      throw toApiError(err);
    }
  }

  async logout(): Promise<void> {
    try {
      await this.authApi.logoutLocalUser();
    } catch {
      // Best-effort server-side revoke - always clear local tokens regardless.
    } finally {
      await this.clearTokens();
    }
  }

  /** Returns null (rather than throwing) when there is no valid session - the caller (authStore)
   * falls back to establishing a fresh anonymous session in that case. */
  async getSession(): Promise<MudbaseUser | null> {
    if (!this.token) return null;
    try {
      const body = await this.withAuthRetry(() => this.authApi.getLocalSession({ projectId: MUDBASE_PROJECT_ID }));
      const parsed: AuthResult = authResultSchema.parse(body);
      return parsed.user ? mudbaseUserSchema.parse(parsed.user) : null;
    } catch {
      await this.clearTokens();
      return null;
    }
  }

  // ─── Collections (Data API) ────────────────────────────────────────────────

  async listDocuments<T>(
    schema: z.ZodType<T>,
    collectionId: string,
    options: ListDocumentsOptions = {},
  ): Promise<{ data: T[]; pagination: PaginationMeta }> {
    const filterStr =
      options.filter && Object.keys(options.filter).length > 0 ? JSON.stringify(options.filter) : undefined;
    const body = await this.withAuthRetry(() =>
      this.dataApi.listData({
        projectId: MUDBASE_PROJECT_ID,
        collectionId,
        page: options.page,
        limit: options.limit,
        sort: options.sort,
        filter: filterStr,
      }),
    );
    const list = z.array(schema).parse(body.data ?? []);
    const page = body.pagination?.page ?? 1;
    const totalPages = body.pagination?.totalPages ?? 1;
    return {
      data: list,
      pagination: {
        page,
        limit: body.pagination?.limit ?? list.length,
        total: body.pagination?.total ?? list.length,
        totalPages,
        hasMore: page < totalPages,
      },
    };
  }

  async getDocument<T>(schema: z.ZodType<T>, collectionId: string, documentId: string): Promise<T> {
    const body = await this.withAuthRetry(() =>
      this.dataApi.getData({ projectId: MUDBASE_PROJECT_ID, collectionId, documentId }),
    );
    return schema.parse(body.data);
  }

  async createDocument<T>(schema: z.ZodType<T>, collectionId: string, data: Record<string, unknown>): Promise<T> {
    const body = await this.withAuthRetry(() =>
      this.dataApi.createData({ projectId: MUDBASE_PROJECT_ID, collectionId, body: data }),
    );
    return schema.parse(body.data);
  }

  async updateDocument<T>(
    schema: z.ZodType<T>,
    collectionId: string,
    documentId: string,
    data: Record<string, unknown>,
  ): Promise<T> {
    const body = await this.withAuthRetry(() =>
      this.dataApi.updateData({ projectId: MUDBASE_PROJECT_ID, collectionId, documentId, body: data }),
    );
    return schema.parse(body.data);
  }

  /**
   * Server-side keyword search across a collection's string fields (title/description/name/
   * content/email). This is the real search surface - the collection-data `filter` param cannot
   * do substring search: `$regex` (and `$text`'s `$search`) are on the deployed query sanitizer's
   * dangerous-operator blocklist and always 400 (see plan/build-plan.md - this is a deliberate DoS
   * guard, not a bug, and it applies here exactly as it does in the web reference). `collections`
   * takes the collection's slug (see LISTINGS_COLLECTION_SLUG), not its `_id`.
   */
  async search<T>(itemSchema: z.ZodType<T>, params: { q: string; collections: string; limit?: number }): Promise<SearchResponse<T>> {
    const body = await this.withAuthRetry(() =>
      this.searchApi.searchData({
        projectId: MUDBASE_PROJECT_ID,
        q: params.q,
        collections: params.collections,
        limit: params.limit,
      }),
    );
    return searchResponseSchema(itemSchema).parse(body as unknown);
  }
}

export const mudbaseClient = new MudbaseClient();
