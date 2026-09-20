---
title: Courier Flutter Application Architecture
system: AISLEY
type: Client Architecture
platform: Flutter / Dart
role: Courier / Rider
status: Active — authentication, account, vehicle, policy, notification, pickup, delivery, and history client; route/location/media extensions deferred
backend_contract_commit: feature/courier-notifications
---

# Scope

This document describes the external Flutter application used by Couriers. Android APK is its mobile delivery target; a local Flutter `web-server` browser run of the same codebase is the camera and file-upload testing target. It is not the architecture of the Laravel monorepo and it does not authorize changes to the backend, the Customer/Seller/Admin/Logistics web applications, or the database.

The Laravel API remains the source of truth for identity, approval, role access, organization and hub ownership, order status, task assignment, and delivery state. The Flutter app renders server responses and submits only fields allowed by the versioned API contract.

## Current implementation boundary

The backend currently exposes Courier authentication, account and vehicle management, policy consent, and the approved first-mile/final-mile task workflow:

- `GET /api/v1/courier/auth/logistics-options`
- `POST /api/v1/courier/auth/register`
- `POST /api/v1/courier/auth/login`
- `POST /api/v1/courier/auth/forgot-password` (generic response only)
- `GET /api/v1/courier/auth/me` (authenticated)
- `POST /api/v1/courier/auth/logout` (authenticated)
- `GET /api/v1/courier/account` (authenticated)
- `PATCH /api/v1/courier/account/profile` (authenticated)
- `PUT /api/v1/courier/account/password` (authenticated)
- `POST /api/v1/courier/account/profile-photo` (authenticated multipart upload)
- `GET /api/v1/courier/account/profile-photo` (authenticated private stream)
- `DELETE /api/v1/courier/account/profile-photo` (authenticated idempotent removal)
- `GET /api/v1/courier/vehicle` (authenticated own-vehicle read)
- `PATCH /api/v1/courier/vehicle` (authenticated revision-checked field update)
- `POST /api/v1/courier/vehicle/documents/{kind}` (authenticated independent OR/CR replacement)
- `GET /api/v1/courier/vehicle/documents/{kind}` (authenticated private current-document read)
- `GET /api/v1/platform/policies/{type}` and policy history reads (public)
- `GET /api/v1/policy-consent/status` and `POST /api/v1/policy-consent/{type}/versions/{version}/accept` (authenticated)
- `GET /api/v1/courier/first-mile-tasks` (authenticated, private paginated task list)
- `POST /api/v1/courier/first-mile-tasks/{task}/accept` (authenticated task acceptance)
- `POST /api/v1/courier/waybills/resolve` (authenticated read-only QR candidate resolution)
- `POST /api/v1/courier/first-mile-tasks/{task}/pickup` (authenticated idempotent Seller handoff)
- `GET /api/v1/courier/pickup-schedules/{schedule}/route-manifest` (authenticated ordered manifest)
- `GET /api/v1/courier/final-mile-tasks` and `GET /api/v1/courier/final-mile-tasks/{task}` (authenticated)
- `POST /api/v1/courier/final-mile-tasks/{task}/accept` (authenticated task acceptance)
- `POST /api/v1/courier/final-mile-tasks/{task}/reject` (authenticated final-mile offer rejection)
- `POST /api/v1/courier/final-mile-tasks/{task}/pickup` (authenticated pending hub-handoff evidence)
- `GET /api/v1/courier/tasks/{task}/delivery` (authenticated accepted-task delivery context)
- `POST /api/v1/courier/final-mile-tasks/{task}/status` (authenticated revision-checked movement)
- `POST /api/v1/courier/tasks/{task}/proof-of-delivery` (authenticated P0 QR/reference proof submission)
- `GET /api/v1/courier/tasks/{task}/completion` and `POST /api/v1/courier/tasks/{task}/completion` (authenticated completion projection/intent)
- `GET /api/v1/courier/delivery-history` and `GET /api/v1/courier/delivery-history/{task}` (authenticated read-only delivered history)
- `GET /api/v1/courier/notifications` (authenticated bounded inbox list)
- `GET /api/v1/courier/notifications/unread-count` (authenticated unread count)
- `GET /api/v1/courier/notifications/{notification}` (authenticated notification detail)
- `POST /api/v1/courier/notifications/{notification}/read` (authenticated idempotent mark-read)

