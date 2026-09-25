# Courier Flutter Progress

This is the progress log for the external Courier Flutter application. It is separate from the Laravel repository's `docs/PROGRESS.md`.

## Backend contract snapshot

- **Copied backend documentation baseline:** Laravel checkout `94e3467` (2026-09-24); Courier chat API `courier-operational-messaging-v2`. Earlier feature-specific API versions and implementation history are preserved in the [2026-09-25 archive](logs/PROGRESS-2026-09-25.md).
- **Flutter status:** Auth/account/vehicle/policy, notifications, first-mile pickup, partial final-mile hub handoff/photo POD/completion intent, delivered history, dashboard scaffold plus separate read-only task previews, and Courier task-chat inbox/Logistics messaging are implemented. Seller/Buyer chat remains read-only in this rollout; Logistics chat has not passed live cross-role acceptance.
- **Outstanding contract/acceptance work:** Final-mile batch acceptance DTO/retry contract, failed-attempt submission, linehaul trip reads, authenticated Logistics validation, live chat exchange/reassignment/terminal behavior, and installed APK/browser camera/upload/chat acceptance remain unverified or deferred. The dashboard aggregate remains `courier-dashboard-scaffold-v1` and must not fabricate operational data.

## 2026-09-25

- Archived the complete 343-line progress history unchanged in [PROGRESS-2026-09-25.md](logs/PROGRESS-2026-09-25.md) after adding today's chat implementation entry, as required by `AGENTS.md`.
- Implemented Courier task chat against `courier-operational-messaging-v2`: protected inbox/history/read markers, task-linked Logistics messages, bounded polling, exact-key retry, session cleanup, and read-only Seller/Buyer threads. The unauthenticated live inbox returned `401`; authenticated cross-role behavior is still unverified.
- Verification: `flutter analyze`, full `flutter test` (167 passed), `flutter build web`, `flutter build apk --release`, `git diff --check`, and 230-line chat-spec check passed. No Laravel code was changed.

## 2026-09-25

- Revised the Flutter Courier Dashboard spec to v2.7 as a scaffold-to-partial-implementation handoff against copied Laravel checkout `94e3467` and existing `courier-dashboard-scaffold-v1`. The Laravel aggregate remains unavailable; the next client phase may show separate, read-only first-/final-mile task previews sourced from their implemented list APIs, alongside the existing notification badge and task-chat link.
- Defined independent source loading/error/freshness, bounded previews, server-status classification, read-only navigation/refetch, privacy, and tests. This is documentation only: no Flutter preview, Laravel endpoint, live API verification, or device behavior was implemented or tested by this entry.

## 2026-09-25

- Implemented the Dashboard v2.7 partial-preview handoff against copied Laravel checkout `94e3467`, `courier-dashboard-scaffold-v1`, `first-and-final-mile-pickup-v1-tracking-id`, and `courier-delivery-v1-final-mile-task`. The aggregate remains explicitly unavailable. Separate first-mile page and final-mile list reads now supply up to five read-only task previews each, with source/leg labels, server-status classification, optional safe distance/ETA, and navigation to the owning work list rather than any dashboard mutation. Preview state retains only minimal safe references/areas, not full task/address models.
- Added independent loading, empty, failure, offline, timeout, rate-limit, stale-data, refresh, app-resume, authorization/session cleanup, response-race, revision, and retry handling. Explicitly unknown task legs now remain unclassified instead of being silently defaulted to the requested list leg; absent legacy leg fields still use the list default. Returning from an owning work screen refetches its preview; no new API route, package, task action, persisted cache, or Laravel change was added. Updated the dashboard spec's Flutter implementation markers and design guide without changing the backend contract version.
- Verification: full `flutter test` (184 passed), `flutter analyze`, `flutter build web`, `flutter build apk --release`, 226-line dashboard spec, and `git diff --check` passed. The local Laravel API was not reachable at `127.0.0.1:8000`, so authenticated live response and device/browser runtime acceptance remain unverified.
