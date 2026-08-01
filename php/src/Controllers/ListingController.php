<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Http\Csrf;
use App\Http\Flash;
use App\Http\Response;
use App\Mudbase\MudbaseApiError;
use App\Support\ObjectId;
use App\View;

/**
 * Listings — browse (public), post, view detail, edit. Mirrors the reference app's `/`,
 * `/listings/new`, `/listings/[id]`, `/listings/[id]/edit`, and `/listings/mine`.
 *
 * Every action that mutates a *specific* listing (`update()`) re-fetches that listing by its URL
 * id and verifies `clientId` on the fetched document matches the current session's user id before
 * writing anything — see `fetchOwnedListingOrRedirect()`. This is the actual authorization
 * boundary: a raw POST to `/listings/{someone-elses-id}/edit` is rejected here regardless of the
 * session's role or any submitted form field, the same discipline the sibling C# Events port's
 * booking-cancellation fix established after a real IDOR was found there (a hidden-form value was
 * trusted for ownership instead of the fetched record).
 */
final class ListingController
{
    private const PAGE_SIZE = 12;
    private const MINE_PAGE_SIZE = 10;
    private const MIN_TITLE_LENGTH = 3;
    private const MAX_TITLE_LENGTH = 120;
    private const MIN_DESCRIPTION_LENGTH = 20;
    private const MAX_CATEGORY_LENGTH = 60;
    private const STATUSES = ['open', 'in_progress', 'completed'];

    /** @param array<string, string> $params */
    public function index(array $params): void
    {
        $ctx = AppContext::current();

        $q = trim((string) ($_GET['q'] ?? ''));
        $category = trim((string) ($_GET['category'] ?? ''));
        $minBudget = $this->parsePositiveNumber($_GET['minBudget'] ?? null);
        $maxBudget = $this->parsePositiveNumber($_GET['maxBudget'] ?? null);
        $page = max(1, (int) ($_GET['page'] ?? 1));

        $error = null;
        $listings = [];
        $pagination = ['page' => $page, 'limit' => self::PAGE_SIZE, 'total' => 0, 'totalPages' => 1];
        $categories = [];

        try {
            // A lightweight, unfiltered sample used only to populate the category dropdown -
            // avoids a dedicated "distinct categories" endpoint Mudbase's data API doesn't expose.
            // Same approach the reference web app uses (see its src/app/page.tsx).
            $sample = $ctx->mudbase->listDocuments($ctx->listingsCollectionId, null, '-createdAt', 1, 100)['data'];
            $categorySet = [];
            foreach ($sample as $listing) {
                $cat = is_string($listing['category'] ?? null) ? $listing['category'] : null;
                if ($cat !== null && $cat !== '') {
                    $categorySet[$cat] = true;
                }
            }
            $categories = array_keys($categorySet);
            sort($categories);

            if ($q !== '') {
                // Branch 1: a keyword was typed - use the dedicated search endpoint (server-side
                // regex over title/description isn't reachable through the collection-data
                // `filter` param - see MudbaseClient::search()), then apply category/budget
                // filters and pagination client-side over the returned batch, since the search
                // endpoint doesn't accept structured filters alongside `q`.
                $searchResult = $ctx->mudbase->search($ctx->listingsCollectionSlug, $q, 50, 1);
                $all = $searchResult['results'][0]['results'] ?? [];
                $filtered = array_values(array_filter(
                    $all,
                    function (array $listing) use ($category, $minBudget, $maxBudget): bool {
                        if ($category !== '' && ($listing['category'] ?? null) !== $category) {
                            return false;
                        }
                        $budget = is_numeric($listing['budget'] ?? null) ? (float) $listing['budget'] : 0.0;
                        if ($minBudget !== null && $budget < $minBudget) {
                            return false;
                        }
                        if ($maxBudget !== null && $budget > $maxBudget) {
                            return false;
                        }
                        return true;
                    },
                ));

                $total = count($filtered);
                $totalPages = max(1, (int) ceil($total / self::PAGE_SIZE));
                $page = min($page, $totalPages);
                $listings = array_slice($filtered, ($page - 1) * self::PAGE_SIZE, self::PAGE_SIZE);
                $pagination = ['page' => $page, 'limit' => self::PAGE_SIZE, 'total' => $total, 'totalPages' => $totalPages];
            } else {
                // Branch 2: no keyword - real server-side filter + pagination on category/budget.
                $filter = [];
                if ($category !== '') {
                    $filter['category'] = $category;
                }
                if ($minBudget !== null || $maxBudget !== null) {
                    $budgetFilter = [];
                    if ($minBudget !== null) {
                        $budgetFilter['$gte'] = $minBudget;
                    }
                    if ($maxBudget !== null) {
                        $budgetFilter['$lte'] = $maxBudget;
                    }
                    $filter['budget'] = $budgetFilter;
                }

                $result = $ctx->mudbase->listDocuments($ctx->listingsCollectionId, $filter, '-createdAt', $page, self::PAGE_SIZE);
                $listings = $result['data'];
                $pagination = $result['pagination'];
            }
        } catch (MudbaseApiError $e) {
            $error = "Couldn't load listings right now: {$e->getMessage()}";
        }

        View::render('home', [
            'listings' => $listings,
            'pagination' => $pagination,
            'categories' => $categories,
            'filters' => [
                'q' => $q,
                'category' => $category,
                'minBudget' => (string) ($_GET['minBudget'] ?? ''),
                'maxBudget' => (string) ($_GET['maxBudget'] ?? ''),
            ],
            'error' => $error,
        ]);
    }

