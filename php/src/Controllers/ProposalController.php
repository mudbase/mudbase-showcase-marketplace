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
 * Proposals — a freelancer submits one per listing; the owning client accepts/rejects. Mirrors
 * the reference app's ProposalForm/ProposalList components.
 *
 * `accept()`/`reject()` are the highest-risk actions in this app precisely because their target is
 * chosen by an id the client controls (`/proposals/{id}/accept`) - the same shape of request the
 * sibling C# Events port's booking-cancellation IDOR exploited (a hidden-form value trusted for
 * ownership instead of the fetched record). Both methods re-fetch the proposal, then re-fetch
 * *its listing*, then verify `listing.clientId` on that freshly-fetched listing document matches
 * the current session's user id - never the session's role alone, and never anything the request
 * itself claims about who owns what. See `authorizeProposalOwnerOrRedirect()`.
 */
final class ProposalController
{
    private const MIN_COVER_LETTER_LENGTH = 20;
    private const MINE_PAGE_SIZE = 10;

    /** @param array{id: string} $params */
    public function create(array $params): void
    {
        $ctx = AppContext::current();
        $listingId = $params['id'];
        $ctx->requireRole('freelancer', "/listings/{$listingId}", 'Sign in with a freelancer account to submit a proposal.');
        $this->requireCsrf("/listings/{$listingId}");

        if (!ObjectId::isValid($listingId)) {
            Flash::set('error', 'That listing could not be found.');
            Response::redirect('/');
        }

        $coverLetter = trim((string) ($_POST['coverLetter'] ?? ''));
        $proposedRateRaw = trim((string) ($_POST['proposedRate'] ?? ''));

        if (mb_strlen($coverLetter) < self::MIN_COVER_LETTER_LENGTH) {
            Flash::set('error', 'Cover letter must be at least ' . self::MIN_COVER_LETTER_LENGTH . ' characters.');
            Response::redirect("/listings/{$listingId}");
        }
        if (!is_numeric($proposedRateRaw) || (float) $proposedRateRaw <= 0) {
            Flash::set('error', 'Proposed rate must be a number greater than 0.');
            Response::redirect("/listings/{$listingId}");
        }

        $userId = $ctx->userId();
        if ($userId === null) {
            Flash::set('error', 'Your session expired — please sign in again.');
            Response::redirect('/login');
        }

        try {
            $listing = $ctx->mudbase->getDocument($ctx->listingsCollectionId, $listingId);
        } catch (MudbaseApiError $e) {
            Flash::set('error', $e->isNotFound() ? 'That listing could not be found.' : "Couldn't load that listing: {$e->getMessage()}");
            Response::redirect('/');
        }
        if ($listing === [] || !isset($listing['_id'])) {
            Flash::set('error', 'That listing could not be found.');
            Response::redirect('/');
        }

        try {
            // One proposal per freelancer per listing - guards against a duplicate submit (double
            // click, replayed form) creating two proposals for the same pair.
            $existing = $ctx->mudbase->listDocuments(
                $ctx->proposalsCollectionId,
                ['listingId' => $listingId, 'freelancerId' => $userId],
                '-createdAt',
                1,
                1,
            );
            if ($existing['data'] !== []) {
                Flash::set('error', 'You already submitted a proposal for this listing.');
                Response::redirect("/listings/{$listingId}");
            }

            $ctx->mudbase->createDocument($ctx->proposalsCollectionId, [
                'listingId' => $listingId,
                'freelancerId' => $userId,
                'freelancerName' => $ctx->displayName() ?? 'Freelancer',
                'coverLetter' => $coverLetter,
                'proposedRate' => (float) $proposedRateRaw,
                'status' => 'pending',
            ]);
        } catch (MudbaseApiError $e) {
            Flash::set('error', $this->writeErrorMessage($e, 'submit proposals'));
            Response::redirect("/listings/{$listingId}");
        }

        Response::redirect("/listings/{$listingId}");
    }

    /** @param array{id: string} $params */
    public function accept(array $params): void
    {
        $this->decide($params['id'], 'accepted');
    }

    /** @param array{id: string} $params */
    public function reject(array $params): void
    {
        $this->decide($params['id'], 'rejected');
    }

