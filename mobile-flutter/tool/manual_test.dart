// ignore_for_file: avoid_print
//
// Standalone, non-Flutter smoke test that exercises this app's own
// `lib/core/*`/`lib/data/*` layer - the exact classes `AuthController`,
// `ListingsController`, `ListingDetailController`, `ProposalReviewController`,
// and `MessageThreadController` call - directly against the real, live
// `cloud.mudbase.dev` project. No Flutter SDK/device is required to run
// this: `AuthService`, `MudbaseDataService`, `MudbaseSearchService`, and
// every repository only depend on `dio`/`mudbase_sdk`, never
// `package:flutter`. Mirrors the sibling social/ecommerce/kanban Flutter
// apps' `tool/manual_test.dart` in structure and intent.
//
// Run with (values are this showcase's real, already-provisioned ids - not
// secrets, same ones baked into `dart_define.example.json` and
// `lib/config/env_config.dart`'s own defaults):
//
//   dart run tool/manual_test.dart
//
// NOTE (environment constraint, documented in `plan/build-plan.md` "Testing
// Note"): this build environment has no Flutter SDK installed, and this
// project's pubspec.yaml depends on `flutter: sdk: flutter` - so `dart pub
// get`/`dart run` cannot resolve *this* package's dependencies here
// directly. This script was actually executed via the scratch-package
// technique documented in `plan/build-plan.md` (copying the Flutter-free
// subset of `lib/` into a throwaway package with a `flutter`-free
// `pubspec.yaml`) - see that section for the real, live output this
// produced.
//
// Exits with a non-zero status if any required step fails, printing which
// step and why.
import 'dart:io';

import 'package:mudbase_showcase_marketplace/config/env_config.dart';
import 'package:mudbase_showcase_marketplace/core/auth_service.dart';
import 'package:mudbase_showcase_marketplace/core/mudbase_data_service.dart';
import 'package:mudbase_showcase_marketplace/core/mudbase_exception.dart';
import 'package:mudbase_showcase_marketplace/core/mudbase_search_service.dart';
import 'package:mudbase_showcase_marketplace/data/repositories/listing_repository.dart';
import 'package:mudbase_showcase_marketplace/data/repositories/message_repository.dart';
import 'package:mudbase_showcase_marketplace/data/repositories/proposal_repository.dart';
import 'package:mudbase_showcase_marketplace/models/listing.dart';
import 'package:mudbase_showcase_marketplace/models/proposal.dart';
import 'package:mudbase_sdk/mudbase_sdk.dart';

// The two already-verified, already-registered demo accounts named in this
// app's own task brief - this script only ever logs in, never registers.
const _clientEmail = 'market.client.demo@gmail.com';
const _freelancerEmail = 'market.freelancer.demo@gmail.com';
const _password = 'DemoTest123!';

// A distinctly-timestamped test listing so this run's writes are easy to
// spot and don't collide with any other language/platform port's own smoke
// test data on this shared demo project.
final String _testListingTitle =
    'Flutter smoke test listing ${DateTime.now().millisecondsSinceEpoch}';

int _passed = 0;
int _failed = 0;

Future<void> _step(String description, Future<void> Function() action) async {
  stdout.write('- $description ... ');
  try {
    await action();
    stdout.writeln('PASS');
    _passed++;
  } on Object catch (error) {
    stdout.writeln('FAIL ($error)');
    _failed++;
  }
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

/// The shared `/api/auth/local/login` endpoint is rate-limited to 5
/// requests / 15 minutes per IP, and this same demo project is exercised by
/// every language/platform port's own smoke test (often concurrently, from
/// several build sessions at once) - a 429/"too many requests" here is a
/// real, expected platform control, not a bug. Waits out the window
/// synchronously (bounded retries) rather than failing the whole run.
/// Observed live during this build: a run from one egress IP can 429 on one
/// login while a concurrent run from a different IP (or a fresh attempt
/// moments later) succeeds - contention is per-window and shared across
/// every concurrent smoke test on this project, not a fixed per-caller
/// quota, so a short bounded retry (rather than one giant wait) is the
/// right shape here.
Future<T> _withRateLimitRetry<T>(Future<T> Function() action) async {
  const maxAttempts = 3;
  const backoff = Duration(seconds: 90);
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } on MudbaseException catch (error) {
      final isRateLimited = error.statusCode == 429 ||
          error.message.toLowerCase().contains('too many requests');
      if (!isRateLimited || attempt == maxAttempts) rethrow;
      stdout.writeln(
        '  (rate limited, waiting ${backoff.inSeconds}s before retry '
        '$attempt/$maxAttempts) ...',
      );
      await Future<void>.delayed(backoff);
    }
  }
  throw StateError('unreachable');
}

