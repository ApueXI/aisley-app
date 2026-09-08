---
title: Courier Flutter Application Architecture
system: AISLEY
type: Client Architecture
platform: Flutter / Dart
role: Courier / Rider
status: Active — authentication and account client; operational delivery client deferred
backend_contract_commit: 678618b
---

# Scope

This document describes the external Flutter application used by Couriers. It is not the architecture of the Laravel monorepo and it does not authorize changes to the backend, the Customer/Seller/Admin/Logistics web applications, or the database.

The Laravel API remains the source of truth for identity, approval, role access, organization and hub ownership, order status, task assignment, and delivery state. The Flutter app renders server responses and submits only fields allowed by the versioned API contract.

## Current implementation boundary

The backend currently exposes Courier authentication and Phase 1 account management:

- `GET /api/v1/courier/auth/logistics-options`
- `POST /api/v1/courier/auth/register`
- `POST /api/v1/courier/auth/login`
- `POST /api/v1/courier/auth/forgot-password` (generic response only)
- `GET /api/v1/courier/auth/me` (authenticated)
- `POST /api/v1/courier/auth/logout` (authenticated)
- `GET /api/v1/courier/account` (authenticated)
- `PATCH /api/v1/courier/account/profile` (authenticated)
- `PUT /api/v1/courier/account/password` (authenticated)

Shipment, Parcel, Waybill, Scan, Delivery Task, assignment, proof-of-delivery, routing, chat, earnings, and offline synchronization endpoints are not currently available. The app may provide an honest scaffold or unavailable state for those capabilities, but must not fabricate jobs or call conceptual routes from draft specifications.

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
│   └── auth/
│       ├── data/         # DTOs, multipart requests, repository
│       ├── domain/       # Auth state and validation rules
│       └── presentation/ # Login, registration, pending, and session screens
│   └── account/
│       ├── data/         # Account DTOs and authenticated repository
│       ├── domain/       # Private account projection
│       └── presentation/ # Account form and password/session controls
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

Pending Couriers cannot use `/me`; the current API does not provide a cross-device pending-status endpoint. The pending screen must therefore be local and informational until a future status or notification contract exists.

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

Read the relevant sections of `docs/requirements.md`, `docs/workspace.md`, `docs/schema.md`, `docs/domain/Courier.md`, `docs/domain/Logistics.md`, the matching Courier feature specification, and the two registration/upload references. The decision worksheet is historical context only; it is not an implementation authority.
