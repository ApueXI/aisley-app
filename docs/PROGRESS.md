# Courier Flutter Progress

This is the progress log for the external Courier Flutter application. It is separate from the Laravel repository's `docs/PROGRESS.md`.

## Backend contract snapshot

- **Copied backend documentation baseline:** Laravel checkout `94e3467` (2026-09-24); Courier chat API `courier-operational-messaging-v2`. Earlier feature-specific API versions and implementation history are preserved in the [2026-09-25 archive](logs/PROGRESS-2026-09-25.md).
- **Flutter status:** Auth/account/vehicle/policy, notifications, first-mile pickup, partial final-mile hub handoff/photo POD/completion intent, delivered history, dashboard scaffold, and Courier task-chat inbox/Logistics messaging are implemented. Seller/Buyer chat remains read-only in this rollout; Logistics chat has not passed live cross-role acceptance.
- **Outstanding contract/acceptance work:** Final-mile batch acceptance DTO/retry contract, failed-attempt submission, linehaul trip reads, authenticated Logistics validation, live chat exchange/reassignment/terminal behavior, and installed APK/browser camera/upload/chat acceptance remain unverified or deferred. The dashboard aggregate remains `courier-dashboard-scaffold-v1` and must not fabricate operational data.

## 2026-09-25

- Archived the complete 343-line progress history unchanged in [PROGRESS-2026-09-25.md](logs/PROGRESS-2026-09-25.md) after adding today's chat implementation entry, as required by `AGENTS.md`.
- Implemented Courier task chat against `courier-operational-messaging-v2`: protected inbox/history/read markers, task-linked Logistics messages, bounded polling, exact-key retry, session cleanup, and read-only Seller/Buyer threads. The unauthenticated live inbox returned `401`; authenticated cross-role behavior is still unverified.
- Verification: `flutter analyze`, full `flutter test` (167 passed), `flutter build web`, `flutter build apk --release`, `git diff --check`, and 230-line chat-spec check passed. No Laravel code was changed.

## 2026-09-25

- Revised the Flutter Courier Dashboard spec to v2.7 as a scaffold-to-partial-implementation handoff against copied Laravel checkout `94e3467` and existing `courier-dashboard-scaffold-v1`. The Laravel aggregate remains unavailable; the next client phase may show separate, read-only first-/final-mile task previews sourced from their implemented list APIs, alongside the existing notification badge and task-chat link.
- Defined independent source loading/error/freshness, bounded previews, server-status classification, read-only navigation/refetch, privacy, and tests. This is documentation only: no Flutter preview, Laravel endpoint, live API verification, or device behavior was implemented or tested by this entry.
