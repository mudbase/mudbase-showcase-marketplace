<?php

declare(strict_types=1);

namespace App\Mudbase;

use GuzzleHttp\Client as GuzzleClient;
use GuzzleHttp\Exception\GuzzleException;
use Mudbase\Sdk\Api\AuthenticationApi;
use Mudbase\Sdk\Api\DataApi;
use Mudbase\Sdk\Api\SearchApi;
use Mudbase\Sdk\ApiException;
use Mudbase\Sdk\Configuration;
use Mudbase\Sdk\Model\CreateAnonymousSessionRequest;
use Mudbase\Sdk\Model\LoginLocalUserRequest;
use Mudbase\Sdk\Model\RefreshTokenRequest;

/**
 * Thin wrapper around the real, generated Mudbase PHP SDK (composer package `mudbase/sdk`,
 * namespace `Mudbase\Sdk`), ported near-verbatim from the sibling kanban PHP port's client of the
 * same name — see that file for the fuller rationale behind each design choice. This app adds two
 * things the kanban port didn't need: `loginAnonymous()` (this app has a public listings feed —
 * see plan/build-plan.md "Auth Model", unlike kanban's every-role-requires-login model) and
 * `search()` (the dedicated keyword-search endpoint this app's listings browse uses instead of a
 * `$regex` filter — see plan/build-plan.md "Search").
 *
 * Two real SDK gaps this class works around (documented in README "Known limitations", not silent
 * workarounds):
 *
 * 1. `DataApi::listData()` deserializes into `DataListResponseDataInner`, a typed model that only
 *    declares `_id`, `created_at`, `updated_at` — the generator had no way to type a project's
 *    user-defined collection fields, and unlike the single-document endpoints (whose `data`
 *    property is typed as a passthrough `object`), it did not fall back to a generic map for the
 *    list variant. Every actual field (`title`, `clientId`, `status`, ...) is silently dropped by
 *    the typed method. This class calls `DataApi::listDataRequest()` — a public method on the
 *    generated class that builds the same signed PSR-7 request — and sends it through the SDK's
 *    own Guzzle client, then decodes the JSON body itself instead of routing it through the lossy
 *    typed deserializer.
 * 2. `SearchApi::searchData()` has the identical gap one level deeper: `SearchResultItem` only
 *    types `_id` and `score`, dropping every real document field a search hit actually needs
 *    (title, description, ...). Handled the same way: `SearchApi::searchDataRequest()` builds the
 *    signed request, this class sends and decodes it directly.
 *
 * Access-token refresh: every method that hits the SDK funnels through `callApi()` (ApiException-
 * based calls) or the inline retry in `listDocuments()`/`search()` (their own raw-Guzzle path, see
 * gaps above). All attempt exactly one silent refresh-and-retry on a 401 using the refresh token
 * this instance was constructed with, via `POST /api/auth/refresh` (`AuthenticationApi::refreshToken()`).
 * A successful refresh calls the optional `$onTokenRefreshed` callback so the caller (bootstrap.php)
 * can persist the new pair into `$_SESSION` — this class has no `$_SESSION` dependency of its own,
 * keeping it usable outside a web request (e.g. from a CLI script). If the refresh itself fails
 * (refresh token expired/revoked too), the original 401 is rethrown as `MudbaseApiError` and the
 * front controller's fallback (public/index.php — clear session, re-establish as anonymous) takes over.
 */
final class MudbaseClient
{
    private readonly Configuration $config;
    private readonly GuzzleClient $httpClient;
    private readonly AuthenticationApi $auth;
    private readonly DataApi $data;
    private readonly SearchApi $searchApi;

    /**
     * The generated SDK's `DataApi::listDataRequest()`/`listData()` both throw
     * `\InvalidArgumentException` client-side for any `$limit > 100` (confirmed by reading the
     * generated source — `lib/Api/DataApi.php` hard-codes this cap, it is not a server-side
     * constraint this app can query around). `listDocuments()` silently clamps to this rather
     * than letting that exception escape as an uncaught 500 — every caller in this app is already
     * operating at demo scale, where 100 is functionally unbounded.
     */
    private const SDK_MAX_LIMIT = 100;

