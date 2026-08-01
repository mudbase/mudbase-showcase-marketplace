<?php
/**
 * @var array<string, mixed> $message
 * @var string $userId
 */

use App\Support\Strings;
use App\Support\TimeFormat;
use App\View;

$isOwn = ($message['senderId'] ?? null) === $userId;
?>
<div class="message-bubble<?= $isOwn ? ' message-bubble--own' : '' ?>">
  <div class="message-bubble__avatar"><?= View::escape(Strings::initials((string) ($message['senderName'] ?? '?'))) ?></div>
  <div>
    <div class="message-bubble__content">
      <p style="margin:0;white-space:pre-wrap"><?= View::escape((string) ($message['content'] ?? '')) ?></p>
    </div>
    <p class="message-bubble__meta"><?= View::escape((string) ($message['senderName'] ?? '')) ?> · <?= View::escape(TimeFormat::datetime((string) ($message['createdAt'] ?? ''))) ?></p>
  </div>
</div>
