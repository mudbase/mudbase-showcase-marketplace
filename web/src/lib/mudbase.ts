const MUDBASE_BASE_URL = "https://cloud.mudbase.dev"

export interface MudbaseConfig {
  baseUrl?: string
  projectId: string
}

export type AppRole = "client" | "freelancer"

export interface RegisterParams {
  email: string
  password: string
  firstName: string
  lastName: string
  role: AppRole
  /** Required by Mudbase's registration validator — a direct API call without it is rejected. */
  agreedToTerms: boolean
}

export interface LoginParams {
  email: string
  password: string
}

export interface AuthResponse {
  message: string
  token?: string
  refreshToken?: string
  expiresIn?: number
  user: UserObject
  requireVerification?: boolean
}

export interface UserObject {
  id: string
  email: string
  firstName: string
  lastName: string
  role?: string
  customRole?: string | null
  emailVerified: boolean
  isAnonymous?: boolean
}

export interface SessionResponse {
  user: UserObject
  token: string
}

export interface Document {
  _id: string
  createdAt: string
  updatedAt: string
  [key: string]: unknown
}

export interface PaginationMeta {
  page: number
  limit: number
  total: number
  totalPages: number
  hasMore: boolean
}

export interface ListResponse<T> {
  data: T[]
  pagination: PaginationMeta
}

export type MongoFilter = Record<string, unknown>

export interface QueryParams {
  filter?: MongoFilter
  sort?: string
  page?: number
  limit?: number
  fields?: string[]
}

export interface FileObject {
  id: string
  originalName: string
  fileName: string
  size: number
  mimetype: string
  url: string
  isPublic: boolean
  uploadedAt: string
}

export interface SearchParams {
  q: string
  /** Comma-separated collection slugs to restrict the search to. */
  collections?: string
  fields?: string
  limit?: number
  page?: number
}

export interface SearchCollectionResult<T> {
  collection: { id: string; name: string; slug: string }
  results: T[]
  pagination: { page: number; limit: number; total: number; totalPages: number }
}

export interface SearchResponse<T> {
  results: SearchCollectionResult<T>[]
  query: string
  totalResults: number
  executionTime: number
}

export class MudbaseError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public details?: unknown,
  ) {
    super(message)
    this.name = "MudbaseError"
  }
}

/** Narrows MudbaseError.details to read a server-provided error `code` (e.g. EMAIL_VERIFICATION_REQUIRED). */
export function errorCode(err: unknown): string | undefined {
  if (!(err instanceof MudbaseError)) return undefined
  const details = err.details as { code?: string } | undefined
  return details?.code
}

export class MudbaseClient {
  private baseUrl: string
  private projectId: string
  private token: string | null = null
  private refreshToken: string | null = null
  // Refresh tokens rotate on every use (single-use, platform-enforced) - if two requests both
  // hit a 401 at once, only the first refresh call may succeed since the second would present
  // an already-rotated-away token. This promise lets concurrent callers await the same in-flight
  // refresh instead of racing each other into failure.
  private refreshInFlight: Promise<string> | null = null

  constructor(config: MudbaseConfig) {
    this.baseUrl = config.baseUrl ?? MUDBASE_BASE_URL
    this.projectId = config.projectId
    if (typeof window !== "undefined") {
      this.token = localStorage.getItem("mudbase_token")
      this.refreshToken = localStorage.getItem("mudbase_refresh_token")
    }
  }

  getProjectId(): string {
    return this.projectId
  }

  setToken(token: string, refreshToken?: string): void {
    this.token = token
    if (typeof window !== "undefined") {
      localStorage.setItem("mudbase_token", token)
    }
    if (refreshToken) {
      this.refreshToken = refreshToken
      if (typeof window !== "undefined") {
        localStorage.setItem("mudbase_refresh_token", refreshToken)
      }
    }
  }

  clearToken(): void {
    this.token = null
    this.refreshToken = null
    if (typeof window !== "undefined") {
      localStorage.removeItem("mudbase_token")
      localStorage.removeItem("mudbase_refresh_token")
    }
  }

  getToken(): string | null {
    return this.token
  }