    /**
     * @param (callable(string $token, ?string $refreshToken): void)|null $onTokenRefreshed
     *        Invoked once, synchronously, immediately after a successful silent token refresh —
     *        the caller's chance to persist the new pair (e.g. into `$_SESSION`) before the
     *        retried call goes out with it.
     */
    public function __construct(
        private readonly string $baseUrl,
        private readonly string $projectId,
        private ?string $accessToken = null,
        private ?string $refreshTokenValue = null,
        private readonly mixed $onTokenRefreshed = null,
    ) {
        $this->config = Configuration::getDefaultConfiguration()->setHost($this->baseUrl);
        if ($this->accessToken !== null) {
            $this->config->setAccessToken($this->accessToken);
        }
        $this->httpClient = new GuzzleClient();
        $this->auth = new AuthenticationApi($this->httpClient, $this->config);
        $this->data = new DataApi($this->httpClient, $this->config);
        $this->searchApi = new SearchApi($this->httpClient, $this->config);
    }

    /**
     * Returns a new client bound to the same project/host but a different bearer token (and,
     * usually, its paired refresh token). Carries the refresh-callback forward so a client handed
     * out after login can still self-heal on a later 401 the same way the original could.
     */
    public function withToken(string $token, ?string $refreshToken = null): self
    {
        return new self($this->baseUrl, $this->projectId, $token, $refreshToken, $this->onTokenRefreshed);
    }

    // ─── Auth ────────────────────────────────────────────────────────────────

    /**
     * @return array{token: string, refreshToken: ?string, user: array<string, mixed>}
     */
    public function login(string $email, string $password): array
    {
        $request = new LoginLocalUserRequest([
            'email' => $email,
            'password' => $password,
            'project_id' => $this->projectId,
        ]);

        $response = $this->callApi(fn () => $this->auth->loginLocalUser($request));

        $token = $response->getToken();
        if ($token === null || $token === '') {
            throw new MudbaseApiError('Login did not return a token', 500);
        }

        $refreshToken = $response->getRefreshToken();
        $authed = $this->withToken($token, $refreshToken);
        return [
            'token' => $token,
            'refreshToken' => $refreshToken,
            'user' => $authed->fetchSessionUser(),
        ];
    }

    /**
     * `POST /api/auth/anonymous` — establishes a guest identity so the public listings feed can
     * read from Mudbase without forcing signup (the collection read permission is "authenticated",
     * and an anonymous session still carries that baseline). Mirrors the reference web app's
     * `MudbaseProvider` mount effect. Unlike `login()`, a failure here is not fatal to the caller —
     * bootstrap.php degrades to an unauthenticated client rather than blocking the whole request.
     *
     * @return array{token: string, refreshToken: ?string, user: array<string, mixed>}
     */
    public function loginAnonymous(): array
    {
        $request = new CreateAnonymousSessionRequest(['project_id' => $this->projectId]);
        $response = $this->callApi(fn () => $this->auth->createAnonymousSession($request));

        $token = $response->getToken();
        if ($token === null || $token === '') {
            throw new MudbaseApiError('Anonymous session did not return a token', 500);
        }

        $refreshToken = $response->getRefreshToken();
        $authed = $this->withToken($token, $refreshToken);
        return [
            'token' => $token,
            'refreshToken' => $refreshToken,
            'user' => $authed->fetchSessionUser(),
        ];
    }

    /** Best-effort — the caller clears its local session regardless of whether this succeeds. */
    public function logout(): void
    {
        try {
            $this->auth->logoutLocalUser();
        } catch (ApiException) {
            // Session may already be expired/invalid server-side; nothing left to revoke.
        }
    }

    /**
     * `GET /api/auth/local/session` — the authoritative source of the current user's full
     * application state (id, email, name, `customRole`, `isAnonymous`, ...). Deliberately used
     * instead of trusting the narrower typed `user` object returned by login/anonymous-session:
     * those typed models only declare a handful of fields — no `customRole`, which
     * `AppContext::isSignedIn()`/`role()` need — whereas this endpoint's response is a passthrough
     * object in the OpenAPI spec, so every field the server actually returns survives
     * deserialization.
     *
     * @return array<string, mixed>
     */
    public function fetchSessionUser(): array
    {
        $response = $this->callApi(fn () => $this->auth->getLocalSession($this->projectId));

        $user = $response->getUser();
        return is_array($user) ? $user : [];
    }