    /** @param array<string, string> $params */
    public function newForm(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireRole('client', '/', 'Sign in with a client account to post a listing.');
        View::render('listing_form', ['mode' => 'create', 'listing' => null]);
    }

    /** @param array<string, string> $params */
    public function create(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireRole('client', '/', 'Sign in with a client account to post a listing.');
        $this->requireCsrf('/listings/new');

        [$title, $description, $budget, $category, $error] = $this->validateListingInput($_POST);
        if ($error !== null) {
            Flash::set('error', $error);
            Response::redirect('/listings/new');
        }

        $userId = $ctx->userId();
        if ($userId === null) {
            Flash::set('error', 'Your session expired — please sign in again.');
            Response::redirect('/login');
        }

        try {
            $fields = [
                'title' => $title,
                'description' => $description,
                'budget' => $budget,
                'status' => 'open',
                'clientId' => $userId,
                'clientName' => $ctx->displayName() ?? 'Client',
            ];
            if ($category !== null) {
                $fields['category'] = $category;
            }
            $created = $ctx->mudbase->createDocument($ctx->listingsCollectionId, $fields);
        } catch (MudbaseApiError $e) {
            Flash::set('error', $this->writeErrorMessage($e, 'post listings'));
            Response::redirect('/listings/new');
        }

        Response::redirect('/listings/' . (string) ($created['_id'] ?? ''));
    }

    /** @param array{id: string} $params */
    public function show(array $params): void
    {
        $ctx = AppContext::current();
        $id = $params['id'];

        if (!ObjectId::isValid($id)) {
            View::render('errors/not_found', [], 404);
            return;
        }

        try {
            $listing = $ctx->mudbase->getDocument($ctx->listingsCollectionId, $id);
        } catch (MudbaseApiError $e) {
            if ($e->isNotFound()) {
                View::render('errors/not_found', [], 404);
                return;
            }
            View::render('errors/server_error', ['message' => $e->getMessage()], 500);
            return;
        }
        if ($listing === [] || !isset($listing['_id'])) {
            View::render('errors/not_found', [], 404);
            return;
        }

        $userId = $ctx->userId();
        $isOwningClient = $ctx->isClient() && $userId !== null && ($listing['clientId'] ?? null) === $userId;
        $isFreelancer = $ctx->isFreelancer();

        $ownProposal = null;
        if ($isFreelancer && $userId !== null) {
            $result = $ctx->mudbase->listDocuments(
                $ctx->proposalsCollectionId,
                ['listingId' => $id, 'freelancerId' => $userId],
                '-createdAt',
                1,
                1,
            );
            $ownProposal = $result['data'][0] ?? null;
        }

        $proposals = [];
        if ($isOwningClient) {
            $proposals = $ctx->mudbase->listDocuments($ctx->proposalsCollectionId, ['listingId' => $id], '-createdAt', 1, 100)['data'];
        }

        // Whichever proposal (if any) has been accepted on this listing - decides who besides the
        // client can see and use the message thread. See plan/build-plan.md "Messaging visibility".
        $acceptedFreelancerId = $this->acceptedFreelancerId($ctx, $id);
        $canMessage = $ctx->isSignedIn() && $userId !== null
            && (($listing['clientId'] ?? null) === $userId || ($isFreelancer && $acceptedFreelancerId === $userId));

        $messages = [];
        if ($canMessage) {
            $messages = $ctx->mudbase->listDocuments($ctx->messagesCollectionId, ['listingId' => $id], 'createdAt', 1, 100)['data'];
        }

        View::render('listing_detail', [
            'listing' => $listing,
            'isOwningClient' => $isOwningClient,
            'isFreelancer' => $isFreelancer,
            'ownProposal' => $ownProposal,
            'proposals' => $proposals,
            'canMessage' => $canMessage,
            'messages' => $messages,
        ]);
    }

