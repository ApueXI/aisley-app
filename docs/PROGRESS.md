# Courier Flutter Progress

This is the progress log for the external Courier Flutter application. It is separate from the Laravel repository's `docs/PROGRESS.md`.

## Backend contract snapshot

- **Backend commit:** `d1abeee73d0141e1fd7dda4bea0ee3fead370378` for the first/final-mile operational contracts, with pickup foundation at `d5c160d4a5a21272e487b6f46a82de35e81395cb`, policy consent at `c3b9cad`, and account/profile-photo behavior at `20afd9f`.
- **Current API surface:** Courier Logistics discovery, registration, login, generic password-recovery response, `/me`, current-token logout, account profile/password management, private profile-photo upload/retrieval/removal, public Terms/Privacy reads and history, authenticated policy status/acceptance, first-mile and final-mile task reads/acceptance/rejection, waybill candidate resolution, idempotent first-mile Seller handoff, ordered first-mile route manifests, pending final-mile hub-handoff evidence, accepted-task delivery context, revision-checked final-mile movement, P0 QR/reference proof, completion intent/projection, read-only delivered history, and the read-only Courier dashboard scaffold.
- **Deferred:** Dashboard operational aggregation, camera QR decoding, photo/signature proof media, route/location telemetry, chat, earnings, notification transport, and offline synchronization APIs.

## 2026-09-08

- Prepared the Flutter documentation bundle and aligned its rules, paths, architecture, and current Courier authentication boundary with the backend contract.
- Added an automatic progress-synchronization rule: implementation, test, backend-contract, and material project-documentation changes must update this file in the same task; read-only reviews do not.
- Added feature Git workflow rules requiring a new `feature/...` branch before feature changes and an automatic `feat: ...` commit after verified completion, while preserving unrelated worktree changes.
- Implemented the Flutter Courier auth slice: environment-configured API client, secure Sanctum token storage, login/session restore/logout, explicit approval and network failure states, and protected dashboard-scaffold loading with no fabricated operational data. Verified with `flutter analyze` and `flutter test` (9 tests passed).
- Added `.env.example`-based API configuration loading so local runs can use `API_BASE_URL` without a `--dart-define`; the real `.env` remains ignored and is bundled only for local builds.
- Upgraded `flutter_secure_storage` to `11.0.0` (Linux plugin `3.0.2`) to resolve Clang deprecation errors on Linux desktop; verified with `flutter analyze`, `flutter test`, and `flutter build linux --debug`.
- Updated the Linux runner to show its GTK window immediately so Sway receives a mapped node without waiting for a first Flutter frame.
- Added a visible startup bootstrap and deferred secure-session initialization until after the first Flutter frame, so asynchronous `.env` and keyring work cannot blank the Linux surface.
- Added a Linux Secret Service preflight and bounded secure-storage operations so a missing or locked keyring reaches the explicit storage-failure screen instead of blocking the Flutter surface.
- Added a corrected `AGENTS.md` documentation lookup table using this repository's actual workflow, domain, design, feature, and location-contract paths.

## 2026-09-08

- Synced the Courier authentication and Dashboard contracts from the Laravel repository.
- API contract baseline: `d817a10`
- Specification revision: `910300c`
- Courier authentication includes registration, Logistics approval states, bearer-token login, `/me`, logout, and recovery entry behavior.
- Courier Dashboard remains a mobile scaffold; operational task and notification endpoints are not yet available.
- Re-sync these documents whenever the Laravel API contract, DTOs, or status rules change.
- Replaced the starter root README with Aisley Courier purpose, clone/configuration instructions, Linux desktop usage, and documented browser/Windows setup and limitations without changing runtime behavior.

## 2026-09-08

- Added the Courier registration path beside sign-in, including Logistics organization discovery, exact multipart registration fields, server field-error display, password clearing before retries, and a pending-approval result without creating a session.
- Added cross-platform evidence selection for `government_id` and `vehicle_registration` with JPEG/JPG/PNG/WebP, strict under-10-MiB, and image-signature convenience checks; upload progress, cancellation, retry, and privacy-safe error states are shown while Laravel remains authoritative.
- Added multipart/API model and repository contract tests plus registration navigation coverage. The repository has no bundled PSGC dataset, so this implementation uses the documented complete manual address fallback and does not fabricate cascading region data.
- Verification: `flutter analyze`, `flutter test` (14 tests passed), and `flutter build linux --debug`.

