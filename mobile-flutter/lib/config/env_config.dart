/// Compile-time configuration, supplied via `--dart-define` /
/// `--dart-define-from-file` - this project's Flutter convention (see
/// `flutter/SKILL.md` and the sibling `mudbase-showcase-kanban`/
/// `mudbase-showcase-social` ports), never a runtime `.env` file.
///
/// Every value below is public (a Mudbase project/collection id is not a
/// secret, same as the web app's `NEXT_PUBLIC_*` vars) - there is no
/// server-side credential anywhere in this app. This app targets one
/// specific, already-provisioned, real shared project, so every value below
/// defaults to that project's real ids, matching the reference web app's own
/// `.env.example` (which ships the real values pre-filled, ready to run).
/// `--dart-define` still overrides any of them if a consumer of this repo
/// points it at their own project.
class EnvConfig {
  const EnvConfig._();

  static const String mudbaseBaseUrl = String.fromEnvironment(
    'MUDBASE_BASE_URL',
    defaultValue: 'https://cloud.mudbase.dev',
  );

  static const String mudbaseProjectId = String.fromEnvironment(
    'MUDBASE_PROJECT_ID',
    defaultValue: '6a6d3faad07caabbbdfc56a6',
  );

  /// The publishable (`pk_`) project key - safe client-side, currently
  /// unused by any request (collection reads/writes are authorized by the
  /// user's bearer JWT, not the project key), kept for parity with the
  /// platform dashboard and forward-compatibility, mirroring the web app's
  /// `MUDBASE_API_KEY`.
  static const String mudbaseApiKey = String.fromEnvironment(
    'MUDBASE_API_KEY',
    defaultValue: 'pk_7d6f88a8d8537bdf00c8cc4a2ebf79ee',
  );

  static const String listingsCollectionId = String.fromEnvironment(
    'LISTINGS_COLLECTION_ID',
    defaultValue: '6a6d3fced07caabbbdfc586b',
  );

  /// The collection's slug, distinct from its _id above - the search
  /// endpoint's `collections` param matches on slug (see
  /// `MudbaseSearchService.search`), mirroring the web app's
  /// `LISTINGS_COLLECTION_SLUG`. Not itself worth a `--dart-define` override
  /// since it's a fixed schema property of this one collection, not a
  /// per-deployment id.
  static const String listingsCollectionSlug = 'listings';

  static const String proposalsCollectionId = String.fromEnvironment(
    'PROPOSALS_COLLECTION_ID',
    defaultValue: '6a6d3fcfd07caabbbdfc5896',
  );

  static const String messagesCollectionId = String.fromEnvironment(
    'MESSAGES_COLLECTION_ID',
    defaultValue: '6a6d3fd0d07caabbbdfc58c5',
  );

  /// Fails fast at startup (in `main()`) rather than surfacing a confusing
  /// mid-flow 404/401 the first time a screen tries to read an empty
  /// collection id - mirrors the web app's `requireEnv()`
  /// (`web/src/lib/config.ts`) and the sibling Flutter ports' own
  /// `assertConfigured()`. In practice this only fires if a consumer
  /// explicitly overrides one of the defaults above with an empty string.
  static void assertConfigured() {
    final missing = <String>[
      if (mudbaseProjectId.isEmpty) 'MUDBASE_PROJECT_ID',
      if (listingsCollectionId.isEmpty) 'LISTINGS_COLLECTION_ID',
      if (proposalsCollectionId.isEmpty) 'PROPOSALS_COLLECTION_ID',
      if (messagesCollectionId.isEmpty) 'MESSAGES_COLLECTION_ID',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required --dart-define values: ${missing.join(', ')}. '
        'See README "Setup" for the full list and how to supply them.',
      );
    }
  }
}