  private async refreshAccessToken(): Promise<string> {
    if (this.refreshInFlight) return this.refreshInFlight

    this.refreshInFlight = (async () => {
      if (!this.refreshToken) throw new MudbaseError("No refresh token available", 401)
      const res = await fetch(`${this.baseUrl}/api/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken: this.refreshToken }),
      })
      if (!res.ok) {
        this.clearToken()
        throw new MudbaseError("Session expired - please log in again", 401)
      }
      const body = (await res.json()) as { token: string; refreshToken: string }
      this.setToken(body.token, body.refreshToken)
      return body.token
    })()

    try {
      return await this.refreshInFlight
    } finally {
      this.refreshInFlight = null
    }
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown,
    options: { auth?: boolean; formData?: FormData; retriedAfterRefresh?: boolean } = {},
  ): Promise<T> {
    const headers: Record<string, string> = {}
    if (!options.formData) {
      headers["Content-Type"] = "application/json"
    }
    if (options.auth !== false && this.token) {
      headers["Authorization"] = `Bearer ${this.token}`
    }

    const res = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers,
      body: options.formData ? options.formData : body !== undefined ? JSON.stringify(body) : undefined,
    })

    if (res.status === 401 && options.auth !== false && this.refreshToken && !options.retriedAfterRefresh) {
      await this.refreshAccessToken()
      return this.request<T>(method, path, body, { ...options, retriedAfterRefresh: true })
    }

    if (!res.ok) {
      const error = (await res.json().catch(() => ({ error: res.statusText }))) as { error?: string; message?: string }
      throw new MudbaseError(error.error ?? error.message ?? "Request failed", res.status, error)
    }

    const text = await res.text()
    return text ? (JSON.parse(text) as T) : ({} as T)
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  async register(params: RegisterParams): Promise<AuthResponse> {
    // The signup validator explicitly rejects `role`/`customRole` in the request body
    // (`.unknown(false)`, a deliberate anti-role-injection control) - the role is taken only
    // from the URL path segment below, so it must not be spread into the body too.
    const { role, ...body } = params
    const res = await this.request<AuthResponse>(
      "POST",
      `/api/auth/local/signup/${role}`,
      { ...body, projectId: this.projectId },
      { auth: false },
    )
    if (res.token) this.setToken(res.token)
    return res
  }

  async login(params: LoginParams): Promise<AuthResponse> {
    const res = await this.request<AuthResponse>(
      "POST",
      "/api/auth/local/login",
      { ...params, projectId: this.projectId },
      { auth: false },
    )
    if (res.token) this.setToken(res.token)
    return res
  }

  async logout(): Promise<void> {
    try {
      await this.request<void>("POST", "/api/auth/logout", { projectId: this.projectId })
    } finally {
      this.clearToken()
    }
  }

  async getSession(): Promise<SessionResponse> {
    return this.request<SessionResponse>("GET", `/api/auth/session?projectId=${this.projectId}`)
  }

  async loginAnonymous(): Promise<AuthResponse> {
    const res = await this.request<AuthResponse>(
      "POST",
      "/api/auth/anonymous",
      { projectId: this.projectId },
      { auth: false },
    )
    if (res.token) this.setToken(res.token)
    return res
  }

  // ─── Collections ─────────────────────────────────────────────────────────────

  private dataPath(collectionId: string, documentId?: string): string {
    const base = `/api/data/projects/${this.projectId}/collections/${collectionId}/data`
    return documentId ? `${base}/${documentId}` : base
  }

  async getDocuments<T = Document>(collectionId: string, query?: QueryParams): Promise<ListResponse<T>> {
    const params = new URLSearchParams()
    if (query?.filter && Object.keys(query.filter).length > 0) {
      params.set("filter", JSON.stringify(query.filter))
    }
    if (query?.sort) params.set("sort", query.sort)
    if (query?.page !== undefined) params.set("page", String(query.page))
    if (query?.limit !== undefined) params.set("limit", String(query.limit))
    if (query?.fields?.length) params.set("fields", query.fields.join(","))

    const qs = params.toString()
    return this.request<ListResponse<T>>("GET", qs ? `${this.dataPath(collectionId)}?${qs}` : this.dataPath(collectionId))
  }

  async getDocument<T = Document>(collectionId: string, documentId: string): Promise<T> {
    const res = await this.request<{ data: T }>("GET", this.dataPath(collectionId, documentId))
    return res.data
  }

  async createDocument<T = Document>(collectionId: string, data: Record<string, unknown>): Promise<T> {
    const res = await this.request<{ message: string; data: T }>("POST", this.dataPath(collectionId), data)
    return res.data
  }

  async updateDocument<T = Document>(
    collectionId: string,
    documentId: string,
    data: Record<string, unknown>,
  ): Promise<T> {
    const res = await this.request<{ message: string; data: T }>("PATCH", this.dataPath(collectionId, documentId), data)
    return res.data
  }

  async deleteDocument(collectionId: string, documentId: string): Promise<void> {
    await this.request<{ message: string }>("DELETE", this.dataPath(collectionId, documentId))
  }

  /**
   * Server-side keyword search across a collection's string fields (title/description/name/
   * content/email). This is the real search surface — the collection-data `filter` param
   * cannot do substring search: `$regex` (and `$text`'s `$search`) are on the deployed query
   * sanitizer's dangerous-operator blocklist and always 400, verified live against this
   * project on 2026-08-01. This endpoint builds its own regex server-side (not from raw
   * client input passed through the sanitizer), so it isn't subject to that block.
   */
  async search<T = Document>(params: SearchParams): Promise<SearchResponse<T>> {
    const qs = new URLSearchParams()
    qs.set("q", params.q)
    if (params.collections) qs.set("collections", params.collections)
    if (params.fields) qs.set("fields", params.fields)
    if (params.limit !== undefined) qs.set("limit", String(params.limit))
    if (params.page !== undefined) qs.set("page", String(params.page))
    return this.request<SearchResponse<T>>("GET", `/api/search/projects/${this.projectId}/search?${qs.toString()}`)
  }

  // ─── Files (buckets) ─────────────────────────────────────────────────────────

  /**
   * Kept for API-contract completeness (mirrors the ecommerce/social showcases). Not called from
   * this app's UI in this pass - see plan/build-plan.md "Known limitations" for why portfolio
   * upload was deprioritized behind the core listings/proposals/messages flow.
   */
  async uploadFile(bucketId: string, file: File, isPublic = true): Promise<FileObject> {
    const formData = new FormData()
    formData.append("files", file)
    formData.append("isPublic", String(isPublic))
    const res = await this.request<{ success: boolean; files: FileObject[] }>(
      "POST",
      `/api/bucket/projects/${this.projectId}/buckets/${bucketId}/files`,
      undefined,
      { formData },
    )
    const uploaded = res.files[0]
    if (!uploaded) throw new MudbaseError("Upload returned no file record", 500)
    return uploaded
  }
}

let _client: MudbaseClient | null = null

export function getMudbaseClient(): MudbaseClient {
  if (!_client) throw new Error("Mudbase client not initialized. Call initMudbase() first.")
  return _client
}

export function initMudbase(config: MudbaseConfig): MudbaseClient {
  _client = new MudbaseClient(config)
  return _client
}