## 2026-09-08

- Integrated the provided `lib/psgc-address-data` Q2 2026 hierarchy into registration as bundled, searchable Region → Province → City/Municipality → Barangay selectors, including NCR/sub-municipality barangay traversal and a manual fallback when data is unavailable or incomplete.
- Expanded the Linux setup guide with `gnome-keyring`, `libsecret` runtime requirements, session startup guidance, and secure-storage troubleshooting for `flutter_secure_storage`.
- Added PSGC asset/data-source parsing and hierarchy coverage; registration still submits only the documented address labels and does not send PSGC codes or coordinates.

## 2026-09-08

- Added the Android runner and release build configuration, including compile SDK 37 and Android Gradle Plugin 9.1.1 required by `flutter_secure_storage` 11.0.0; set the Android app label to `Aisley`.
- Verification: `flutter build apk --release` completed successfully locally.

## 2026-09-09

- Implemented the Flutter Courier account-management slice against backend commit `678618b` / API version `courier-account-management-v1`: private account read, allow-listed profile editing, and current-password password change.
- Added explicit loading, validation, forbidden, signed-out, retryable network, secure-storage, and success handling; account data is cleared on logout, authorization denial, and password-session revocation.
- Kept email, status, sex, birth date, derived age, Logistics affiliation, sole hub, vehicle, photo, and other authority fields read-only. Successful password changes clear secure session state and return to sign-in.
- Added bearer/JSON contract tests, idempotency-key coverage for profile saves, password field privacy assertions, controller failure-state tests, and account accessibility/widget coverage.
- Verification: `flutter analyze` and `flutter test` pass.

## 2026-09-10

- Updated the Flutter Courier account-management implementation to backend commit `20afd9f` / API version `courier-account-management-v1`, adding authenticated profile-photo upload, private bearer-token retrieval, replacement, and idempotent removal.
- Added server-URL validation so only the configured API origin and `/api/v1` private resource paths can be used for profile photos; no public/blob/storage URL or browser-cookie flow is introduced.
- Added under-10-MB JPEG/JPG/PNG/WebP picker checks, signature convenience validation, in-memory preview, upload progress/cancellation, server field-error handling, missing-photo fallback, confirmed refresh, and uncertain-response reconciliation.
- Updated the account feature tests and copied Courier architecture/design/index documentation for the released photo routes. The local `.env` and other secret-bearing files remain untouched.
- Verification: focused account tests and full `flutter test` pass; `flutter analyze` and `flutter build linux --debug` are run before handoff.

## 2026-09-10

- Implemented the Courier policy-viewing and consent client against backend commit `c3b9cad`: public current/history/exact reads for Terms of Service and Privacy Policy, private status, and exact-current-version acceptance with bearer auth.
- Added typed policy parsing, bounded in-memory public caching, explicit loading/consent/accepted/stale/forbidden/rate-limit/timeout/offline/retry states, 401 auth-boundary handling, uncertain-acceptance reconciliation, and account/settings navigation.
- Added safe plain-text current and historical document screens, explicit confirmation checkboxes, localized timestamps, accessibility labels, and no published-version/partial-failure states. Draft/Internal Rules content is not requested or rendered.
- Added repository, model, controller, and widget contract tests for exact paths, headers, body, envelopes, caching, stale versions, 401, unknown acceptance results, and accessible consent controls.

## 2026-09-12

- Implemented the Courier pickup workflow against backend commit `d5c160d4a5a21272e487b6f46a82de35e81395cb` / API version `first-and-final-mile-pickup-v1`.
- Added separate Seller-pickup and hub-pickup task sections, server-authoritative task details, explicit task acceptance, QR-payload/manual Order-reference verification, first-mile idempotent physical pickup confirmation, final-mile pending hub-handoff evidence submission, and schedule-scoped ordered route-manifest viewing.
- Added session-bound error handling for `401`, policy-consent `403`, forbidden/validation/conflict/rate-limit responses, timeout/offline failures, secure-storage failures, stale-task refresh, and preserved idempotency retries. Pickup data and route manifests remain in memory and are cleared on session end.
- Kept Dashboard cards read-only and linked to the dedicated pickup screen. The current Flutter client uses scanner keyboard/paste QR payloads and manual fallback; no camera, map SDK, provider key, or turn-by-turn navigation dependency was added.
- Added repository, controller, and widget contract coverage for exact routes, bearer headers, request bodies, idempotency, response-state semantics, error separation, accessibility labels, and final-mile “awaiting validation” behavior.
- Verification: focused pickup tests pass; full `flutter analyze`, `flutter test`, and `flutter build linux --debug` are run before handoff.

