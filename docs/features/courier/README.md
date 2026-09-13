---
title: Courier Feature Index
system: AISLEY
type: Feature Index
role: Courier / Rider
platform: Flutter / Dart
status: Auth, account management, policy consent, first/final-mile pickup, delivery, and read-only history implemented; route/location/media extensions deferred
---

# Courier feature index

## Implementation rule

`auth/spec.md`, the Phase 1 `account-management/specs.md`, the policy-consent specification, `accept-delivery-requests/specs.md`, `pick-up-order/specs.md`, `delivery-order/specs.md`, `proof-of-delivery/specs.md`, `complete-delivery/specs.md`, and `delivery-history/specs.md` describe the currently implemented API slices. The remaining Courier specifications are planning drafts copied for future design work. They are not endpoint contracts and must not be used to invent Flutter requests, response fields, statuses, providers, or offline behavior.

Before implementing an unavailable capability, confirm the backend provides:

1. an approved feature specification;
2. a versioned `/api/v1/courier/...` endpoint contract with request and response examples;
3. any schema and transition contract that capability actually requires (the shared fulfillment foundation already exists); and
4. integration/contract-test coverage.

Until then, implement only a truthful scaffold or unavailable state for the missing capability. Do not fabricate delivery requests, task counts, routes, proof requirements, earnings, notifications, or history.

## Current Courier API

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
- `GET /api/v1/platform/policies/{type}` (public current Terms/Privacy read)
- `GET /api/v1/platform/policies/{type}/history` (public published history)
- `GET /api/v1/platform/policies/{type}/history/{version}` (public exact history read)
- `GET /api/v1/policy-consent/status` (authenticated Courier status)
- `POST /api/v1/policy-consent/{type}/versions/{version}/accept` (authenticated exact-version acceptance)
- `GET /api/v1/courier/first-mile-tasks` (authenticated private task list)
- `POST /api/v1/courier/first-mile-tasks/{task}/accept` (authenticated first-mile acceptance)
- `POST /api/v1/courier/waybills/resolve` (authenticated read-only QR candidate resolution)
- `POST /api/v1/courier/first-mile-tasks/{task}/pickup` (authenticated idempotent Seller handoff)
- `GET /api/v1/courier/pickup-schedules/{schedule}/route-manifest` (authenticated ordered manifest)
- `GET /api/v1/courier/final-mile-tasks` and `GET /api/v1/courier/final-mile-tasks/{task}` (authenticated final-mile reads)
- `POST /api/v1/courier/final-mile-tasks/{task}/accept` (authenticated final-mile acceptance)
- `POST /api/v1/courier/final-mile-tasks/{task}/reject` (authenticated final-mile rejection with idempotency)
- `POST /api/v1/courier/final-mile-tasks/{task}/pickup` (authenticated pending hub-handoff evidence)
- `GET /api/v1/courier/tasks/{task}/delivery` (authenticated accepted-task context)
- `POST /api/v1/courier/final-mile-tasks/{task}/status` (authenticated movement transition)
- `POST /api/v1/courier/tasks/{task}/proof-of-delivery` (authenticated QR/reference proof)
- `GET /api/v1/courier/tasks/{task}/completion` and `POST /api/v1/courier/tasks/{task}/completion` (authenticated completion projection/intent)
- `GET /api/v1/courier/delivery-history` and `GET /api/v1/courier/delivery-history/{task}` (authenticated delivered history)

The dashboard scaffold (`GET /api/v1/courier/dashboard`), `GET /api/v1/courier/map-style`, and `GET /api/v1/courier/map-tiles/{z}/{x}/{y}.png` also exist; the last two are private map resources, not evidence of implemented Flutter map rendering. Routes shown only in historical backlog drafts are unavailable. They are not implemented merely because they appear in a specification. The client deliberately uses text/area delivery context, revision-checked movement, P0 QR/reference proof, and read-only completion/history projections; camera scanning, route/location telemetry, and proof media remain unavailable.

## Canonical constraints for future features

- Use lowercase `snake_case` API/status values from the approved backend contract.
- Keep first-mile and final-mile assignments independent; a first-mile Courier is not automatically the final-mile Courier.
- Keep all records scoped to the authenticated Courier, its approved Logistics organization, and that organization's sole hub.
- Do not use Mapbox or introduce a routing provider without an approved provider contract. Current Courier registration does not require a map pin or coordinates.
- Do not store or expose private evidence, raw storage paths, bearer tokens, or unnecessary Buyer/Seller data.

## Draft files

The following files remain backlog material: Chat/Messaging, Dashboard operational aggregation, Incident Reporting, Profit Dashboard, and route/location extensions. Acceptance, Deliver Order movement, P0 Proof of Delivery, Complete Delivery intent, and Delivery History are implemented through the dedicated Flutter flows and their owning contracts; photo/signature proof and camera scanning remain deferred.
