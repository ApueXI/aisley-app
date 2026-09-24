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
