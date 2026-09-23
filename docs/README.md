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

The Laravel API supports Courier authentication, account/profile photo, vehicle management, shared policy consent, the notification inbox, both task legs, first-mile pickup, task-bound final-mile hub handoff, private photo POD/Logistics-reviewed completion, failed attempts, advisory batch routes, delivered history, and assigned company-truck trip reads. The external Flutter progress confirms the notification UI, but its older QR/reference delivery-proof screen has not adopted the photo-POD contract. The Courier dashboard's operational aggregation remains a scaffold. Use `docs/features/courier/README.md` to distinguish working routes from implemented Flutter screens and draft features.

Flutter QR/Code 128 camera candidate capture is implemented for the Android release APK and the same Flutter app served locally through `web-server` on port `8765`; physical acceptance remains unverified. Those identifiers still serve first-mile pickup, not final-mile delivery POD. Linux remains manual-input only. The root `README.md` owns run commands; the pickup and proof specs own the current, separate identifier and photo contracts. Local Flutter web testing does not create a separate Courier webapp or authorize a production browser release.

File uploads are documented separately in [`flutter-file-uploads.md`](flutter-file-uploads.md). The external progress records platform-safe selected-byte multipart transport for browser uploads and preserved native-path transport for registration/profile/OR/CR, with analyzer, tests, web, and APK builds passing. Browser CORS/private-read and installed-device acceptance remain unverified. This does not prove that the new **delivery photo POD** upload is implemented in Flutter.

The copied backend documents preserve upstream source paths such as `docs/domains/Courier.md`; this Flutter bundle stores the Courier and Logistics domain copies under `docs/domain/`. References to other role specs or Logistics-only specs not included in this bundle point to the backend repository, not missing Flutter implementation work. Linehaul mutations and Sort plans remain Logistics-owned; the explicit Courier `GET /api/v1/courier/linehaul-trips` read is the only newly documented client exception, and it does not authorize trip actions.

## Synchronization

The copied requirements, workspace, schema, Courier/Logistics domains, and affected Courier feature contracts were reconciled against local backend checkout `833ee52` (based on `origin/main` `317223a`) on 2026-09-23. Flutter-owned architecture, design, and progress preserve the actual older client-adoption history. This is documentation synchronization, not proof that Flutter adopted newer routes or that live API behavior was retested. Recheck the live API and record the backend commit/API version when implementing a client change. Update the Flutter project's `docs/PROGRESS.md` after implementation, test, backend-contract, or material project-documentation changes; retain historical entries.
