---
project: Courier Flutter application
type: Project Rules
status: Active
backend: External Laravel API
---

# Courier Flutter Project Rules

## Scope and boundaries

- This project is the external Flutter/Dart mobile application for the Courier role. Courier UI belongs here; do not build a Courier web dashboard in the Laravel repository.
- The Laravel API in the Aisley repository is the backend source of truth. Do not duplicate authorization, order status transitions, Logistics ownership, or inventory logic in the app.
- This project must not edit Laravel controllers, migrations, models, React apps, Next.js code, or backend environment files. Backend changes belong in the Aisley repository.
- The app serves Couriers only. Customer, Seller, Admin, and Logistics screens, credentials, and workflows do not belong here.

## Read before changing code

- Read the copied `docs/features/courier/auth/spec.md` and `docs/domain/Courier.md` before implementing Courier work.
- For registration or approval work, also read `docs/references/user-registration-requirements.md` and `docs/references/file-upload-requirements.md`.
- For pickup, delivery, scanning, routing, proof, chat, offline, or earnings work, read the matching Courier feature spec and the relevant Courier/shared sections of `docs/requirements.md`, `docs/workspace.md`, and `docs/schema.md`.
- Relevant shared sections include authentication, authorization, Logistics affiliation, order flow, and status rules. Treat the backend repository versions as authoritative.
- The order/logistics decision worksheet is background history, not an implementation authority.
- If a matching spec or API endpoint does not exist, stop at a scaffold or report the contract gap. Do not invent fields, statuses, permissions, or endpoints.
- Record the backend API version or commit used by this app and update the copied contract when the backend changes.
- Automatically update `docs/PROGRESS.md` in the same task after implementation, test, backend-contract, or material project-documentation changes. Add a dated, concise entry describing what actually changed, update the backend/API snapshot when relevant, and include verification performed. Do not add progress noise for read-only reviews or claim work that was not completed.
- For Flutter UI work, read `docs/design-courier.md` before changing screens, layout, styling, accessibility, or interaction behavior.

## Git commit & branch rules

### Feature branching & commits

- When implementing a new feature, first create and switch to a new branch derived from the current active branch before making feature changes.
- Format feature branches as `feature/short-commit-title`, using a concise lowercase kebab-case title.
- After the feature is completed and verified, automatically commit the feature changes with a descriptive Conventional Commit message formatted as `feat: concise summary of changes`.
- Inspect the worktree before branching and committing. Preserve unrelated user changes and do not include them in the feature commit.
- Do not create a feature branch or commit for read-only reviews, planning-only responses, or documentation-only policy changes unless the user explicitly requests it.

## Flutter code and dependency rules

- Follow the Flutter/Dart version pinned by this project and inspect `pubspec.yaml` before adding packages.
- Keep networking, JSON models, secure token storage, repositories, state/controllers, and widgets separated. Use one API client rather than issuing ad-hoc HTTP calls from screens.
- Keep the API base URL environment-specific. Never hard-code production credentials, API tokens, signing keys, or private service URLs.
- Add only dependencies that are necessary and compatible with the project. Prefer existing shared utilities and established Flutter patterns over duplicate abstractions.
- Keep API models tolerant of additive fields but fail safely when required fields or status values are unknown. Do not silently map an unknown server status to a successful state.

## Current Courier API contract

- Use the versioned API prefix `/api/v1` and HTTPS outside local development.
- `GET /api/v1/courier/auth/logistics-options` returns active Logistics organizations with safe `id` and `business_name` fields. Optional `search` is server-filtered and the current response is bounded to 50 results.
- `POST /api/v1/courier/auth/register` is multipart. Current fields are the personal fields, `logistics_organization_id`, `vehicle_type`, `plate_number`, nested `address[...]` values, `government_id`, and `vehicle_registration`.
- `POST /api/v1/courier/auth/login` accepts `email`, `password`, and a client-generated `device_name`. The client must not send `role`, `abilities`, hub IDs, or reviewer fields.
- Successful login returns a plain-text Sanctum token once. Store it only in OS secure storage and send it as `Authorization: Bearer <token>`.
- `GET /api/v1/courier/auth/me` returns the authenticated Courier identity, profile summary, affiliation status, organization name, and hub name. It is available only after the account and affiliation are approved.
- `POST /api/v1/courier/auth/logout` revokes the current token. Clear local authentication state only after handling the server response or a confirmed invalid session.
- `POST /api/v1/courier/auth/forgot-password` currently returns a generic response only. There is no completed reset-token or notification flow; do not create a reset screen against an unimplemented route.
- Logistics approval endpoints are used by the Logistics application, not by the Courier app. A Courier cannot approve itself or another Courier.

## Authentication and security

