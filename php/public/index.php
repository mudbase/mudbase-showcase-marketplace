<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Controllers\AuthController;
use App\Controllers\ListingController;
use App\Controllers\MessageController;
use App\Controllers\ProposalController;
use App\Http\Flash;
use App\Mudbase\MudbaseApiError;
use App\Router;
use App\View;

$router = new Router();

$listings = new ListingController();
$proposals = new ProposalController();
$messages = new MessageController();
$auth = new AuthController();

$router->get('/', [$listings, 'index']);
$router->get('/listings/new', [$listings, 'newForm']);
$router->post('/listings', [$listings, 'create']);
$router->get('/listings/mine', [$listings, 'mine']);
$router->get('/listings/{id}', [$listings, 'show']);
$router->get('/listings/{id}/edit', [$listings, 'editForm']);
$router->post('/listings/{id}/edit', [$listings, 'update']);

$router->post('/listings/{id}/proposals', [$proposals, 'create']);
$router->post('/proposals/{id}/accept', [$proposals, 'accept']);
$router->post('/proposals/{id}/reject', [$proposals, 'reject']);
$router->get('/proposals', [$proposals, 'mine']);

$router->post('/listings/{id}/messages', [$messages, 'send']);

$router->get('/login', [$auth, 'loginForm']);
$router->post('/login', [$auth, 'login']);
$router->post('/logout', [$auth, 'logout']);

try {
    $router->dispatch((string) $_SERVER['REQUEST_METHOD'], (string) $_SERVER['REQUEST_URI'], function (): void {
        View::render('errors/not_found', [], 404);
    });
} catch (MudbaseApiError $e) {
    if ($e->isUnauthorized()) {
        // Token expired/was revoked mid-session - clear it and send the visitor back to the same
        // URL. Unlike the kanban PHP port (no guest mode at all, so a 401 always means "go log
        // back in"), this app re-bootstraps as a fresh anonymous guest on the very next request
        // (see bootstrap.php), so a browsing request degrades gracefully instead of forcing a
        // login the visitor never needed for browsing in the first place.
        $requestedPath = (string) $_SERVER['REQUEST_URI'];
        unset($_SESSION['mudbase_token'], $_SESSION['mudbase_refresh_token'], $_SESSION['mudbase_user']);
        Flash::set('error', 'Your session expired — please try again.');
        header('Location: ' . $requestedPath, true, 303);
        exit;
    }

    View::render('errors/server_error', ['message' => $e->getMessage()], 500);
} catch (\Throwable $e) {
    View::render('errors/server_error', ['message' => $e->getMessage()], 500);
}