    /** @param array<string, string> $params */
    public function mine(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireRole('freelancer', '/', 'Sign in with a freelancer account to view your proposals.');

        $userId = $ctx->userId();
        $page = max(1, (int) ($_GET['page'] ?? 1));

        $error = null;
        $proposals = [];
        $pagination = ['page' => $page, 'limit' => self::MINE_PAGE_SIZE, 'total' => 0, 'totalPages' => 1];
        $listingsById = [];

        try {
            if ($userId !== null && ObjectId::isValid($userId)) {
                $result = $ctx->mudbase->listDocuments(
                    $ctx->proposalsCollectionId,
                    ['freelancerId' => $userId],
                    '-createdAt',
                    $page,
                    self::MINE_PAGE_SIZE,
                );
                $proposals = $result['data'];
                $pagination = $result['pagination'];

                // One batched query for the listing titles referenced on this page, instead of an
                // N+1 query per proposal - matches the reference app's src/app/proposals/page.tsx.
                $listingIds = array_values(array_unique(array_map(
                    static fn (array $p): string => (string) ($p['listingId'] ?? ''),
                    $proposals,
                )));
                if ($listingIds !== []) {
                    $listingsResult = $ctx->mudbase->listDocuments(
                        $ctx->listingsCollectionId,
                        ['_id' => ['$in' => $listingIds]],
                        '-createdAt',
                        1,
                        100,
                    );
                    foreach ($listingsResult['data'] as $listing) {
                        $listingsById[(string) $listing['_id']] = $listing;
                    }
                }
            }
        } catch (MudbaseApiError $e) {
            $error = "Couldn't load your proposals: {$e->getMessage()}";
        }

        View::render('proposals_mine', [
            'proposals' => $proposals,
            'pagination' => $pagination,
            'listingsById' => $listingsById,
            'error' => $error,
        ]);
    }

    private function decide(string $proposalId, string $newStatus): void
    {
        $ctx = AppContext::current();
        $ctx->requireRole('client', '/', 'Sign in with a client account to manage proposals.');
        $this->requireCsrf('/');

        [$proposal, $listing] = $this->authorizeProposalOwnerOrRedirect($ctx, $proposalId);
        $listingId = (string) ($listing['_id'] ?? '');

        if (($proposal['status'] ?? null) !== 'pending') {
            Flash::set('error', 'This proposal has already been decided.');
            Response::redirect("/listings/{$listingId}");
        }

        try {
            $ctx->mudbase->updateDocument($ctx->proposalsCollectionId, $proposalId, ['status' => $newStatus]);
        } catch (MudbaseApiError $e) {
            Flash::set('error', $this->writeErrorMessage($e, 'manage proposals'));
        }

        Response::redirect("/listings/{$listingId}");
    }

    /**
     * Fetches the proposal by its URL id, then fetches *its listing*, then verifies the fetched
     * listing's `clientId` matches the current session's user id - the actual authorization
     * boundary for accept/reject (see class docblock). Redirects (never returns) on any failure:
     * proposal not found, listing not found, or the current user doesn't own that listing.
     *
     * @return array{0: array<string, mixed>, 1: array<string, mixed>} [proposal, listing]
     */
    private function authorizeProposalOwnerOrRedirect(AppContext $ctx, string $proposalId): array
    {
        if (!ObjectId::isValid($proposalId)) {
            Flash::set('error', 'That proposal could not be found.');
            Response::redirect('/');
        }

        try {
            $proposal = $ctx->mudbase->getDocument($ctx->proposalsCollectionId, $proposalId);
        } catch (MudbaseApiError $e) {
            Flash::set('error', $e->isNotFound() ? 'That proposal could not be found.' : "Couldn't load that proposal: {$e->getMessage()}");
            Response::redirect('/');
        }
        if ($proposal === [] || !isset($proposal['_id'])) {
            Flash::set('error', 'That proposal could not be found.');
            Response::redirect('/');
        }

        $listingId = (string) ($proposal['listingId'] ?? '');
        if (!ObjectId::isValid($listingId)) {
            Flash::set('error', 'That listing could not be found.');
            Response::redirect('/');
        }

        try {
            $listing = $ctx->mudbase->getDocument($ctx->listingsCollectionId, $listingId);
        } catch (MudbaseApiError $e) {
            Flash::set('error', $e->isNotFound() ? 'That listing could not be found.' : "Couldn't load that listing: {$e->getMessage()}");
            Response::redirect('/');
        }
        if ($listing === [] || !isset($listing['_id'])) {
            Flash::set('error', 'That listing could not be found.');
            Response::redirect('/');
        }

        $userId = $ctx->userId();
        if ($userId === null || ($listing['clientId'] ?? null) !== $userId) {
            Flash::set('error', "You don't have permission to manage proposals on this listing.");
            Response::redirect("/listings/{$listingId}");
        }

        return [$proposal, $listing];
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
