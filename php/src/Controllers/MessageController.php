<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Http\Csrf;
use App\Http\Flash;
use App\Http\Response;
use App\Mudbase\MudbaseApiError;
use App\Support\ObjectId;

/**
 * Per-listing messaging — mirrors the reference app's MessageThread component.
 *
 * Messaging visibility (plan/build-plan.md "Messaging visibility"): a listing's thread is usable
 * only by the listing's client, or the specific freelancer whose proposal on that listing has been
 * accepted. Mudbase's collection permissions are collection-level, not document-level, so this
 * eligibility check is re-derived here from freshly-fetched records on every send - never from the
 * fact that the message composer only *renders* for eligible users, and never from anything the
 * request itself claims. Same IDOR discipline as ProposalController::decide()/ListingController::update().
 */
final class MessageController
{
    private const MAX_CONTENT_LENGTH = 4000;

    /** @param array{id: string} $params */
    public function send(array $params): void
    {
        $ctx = AppContext::current();
        $listingId = $params['id'];
        $ctx->requireSignIn("/listings/{$listingId}");
        $this->requireCsrf("/listings/{$listingId}");

        if (!ObjectId::isValid($listingId)) {
            Flash::set('error', 'That listing could not be found.');
            Response::redirect('/');
        }

        $content = trim((string) ($_POST['content'] ?? ''));
        if ($content === '') {
            Flash::set('error', 'Message cannot be empty.');
            Response::redirect("/listings/{$listingId}");
        }
        if (mb_strlen($content) > self::MAX_CONTENT_LENGTH) {
            Flash::set('error', 'Keep messages under ' . self::MAX_CONTENT_LENGTH . ' characters.');
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

        $canMessage = ($listing['clientId'] ?? null) === $userId;
        if (!$canMessage && $ctx->isFreelancer()) {
            $accepted = $ctx->mudbase->listDocuments(
                $ctx->proposalsCollectionId,
                ['listingId' => $listingId, 'status' => 'accepted'],
                '-createdAt',
                1,
                1,
            )['data'][0] ?? null;
            $canMessage = is_array($accepted) && ($accepted['freelancerId'] ?? null) === $userId;
        }

        if (!$canMessage) {
            Flash::set('error', "You don't have permission to message on this listing.");
            Response::redirect("/listings/{$listingId}");
        }

        try {
            $ctx->mudbase->createDocument($ctx->messagesCollectionId, [
                'listingId' => $listingId,
                'senderId' => $userId,
                'senderName' => $ctx->displayName() ?? 'User',
                'content' => $content,
            ]);
        } catch (MudbaseApiError $e) {
            Flash::set('error', $e->isForbidden() ? "You don't have permission to send messages." : "That didn't work: {$e->getMessage()}");
        }

        Response::redirect("/listings/{$listingId}");
    }

    private function requireCsrf(string $fallbackRedirect): void
    {
        if (!Csrf::verify($_POST['_csrf'] ?? null)) {
            Flash::set('error', 'Your session expired — please try again.');
            Response::redirect($fallbackRedirect);
        }
    }
}
