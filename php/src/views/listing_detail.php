<?php
/**
 * @var array<string, mixed> $listing
 * @var bool $isOwningClient
 * @var bool $isFreelancer
 * @var array<string, mixed>|null $ownProposal
 * @var list<array<string, mixed>> $proposals
 * @var bool $canMessage
 * @var list<array<string, mixed>> $messages
 * @var \App\Http\AppContext $context
 */

use App\Http\Csrf;
use App\Support\TimeFormat;
use App\View;

$title = (string) $listing['title'];
$statusSlug = (string) ($listing['status'] ?? 'open');
$statusLabels = ['open' => 'Open', 'in_progress' => 'In progress', 'completed' => 'Completed'];
$listingId = (string) $listing['_id'];
$userId = $context->userId();
?>
<div class="card" style="margin-bottom:1rem">
  <div class="detail-header">
    <div>
      <h1><?= View::escape((string) $listing['title']) ?></h1>
      <p class="muted">Posted by <?= View::escape((string) ($listing['clientName'] ?? 'a client')) ?> · <?= View::escape(TimeFormat::relative((string) ($listing['createdAt'] ?? ''))) ?></p>
    </div>
    <span class="status-badge status-badge--<?= View::escape($statusSlug) ?>"><?= View::escape($statusLabels[$statusSlug] ?? $statusSlug) ?></span>
  </div>
  <p style="white-space:pre-wrap"><?= View::escape((string) ($listing['description'] ?? '')) ?></p>
  <div style="display:flex;align-items:center;gap:0.75rem;font-size:0.9rem;margin-bottom:0.5rem">
    <span class="listing-card__budget"><?= View::escape(TimeFormat::currency((float) ($listing['budget'] ?? 0))) ?></span>
    <?php if (!empty($listing['category'])): ?>
      <span class="category-badge"><?= View::escape((string) $listing['category']) ?></span>
    <?php endif; ?>
  </div>
  <?php if ($isOwningClient): ?>
    <a class="btn btn--outline btn--sm" href="/listings/<?= View::escape($listingId) ?>/edit">Edit listing</a>
  <?php endif; ?>
</div>

<?php if ($isFreelancer): ?>
  <div class="card" style="margin-bottom:1rem">
    <h2>Your proposal</h2>
    <?php if ($ownProposal !== null): ?>
      <div class="proposal-item">
        <div class="proposal-item__header">
          <span class="muted">Your proposed rate: <?= View::escape(TimeFormat::currency((float) ($ownProposal['proposedRate'] ?? 0))) ?></span>
          <span class="status-badge status-badge--<?= View::escape((string) $ownProposal['status']) ?>"><?= View::escape(ucfirst((string) $ownProposal['status'])) ?></span>
        </div>
        <p style="white-space:pre-wrap"><?= View::escape((string) $ownProposal['coverLetter']) ?></p>
      </div>
    <?php else: ?>
      <form method="post" action="/listings/<?= View::escape($listingId) ?>/proposals">
        <?= Csrf::field() ?>
        <div class="field">
          <label for="coverLetter">Cover letter</label>
          <textarea id="coverLetter" name="coverLetter" rows="5" placeholder="Explain why you're a good fit for this job…" required></textarea>
          <p class="field-hint">At least 20 characters.</p>
        </div>
        <div class="field">
          <label for="proposedRate">Proposed rate (USD)</label>
          <input type="number" id="proposedRate" name="proposedRate" min="1" step="1" required>
        </div>
        <button type="submit" class="btn">Submit proposal</button>
      </form>
    <?php endif; ?>
  </div>
<?php endif; ?>

<?php if ($isOwningClient): ?>
  <div class="card" style="margin-bottom:1rem">
    <h2>Proposals received</h2>
    <?php if ($proposals === []): ?>
      <p class="muted">No proposals yet.</p>
    <?php else: ?>
      <?php foreach ($proposals as $proposal): ?>
        <?php require __DIR__ . '/partials/proposal_item.php'; ?>
      <?php endforeach; ?>
    <?php endif; ?>
  </div>
<?php endif; ?>

<?php if ($canMessage && $userId !== null): ?>
  <div class="card">
    <h2>Messages</h2>
    <p class="muted" style="margin-top:-0.4rem">Visible to the client and the accepted freelancer.</p>
    <div class="message-thread">
      <?php if ($messages === []): ?>
        <p class="muted">No messages yet — say hello.</p>
      <?php endif; ?>
      <?php foreach ($messages as $message): ?>
        <?php require __DIR__ . '/partials/message_bubble.php'; ?>
      <?php endforeach; ?>
    </div>
    <form method="post" action="/listings/<?= View::escape($listingId) ?>/messages" class="message-form">
      <?= Csrf::field() ?>
      <label for="content" class="sr-only">Message</label>
      <textarea id="content" name="content" rows="2" placeholder="Write a message…" required></textarea>
      <button type="submit" class="btn">Send</button>
    </form>
  </div>
<?php endif; ?>

<?php if (!$context->isSignedIn()): ?>
  <p class="muted" style="text-align:center">
    <a href="/login">Sign in</a> to submit a proposal or message about this listing.
  </p>
<?php endif; ?>
