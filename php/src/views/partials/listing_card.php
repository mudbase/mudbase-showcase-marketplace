<?php
/** @var array<string, mixed> $listing */

use App\Support\TimeFormat;
use App\View;

$statusSlug = (string) ($listing['status'] ?? 'open');
$statusLabels = ['open' => 'Open', 'in_progress' => 'In progress', 'completed' => 'Completed'];
?>
<a href="/listings/<?= View::escape((string) $listing['_id']) ?>" class="card listing-card">
  <div class="listing-card__header">
    <h3 class="listing-card__title"><?= View::escape((string) $listing['title']) ?></h3>
    <span class="status-badge status-badge--<?= View::escape($statusSlug) ?>"><?= View::escape($statusLabels[$statusSlug] ?? $statusSlug) ?></span>
  </div>
  <p class="listing-card__desc"><?= View::escape((string) ($listing['description'] ?? '')) ?></p>
  <div class="listing-card__meta">
    <span class="listing-card__budget"><?= View::escape(TimeFormat::currency((float) ($listing['budget'] ?? 0))) ?></span>
    <?php if (!empty($listing['category'])): ?>
      <span class="category-badge"><?= View::escape((string) $listing['category']) ?></span>
    <?php endif; ?>
  </div>
  <p class="muted" style="font-size:0.78rem;margin:0.5rem 0 0">
    Posted by <?= View::escape((string) ($listing['clientName'] ?? 'a client')) ?> · <?= View::escape(TimeFormat::relative((string) ($listing['createdAt'] ?? ''))) ?>
  </p>
</a>