## 2026-09-12

- Fixed the Courier policy-gated dashboard flow against the existing `d5c160d4a5a21272e487b6f46a82de35e81395cb` / `c3b9cad` contract: `403 POLICY_CONSENT_REQUIRED` now preserves the secure session and opens the Flutter consent screen instead of being mislabeled as an invalid Logistics affiliation.
- Added explicit post-consent return to the dashboard, a sign-out action while consent is required, and a generic access-denied state for unrecognized or role-forbidden `403` responses; only `LOGISTICS_ASSOCIATION_INVALID` shows the affiliation-blocked state.
- Added auth-controller and widget regression coverage for session preservation, consent routing, and separation of affiliation from other authorization failures.
- Verification: workspace Dart analysis reports no issues; Flutter analyzer/test execution remains blocked here because the installed SDK tries to write its cache outside this project.

## 2026-09-12

- Clarified the policy consent recovery state when authenticated status loading fails: missing policy routes, backend server/bootstrap failures, contract mismatches, and local secure-storage failures now receive distinct actionable messages without exposing response bodies or credentials.
- Added controller regression coverage for missing policy routes and locked secure storage. The documented policy endpoints and response contract remain unchanged; the API must still provide `/api/v1/policy-consent/status` and current seeded Terms/Privacy versions.
- Verification: direct Dart analysis passes; focused Flutter tests remain blocked by the installed SDK's external build hooks in this environment.

## 2026-09-12

- Aligned the policy repository with the API's successful policy DTO response by accepting either the documented `data` resource envelope or a complete endpoint-specific top-level DTO; incomplete or unrelated successful responses still fail closed.
- Added a direct status-response contract fixture while preserving the bearer-auth path, exact routes, private status handling, and server-authoritative consent decisions.
- Verification: direct Dart analysis passes; focused Flutter tests remain blocked by the installed SDK's external build hooks in this environment.

## 2026-09-12

- Added privacy-safe policy contract diagnostics that identify the rejected status field without rendering the response body, token, or private account data.
- Added controller coverage for contract-field reporting; no policy authority, endpoint, or consent fallback was introduced.

## 2026-09-12

- Normalized the live policy status version projection when Laravel serializes `current_version` or `accepted_version` as a numeric string or a version descriptor containing an integer `version`; invalid, fractional, zero, and unrelated values still fail closed.
- Added model coverage for both deployed representations while retaining the documented integer DTO as the canonical contract.

## 2026-09-12

- Fixed the Dashboard welcome avatar so it renders the confirmed private profile-photo bytes held by the shared account controller instead of always showing initials.
- Dashboard now listens for account/photo state changes, loads the account photo on the first authenticated dashboard visit, and falls back to initials for missing or invalid photo data; no new endpoint or API contract was introduced.
- Added a widget regression test for refreshing the Dashboard avatar after a profile-photo update.
- Verification: direct Dart analysis passes; Flutter widget tests remain blocked by the installed SDK attempting to write its cache/build-hook files outside this project.

## 2026-09-12

- Made Courier registration failures explicit: local validation now displays a top-level explanation, and server field errors are summarized above the form as well as shown beside their fields.
- Added specific guidance for duplicate Courier email, throttling with retry timing, registration conflicts, unavailable organizations, generic validation responses, network failures, and required evidence/field review.
- Added widget coverage proving an empty registration submission explains why it cannot continue; the registration endpoint and multipart contract remain unchanged.
- Verification: direct Dart analysis passes; the focused Flutter widget test is blocked by the installed SDK's read-only external cache/build-hook files.

## 2026-09-12

- Corrected registration diagnostics so non-validation API failures are no longer described as missing Logistics or document fields; the UI now identifies server/API failures with safe HTTP status and stable error-code guidance.
- Preserved nested validation paths such as `address.postal_code` when the API returns nested `errors` objects, allowing the form summary and inline fields to identify the rejected address field.
- Added API error-parser coverage for nested registration validation responses; the registration endpoint and multipart field contract remain unchanged.
- Verification: direct Dart analysis passes; Flutter tests remain blocked by the installed SDK's read-only external cache/build-hook files.

