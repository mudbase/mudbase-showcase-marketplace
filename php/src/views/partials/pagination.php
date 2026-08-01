<?php
/**
 * @var array{page: int, limit: int, total: int, totalPages: int} $pagination
 * @var array<string, string> $queryParams base query params to preserve across page links (filters etc.)
 */

use App\View;

$page = (int) ($pagination['page'] ?? 1);
$totalPages = (int) ($pagination['totalPages'] ?? 1);
if ($totalPages <= 1) {
    return;
}

$buildHref = static function (int $targetPage) use ($queryParams): string {
    $params = $queryParams;
    $params['page'] = (string) $targetPage;
    return '?' . http_build_query($params);
};
?>
<nav class="pagination" aria-label="Pagination">
  <?php if ($page > 1): ?>
    <a class="btn btn--outline btn--sm" href="<?= View::escape($buildHref($page - 1)) ?>">Previous</a>
  <?php endif; ?>
  <span>Page <?= (int) $page ?> of <?= (int) $totalPages ?></span>
  <?php if ($page < $totalPages): ?>
    <a class="btn btn--outline btn--sm" href="<?= View::escape($buildHref($page + 1)) ?>">Next</a>
  <?php endif; ?>
</nav>
