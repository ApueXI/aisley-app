---
title: Courier Feature Index
system: AISLEY
type: Feature Index
role: Courier / Rider
platform: Flutter / Dart
status: Flutter dashboard previews, inbox, photo-POD/COD intent, and Logistics chat implemented; batch adoption and live acceptance remain open
---

# Courier feature index

## Implementation rule

`auth/spec.md`, `account-management/specs.md`, `../logistics/vehicle-fleet-management/specs.md` (the shared Courier/Logistics vehicle contract), the policy-consent specification, `notification/specs.md`, `accept-delivery-requests/specs.md`, `pick-up-order/specs.md`, `delivery-order/specs.md`, `proof-of-delivery/specs.md`, `complete-delivery/specs.md`, `delivery-history/specs.md`, and `chat-messaging/specs.md` describe implemented API slices; client adoption and live acceptance vary. Flutter has a task-chat inbox and Logistics sending; Seller/Buyer threads remain read-only. Incident Reporting and Profit Dashboard remain planning drafts and cannot authorize invented requests, fields, statuses, providers, or offline behavior.

Every Flutter feature follows [`../../design-courier.md`](../../design-courier.md), including its Jakob's Law/Hick's Law interaction rules and frontend review criteria. Reuse familiar controls and labels, emphasize the current next action, and group optional choices while preserving essential context. Feature-specific workflow and API requirements remain binding; consult [`../../PROGRESS.md`](../../PROGRESS.md) for current Flutter implementation evidence.

Before implementing a remaining draft feature, verify that the backend provides:

1. an approved feature specification;
2. a versioned `/api/v1/courier/...` endpoint contract with request and response examples;
3. any required shared Shipment/Delivery Task schema and transition rules; and
4. integration/contract-test coverage.

Until then, implement only a truthful scaffold or unavailable state for that missing capability. Do not fabricate task counts, route/location telemetry, proof media, earnings, or notification data. Flutter implements photo selection/upload and completion intent with COD confirmation; authenticated COD/Logistics validation and installed-device/browser uploads remain unverified. Normal dispatch-batch acceptance remains unavailable in Flutter pending adoption of its complete DTO/retry contract.

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
- `POST /api/v1/courier/tasks/{task}/proof-of-delivery` (authenticated private multipart `photo` POD; Flutter selected-file upload implemented, live acceptance unverified)
- `GET /api/v1/courier/delivery-proofs/{proof}/photo` (authenticated private Courier proof read)
- `GET /api/v1/courier/tasks/{task}/completion` and `POST /api/v1/courier/tasks/{task}/completion` (authenticated completion projection/intent)
- `POST /api/v1/courier/final-mile-tasks/{task}/failed-attempts` (authenticated nonterminal delivery-attempt record)
- `GET /api/v1/courier/delivery-history` and `GET /api/v1/courier/delivery-history/{task}` (authenticated delivered history)
- `GET /api/v1/courier/notifications` (authenticated bounded inbox list)
- `GET /api/v1/courier/notifications/unread-count` (authenticated unread count)
- `GET /api/v1/courier/notifications/{notification}` (authenticated notification detail)
- `POST /api/v1/courier/notifications/{notification}/read` (authenticated idempotent mark-read)
- `GET /api/v1/courier/operational-conversations` and `POST /api/v1/courier/operational-conversations` (authenticated task-scoped inbox and first message)
- `GET /api/v1/courier/operational-conversations/{conversation}` and `GET /api/v1/courier/operational-conversations/{conversation}/messages` (private detail/history)
- `POST /api/v1/courier/operational-conversations/{conversation}/messages` and `POST /api/v1/courier/operational-conversations/{conversation}/read` (idempotent send and monotonic read marker)
- `GET /api/v1/courier/linehaul-trips` (authenticated assigned company-truck trip read; Flutter trip screen not verified)

All other routes shown in draft files are conceptual placeholders. Flutter implements QR/Code 128 candidates, delivery context/movement, photo upload and COD-aware completion intent, history, notification inbox, dashboard task previews, and task-chat inbox/Logistics sending. Current delivery proof accepts **photo POD, not QR/reference JSON**; COD completion additionally requires explicit `cod_collected: true`. Seller/Buyer chat remains read-only pending client/counterpart adoption and verification. Normal batch acceptance, batch routes, failed-attempt submission, and company-truck trip reads still need client adoption. Linux remains manual-input only for barcodes. Logistics-owned Linehaul mutation and Sort plan routes are not Courier API routes.

Flutter camera work targets the Android release APK and the same Flutter app served at `http://localhost:8765` on a fixed localhost `web-server` port. QR and Code 128 tracking-ID scanning remain relevant to first-mile pickup; the legacy delivery-proof scanner must not be used as current photo POD. It does not add a Courier webapp or new backend endpoint; physical camera acceptance remains a release verification task.

## Canonical constraints for future features

- Use lowercase `snake_case` API/status values from the approved backend contract.
- Keep first-mile and final-mile assignments independent; a first-mile Courier is not automatically the final-mile Courier.
- Keep all records scoped to the authenticated Courier, its approved Logistics organization, and that organization's sole hub.
- Do not use Mapbox or introduce a routing provider without an approved provider contract. Current Courier registration does not require a map pin or coordinates.
- Display private evidence only through its authorized feature preview; never log, export, or store it in ordinary app storage. Do not expose raw storage paths, bearer tokens, or unnecessary Buyer/Seller data.

## Draft files

The remaining draft features are Incident Reporting and Profit Dashboard. Dashboard operational aggregation remains unavailable; separate Flutter task previews and the notification badge are implemented. Courier Chat/Messaging has a Flutter Logistics client and read-only Seller/Buyer threads; use `chat-messaging/api-handoff.md` for exact calls. Task-bound hub handoff, photo upload, and COD-aware completion intent still need authenticated end-to-end Logistics validation and installed-device/browser acceptance. Normal batch acceptance and route presentation are unadopted; background push, signature proof, and notification-driven mutations remain deferred.
