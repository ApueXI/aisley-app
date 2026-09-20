# Courier Flutter documentation bundle

This directory is a documentation snapshot for the external Courier Flutter application. Copy the contents into that project's `docs/` directory and retain its own Flutter `AGENTS.md`, architecture, design, rules, and progress history. Do not copy Laravel, React, Next.js, or database source code into the Flutter project.

## Authority order

1. The live, versioned Laravel API contract.
2. The copied `docs/requirements.md`, `docs/workspace.md`, and `docs/schema.md` sections relevant to Courier.
3. `docs/domain/Courier.md` and `docs/domain/Logistics.md`.
4. The matching Courier feature specification.
5. `docs/order-logistics-flow-decisions.md` only as historical rationale; it is not canonical.

If these sources disagree, stop and resolve the backend contract before implementing behavior.

## Current implementation

The Laravel API supports Courier authentication, account/profile photo, vehicle management, shared policy consent, both task legs, first-mile pickup, final-mile evidence/movement/completion, and read-only delivery history. The Courier dashboard's operational aggregation remains a scaffold. Use `docs/features/courier/README.md` to distinguish working routes from draft features; a spec's planned route is not a working API call.

Flutter camera scanning is implemented in the shared client for the Android release APK and the same Flutter app served locally through `web-server` on port `8765`. The backend QR/tracking-ID endpoints already exist; Linux remains manual-input only. The root `README.md` owns run commands; the pickup and proof specs own scanner behavior. Local Flutter web testing does not create a separate Courier webapp or authorize a production browser release.

The copied backend documents preserve upstream source paths such as `docs/domains/Courier.md`; this Flutter bundle stores the Courier and Logistics domain copies under `docs/domain/`. References to other role specs or Logistics-only specs not included in this bundle point to the backend repository, not missing Flutter implementation work. The latest Linehaul and Sort plan details remain Logistics-owned; do not infer Courier linehaul or transfer endpoints from them.

## Synchronization

The copied contracts were checked against backend commit `4045cc57d6466d7e84f249a6ceaf45cb49a88151` on 2026-09-20. This is a documentation baseline, not proof that the Flutter client has adopted every newer field or that backend runtime behavior was retested here. Recheck the live API and record the backend commit/API version when implementing a client change. Update the Flutter project's `docs/PROGRESS.md` after implementation, test, backend-contract, or material project-documentation changes; retain historical entries.
