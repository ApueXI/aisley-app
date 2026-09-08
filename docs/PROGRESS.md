# Courier Flutter Progress

This is the progress log for the external Courier Flutter application. It is separate from the Laravel repository's `docs/PROGRESS.md`.

## Backend contract snapshot

- **Backend commit:** `d817a10` (verify again before release or after backend changes)
- **Current API surface:** Courier Logistics discovery, registration, login, generic password-recovery response, `/me`, and current-token logout.
- **Deferred:** Shipment, Parcel, Waybill, Scan, Delivery Task, assignment, proof-of-delivery, routing, chat, earnings, and offline synchronization APIs.

## 2026-09-08

- Prepared the Flutter documentation bundle and aligned its rules, paths, architecture, and current Courier authentication boundary with the backend contract.
- Added an automatic progress-synchronization rule: implementation, test, backend-contract, and material project-documentation changes must update this file in the same task; read-only reviews do not.
- Added feature Git workflow rules requiring a new `feature/...` branch before feature changes and an automatic `feat: ...` commit after verified completion, while preserving unrelated worktree changes.
- Added a corrected `AGENTS.md` documentation lookup table using this repository's actual workflow, domain, design, feature, and location-contract paths.

## 2026-09-08

- Synced the Courier authentication and Dashboard contracts from the Laravel repository.
- API contract baseline: `d817a10`
- Specification revision: `910300c`
- Courier authentication includes registration, Logistics approval states, bearer-token login, `/me`, logout, and recovery entry behavior.
- Courier Dashboard remains a mobile scaffold; operational task and notification endpoints are not yet available.
- Re-sync these documents whenever the Laravel API contract, DTOs, or status rules change.
