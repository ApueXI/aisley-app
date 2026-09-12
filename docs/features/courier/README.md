---
title: Courier Feature Index
system: AISLEY
type: Feature Index
role: Courier / Rider
platform: Flutter / Dart
status: Auth, account management, policy consent, and pickup workflow implemented; other operational features deferred
---

# Courier feature index

## Implementation rule

`auth/spec.md`, the Phase 1 `account-management/specs.md`, the policy-consent specification, and `pick-up-order/specs.md` describe currently implemented APIs. The remaining Courier specifications are planning drafts copied for future design work. They are not endpoint contracts and must not be used to invent Flutter requests, response fields, statuses, providers, or offline behavior.

Before implementing any other non-auth feature, the backend must first provide:

1. an approved feature specification;
2. a versioned `/api/v1/courier/...` endpoint contract with request and response examples;
3. the shared Shipment/Delivery Task schema and transition rules; and
4. integration/contract-test coverage.

Until then, implement only a truthful scaffold or unavailable state. Do not fabricate delivery requests, task counts, routes, proof requirements, earnings, notifications, or history.

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
- `POST /api/v1/courier/final-mile-tasks/{task}/pickup` (authenticated pending hub-handoff evidence)

All other routes shown in the draft files are conceptual placeholders. They are not implemented merely because they appear in a specification. The pickup client deliberately uses the accessible ordered manifest list and scanner keyboard/paste/manual identifier input; camera scanning, delivery routing, and proof media remain separate work.

## Canonical constraints for future features

- Use lowercase `snake_case` API/status values from the approved backend contract.
- Keep first-mile and final-mile assignments independent; a first-mile Courier is not automatically the final-mile Courier.
- Keep all records scoped to the authenticated Courier, its approved Logistics organization, and that organization's sole hub.
- Do not use Mapbox or introduce a routing provider without an approved provider contract. Current Courier registration does not require a map pin or coordinates.
- Do not store or expose private evidence, raw storage paths, bearer tokens, or unnecessary Buyer/Seller data.

## Draft files

The following files remain backlog material: Accept Delivery Requests as a standalone screen, Chat/Messaging, Complete Delivery, Dashboard operational sections, Delivery History, Deliver Order, Incident Reporting, Profit Dashboard, and Proof of Delivery. Pickup includes the documented acceptance prerequisite; revise each remaining feature against its real API before implementation.
