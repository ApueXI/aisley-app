---
role: Courier / Rider
feature: courier-pick-up-order
title: Pick Up Order
system: AISLEY
type: Feature Specification
version: 1.1
status: Waybill resolve implemented; physical pickup scan/evidence transition deferred
implementation_status: Courier QR resolve is access-only; pickup submission and Logistics recording are planned/unavailable
canonical: true
scope: External Flutter mobile client and Laravel Courier API
backend_contract_commit: 5596fab
backend_contract_version: courier-pickup-v1-deferred
source_coverage: docs/requirements.md, docs/workspace.md, docs/schema.md, docs/domains/Courier.md, docs/domains/Logistics.md, docs/references/file-upload-requirements.md, docs/features/shared/shipment-fulfillment/spec.md
---

# Pick Up Order

## WHAT

- **Purpose:** Let an accepted Courier task verify the correct parcel at its origin and submit physical handoff evidence.
- **Actor boundary:** Courier performs the physical scan in the external Flutter app. Logistics validates and records the authoritative event; the shared transition service commits custody state.
- **Current implementation:** `POST /api/v1/courier/waybills/resolve` resolves an assigned first-mile waybill and writes an access event. No physical pickup, evidence, or custody-transition endpoint is implemented.
- **Flow:** accepted task → travel to Seller or hub → scan shared waybill QR/reference → submit event/evidence → Logistics validates → `picked_up_from_seller` or `picked_up_from_hub` is committed → Deliver Order or hub processing.
- **Task boundary:** One Delivery Task represents one Order/Parcel for one leg. First-mile Seller pickup and final-mile hub pickup are independent tasks.
- **Non-goals:** accepting/assigning tasks, waybill generation, hub sorting, route authority, delivery completion, proof-of-delivery policy, returns, refunds, partial fulfillment, or Courier web UI.

```text
accepted task
→ origin verification
→ Courier scans QR/reference
→ Courier submits evidence
→ Logistics validates/records
→ shared transition commits physical pickup
```

## MUST

### Authentication and task scope

- Require `auth:sanctum` and `courier.active`; Flutter sends `Authorization: Bearer <token>`.
- Derive Courier, task, Order/Parcel, Logistics organization, and sole hub from server records. Never trust client `courier_id`, `organization_id`, `hub_id`, status, or task ownership.
- The task must be offered/accepted to the authenticated Courier and belong to its active approved Logistics affiliation.
- First-mile pickup is valid only at the Seller origin after `seller_pickup_accepted`; final-mile pickup is valid only at the sole hub after `delivery_accepted` and hub dispatch.
- An old Courier loses authority if Logistics reassigns, withdraws, or changes the task before commit; return a safe conflict without revealing another tenant.

### Scan and evidence authority

- The Courier scans the shared waybill's opaque QR/reference at the physical handoff and submits the event/evidence to the owning Logistics organization.
- The submission is ingress only. It does not directly write `picked_up_from_seller`, `picked_up_from_hub`, `in_transit`, or a generic Order `picked_up` value.
- Logistics validates the waybill/Order/Parcel link, task leg, current state, Courier authorization, sole-hub scope, expected revision, and idempotency key before recording an authoritative event.
- The recorded event preserves the performing Courier, recording Logistics account, server event time, location/context required by the transition, and safe QR/reference/evidence metadata.
- A scan or `waybill_access_events` resolve record alone never advances custody. Only the shared transition service may commit the approved detailed state.
- Evidence states are separate from custody: `submitted`, `awaiting_validation`, `validated`, `rejected`, or `unavailable`.
- If an image is attached, inherit `docs/references/file-upload-requirements.md`: JPEG/JPG, PNG, or WebP, strictly below 10 MiB, server MIME/signature/decode validation, generated object key, and private authorized delivery.
- Do not store or return raw storage paths, bearer tokens, private evidence bytes, or client-supplied actor/status claims.

### Physical state and handoff

- First-mile completion records `picked_up_from_seller` only after Logistics validates the submitted handoff and the transition service accepts the current state.
- Final-mile completion records `picked_up_from_hub` only after the independent final-mile task is accepted and the hub handoff is validated.
- High-level Order `assigned` and `picked_up` remain broad projections; this feature consumes explicit task state and does not invent new `orders.status` values.
- Successful first-mile pickup hands the parcel to Logistics for `received_at_hub` processing. It does not automatically assign the same Courier the final-mile leg.
- A failed validation leaves custody unchanged. Manual Logistics recovery uses the same transition service and must not duplicate a valid Courier event.
- Pickup confirmation is not delivery completion; Complete Delivery owns `delivered` after required proof.

### Manifest and privacy

- Show only the authoritative task/waybill manifest required to compare the physical parcel: task leg, Order/waybill reference, pickup origin, item/package summary, destination area, and permitted instructions.
- Exact address/contact fields are revealed only when the accepted task contract authorizes them and only for operational need.
- Customer, Seller, and Logistics PII, payment data, private registration/POD evidence, and unrestricted location history are excluded.
- The QR payload is untrusted input. Do not execute URI/script content or treat a copied QR as possession or permission.