The dashboard aggregation remains a read-only scaffold. Tracking IDs may resolve through the documented QR/reference flows, and the shared scanner supplies QR/Code 128 candidates on Android and the local web-server target. Background push/WebSockets, route/location telemetry, photo/signature proof media, chat, earnings, and offline synchronization endpoints are not currently available. The app renders explicit unavailable states for those capabilities and must not fabricate jobs or call conceptual routes from draft specifications. Logistics Linehaul and Sort plan operations do not create Courier endpoints.

## Camera targets

- The shared Flutter camera-scanning workflow is available in the Android release APK and the same Flutter app at `http://localhost:8765` via `flutter run -d web-server --web-hostname localhost --web-port 8765`. This is a local browser test target, not a separate Courier web UI or a production web deployment.
- `mobile_scanner` decodes QR payloads and Code 128 waybill tracking IDs on the supported targets, then passes an untrusted candidate to the existing first-mile, hub-pickup, or delivery-proof controller. The owning feature selects `qr` or `tracking_id`; the server remains authoritative. Manual Order-reference entry and explicit mutation confirmation remain available.
- Scanner lifecycle and permission feedback stay in Flutter presentation code; repositories continue to use the documented bearer-token endpoints. Linux and other unsupported platforms hide the camera action and retain manual input.
- The direct `dart:io` socket handling in `lib/core/networking/api_client.dart` is isolated behind a conditional adapter for web compilation. Browser authentication continues to use the existing `flutter_secure_storage` WebCrypto/LocalStorage implementation without a plaintext fallback; that browser token is same-origin and intended only for the reviewed localhost test boundary. API CORS must allow the exact fixed origin, and non-local browser camera tests need HTTPS.
- Web and Android release builds are verified. Physical QR/Code 128 capture, permission denial, and browser camera acceptance still require an installed release APK and a browser with an available camera.

## File-upload targets

- The existing Android/native registration evidence, account photo, and vehicle OR/CR uploads use `file_selector` and the shared multipart API client. Browser file selection is available, but the current `MultipartFile.fromPath` transport requires `dart:io`; a compiling web build is not evidence that uploads work in `web-server`.
- Follow [`flutter-file-uploads.md`](flutter-file-uploads.md) for the web-safe selected-file/byte transport and Android regression boundary. Keep exact Laravel multipart parts and server-side validation; do not create web-only endpoints, a second Flutter codebase, or a React upload page. Photo/signature delivery proof media remains deferred.
- The fixed `http://localhost:8765` origin needs backend CORS for upload `POST`, private-image `GET`, and applicable `OPTIONS` preflight with bearer/idempotency headers. The same secure session and authenticated private-read rules apply on web; browser upload acceptance and installed-APK regression remain verification tasks.

## Client structure

Use feature-oriented Dart code with clear boundaries:

```text
lib/
├── app/                 # Material theme, routing, dependency composition
├── core/
│   ├── config/           # API base URL and environment configuration
│   ├── networking/      # One authenticated HTTP client and error mapping
│   ├── security/        # Secure token storage and redaction helpers
│   └── widgets/         # Small approved shared UI primitives
├── features/
│   ├── auth/
│       ├── data/         # DTOs, multipart requests, repository
│       ├── domain/       # Auth state and validation rules
│       └── presentation/ # Login, registration, pending, and session screens
│   ├── account/
│       ├── data/         # Account DTOs, photo transport, authenticated repository
│       ├── domain/       # Private account projection and in-memory photo data
│       └── presentation/ # Account form, photo controls, and password/session controls
│   ├── vehicle/
│       ├── data/         # Own-vehicle and private OR/CR transport
│       ├── domain/       # Revision, document state, and validation models
│       └── presentation/ # Vehicle fields and independent document controls
│   ├── pickup/
│   │   ├── data/         # Pickup task, manifest, and handoff repositories
│   │   ├── domain/       # Server status, task, manifest, and handoff models
│   │   └── presentation/ # Pickup list, detail, verification, and route-order screens
│   ├── delivery/
│   │   ├── data/         # Final-mile delivery repository
│   │   ├── domain/       # Delivery context, movement, proof, and completion models
│   │   └── presentation/ # Delivery work, movement, proof, and completion screens
│   └── history/
│       ├── data/         # Read-only delivered-history repository
│       ├── domain/       # Immutable history projections
│       └── presentation/ # History list and detail screens
└── main.dart
test/
├── unit/
├── widget/
└── contract/
```

