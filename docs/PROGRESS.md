# Courier Flutter Progress

This is the progress log for the external Courier Flutter application. It is separate from the Laravel repository's `docs/PROGRESS.md`.

## Backend contract snapshot

- **Backend commit:** `d5c160d4a5a21272e487b6f46a82de35e81395cb` for `first-and-final-mile-pickup-v1`, with policy consent at `c3b9cad` and account/profile-photo behavior at `20afd9f`.
- **Current API surface:** Courier Logistics discovery, registration, login, generic password-recovery response, `/me`, current-token logout, account profile/password management, private profile-photo upload/retrieval/removal, public Terms/Privacy reads and history, authenticated policy status/acceptance, first-mile and final-mile pickup task reads/acceptance, waybill candidate resolution, idempotent first-mile Seller handoff, ordered first-mile route manifests, pending final-mile hub-handoff evidence, and the read-only Courier dashboard scaffold.
- **Deferred:** Delivery movement, camera QR decoding, proof-of-delivery media, routing/ETA, chat, earnings, notification transport, and offline synchronization APIs.

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
