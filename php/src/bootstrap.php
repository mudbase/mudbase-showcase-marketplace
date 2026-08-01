<?php

declare(strict_types=1);

use App\Config;
use App\Http\AppContext;
use App\Mudbase\MudbaseClient;

require dirname(__DIR__) . '/vendor/autoload.php';

$rootDir = dirname(__DIR__);
Config::load($rootDir);

session_name(Config::optional('SESSION_NAME', 'mudbase_showcase_marketplace_php'));
session_start();

$mudbaseUrl = rtrim(Config::optional('MUDBASE_URL', 'https://cloud.mudbase.dev'), '/');
$projectId = Config::required('MUDBASE_PROJECT_ID');
$listingsCollectionId = Config::required('MUDBASE_LISTINGS_COLLECTION_ID');
$proposalsCollectionId = Config::required('MUDBASE_PROPOSALS_COLLECTION_ID');
$messagesCollectionId = Config::required('MUDBASE_MESSAGES_COLLECTION_ID');
$listingsCollectionSlug = Config::optional('MUDBASE_LISTINGS_COLLECTION_SLUG', 'listings');

$token = $_SESSION['mudbase_token'] ?? null;
$refreshToken = $_SESSION['mudbase_refresh_token'] ?? null;

/**
 * Wired into MudbaseClient so a mid-request 401 (access token expired) can be recovered from
 * silently: MudbaseClient::listDocuments()/search()/callApi() exchange the refresh token for a new
 * pair via POST /api/auth/refresh and retry the failing call once before giving up. This callback
 * is the only thing that persists the refreshed pair back into $_SESSION — MudbaseClient itself
 * has no session dependency, so it stays usable from a CLI script. Only a refresh-token failure
 * (itself expired/revoked) still reaches the front controller's catch(MudbaseApiError) in
 * public/index.php, which re-bootstraps as a fresh anonymous guest — see that file.
 */
$onTokenRefreshed = static function (string $newToken, ?string $newRefreshToken): void {
    $_SESSION['mudbase_token'] = $newToken;
    $_SESSION['mudbase_refresh_token'] = $newRefreshToken;
};

$mudbase = new MudbaseClient(
    $mudbaseUrl,
    $projectId,
    is_string($token) ? $token : null,
    is_string($refreshToken) ? $refreshToken : null,
    $onTokenRefreshed,
);
$user = is_array($_SESSION['mudbase_user'] ?? null) ? $_SESSION['mudbase_user'] : null;

// Unlike the kanban PHP port (every role requires a real login — no guest mode at all), this
// app's listings feed is publicly browsable (see plan/build-plan.md "Auth Model"), mirroring the
// reference Next.js app's MudbaseProvider mount effect. If this request has no session at all yet
// (first-ever visit, or a previous session's tokens were just cleared on logout/expiry), establish
// an anonymous guest session now so the very first render already has "authenticated"-role read
// access to the listings/proposals/messages collections. A failure here degrades to $user = null
// rather than blocking the request — the front controller's own MudbaseApiError handling still
// covers whatever a subsequent real read attempt surfaces.
if ($token === null && $user === null) {
    try {
        $session = $mudbase->loginAnonymous();
        $_SESSION['mudbase_token'] = $session['token'];
        $_SESSION['mudbase_refresh_token'] = $session['refreshToken'];
        $_SESSION['mudbase_user'] = $session['user'];
        $mudbase = $mudbase->withToken($session['token'], $session['refreshToken']);
        $user = $session['user'];
    } catch (\Throwable) {
        // Degrade to no session - reads that require the "authenticated" role will 401 and the
        // front controller's own error handling takes over from there.
    }
}

AppContext::set(new AppContext(
    mudbase: $mudbase,
    user: $user,
    listingsCollectionId: $listingsCollectionId,
    proposalsCollectionId: $proposalsCollectionId,
    messagesCollectionId: $messagesCollectionId,
    listingsCollectionSlug: $listingsCollectionSlug,
    mudbaseUrl: $mudbaseUrl,
));
