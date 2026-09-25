# Courier Flutter Progress

This is the progress log for the external Courier Flutter application. It is separate from the Laravel repository's `docs/PROGRESS.md`.

## Backend contract snapshot

- **Copied backend documentation baseline:** Laravel checkout `ca1487c` (2026-09-25), including Courier COD delivery reads, support tickets, and Courier chat API `courier-operational-messaging-v2`. Earlier feature-specific API versions and implementation history are preserved in the [2026-09-25 archive](logs/PROGRESS-2026-09-25.md).
- **Flutter status:** Auth/account/vehicle/policy, notifications, first-mile pickup, partial final-mile hub handoff/photo POD/completion intent with COD cash confirmation, delivered history, dashboard scaffold plus separate read-only task previews, and Courier task-chat inbox with Logistics/Seller messaging are implemented. Buyer chat remains read-only; Logistics/Seller chat has not passed live cross-role acceptance.
- **Outstanding adoption/acceptance work:** Courier support-ticket screens, state-idempotent final-mile batch acceptance, failed-attempt submission, linehaul trip reads, authenticated COD/Logistics validation, live chat exchange/reassignment/terminal behavior and Seller counterpart acceptance, and installed APK/browser camera/upload/chat acceptance remain unverified or deferred. The dashboard aggregate remains `courier-dashboard-scaffold-v1` and must not fabricate operational data.

## 2026-09-26

- Synchronized the copied backend contract from `docs-flutter-from-webapp` to Laravel checkout `ca1487c` while preserving Flutter-owned progress, design rules, and the newer Courier-to-Seller messaging status. Added the implemented `courier-support-tickets-v1` contract, support-ticket schema records and route index, and the historical Flutter handoff record.
- Updated final-mile batch acceptance to the now-complete contract: list is bounded to 30 schedules ordered by `scheduled_for` descending; detail and accept return the canonical batch projection; accept sends an empty JSON object without `Idempotency-Key`; retries are state-idempotent; `404 BATCH_NOT_FOUND` and `409 BATCH_STATE_CONFLICT` define reconciliation. Flutter batch acceptance remains unimplemented by this documentation sync.
- Updated copied feature versions/baselines and replaced the obsolete deferred-shipment rule with reuse of deployed Shipment/Parcel/Delivery Task/evidence records. This is documentation only; no Dart code or Laravel source changed.

## 2026-09-25

- Implemented Courier-to-Seller task messaging against `courier-operational-messaging-v2`. An accepted first-mile task now exposes **Message Seller** until Seller handoff, starts or resumes the role-isolated Seller thread with the exact task UUID, and preserves existing idempotent retry, polling, read-marker, session-clearing, and server-authoritative sendability behavior.
- Added response-context validation so a send cannot silently switch task, leg, counterpart, or existing conversation. Seller inbox threads are composable when `send_allowed` is true; Buyer threads remain read-only.
- Verification: targeted chat/pickup tests (23 passed), full `flutter test` (197 passed), `flutter analyze`, the 230-line chat-spec check, and `git diff --check` passed. Authenticated Courier–Seller exchange and the Seller counterpart reply screen remain unverified.

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

## 2026-09-25

- Implemented final-mile COD completion against the documented Laravel `ca1487c` delivery-read clarification. The client refetches the assigned task's `data.order.payment_method`, `payment_status`, `payable_total`, and `currency` before displaying the cash amount, requires an explicit full-collection acknowledgment, and rechecks those values before sending `cod_collected: true` with the photo-linked completion intent. Missing, unsupported, or changed payment details block the intent; `parcel.price` is never used as cash due. No amount or payment status is written by Flutter, and only Logistics validation may establish delivered/paid.
- Added COD parsing, request, controller, retry/error, and widget tests. Verification: full `flutter test` (194 passed), `flutter analyze`, `flutter build web`, `flutter build apk --release`, and `git diff --check` passed. Authenticated live COD/Logistics acceptance and installed-device/browser interaction remain unverified; no Laravel code or copied Courier spec was changed.

## 2026-09-25

- Reconciled Flutter design guidance across `AGENTS.md`, the root/docs/Courier READMEs, architecture, and Courier spec-authoring rules. `docs/design-courier.md` now owns shared frontend conventions based on Jakob's Law and Hick's Law: familiar Material controls, consistent labels/navigation, one prominent next action per active task/form step, grouped secondary choices, and progressive disclosure that preserves essential context, consent, accessibility, and server-required steps.
- Corrected stale chat/dashboard/COD adoption summaries and conflicting pickup-price, identifier, photo-picker/camera, private-preview, and upload-size guidance. Added a frontend review gate and distinguished documented requirements from verified screen compliance. Backend baseline remains `94e3467` with the existing targeted `ca1487c` COD clarification; no API behavior, Flutter runtime code, or historical entries changed.
- Verification: shared-rule references in all seven design/rule entry points, all 16 local Markdown links in those files, progress archive threshold, and `git diff --check` passed. Documentation-only change; Flutter analyzer/tests and live/device checks were not rerun, and existing screens are not certified compliant by this update.