    /** @param array{id: string} $params */
    public function editForm(array $params): void
    {
        $ctx = AppContext::current();
        $id = $params['id'];
        $ctx->requireSignIn("/listings/{$id}/edit");

        $listing = $this->fetchOwnedListingOrRedirect($ctx, $id);

        View::render('listing_form', ['mode' => 'edit', 'listing' => $listing]);
    }

    /** @param array{id: string} $params */
    public function update(array $params): void
    {
        $ctx = AppContext::current();
        $id = $params['id'];
        $ctx->requireSignIn("/listings/{$id}/edit");
        $this->requireCsrf("/listings/{$id}/edit");

        // CRITICAL: re-derive ownership from the fetched document itself - see class docblock.
        // Never trust that the edit form only renders for the owner as proof this POST is
        // authorized; a raw request with someone else's listing id must be rejected here.
        $listing = $this->fetchOwnedListingOrRedirect($ctx, $id);

        [$title, $description, $budget, $category, $error] = $this->validateListingInput($_POST);
        if ($error !== null) {
            Flash::set('error', $error);
            Response::redirect("/listings/{$id}/edit");
        }

        $status = (string) ($_POST['status'] ?? '');
        if (!in_array($status, self::STATUSES, true)) {
            Flash::set('error', 'Choose a valid status.');
            Response::redirect("/listings/{$id}/edit");
        }

        try {
            $fields = [
                'title' => $title,
                'description' => $description,
                'budget' => $budget,
                'category' => $category,
                'status' => $status,
            ];
            $ctx->mudbase->updateDocument($ctx->listingsCollectionId, $id, $fields);
        } catch (MudbaseApiError $e) {
            Flash::set('error', $this->writeErrorMessage($e, 'edit this listing'));
            Response::redirect("/listings/{$id}/edit");
        }

        Response::redirect("/listings/{$id}");
    }

    /** @param array<string, string> $params */
    public function mine(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireRole('client', '/', 'Sign in with a client account to view your listings.');

        $userId = $ctx->userId();
        $page = max(1, (int) ($_GET['page'] ?? 1));

        $error = null;
        $listings = [];
        $pagination = ['page' => $page, 'limit' => self::MINE_PAGE_SIZE, 'total' => 0, 'totalPages' => 1];
        $proposalCounts = [];

        try {
            if ($userId !== null && ObjectId::isValid($userId)) {
                $result = $ctx->mudbase->listDocuments(
                    $ctx->listingsCollectionId,
                    ['clientId' => $userId],
                    '-createdAt',
                    $page,
                    self::MINE_PAGE_SIZE,
                );
                $listings = $result['data'];
                $pagination = $result['pagination'];

                // One batched query for proposal counts across every listing on this page, instead
                // of an N+1 query per listing - matches the reference app's src/app/listings/mine/page.tsx.
                $listingIds = array_values(array_map(static fn (array $l): string => (string) $l['_id'], $listings));
                if ($listingIds !== []) {
                    $proposalsResult = $ctx->mudbase->listDocuments(
                        $ctx->proposalsCollectionId,
                        ['listingId' => ['$in' => $listingIds]],
                        '-createdAt',
                        1,
                        100,
                    );
                    foreach ($proposalsResult['data'] as $proposal) {
                        $lid = (string) ($proposal['listingId'] ?? '');
                        $proposalCounts[$lid] = ($proposalCounts[$lid] ?? 0) + 1;
                    }
                }
            }
        } catch (MudbaseApiError $e) {
            $error = "Couldn't load your listings: {$e->getMessage()}";
        }

        View::render('listings_mine', [
            'listings' => $listings,
            'pagination' => $pagination,
            'proposalCounts' => $proposalCounts,
            'error' => $error,
        ]);
    }