Future<void> main() async {
  print('Mudbase Showcase Marketplace (Flutter) - live manual smoke test');
  print('Base URL: ${EnvConfig.mudbaseBaseUrl}');
  print('Project:  ${EnvConfig.mudbaseProjectId}');
  print('');

  final sdk = MudbaseSdk(basePathOverride: EnvConfig.mudbaseBaseUrl);
  final authService = AuthService(sdk, EnvConfig.mudbaseProjectId);
  final dataService = MudbaseDataService(sdk, EnvConfig.mudbaseProjectId);
  final searchService = MudbaseSearchService(sdk, EnvConfig.mudbaseProjectId);
  final listingRepo = ListingRepository(dataService, searchService);
  final proposalRepo = ProposalRepository(dataService);
  final messageRepo = MessageRepository(dataService);

  String? clientToken;
  String? clientId;
  String? clientName;
  String? freelancerToken;
  String? freelancerRefreshToken;
  String? freelancerId;
  String? freelancerName;
  Listing? createdListing;
  Proposal? createdProposal;

  await _step('login as Client', () async {
    final json = await _withRateLimitRetry(
      () => authService.login(email: _clientEmail, password: _password),
    );
    clientToken = json['token'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    _expect(clientToken != null, 'no token returned');
    _expect(user != null, 'no user returned');
    _expect(user!['customRole'] == 'client', 'expected customRole "client"');
    clientId = user['id'] as String? ?? user['_id'] as String?;
    clientName = '${user['firstName']} ${user['lastName']}';
  });

  await _step('login as Freelancer', () async {
    final json = await _withRateLimitRetry(
      () => authService.login(email: _freelancerEmail, password: _password),
    );
    freelancerToken = json['token'] as String?;
    freelancerRefreshToken = json['refreshToken'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    _expect(freelancerToken != null, 'no token returned');
    _expect(user != null, 'no user returned');
    _expect(
      user!['customRole'] == 'freelancer',
      'expected customRole "freelancer"',
    );
    freelancerId = user['id'] as String? ?? user['_id'] as String?;
    freelancerName = '${user['firstName']} ${user['lastName']}';
  });

  await _step('Client posts a new listing', () async {
    final listing = await listingRepo.create(
      token: clientToken!,
      title: _testListingTitle,
      description:
          'A distinctly-named listing created by the Flutter port live '
          'smoke test, exercising the full client -> freelancer -> '
          'accept -> message flow end to end.',
      budget: 1800,
      category: 'Web Development',
      clientId: clientId!,
      clientName: clientName!,
    );
    _expect(listing.title == _testListingTitle, 'title mismatch');
    _expect(listing.status == ListingStatus.open, 'expected status "open"');
    createdListing = listing;
  });

  await _step(
    'Freelancer browses listings and finds the new one (server-side filter)',
    () async {
      final page = await listingRepo.browse(
        token: freelancerToken!,
        filter: {'clientId': clientId},
        limit: 20,
      );
      final found = page.items.any((l) => l.id == createdListing!.id);
      _expect(found, 'new listing not found in browse results');
    },
  );

  await _step(
    'Freelancer searches for the listing by keyword (dedicated search '
    'endpoint, not \$regex)',
    () async {
      final results = await listingRepo.search(
        token: freelancerToken!,
        q: 'Flutter smoke test listing',
        limit: 20,
      );
      final found = results.any((l) => l.id == createdListing!.id);
      _expect(found, 'new listing not found via search endpoint');
    },
  );

  await _step('Freelancer submits a proposal on the listing', () async {
    final proposal = await proposalRepo.create(
      token: freelancerToken!,
      listingId: createdListing!.id,
      freelancerId: freelancerId!,
      freelancerName: freelancerName!,
      coverLetter: "I've built several landing pages like this and can deliver "
          'within a week.',
      proposedRate: 1500,
    );
    _expect(
      proposal.status == ProposalStatus.pending,
      'expected status "pending"',
    );
    createdProposal = proposal;
  });

  await _step(
    'Client reads proposals received on the listing and finds it pending',
    () async {
      final proposals = await proposalRepo.forListing(
        token: clientToken!,
        listingId: createdListing!.id,
      );
      final match = proposals.where((p) => p.id == createdProposal!.id);
      _expect(match.isNotEmpty, 'submitted proposal not found');
      _expect(
        match.first.status == ProposalStatus.pending,
        'expected status "pending"',
      );
    },
  );

  await _step(
    'Client accepts the proposal (status field write - previously blocked, '
    'fixed in mudbase-server commit 251db188)',
    () async {
      final updated = await proposalRepo.updateStatus(
        token: clientToken!,
        proposalId: createdProposal!.id,
        status: ProposalStatus.accepted,
      );
      _expect(
        updated.status == ProposalStatus.accepted,
        'expected status "accepted"',
      );
    },
  );

  await _step(
    'acceptedFreelancerId now resolves to the freelancer (drives message '
    'thread visibility)',
    () async {
      final acceptedId = await proposalRepo.acceptedFreelancerId(
        token: clientToken!,
        listingId: createdListing!.id,
      );
      _expect(
        acceptedId == freelancerId,
        'accepted freelancer id mismatch: $acceptedId != $freelancerId',
      );
    },
  );

  await _step('Client sends a message on the listing thread', () async {
    final message = await messageRepo.send(
      token: clientToken!,
      listingId: createdListing!.id,
      senderId: clientId!,
      senderName: clientName!,
      content: "You're hired! Let's get started.",
    );
    _expect(message.content.contains('hired'), 'message content mismatch');
  });

  await _step(
    'Freelancer (now accepted) reads the thread and sees the client\'s message',
    () async {
      final messages = await messageRepo.forListing(
        token: freelancerToken!,
        listingId: createdListing!.id,
      );
      final found = messages.any((m) => m.senderId == clientId);
      _expect(found, "client's message not visible to accepted freelancer");
    },
  );

  await _step('Freelancer replies on the thread', () async {
    final message = await messageRepo.send(
      token: freelancerToken!,
      listingId: createdListing!.id,
      senderId: freelancerId!,
      senderName: freelancerName!,
      content: 'Thank you, starting today!',
    );
    _expect(message.senderId == freelancerId, 'sender id mismatch');
  });

  await _step(
    "Client reads the thread and sees the freelancer's reply",
    () async {
      final messages = await messageRepo.forListing(
        token: clientToken!,
        listingId: createdListing!.id,
      );
      final found = messages.any((m) => m.senderId == freelancerId);
      _expect(found, "freelancer's reply not visible to client");
    },
  );

  await _step(
    "Freelancer's own proposal now reads back as accepted",
    () async {
      final ownProposal = await proposalRepo.ownProposal(
        token: freelancerToken!,
        listingId: createdListing!.id,
        freelancerId: freelancerId!,
      );
      _expect(ownProposal != null, 'own proposal not found');
      _expect(
        ownProposal!.status == ProposalStatus.accepted,
        'expected status "accepted", got ${ownProposal.status}',
      );
    },
  );

  await _step(
    'POST /api/auth/refresh returns a new, distinct, usable token pair',
    () async {
      // Reuses the freelancer's own refresh token captured at login time
      // (not a fresh login call) - the login endpoint is the rate-limited
      // one (5 requests / 15 minutes per IP, shared across every
      // language/platform port's own smoke test on this project), so this
      // step must not spend another login attempt just to exercise refresh.
      final refreshToken = freelancerRefreshToken;
      _expect(refreshToken != null, 'no refreshToken captured at login');
      final refreshed = await authService.refreshSession(refreshToken!);
      final newToken = refreshed['token'] as String?;
      _expect(newToken != null, 'no token returned by refresh');
      _expect(newToken != freelancerToken, 'refreshed token not distinct');
      // Confirm the new token is actually usable.
      final session = await authService.getSession(newToken!);
      _expect(session['user'] != null, 'refreshed token not usable');
    },
  );

  await _step('An invalid access token is rejected with a real 401', () async {
    try {
      await authService.getSession('not-a-real-token');
      throw StateError('expected a MudbaseException');
    } on MudbaseException catch (error) {
      _expect(error.statusCode == 401, 'expected 401, got ${error.statusCode}');
    }
  });

  await _step('Sign out (best-effort server-side revoke)', () async {
    await authService.logout(clientToken!);
    await authService.logout(freelancerToken!);
  });

  print('');
  print('Passed: $_passed, Failed: $_failed');
  if (_failed > 0) exit(1);
}
