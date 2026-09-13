# Courier Flutter documentation bundle

This bundle contains the external Flutter client's documentation. Copy this `docs/` tree into the Flutter project without replacing Flutter source or its root rules. No `AGENTS.md` is included in this bundle; retain the Flutter project's existing one.

## Current implementation

- Backend supports Courier auth, account/photo, shared policies, both task legs, first-mile manifests, final-mile QR proof/completion, and delivered history.
- Flutter progress reports those client slices implemented, using manual/keyboard/pasted QR input and ordered manifest text.
- Camera decoding and graphical maps/navigation remain client extensions; they are not missing scan APIs.
- Courier dashboard aggregation, notification endpoints, final-mile route/location telemetry, photo/signature proof, chat, earnings, incidents, and offline mutations remain unavailable.
- Logistics has its own implemented inbox and hub review UI; these are not Courier routes.

## Authority and paths

- Backend requirements, workspace, schema, role domains and owning feature contracts govern API behavior; copied docs are snapshots, not permission to change the backend.
- `docs/domain/` is the local role-reference folder. `src/api/`, Logistics/Admin/Seller/Customer specs not included here, and migrations named in shared copies are upstream backend references, not missing Flutter implementation files.
- Read only Courier-relevant and shared sections. This bundle's architecture and design guide apply to Flutter; web-library requirements elsewhere apply to the upstream web apps.
- Historical decision worksheets, the prior handoff report, `specs-from-webapp.md`, and legacy chat/incident/profit drafts do not authorize routes, statuses, providers, or business rules.
- If runtime behavior contradicts a contract, report the response/code and owning contract; do not guess fields or bypass authorization.

## Synchronization and verification

Audited against backend `9a2e1af987fadd91d17979e7defbffdbb0e5ca44` on 2026-09-14. Older implementation commits in progress remain historical provenance. See `AUDIT.md` for coverage and remaining verification.

Retain client implementation notes and append actual changes/test outcomes to `docs/PROGRESS.md`. Copying specs does not prove live integration, and the latest supplied Flutter log still reports SDK-blocked test execution.
