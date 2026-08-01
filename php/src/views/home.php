<?php
/**
 * @var list<array<string, mixed>> $listings
 * @var array{page: int, limit: int, total: int, totalPages: int} $pagination
 * @var list<string> $categories
 * @var array{q: string, category: string, minBudget: string, maxBudget: string} $filters
 * @var string|null $error
 */

use App\View;

$title = 'Browse listings';
?>
<div>
  <h1>Find your next project</h1>
  <p class="muted">Browse open listings posted by clients looking for freelancers.</p>
</div>

<form method="get" action="/" class="card filters-bar">
  <div class="field">
    <label for="q">Search</label>
    <input type="text" id="q" name="q" placeholder="Search title or description…" value="<?= View::escape($filters['q']) ?>">
  </div>
  <div class="field">
    <label for="category">Category</label>
    <select id="category" name="category">
      <option value="">All categories</option>
      <?php foreach ($categories as $category): ?>
        <option value="<?= View::escape($category) ?>" <?= $filters['category'] === $category ? 'selected' : '' ?>><?= View::escape($category) ?></option>
      <?php endforeach; ?>
    </select>
  </div>
  <div class="field">
    <label>Budget range</label>
    <div class="budget-range">
      <input type="text" inputmode="numeric" name="minBudget" placeholder="Min" value="<?= View::escape($filters['minBudget']) ?>">
      <input type="text" inputmode="numeric" name="maxBudget" placeholder="Max" value="<?= View::escape($filters['maxBudget']) ?>">
    </div>
  </div>
  <div class="field" style="align-self:end;grid-column:1/-1;display:flex;gap:0.5rem;justify-content:flex-end">
    <button type="submit" class="btn btn--sm">Apply filters</button>
    <a class="btn btn--outline btn--sm" href="/">Clear</a>
  </div>
</form>

<?php if ($error !== null): ?>
  <p class="flash flash--error"><?= View::escape($error) ?></p>
<?php elseif ($listings === []): ?>
  <div class="empty-state">
    <p>No listings match your filters.</p>
  </div>
<?php else: ?>
  <div class="listing-grid">
    <?php foreach ($listings as $listing): ?>
      <?php require __DIR__ . '/partials/listing_card.php'; ?>
    <?php endforeach; ?>
  </div>

  <?php
    $queryParams = array_filter([
        'q' => $filters['q'],
        'category' => $filters['category'],
        'minBudget' => $filters['minBudget'],
        'maxBudget' => $filters['maxBudget'],
    ], static fn (string $v): bool => $v !== '');
    require __DIR__ . '/partials/pagination.php';
  ?>
<?php endif; ?>
