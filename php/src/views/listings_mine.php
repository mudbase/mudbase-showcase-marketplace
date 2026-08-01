<?php
/**
 * @var list<array<string, mixed>> $listings
 * @var array{page: int, limit: int, total: int, totalPages: int} $pagination
 * @var array<string, int> $proposalCounts
 * @var string|null $error
 */

use App\Support\TimeFormat;
use App\View;

$title = 'My listings';
?>
<div class="list-row-header" style="margin-bottom:1.25rem">
  <h1 style="margin:0">My listings</h1>
  <a class="btn btn--sm" href="/listings/new">Post a listing</a>
</div>

<?php if ($error !== null): ?>
  <p class="flash flash--error"><?= View::escape($error) ?></p>
<?php elseif ($listings === []): ?>
  <div class="empty-state">
    <p>You haven't posted any listings yet.</p>
  </div>
<?php else: ?>
  <div class="list-row">
    <?php foreach ($listings as $listing): ?>
      <?php
        $listingId = (string) $listing['_id'];
        $statusSlug = (string) ($listing['status'] ?? 'open');
        $statusLabels = ['open' => 'Open', 'in_progress' => 'In progress', 'completed' => 'Completed'];
        $count = $proposalCounts[$listingId] ?? 0;
      ?>
      <a href="/listings/<?= View::escape($listingId) ?>" class="card">
        <div class="list-row-header">
          <h3 style="margin:0"><?= View::escape((string) $listing['title']) ?></h3>
          <span class="status-badge status-badge--<?= View::escape($statusSlug) ?>"><?= View::escape($statusLabels[$statusSlug] ?? $statusSlug) ?></span>
        </div>
        <div class="list-row-body">
          <span><?= View::escape(TimeFormat::currency((float) ($listing['budget'] ?? 0))) ?></span>
          <span><?= (int) $count ?> proposal<?= $count === 1 ? '' : 's' ?></span>
          <span><?= View::escape(TimeFormat::relative((string) ($listing['createdAt'] ?? ''))) ?></span>
        </div>
      </a>
    <?php endforeach; ?>
  </div>

  <?php $queryParams = []; require __DIR__ . '/partials/pagination.php'; ?>
<?php endif; ?>