## 2026-09-13

- Completed the first-mile and final-mile Courier UI against backend commit `d1abeee73d0141e1fd7dda4bea0ee3fead370378`: final-mile offer rejection, accepted-task delivery context, revision-checked movement, P0 QR/reference proof, completion intent/projection, and read-only delivered history are now available from the authenticated dashboard.
- The copied Deliver Order spec marks the movement route implemented and requires a task revision but omits an exact request-body example; this client uses the bounded `{status, expected_revision}` payload implied by the shared transition wording, and that field shape must be confirmed against the Laravel route before release.
- Kept first-mile Seller pickup and final-mile hub pickup independent. Hub evidence remains visibly `awaiting_validation` until Logistics records custody; delivery movement begins only from the server-returned `picked_up_from_hub` state.
- Added explicit loading, empty, unavailable, policy-consent, unauthorized, conflict, validation, timeout/offline, rate-limit, secure-storage, retry, pending-validation, and server-confirmed completion states. Uncertain proof/completion mutations retain their original idempotency attempt.
- Kept route/location telemetry, map/navigation, camera QR decoding, photo/signature proof, chat, earnings, notification transport, offline mutation, and dashboard aggregation unavailable; no client-generated status, route, ETA, ownership, or delivery completion is used.
- Added repository/controller contract coverage for movement, proof, completion, history, bearer paths, request bodies, idempotency, pending 202 responses, and 401 delegation; synchronized the architecture, feature index, mobile design guide, and the dashboard/history spec status/checklists (dashboard v2.4, history v1.4).
- Verification: direct Dart analysis passes and `git diff --check` passes. `flutter test`/`flutter analyze` could not run because this environment's Flutter SDK attempts to write cache/build-hook files outside the project; direct `dart test` was stopped after the external build-hook remained stalled.

## 2026-09-13

- Fixed the final-mile completion handoff against backend commit `d1abeee73d0141e1fd7dda4bea0ee3fead370378`: an HTTP 202 proof response now stores its `proof_id` and immediately enables the separate completion-intent action while evidence remains `awaiting_validation`.
- Final-mile proof is gated to `out_for_delivery`; manual input is sent as the public Order reference with `identifier_type: order_id`, QR input preserves the raw payload with `identifier_type: qr`, and completion uses the latest known revision plus a distinct UUID idempotency key.
- HTTP 202 completion responses remain “Awaiting Logistics validation” and never mark the task or Order delivered locally. Completion GET remains the authority for evidence, completion, task, Order, revision, and delivered timestamp projections; conflicts refresh task details and completion state.
- Added repository, controller, and widget coverage for raw/manual identifiers, proof-ID handoff, pending validation, wrong parcel references, stale revisions, retry-key reuse, offline recovery, latest revision selection, and non-delivered completion acknowledgment.
- Verification: direct Dart analysis passes; focused Flutter tests remain blocked by the installed SDK's external build-hook/cache writes in this environment.

## 2026-09-13

- Hardened the final-mile proof-to-completion handoff against stale completion projections: the latest server-returned proof ID now remains the completion evidence source, and an older intent for another proof cannot hide or block the current `Submit completion` action.
- Made the pending completion state explicit in the UI by confirming that the server accepted the completion intent while preserving the required “Awaiting Logistics validation” state; the task remains undelivered until a server completion read reports `delivered`.
- Added controller coverage for stale proof/intent projections and widget coverage that taps the completion confirmation and verifies the completion request receives the proof ID.
- Verification: direct Dart analysis passes; focused Flutter tests remain blocked by the installed SDK's external build-hook/cache writes in this environment.

## 2026-09-13

- Fixed completion projection parsing for the deployed API serialization: Flutter now accepts the documented `data` envelope and a complete direct completion DTO without weakening required task, status, or completion fields.
- A successful HTTP 202 completion acknowledgment with an empty or otherwise unsupported body now falls back to the documented completion GET, whose projection remains authoritative; incomplete GET projections still fail closed.
- Completion contract failures now identify the safe rejected field path so an API-shape mismatch is distinguishable from Logistics proof validation; response bodies, tokens, and private delivery data remain hidden.
- Added repository coverage for direct and empty-body HTTP 202 completion responses and controller coverage for contract-field diagnostics. No Laravel endpoint, request body, status authority, or delivery transition was changed.
- Verification: direct Dart analysis passes; focused Flutter tests remain blocked by the installed SDK's external build-hook/cache writes in this environment.

