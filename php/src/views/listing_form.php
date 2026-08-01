<?php
/**
 * @var string $mode 'create'|'edit'
 * @var array<string, mixed>|null $listing
 */

use App\Http\Csrf;
use App\View;

$title = $mode === 'edit' ? 'Edit listing' : 'Post a new listing';
$action = $mode === 'edit' ? '/listings/' . (string) $listing['_id'] . '/edit' : '/listings';
$statuses = ['open' => 'Open', 'in_progress' => 'In progress', 'completed' => 'Completed'];
?>
<div style="max-width:40rem;margin:0 auto">
  <div class="card">
    <h1><?= View::escape($title) ?></h1>
    <p class="muted"><?= $mode === 'edit' ? 'Update the details or change its status.' : "Freelancers will be able to browse and submit proposals immediately." ?></p>

    <form method="post" action="<?= View::escape($action) ?>">
      <?= Csrf::field() ?>

      <div class="field">
        <label for="listing-title">Title</label>
        <input type="text" id="listing-title" name="title" maxlength="120" placeholder="e.g. Build a marketing landing page"
               value="<?= View::escape((string) ($listing['title'] ?? '')) ?>" required>
      </div>

      <div class="field">
        <label for="listing-description">Description</label>
        <textarea id="listing-description" name="description" rows="6" placeholder="Describe the scope, deliverables, and timeline…" required><?= View::escape((string) ($listing['description'] ?? '')) ?></textarea>
        <p class="field-hint">At least 20 characters.</p>
      </div>

      <div class="field-row">
        <div class="field">
          <label for="listing-budget">Budget (USD)</label>
          <input type="number" id="listing-budget" name="budget" min="1" step="1" value="<?= View::escape((string) ($listing['budget'] ?? '')) ?>" required>
        </div>
        <div class="field">
          <label for="listing-category">Category (optional)</label>
          <input type="text" id="listing-category" name="category" maxlength="60" placeholder="e.g. Web Development" value="<?= View::escape((string) ($listing['category'] ?? '')) ?>">
        </div>
      </div>

      <?php if ($mode === 'edit'): ?>
        <div class="field">
          <label for="listing-status">Status</label>
          <select id="listing-status" name="status">
            <?php foreach ($statuses as $value => $label): ?>
              <option value="<?= View::escape($value) ?>" <?= ($listing['status'] ?? 'open') === $value ? 'selected' : '' ?>><?= View::escape($label) ?></option>
            <?php endforeach; ?>
          </select>
        </div>
      <?php endif; ?>

      <button type="submit" class="btn"><?= $mode === 'edit' ? 'Save changes' : 'Post listing' ?></button>
    </form>
  </div>
</div>