### Reliability and offline boundary

- Scan submission and any physical pickup mutation require online server coordination in the MVP; offline capture is reference-only until an approved offline policy exists.
- Use a client idempotency key and expected task revision. Matching retries return the committed projection; changed payloads or stale revisions return `409`.
- Concurrent Courier and Logistics actions cannot create two custody transitions. Append-only history is durable in the same transaction as the state change.
- Notification or communication failure after Logistics records a transition cannot roll it back; retries are separate from custody.
- Camera denial, scanner failure, timeout, unknown QR, wrong parcel, and unavailable evidence show recoverable states and never claim pickup.

## HOW

### Endpoint contract

- **Implemented** `POST /api/v1/courier/waybills/resolve` — `auth:sanctum,courier.active`; JSON `{ "payload": "opaque-qr-or-reference" }`, maximum 128 characters. It returns an authorized waybill/task match and records a `resolve` access event only.
- Resolve returns `404` for an unknown, inactive, foreign, or unassigned waybill without disclosing why; `422` covers malformed payload and `429` covers throttling. It never returns custody state as changed.
- **Planned/unavailable** `GET /api/v1/courier/tasks/{task}/pickup` — returns the accepted task's safe manifest, origin, leg, current detailed state, evidence state, and allowed next action after the shared schema exists.
- **Planned/unavailable** `POST /api/v1/courier/tasks/{task}/scan-events` — JSON includes `leg`, scanned `reference`, optional permitted evidence metadata, `expected_revision`, and `idempotency_key`; it must not accept `courier_id`, target status, owner IDs, or raw paths.
- The planned response contains an event ID, current safe task projection, evidence status, server timestamp, and whether Logistics validation is pending. It does not promise physical pickup until the authoritative transition commits.
- Planned errors distinguish `401`, `403`, `404`, `409`, `422`, `429`, timeout, offline, storage, and notification failure. Retrying an identical key is safe; uncertain responses require a fresh task read.
- All task/evidence responses are private and `no-store`; Flutter must not share-cache them or retain them after logout/authorization loss.

### Submission details

- `leg` is server-checked against the task and may be `first_mile` or `final_mile`; Flutter cannot switch a task's leg.
- `reference` is the opaque waybill QR/reference value after local scanner normalization. The client never sends a database ID as a substitute unless the API explicitly maps it.
- `expected_revision` prevents a stale pickup screen from overwriting a newer Logistics decision. A missing or stale revision is a validation/conflict error, not permission to skip checks.
- `idempotency_key` is unique per attempted physical handoff and must be retained until the server returns a final projection.
- Optional evidence metadata is bounded and non-sensitive: capture time, scanner type, and a safe client correlation value. Raw QR payloads, GPS history, and device secrets are not stored in logs.
- If media is enabled by the approved contract, upload it through the configured private storage abstraction and wait for server validation before showing `validated`.
- Logistics may return `awaiting_validation` while the submission is queued; Flutter must not display that state as physical possession.

```json
{
  "leg": "first_mile",
  "reference": "WB-opaque-value",
  "expected_revision": 3,
  "idempotency_key": "handoff-attempt-uuid",
  "evidence": {"scanner": "camera_qr", "captured_at": "client-time"}
}
```

### Evidence and custody display

- `submitted` means the Courier sent an event; `awaiting_validation` means Logistics has not committed it; `validated` means evidence passed validation; `rejected` means it did not; `unavailable` means the section cannot be read.
- Custody state remains the server's detailed task state and is displayed beside evidence state, never replaced by it.
- A `validated` evidence status alone is not permission to show `picked_up_from_seller` or `picked_up_from_hub`; the transition service must return the committed custody projection.
- If the Courier submits a duplicate scan after a committed handoff, return the original event/projection and do not append a second physical transition.
- If Logistics rejects the event, show the reason and retry action without changing the Order or reservation.
- If the task is re-offered or marked informationally `stale` before submission, stop the action and require a fresh authorized task response.

### Flutter interaction contract

- The screen starts with the accepted task manifest and a clearly labelled origin: Seller for first mile or sole Logistics hub for final mile.
- The camera prompt occurs only when the Courier chooses **Scan waybill**; denied permission leaves the task usable for safe read-only details and explains the fallback.
- Show `matched`, `wrong parcel`, `unknown reference`, `uploading`, `awaiting Logistics validation`, `validated`, and `rejected` as text with accessible announcements.
- Disable duplicate submission while a request is pending, but preserve the idempotency key across a retry or uncertain timeout.
- A local scan animation, timestamp, or optimistic button state never advances custody or unlocks delivery.
- After a committed first-mile pickup, route to hub-transfer context; after a committed final-mile pickup, route to Deliver Order.

### Failure and recovery matrix