## 2026-09-13

- Reconciled the imported Complete Delivery specification from the webapp project into the canonical Flutter copy: adopted version 1.4 while preserving the same backend commit, endpoints, response envelope, and server authority.
- Documented that an initial completion GET may return `completion_status: null` when no completion intent exists; Flutter now models that field as nullable and continues to require a server-confirmed `delivered` projection before showing completion.
- Updated contract diagnostics to identify the documented JSON location `data.completion_status`. Added repository coverage for an initial projection with no completion intent; the imported `specs-from-webapp.md` comparison file remains unchanged and uncommitted.

## 2026-09-13

- Reconciled the v1.5 Proof of Delivery and Complete Delivery specifications from the webapp project: pending QR/reference proof now explicitly hands its `proof_id` to Courier completion, pending evidence does not block intent submission, and Logistics validates the matching proof and intent during finalization.
- Kept the API contract on the documented `data` envelope, recorded nullable initial `completion_status` and `evidence_id`, clarified Courier task versus Logistics Shipment revisions, and corrected copied domain-document paths to this repository's `docs/domain/` layout.
- Updated Flutter completion parsing and tests to accept explicit null initial status while rejecting an omitted or malformed `completion_status`; no endpoint, request field, status authority, or Laravel code changed.
- Verification: direct Dart analysis and diff/spec-length checks pass; focused Flutter tests remain blocked by the installed SDK's external build-hook/cache writes in this environment.

## 2026-09-13

- Stabilized the Flutter tests against backend contract `d1abeee73d0141e1fd7dda4bea0ee3fead370378`: nested registration validation assertions now match individual messages, the completion widget test scrolls its action into the test viewport, and registration validation uses bounded pumps while PSGC/organization loading indicators are active.
- No production endpoint, status authority, secure-storage behavior, or Laravel code changed.
- Verification: `flutter analyze` passes and `flutter test` passes with 102 tests; `git diff --check` passes.

## 2026-09-16

- Implemented Courier vehicle management against the vehicle-fleet API contract v2.2 and backend snapshot `d1abeee73d0141e1fd7dda4bea0ee3fead370378`: the Account screen now opens a dedicated Vehicle Management screen for the authenticated Courier's sole vehicle.
- Added authenticated `GET /api/v1/courier/vehicle`, revision-checked `PATCH /api/v1/courier/vehicle`, independent OR/CR multipart replacement, and private current-document reads. Ownership, approval, hub, status, and document URLs remain server-derived; no Laravel source was changed.
- Added separate dirty-state and retry handling for vehicle fields, Official Receipt, and Certificate of Registration, including UUID idempotency keys, stale-revision refresh without discarding local edits, uncertain-response reconciliation, field-addressable errors, secure-storage, consent, authorization, rate-limit, timeout, offline, and unavailable states.
- Added client-side image convenience checks for JPEG/JPG/PNG/WebP files under 10 MiB while keeping Laravel authoritative, and ensured private document previews use authenticated bearer requests without rendering raw paths or URLs.
- Added repository, controller, and widget coverage for exact routes/fields, bearer auth, revision/idempotency behavior, private documents, validation errors, stale conflicts, uncertain retry, independent OR/CR handling, and screen states. Verification: `flutter analyze`, `flutter test`, and `git diff --check` pass.

## 2026-09-19

- Modularized `lib/features/account/presentation/` by responsibility without changing the account flow, public widget/controller inputs, API routes, request payloads, or state transitions.
- Split account profile, password, profile-photo workflow/state, screen composition, profile-photo view/workflow, security, and reusable account widgets into focused Dart part files; all hand-written files remain below the modularity guideline's approximate 400-line threshold.
- Verification: `flutter analyze`, focused account tests, `flutter test`, and `git diff --check` pass. Backend/API contract remains the existing account-management snapshot; no Laravel code changed.

## 2026-09-19