    // ─── Collections ─────────────────────────────────────────────────────────

    /**
     * @param array<string, mixed>|null $filter
     * @return array{data: list<array<string, mixed>>, pagination: array{page: int, limit: int, total: int, totalPages: int}}
     */
    public function listDocuments(
        string $collectionId,
        ?array $filter = null,
        string $sort = '-createdAt',
        int $page = 1,
        int $limit = 20,
    ): array {
        $filterJson = $filter !== null && $filter !== [] ? json_encode($filter) : null;
        $clampedLimit = min($limit, self::SDK_MAX_LIMIT);

        $status = 500;
        $refreshed = false;
        while (true) {
            try {
                // See class docblock gap #1 — listDataRequest() builds the same signed request the
                // typed listData() would send; we just decode the body ourselves instead of
                // letting it flow through the lossy DataListResponseDataInner model. Rebuilding
                // the request (rather than reusing one PSR-7 instance) on a retry matters: it
                // reads the Bearer header from $this->config fresh each call, so it picks up the
                // token callApi()'s refresh path just wrote into $this->config.
                $request = $this->data->listDataRequest($this->projectId, $collectionId, $page, $clampedLimit, $sort, $filterJson);
                $response = $this->httpClient->send($request, ['http_errors' => false]);
            } catch (GuzzleException $e) {
                throw new MudbaseApiError($e->getMessage(), 502);
            }

            $status = $response->getStatusCode();
            if ($status === 401 && !$refreshed && $this->refreshAccessToken()) {
                $refreshed = true;
                continue;
            }
            break;
        }

        $decoded = json_decode((string) $response->getBody(), true);

        if ($status >= 400) {
            throw MudbaseApiError::fromResponse($status, $decoded);
        }

        $data = is_array($decoded) && is_array($decoded['data'] ?? null) ? $decoded['data'] : [];
        $pagination = is_array($decoded) && is_array($decoded['pagination'] ?? null) ? $decoded['pagination'] : [];

        return [
            'data' => array_values($data),
            'pagination' => [
                'page' => (int) ($pagination['page'] ?? $page),
                'limit' => (int) ($pagination['limit'] ?? $clampedLimit),
                'total' => (int) ($pagination['total'] ?? count($data)),
                'totalPages' => (int) ($pagination['totalPages'] ?? 1),
            ],
        ];
    }

    /** @return array<string, mixed> */
    public function getDocument(string $collectionId, string $documentId): array
    {
        $response = $this->callApi(fn () => $this->data->getData($this->projectId, $collectionId, $documentId));

        $data = $response->getData();
        return is_array($data) ? $data : [];
    }

    /**
     * @param array<string, mixed> $fields
     * @return array<string, mixed>
     */
    public function createDocument(string $collectionId, array $fields): array
    {
        $response = $this->callApi(fn () => $this->data->createData($this->projectId, $collectionId, $fields));

        $data = $response->getData();
        return is_array($data) ? $data : [];
    }

    /**
     * @param array<string, mixed> $fields
     * @return array<string, mixed>
     */
    public function updateDocument(string $collectionId, string $documentId, array $fields): array
    {
        $response = $this->callApi(fn () => $this->data->updateData($this->projectId, $collectionId, $documentId, $fields));

        $data = $response->getData();
        return is_array($data) ? $data : [];
    }