    /** Whichever proposal on this listing (if any) has status "accepted"; null if none yet. */
    private function acceptedFreelancerId(AppContext $ctx, string $listingId): ?string
    {
        $result = $ctx->mudbase->listDocuments(
            $ctx->proposalsCollectionId,
            ['listingId' => $listingId, 'status' => 'accepted'],
            '-createdAt',
            1,
            1,
        );
        $accepted = $result['data'][0] ?? null;
        return is_array($accepted) && is_string($accepted['freelancerId'] ?? null) ? $accepted['freelancerId'] : null;
    }

    /**
     * Fetches the listing by its URL id and verifies `clientId` on the *fetched document* matches
     * the current session's user id before returning it - the actual authorization boundary for
     * every listing-mutating action (see class docblock). Redirects (never returns) if the listing
     * doesn't exist or isn't owned by the current user.
     *
     * @return array<string, mixed>
     */
    private function fetchOwnedListingOrRedirect(AppContext $ctx, string $id): array
    {
        if (!ObjectId::isValid($id)) {
            Flash::set('error', 'That listing could not be found.');
            Response::redirect('/');
        }

        try {
            $listing = $ctx->mudbase->getDocument($ctx->listingsCollectionId, $id);
        } catch (MudbaseApiError $e) {
            Flash::set('error', $e->isNotFound() ? 'That listing could not be found.' : "Couldn't load that listing: {$e->getMessage()}");
            Response::redirect('/');
        }

        if ($listing === [] || !isset($listing['_id'])) {
            Flash::set('error', 'That listing could not be found.');
            Response::redirect('/');
        }

        $userId = $ctx->userId();
        if ($ctx->role() !== 'client' || $userId === null || ($listing['clientId'] ?? null) !== $userId) {
            Flash::set('error', 'Only the client who posted this listing can manage it.');
            Response::redirect("/listings/{$id}");
        }

        return $listing;
    }

    /**
     * @param array<string, mixed> $post
     * @return array{0: string, 1: string, 2: float, 3: ?string, 4: ?string} [title, description, budget, category, error]
     */
    private function validateListingInput(array $post): array
    {
        $title = trim((string) ($post['title'] ?? ''));
        $description = trim((string) ($post['description'] ?? ''));
        $budgetRaw = trim((string) ($post['budget'] ?? ''));
        $category = trim((string) ($post['category'] ?? ''));

        if (mb_strlen($title) < self::MIN_TITLE_LENGTH || mb_strlen($title) > self::MAX_TITLE_LENGTH) {
            return ['', '', 0.0, null, 'Title must be between ' . self::MIN_TITLE_LENGTH . ' and ' . self::MAX_TITLE_LENGTH . ' characters.'];
        }
        if (mb_strlen($description) < self::MIN_DESCRIPTION_LENGTH) {
            return ['', '', 0.0, null, 'Description must be at least ' . self::MIN_DESCRIPTION_LENGTH . ' characters.'];
        }
        if (!is_numeric($budgetRaw) || (float) $budgetRaw <= 0) {
            return ['', '', 0.0, null, 'Budget must be a number greater than 0.'];
        }
        if (mb_strlen($category) > self::MAX_CATEGORY_LENGTH) {
            return ['', '', 0.0, null, 'Category is too long.'];
        }

        return [$title, $description, (float) $budgetRaw, $category !== '' ? $category : null, null];
    }

    private function parsePositiveNumber(mixed $raw): ?float
    {
        if (!is_string($raw) || $raw === '' || !is_numeric($raw)) {
            return null;
        }
        $value = (float) $raw;
        return $value >= 0 ? $value : null;
    }

    /** Surfaces a real 403 from Mudbase's own collection permissions as a clear, non-technical flash message. */
    private function writeErrorMessage(MudbaseApiError $e, string $capability): string
    {
        return $e->isForbidden() ? "You don't have permission to {$capability}." : "That didn't work: {$e->getMessage()}";
    }

    private function requireCsrf(string $fallbackRedirect): void
    {
        if (!Csrf::verify($_POST['_csrf'] ?? null)) {
            Flash::set('error', 'Your session expired — please try again.');
            Response::redirect($fallbackRedirect);
        }
    }
}