- Grouped all Account screen component part files under `lib/features/account/presentation/components/` and updated only the Dart library paths needed to preserve the existing implementation.
- No account flow, controller behavior, API contract, widget inputs, or state transition changed. Verification: `flutter analyze`, `flutter test`, and `git diff --check` pass.

## 2026-09-19

- Grouped the Account controller facade and workflow/state part files under `lib/features/account/presentation/controllers/` and updated their consumers to the new import path.
- This was a path-only organization change: controller logic, account flow, API contract, and state transitions are unchanged. Verification: `flutter analyze`, `flutter test`, and `git diff --check` pass.

## 2026-09-19

- Modularized `lib/features/auth/presentation/` against the Courier auth contract and backend snapshot `d1abeee73d0141e1fd7dda4bea0ee3fead370378` without changing authentication or registration flow.
- Grouped Auth controller workflows/state under `presentation/controllers/` and split registration data loading, submission/evidence handling, form composition, address, field, section, and result widgets under `presentation/components/`; login, blocked, and registration screens remain the public presentation entry points.
- Updated only imports and Dart part paths for consumers. No API route, request field, secure-storage behavior, state transition, or Laravel code changed. Verification: `flutter analyze`, `flutter test` (112 passed), and `git diff --check` pass.

## 2026-09-19

- Modularized `lib/features/dashboard/presentation/` against the read-only Courier dashboard scaffold contract and backend snapshot `d1abeee73d0141e1fd7dda4bea0ee3fead370378` without changing dashboard flow or API behavior.
- Kept `DashboardScreen` as the public composition/navigation entry point, grouped welcome/section cards and loading/error/unavailable status views under `presentation/components/`, and placed the existing Dashboard-specific `AuthController` extension under `presentation/controllers/` without changing its state or dependency wiring.
- No endpoint, request, response parsing, refresh behavior, navigation action, authorization state, or Laravel code changed. Verification: `flutter analyze`, `flutter test` (112 passed), and `git diff --check` pass.

## 2026-09-19

- Modularized `lib/features/delivery/presentation/` against delivery-order v1.3, proof-of-delivery v1.5, complete-delivery v1.5, and pick-up-order v2.6 using backend snapshot `d1abeee73d0141e1fd7dda4bea0ee3fead370378`.
- Kept `DeliveryScreen` and `DeliveryTaskScreen` public entry points stable, grouped list/detail/context/movement/proof-completion/status widgets under `presentation/components/`, and grouped delivery reads, actions, errors, reconciliation, and pending-attempt state under `presentation/controllers/`.
- No endpoint, request/response mapping, status transition, idempotency, retry, proof/completion behavior, or Laravel code changed. Verification: `flutter analyze`, `flutter test` (112 passed), `git diff --check` pass.

## 2026-09-19

- Modularized `lib/features/history/presentation/` against delivery-history v1.4 and backend snapshot `d1abeee73d0141e1fd7dda4bea0ee3fead370378` without changing the read-only final-mile history flow or API behavior.
- Kept `HistoryScreen` and `HistoryDetailScreen` public entry points stable, grouped list/detail/shared status widgets under `presentation/components/`, and moved the cohesive history read controller under `presentation/controllers/`.
- Preserved Courier-scoped delivered-task reads, bounded cursor behavior, privacy-safe projections, loading/empty/unavailable/retry/consent states, and detail navigation. No endpoint, response parsing, state transition, or Laravel code changed. Verification: `flutter analyze`, `flutter test` (112 passed), and `git diff --check` pass.

## 2026-09-19

- Modularized `lib/features/pickup/presentation/` against pick-up-order v2.6 and backend snapshot `d1abeee73d0141e1fd7dda4bea0ee3fead370378` without changing first-mile or final-mile pickup flow or API behavior.
- Kept `PickupScreen`, `PickupTaskDetailScreen`, and `PickupRouteScreen` public entry points stable, grouped list/task-detail/route/status widgets under `presentation/components/`, and grouped pickup reads, actions, errors, state, and pending attempts under `presentation/controllers/`.
- Preserved separate Seller pickup confirmation and hub-pickup evidence submission, server-authoritative status and validation, idempotency/retry behavior, route-manifest states, privacy, and offline/error handling. No endpoint, request/response mapping, status transition, or Laravel code changed. Verification: `flutter analyze`, `flutter test` (112 passed), and `git diff --check` pass.