- The app must never trust client role, account status, affiliation status, organization, hub, assignment, or token ability as authority. Render access from server responses.
- Keep explicit auth states: checking session, signed out, pending approval, approved/authenticated, rejected, suspended/deactivated, and recoverable network failure.
- Registration returns a pending application. Preserve a local pending state for the user, but do not treat `/me` as a pending-status endpoint: pending Couriers are denied by protected middleware. Cross-device approval status requires a future backend status or notification contract.
- Handle `401` as invalid/expired authentication, `403` as status or affiliation denial, `422` as validation or generic login failure, and `429` as throttling. Preserve useful server error codes without exposing private review notes.
- Never log passwords, bearer tokens, document bytes, raw storage paths, full addresses, or private API responses. Redact sensitive values in crash reports and analytics.
- Use TLS certificate validation, secure storage, short-lived in-memory token copies, and platform logout/clear-data behavior. Do not store tokens in ordinary preferences, SQLite, files, or URLs.
- Authentication requires network access. Offline mode must not bypass approval, refresh tokens, submit registrations silently, or perform protected actions against stale permissions.

## Registration, address, and evidence

- Mirror server validation for required names, contact number, sex, birth date, email, password confirmation, vehicle type (`motorcycle`, `car`, or `van`), and plate number. Client validation improves UX; the API remains authoritative.
- Calculate/display age only as a convenience from `birth_date`; never submit age as an authority.
- Let the applicant select an eligible Logistics organization, but never expose a hub/sub-hub selector. The API derives the organization's sole operational hub.
- Encode address fields using the agreed nested names: `address_line_1`, optional `address_line_2`, `barangay`, `city_municipality`, `province`, `region`, and `postal_code` under the multipart `address` object. Country is server-owned as `Philippines`.
- Use a Dart-compatible bundled PSGC dataset for Region → Province → City/Municipality → Barangay selectors and retain a complete manual fallback. Do not import the JavaScript `@aisley/psgc-address-data` package directly into Flutter.
- Current Courier registration does not capture coordinates or require a map/geocoder. Do not add Geoapify, Mapbox, or map pins without an approved backend contract; if exact pinning is later approved, preserve manually reviewed PSGC/address fields as authoritative.
- Prevalidate `government_id` and `vehicle_registration` as JPEG/JPG, PNG, or WebP images strictly under 10 MiB. The server repeats MIME, signature, decode, and ownership checks; never claim a client validation is sufficient.
- Show upload progress, retryable network errors, and cancellation safely. Do not automatically replay a multipart registration after an uncertain response without user confirmation; duplicate-email handling is server-owned.

## Logistics and delivery boundaries

- Logistics approves or rejects the Courier affiliation. Admin may separately suspend, restore, or deactivate the account; Admin approval is not required for the affiliation in the MVP.
- A Courier has one current Logistics affiliation, and that organization has one operational hub in the MVP. The app must not display or create sub-hubs or alternate affiliations.
- First-mile and final-mile assignments are independent. Completing a Seller pickup never automatically grants final-mile work; the same or a different Courier may receive a separately offered task.
- Shipment, Parcel, Waybill, Scan, Delivery Task, assignment, proof-of-delivery, routing, and earnings endpoints are deferred until the shared operational schema and transition contract are approved. Do not build production actions against guessed APIs.
- Do not infer physical delivery milestones from generic `OrderStatus` values. When operational endpoints exist, use the server's explicit task states and append-only event history.

## UI and accessibility

- Build mobile-first screens with semantic labels, screen-reader announcements, sufficient contrast, visible focus/pressed states, large touch targets, and text that remains usable with system font scaling.
- Every network-backed screen needs loading, empty, validation, unauthorized, offline/retry, and success states appropriate to the endpoint. Never fabricate counts, approval decisions, tasks, routes, or delivery history.
- Keep pending/rejected/disabled explanations clear without exposing private reviewer reasons or another user's data. Do not let UI visibility imply API permission.
- Keep sensitive data out of screenshots, clipboard actions, deep links, analytics events, and notification previews unless explicitly approved.

## Testing and delivery

- Add unit tests for validators, multipart field names, JSON parsing, status mapping, auth-state transitions, and secure-storage error handling.
- Add integration/contract tests against the Laravel API for logistics discovery, registration, login, `me`, logout, token denial, role isolation, file limits, and server error codes. Mocks may support deterministic unit tests but must not replace API contract verification.
- Test revoked/expired tokens, pending/rejected/suspended accounts, inactive Logistics organizations, duplicate submissions, network timeouts, app restarts, secure-storage failure, and out-of-order responses.
- Do not use production credentials or real registration evidence in tests. Keep fixtures synthetic and delete temporary files securely.
- Follow the Flutter project's branch, review, formatting, analyzer, and test commands. A backend API change requires a documented contract update before the Flutter client adopts it.