The exact state-management, routing, networking, and secure-storage packages are project decisions. Inspect `pubspec.yaml` and reuse existing choices before adding a dependency.

## API integration

- Use the `/api/v1` prefix and an environment-specific base URL. Use HTTPS outside local development.
- Centralize requests in one client/repository layer; screens must not issue ad-hoc HTTP calls.
- Send `Authorization: Bearer <token>` only for authenticated requests. The token is issued once at login and is never returned by `/me`.
- Treat server validation, role, account status, affiliation status, organization, hub, task assignment, and status transitions as authoritative.
- Map `401`, `403`, `422`, and `429` responses into explicit UI states without exposing private review notes or server internals.
- Do not silently retry registration, token issuance, or future operational writes after an uncertain response.

## Authentication state

Model at least these states explicitly:

```text
checking_session
signed_out
submitting_registration
pending_approval
authenticated
rejected
suspended_or_deactivated
invalid_affiliation
recoverable_network_failure
```

Pending Couriers cannot use `/me`; the current API does not provide a cross-device pending-status endpoint. The pending screen must therefore be local and informational until a dedicated pending-status endpoint exists.

## Security and privacy

- Store bearer tokens only in platform secure storage (Keychain/Keystore or the approved Flutter secure-storage implementation).
- Never log or persist passwords, tokens, evidence bytes, raw storage paths, full addresses, or private API payloads.
- Do not trust client-supplied role, status, reviewer, hub, affiliation, owner, or token-ability fields.
- Keep private registration evidence private; the app receives only safe resource fields and never a blob path.
- Do not bypass approval or protected actions while offline.

## Registration data

- Use the bundled Dart-compatible PSGC data for Region → Province → City/Municipality → Barangay selectors and retain manual address fallback.
- Current Courier registration does not collect coordinates or require a map pin. Do not add Geoapify, Mapbox, Leaflet, or another map dependency without an approved backend contract.
- Validate the required evidence as JPEG/JPG, PNG, or WebP strictly under 10 MiB before upload. The server remains authoritative for MIME, signature, decode, ownership, and storage validation.
- The selected Logistics organization owns exactly one operational hub; the app must not expose a hub/sub-hub selector.

## UI and accessibility

Follow [`design-courier.md`](design-courier.md). Use mobile-first layouts, system text scaling, semantic labels, visible focus/pressed states, sufficient contrast, keyboard-safe forms, and touch targets of at least 44 logical pixels. Every network-backed screen needs appropriate loading, empty, validation, forbidden, offline/retry, and success states.

## Testing and contract synchronization

- Unit-test validation, multipart field names, PSGC cascading, JSON parsing, status mapping, auth transitions, and secure-storage failures.
- Add API contract tests for Logistics discovery, registration, login, `/me`, logout, role isolation, approval denial, upload limits, and error codes.
- Mocks may support deterministic unit/widget tests but cannot replace API verification.
- Automatically record the backend commit or API version used by the app in `docs/PROGRESS.md` whenever implementation or contract work changes. Recheck the contract before adopting any backend change.

## Canonical documents

Read the relevant sections of `docs/requirements.md`, `docs/workspace.md`, `docs/schema.md`, `docs/domain/Courier.md`, `docs/domain/Logistics.md`, the matching Courier feature specification (or the shared Logistics vehicle specification for Courier vehicle work), and the two registration/upload references. The decision worksheet is historical context only; it is not an implementation authority.
