# Courier Flutter documentation bundle

This directory is a documentation snapshot for the external Courier Flutter application. Copy the contents into that project's `docs/` directory and retain its own Flutter `AGENTS.md`, architecture, design, rules, and progress history. Do not copy Laravel, React, Next.js, or database source code into the Flutter project.

## Authority order

1. The live, versioned Laravel API contract.
2. The copied `docs/requirements.md`, `docs/workspace.md`, and `docs/schema.md` sections relevant to Courier.
3. `docs/domain/Courier.md` and `docs/domain/Logistics.md`.
4. The matching Courier feature specification.
5. `docs/order-logistics-flow-decisions.md` only as historical rationale; it is not canonical.

If these sources disagree, stop and resolve the backend contract before implementing behavior.

For Flutter visual and interaction decisions, [`design-courier.md`](design-courier.md) is the shared authority. Its Jakob's Law and Hick's Law rules apply across features: familiar components and terminology, predictable navigation, focused next actions, and clearly grouped secondary choices. [`architecture.md`](architecture.md) defines code boundaries; [`../AGENTS.md`](../AGENTS.md) and [`features/courier/rules.md`](features/courier/rules.md) require frontend reviews against the design guide. Feature specs retain authority over permitted actions and API contracts. Design guidance never overrides required consent, evidence, payment confirmation, or server authorization.

## Current implementation

The Laravel API supports Courier authentication, account/profile photo, vehicle management, shared policy consent, the notification inbox, both task legs, first-mile pickup, task-bound final-mile hub handoff, private photo POD/Logistics-reviewed completion, failed attempts, advisory batch routes, delivered history, assigned company-truck trip reads, and task-scoped text chat with Logistics, Seller, and Buyer. Flutter implements photo selection/upload and completion intent with COD cash confirmation, the notification inbox, separate read-only dashboard task previews, and task-chat inbox/Logistics sending. Seller/Buyer chat remains read-only. Authenticated COD/Logistics validation, live chat exchange, and installed-device/browser acceptance remain unverified. Normal batch acceptance, batch-route rendering, failed-attempt submission, and linehaul trip screens remain unadopted. The dashboard aggregate remains a scaffold. Use `docs/PROGRESS.md` for dated client evidence and `docs/features/courier/README.md` for API availability and draft boundaries.

Flutter QR/Code 128 camera candidate capture is implemented for the Android release APK and the same Flutter app served locally through `web-server` on port `8765`; physical acceptance remains unverified. Those identifiers still serve first-mile pickup, not final-mile delivery POD. Linux remains manual-input only. The root `README.md` owns run commands; the pickup and proof specs own the current, separate identifier and photo contracts. Local Flutter web testing does not create a separate Courier webapp or authorize a production browser release.

File uploads are documented separately in [`flutter-file-uploads.md`](flutter-file-uploads.md). Flutter implements platform-safe selected-byte multipart transport for browser uploads and native-path transport for registration/profile/OR/CR; delivery photo POD also has a selected-file upload implementation. Analyzer, tests, web, and APK builds are recorded as passing in the progress log. Browser CORS/private-read and installed-device acceptance remain unverified. Dedicated rear-camera POD capture is separate from the implemented barcode scanner and file picker.

The copied backend documents preserve upstream source paths such as `docs/domains/Courier.md`; this Flutter bundle stores the Courier and Logistics domain copies under `docs/domain/`. References to other role specs or Logistics-only specs not included in this bundle point to the backend repository, not missing Flutter implementation work. The Logistics chat spec and Courier chat API handoff are included for the mobile client; they do not grant access to Logistics routes. Linehaul mutations and Sort plans remain Logistics-owned; the explicit Courier `GET /api/v1/courier/linehaul-trips` read is a client exception and does not authorize trip actions.

## Synchronization

The copied backend contracts were reconciled against local Laravel checkout `94e3467` on 2026-09-24. The Courier COD response field paths were additionally checked against Laravel checkout `ca1487c` on 2026-09-25; this is a targeted clarification, not a full bundle resynchronization. Feature-level `backend_contract_commit` values may identify an earlier implementation baseline. Flutter-owned architecture, design, rules, and progress preserve the client-adoption history; this copy does not implement or verify new Flutter features. Current COD completion requires a server-validated `cod_collected: true` declaration: the authorized delivery read provides `data.order.payment_method`, `data.order.payable_total`, and `data.order.currency` for the confirmation screen; `data.parcel.price` is merchandise subtotal. All three Courier chat counterpart APIs exist, but client support must be tested separately. Recheck the live API and record the adopted backend commit/API version when changing Flutter code. Update the Flutter project's `docs/PROGRESS.md` after implementation, test, backend-contract, or material project-documentation changes; retain historical entries.
