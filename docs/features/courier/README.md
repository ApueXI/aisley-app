---
title: Courier Feature Index
system: AISLEY
type: Feature Index
role: Courier / Rider
platform: Flutter / Dart
status: Auth implemented; operational features deferred
---

# Courier feature index

## Implementation rule

`auth/spec.md` is the only Courier feature specification in this bundle that describes a currently implemented API. The remaining Courier specifications are planning drafts copied for future design work. They are not endpoint contracts and must not be used to invent Flutter requests, response fields, statuses, providers, or offline behavior.

Before implementing any non-auth feature, the backend must first provide:

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

All other routes shown in the draft files are conceptual placeholders. They are not implemented merely because they appear in a specification.

## Canonical constraints for future features

- Use lowercase `snake_case` API/status values from the approved backend contract.
- Keep first-mile and final-mile assignments independent; a first-mile Courier is not automatically the final-mile Courier.
- Keep all records scoped to the authenticated Courier, its approved Logistics organization, and that organization's sole hub.
- Do not use Mapbox or introduce a routing provider without an approved provider contract. Current Courier registration does not require a map pin or coordinates.
- Do not store or expose private evidence, raw storage paths, bearer tokens, or unnecessary Buyer/Seller data.

## Draft files

The following files remain backlog material: Accept Delivery Requests, Account Management, Chat/Messaging, Complete Delivery, Dashboard, Delivery History, Deliver Order, Incident Reporting, Pick Up Order, Profit Dashboard, and Proof of Delivery. Revise each against the real API before implementation.