    /**
     * Server-side keyword search across a collection's string fields (title/description/name/
     * content/email). This is the real search surface for the listings browse page — the
     * collection-data `filter` param cannot do substring search: `$regex` (and `$text`'s
     * `$search`) are on the deployed query sanitizer's dangerous-operator blocklist and always
     * 400 (confirmed live against this project by the reference web app — see its
     * plan/build-plan.md). This endpoint builds its own regex server-side (not from raw client
     * input passed through the sanitizer), so it isn't subject to that block.
     *
     * @return array{results: list<array{collection: array{id: string, name: string, slug: string}, results: list<array<string, mixed>>, pagination: array<string, mixed>}>, query: string, totalResults: int, executionTime: mixed}
     */
    public function search(string $collectionSlug, string $q, int $limit = 50, int $page = 1): array
    {
        $status = 500;
        $refreshed = false;
        while (true) {
            try {
                // See class docblock gap #2 — same rationale as listDocuments() above, one layer
                // deeper (SearchResultItem drops every real field too).
                $request = $this->searchApi->searchDataRequest($this->projectId, $q, $collectionSlug, null, $limit, $page);
                $response = $this->httpClient->send($request, ['http_errors' => false]);
            } catch (GuzzleException $e) {
                throw new MudbaseApiError($e->getMessage(), 502);
            }

            $status = $response->getStatusCode();
            if ($status === 401 && !$refreshed && $this->refreshAccessToken()) {
                $refreshed = true;
                continue;
            }
            break;
        }

        $decoded = json_decode((string) $response->getBody(), true);

        if ($status >= 400) {
            throw MudbaseApiError::fromResponse($status, $decoded);
        }

        $results = is_array($decoded) && is_array($decoded['results'] ?? null) ? $decoded['results'] : [];

        return [
            'results' => array_values($results),
            'query' => is_array($decoded) ? (string) ($decoded['query'] ?? $q) : $q,
            'totalResults' => is_array($decoded) ? (int) ($decoded['totalResults'] ?? 0) : 0,
            'executionTime' => is_array($decoded) ? ($decoded['executionTime'] ?? null) : null,
        ];
    }

    public function deleteDocument(string $collectionId, string $documentId): void
    {
        $this->callApi(fn () => $this->data->deleteData($this->projectId, $collectionId, $documentId));
    }

    // ─── Token refresh ───────────────────────────────────────────────────────

    /**
     * Runs one SDK call (anything that throws the generated `ApiException` on a non-2xx
     * response). On a 401, attempts exactly one silent refresh via the stored refresh token and,
     * if that succeeds, retries the same call once more with the new token already baked into
     * `$this->config` (every generated Api class shares that same Configuration instance, so the
     * retried call picks it up automatically). Any other status, or a failed/absent refresh,
     * surfaces as the usual `MudbaseApiError`.
     *
     * @template T
     * @param callable(): T $sdkCall
     * @return T
     */
    private function callApi(callable $sdkCall): mixed
    {
        try {
            return $sdkCall();
        } catch (ApiException $e) {
            if ($e->getCode() === 401 && $this->refreshAccessToken()) {
                try {
                    return $sdkCall();
                } catch (ApiException $retryException) {
                    throw MudbaseApiError::fromApiException($retryException);
                }
            }

            throw MudbaseApiError::fromApiException($e);
        }
    }

    /**
     * `POST /api/auth/refresh` — exchanges the stored refresh token for a new access/refresh
     * pair. Returns false (never throws) when there is no refresh token to use or the exchange
     * itself fails, so callers can fall back to surfacing the original 401 instead of masking it
     * with a confusing refresh-endpoint error. On success, mutates this instance's Configuration
     * in place (so already-constructed Api clients pick up the new Bearer token immediately) and
     * invokes `$onTokenRefreshed` so the caller can persist the new pair.
     */
    private function refreshAccessToken(): bool
    {
        if ($this->refreshTokenValue === null || $this->refreshTokenValue === '') {
            return false;
        }

        try {
            $response = $this->auth->refreshToken(new RefreshTokenRequest([
                'refresh_token' => $this->refreshTokenValue,
            ]));
        } catch (ApiException) {
            // Refresh token itself expired/revoked/invalid — nothing left to recover with.
            return false;
        }

        $newToken = $response->getToken();
        if (!is_string($newToken) || $newToken === '') {
            return false;
        }

        $newRefreshToken = $response->getRefreshToken();
        $this->accessToken = $newToken;
        $this->refreshTokenValue = is_string($newRefreshToken) && $newRefreshToken !== ''
            ? $newRefreshToken
            : $this->refreshTokenValue;
        $this->config->setAccessToken($newToken);

        if ($this->onTokenRefreshed !== null) {
            ($this->onTokenRefreshed)($this->accessToken, $this->refreshTokenValue);
        }

        return true;
    }
}
