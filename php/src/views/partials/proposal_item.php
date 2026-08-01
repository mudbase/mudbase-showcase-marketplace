<?php
/** @var array<string, mixed> $proposal */

use App\Http\Csrf;
use App\Support\TimeFormat;
use App\View;

$proposalId = (string) $proposal['_id'];
$status = (string) ($proposal['status'] ?? 'pending');
?>
<div class="card proposal-item">
  <div class="proposal-item__header">
    <div>
      <h3 style="margin:0"><?= View::escape((string) ($proposal['freelancerName'] ?? 'Freelancer')) ?></h3>
      <p class="muted" style="margin:0.15rem 0 0">
        <?= View::escape(TimeFormat::currency((float) ($proposal['proposedRate'] ?? 0))) ?> · <?= View::escape(TimeFormat::relative((string) ($proposal['createdAt'] ?? ''))) ?>
      </p>
    </div>
    <span class="status-badge status-badge--<?= View::escape($status) ?>"><?= View::escape(ucfirst($status)) ?></span>
  </div>
  <p style="white-space:pre-wrap"><?= View::escape((string) ($proposal['coverLetter'] ?? '')) ?></p>
  <?php if ($status === 'pending'): ?>
    <div class="proposal-item__controls">
      <form method="post" action="/proposals/<?= View::escape($proposalId) ?>/accept">
        <?= Csrf::field() ?>
        <button type="submit" class="btn btn--sm">Accept</button>
      </form>
      <form method="post" action="/proposals/<?= View::escape($proposalId) ?>/reject">
        <?= Csrf::field() ?>
        <button type="submit" class="btn btn--outline btn--sm">Reject</button>
      </form>
    </div>
  <?php endif; ?>
</div>
