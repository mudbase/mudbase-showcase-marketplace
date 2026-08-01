<?php
/**
 * @var list<array<string, mixed>> $proposals
 * @var array{page: int, limit: int, total: int, totalPages: int} $pagination
 * @var array<string, array<string, mixed>> $listingsById
 * @var string|null $error
 */

use App\Support\TimeFormat;
use App\View;

$title = 'My proposals';
?>
<div>
  <h1>My proposals</h1>
  <p class="muted">Every proposal you've submitted, across all listings.</p>
</div>

<?php if ($error !== null): ?>
  <p class="flash flash--error"><?= View::escape($error) ?></p>
<?php elseif ($proposals === []): ?>
  <div class="empty-state">
    <p>You haven't submitted any proposals yet. <a href="/">Browse listings</a>.</p>
  </div>
<?php else: ?>
  <div class="list-row">
    <?php foreach ($proposals as $proposal): ?>
      <?php
        $listingId = (string) ($proposal['listingId'] ?? '');
        $listing = $listingsById[$listingId] ?? null;
        $status = (string) ($proposal['status'] ?? 'pending');
      ?>
      <a href="/listings/<?= View::escape($listingId) ?>" class="card">
        <div class="list-row-header">
          <h3 style="margin:0"><?= View::escape((string) ($listing['title'] ?? 'Listing')) ?></h3>
          <span class="status-badge status-badge--<?= View::escape($status) ?>"><?= View::escape(ucfirst($status)) ?></span>
        </div>
        <div class="list-row-body">
          <span>Your rate: <?= View::escape(TimeFormat::currency((float) ($proposal['proposedRate'] ?? 0))) ?></span>
          <span><?= View::escape(TimeFormat::relative((string) ($proposal['createdAt'] ?? ''))) ?></span>
        </div>
      </a>
    <?php endforeach; ?>
  </div>

  <?php $queryParams = []; require __DIR__ . '/partials/pagination.php'; ?>
<?php endif; ?>
