---
title: Courier Feature Index
system: AISLEY
type: Feature Index
role: Courier / Rider
platform: Flutter / Dart
status: Flutter auth/account/vehicle/policy/inbox and legacy pickup/delivery/history screens recorded; current final-mile photo/batch contract requires client adoption
---

# Courier feature index

## Implementation rule

`auth/spec.md`, `account-management/specs.md`, `../logistics/vehicle-fleet-management/specs.md` (the shared Courier/Logistics vehicle contract), the policy-consent specification, `notification/specs.md`, `accept-delivery-requests/specs.md`, `pick-up-order/specs.md`, `delivery-order/specs.md`, `proof-of-delivery/specs.md`, `complete-delivery/specs.md`, and `delivery-history/specs.md` describe currently implemented API slices. The remaining Courier specifications are planning drafts copied for future design work. They are not endpoint contracts and must not be used to invent Flutter requests, response fields, statuses, providers, or offline behavior.

Before implementing a remaining draft feature, verify that the backend provides:

1. an approved feature specification;
2. a versioned `/api/v1/courier/...` endpoint contract with request and response examples;
3. any required shared Shipment/Delivery Task schema and transition rules; and
4. integration/contract-test coverage.

Until then, implement only a truthful scaffold or unavailable state for that missing capability. Do not fabricate task counts, route/location telemetry, proof media, earnings, or notification data. The Flutter inbox and older task/history screens are recorded as implemented, but the older QR delivery-proof client is incompatible with the current photo-POD backend.

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
- `GET /api/v1/courier/vehicle` (authenticated own-vehicle read)
- `PATCH /api/v1/courier/vehicle` (authenticated revision-checked own-vehicle update)
- `POST /api/v1/courier/vehicle/documents/{kind}` (authenticated independent OR/CR replacement)
- `GET /api/v1/courier/vehicle/documents/{kind}` (authenticated private current-document read)
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
- `GET /api/v1/courier/final-mile-batches` and `GET /api/v1/courier/final-mile-batches/{schedule}` (authenticated dispatch-batch reads)
- `POST /api/v1/courier/final-mile-batches/{schedule}/accept` (authenticated atomic batch acceptance)
- `POST /api/v1/courier/final-mile-tasks/{task}/accept` (authenticated final-mile acceptance)
- `POST /api/v1/courier/final-mile-tasks/{task}/reject` (authenticated final-mile rejection with idempotency)
- `POST /api/v1/courier/final-mile-tasks/{task}/pickup` (authenticated task-bound pending hub-handoff evidence; no identifier fields)
- `GET /api/v1/courier/tasks/{task}/delivery` (authenticated accepted-task context)
- `POST /api/v1/courier/final-mile-tasks/{task}/status` (authenticated movement transition)
- `GET /api/v1/courier/final-mile-batches/{schedule}/route` (authenticated advisory final-mile route; Flutter adoption not verified)
- `POST /api/v1/courier/tasks/{task}/proof-of-delivery` (authenticated private multipart `photo` POD; Flutter adoption not verified)
- `GET /api/v1/courier/delivery-proofs/{proof}/photo` (authenticated private Courier proof read)
- `GET /api/v1/courier/tasks/{task}/completion` and `POST /api/v1/courier/tasks/{task}/completion` (authenticated completion projection/intent)
- `POST /api/v1/courier/final-mile-tasks/{task}/failed-attempts` (authenticated nonterminal delivery-attempt record)
- `GET /api/v1/courier/delivery-history` and `GET /api/v1/courier/delivery-history/{task}` (authenticated delivered history)
- `GET /api/v1/courier/notifications` (authenticated bounded inbox list)
- `GET /api/v1/courier/notifications/unread-count` (authenticated unread count)
- `GET /api/v1/courier/notifications/{notification}` (authenticated notification detail)
- `POST /api/v1/courier/notifications/{notification}/read` (authenticated idempotent mark-read)
- `GET /api/v1/courier/linehaul-trips` (authenticated assigned company-truck trip read; Flutter trip screen not verified)

All other routes shown in draft files are conceptual placeholders. The external Flutter progress records QR/Code 128 candidates, text/area delivery context, movement, old QR/reference proof, history, and a tested notification inbox. The current Laravel delivery endpoint accepts **photo POD, not QR/reference JSON**; the old Flutter proof/completion UI must be migrated before final-mile delivery can work. Laravel also has an advisory final-mile batch route and a Courier-only company-truck trip read, but their Flutter screens are not established by this snapshot. Linux remains manual-input only. Logistics-owned Linehaul mutation and Sort plan routes are not Courier API routes.

Flutter camera work targets the Android release APK and the same Flutter app served at `http://localhost:8765` on a fixed localhost `web-server` port. QR and Code 128 tracking-ID scanning remain relevant to first-mile pickup; the legacy delivery-proof scanner must not be used as current photo POD. It does not add a Courier webapp or new backend endpoint; physical camera acceptance remains a release verification task.

## Canonical constraints for future features

- Use lowercase `snake_case` API/status values from the approved backend contract.
- Keep first-mile and final-mile assignments independent; a first-mile Courier is not automatically the final-mile Courier.
- Keep all records scoped to the authenticated Courier, its approved Logistics organization, and that organization's sole hub.
- Do not use Mapbox or introduce a routing provider without an approved provider contract. Current Courier registration does not require a map pin or coordinates.
- Do not store or expose private evidence, raw storage paths, bearer tokens, or unnecessary Buyer/Seller data.

## Draft files

The following files remain backlog material: Chat/Messaging, Dashboard operational aggregation, Incident Reporting, and Profit Dashboard. The Flutter notification inbox is implemented against the Laravel list/count/detail/read API. Older Deliver Order, proof, completion, and history client slices exist, but task-bound hub handoff, photo POD, failed-attempt/rejection handling, and batch-route presentation require current-contract verification or implementation. Background push, signature proof, and notification-driven mutations remain deferred.