- `401`: clear the session and do not retry automatically; `403`: show blocked affiliation/task ownership; `404`: show unavailable task/reference without cross-tenant detail.
- `409`: refresh the task and show the latest custody/evidence state; do not replay an old revision.
- `422`: show field-addressable scan/evidence errors; `429`: honor retry-after; timeout/offline: keep the attempt uncertain until a safe GET reconciles it.
- Storage or processing failure leaves evidence unvalidated and custody unchanged. Cleanup/reconciliation must remove orphaned private objects.
- Notification failure is independent of state and never causes a second scan or rollback.
- Camera/scanner failure is recoverable and must not be reported as a wrong parcel unless the server validated a mismatch.

### Handoff, history, and retention

- Logistics Update Status is the owning recorder for the validated physical event; this feature owns capture/submission only.
- Preserve task, Order/Parcel, waybill, leg, performing Courier, recording Logistics account, revision, evidence state, and server timestamp in append-only history.
- The shared waybill remains immutable; pickup scans and later routing/assignment events append history rather than rewriting its snapshot.
- Keep evidence private by default and expose only authorized status or short-lived delivery capability; never return a raw disk/blob path.
- Retention, deletion, and exceptional recovery require the approved operational policy; this feature does not invent returns/refunds/partial fulfillment behavior.
- The Flutter project must record backend commit `5596fab` and contract `courier-pickup-v1-deferred` beside its API fixtures.

```json
{
  "data": {
    "task_id": "task-uuid",
    "leg": "first_mile",
    "reference": "WB-123",
    "evidence_status": "awaiting_validation",
    "custody_state": "seller_pickup_accepted",
    "event_id": "event-uuid",
    "recorded_at": "server-time"
  }
}
```

### Backend implementation boundary

- The current waybill resolve controller is an access/read operation. Do not retrofit custody mutation into it.
- Additive migrations must provide Shipment, Parcel, Delivery Task, scan/evidence, actor, revision, and append-only custody records before physical endpoints are enabled.
- Use one shared transition service for state ordering, tenant/hub checks, evidence validation, row locks or revisions, idempotency, and history.
- Logistics Update Status owns validation/authoritative recording; Courier Pick Up Order owns mobile capture and submission. Neither client creates a competing state machine.
- Use string-backed enum-like database columns with PHP enum casts and retain the one-Logistics-organization/one-hub rule.

### Flutter states and permissions

- Screen states: checking session, task loading, camera permission, scan ready, matched, mismatch, unknown, evidence uploading, awaiting Logistics validation, validated, rejected, unavailable, conflict, offline, and retry.
- Store tokens only in OS secure storage. Map `401` to signed out, `403` to blocked affiliation, `404` to unavailable task, `409` to refresh, `422` to field error, and `429` to retry-after.
- Show textual task leg, evidence state, and custody state; never infer a successful pickup from a local scan animation or generic Order status.
- Use semantic labels, large touch targets, accessible progress/error announcements, and a text fallback when camera/scanner hardware is unavailable.
- After a committed pickup response, refresh Dashboard and hand off to Deliver Order only for final-mile `picked_up_from_hub`; first-mile success returns to hub-transfer context.

### Tests, observability, and rollout

- Test role/affiliation/sole-hub/task IDOR, wrong QR, duplicate scan, stale revision, reassignment race, evidence validation, actor preservation, private delivery, and no mutation on resolve/access.
- Test first-/final-mile leg separation, valid state sequence, Logistics manual recovery, notification failure, storage partial failure, and reservation boundary without returns/refunds/partial fulfillment.
- Flutter tests cover camera permission, scanner input safety, upload progress/retry, secure token failure, offline/timeout/conflict states, and accessible status text.
- Log task/leg/event IDs, performing Courier, recording Logistics account, organization/hub, result, revision, and timestamp; never log QR payloads, raw paths, or private media.
- Keep physical endpoints unavailable until additive migrations, transition ownership, and Flutter contract fixtures are deployed together. Record `courier-pickup-v1-deferred` in the Flutter progress log.

### Open decisions

- Confirm whether the MVP requires a photo in addition to the QR/reference minimum; no image is mandatory by this spec alone.
- Confirm evidence retention, optional manual reference entry, and the offline capture/replay policy.
- Confirm transition-specific notification recipients; notification delivery must remain after-commit.

### Acceptance criteria

- [x] Assigned Courier can resolve an authorized waybill through the implemented access-only endpoint.
- [ ] Courier scan/reference submissions are routed to Logistics, validated, and recorded with both performing and recording actors preserved.
- [ ] A valid first-mile or final-mile handoff commits the correct detailed pickup state through the shared transition service only.
- [ ] Resolve/access, invalid evidence, duplicate retries, and stale requests never advance custody or generic Order status.
- [ ] Evidence status is distinct from custody state and private evidence is never exposed through raw storage paths.
- [ ] First-mile pickup does not grant final-mile assignment; the same or another eligible Courier must receive and accept a separate task.

**References:** `docs/features/courier/rules.md`, `docs/features/shared/shipment-fulfillment/spec.md`, `docs/features/orders/logistics-pickups/spec.md`, `docs/features/orders/waybill/spec.md`, `docs/features/logistics/update-status/specs.md`, `docs/features/courier/dashboard/specs.md`, and `docs/features/courier/delivery-order/specs.md`.
