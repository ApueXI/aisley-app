# Flutter documentation audit — 2026-09-14

## Scope and result

Audited all 34 supplied Markdown files against backend `9a2e1af987fadd91d17979e7defbffdbb0e5ca44`, its routes/controllers/request validators, shared contracts, and the imported Flutter progress. This was documentation reconciliation, not Flutter source review or live completion debugging.

Confirmed active-copy inconsistencies were corrected. Historical feature proposals were preserved and explicitly isolated, not rewritten into approved features. Their old wording and lengths do not satisfy the current 200–230-line implementation-spec rule; revise them before working on those features.

## Important resolved differences

- Auth is not the only available API: account/photo, policies, both task legs, QR proof/completion and history exist.
- First-mile ordered route manifests and private map assets exist; Flutter camera decoding/map rendering is a separate client extension. Final-mile route/location APIs remain unavailable.
- Movement accepts canonical `target_state`/`expected_revision` plus documented aliases. UUID request headers and revision checks still apply.
- Courier proof returns `proof_id`; completion submits it as `evidence_id` while validation is pending. Logistics needs a matching intent, then validates proof and finalizes atomically.
- Completion GET can have null intent/status/evidence fields. POST 202 is never proof of delivered state.
- Policy versions are nullable descriptor objects inside `data`, not universally plain integers. Defensive client parsing is not a changed backend contract.
- Admin may disable consent enforcement. `all_required_accepted: true` with `accepted: false` permits entry without inventing acceptance; no Courier switch UI is authorized.
- Local domain paths are `docs/domain/`. Laravel source/migrations and absent role specs cited by shared documents are upstream references, not files Flutter must create.
- The bundle does not contain root `AGENTS.md`; retain the Flutter project's existing rules rather than assuming a missing file was supplied.

## File-by-file coverage

| Supplied path relative to docs/ | Disposition |
| --- | --- |
| `PROGRESS.md` | Preserved every historical entry; appended this audit without certifying blocked tests. |
| `README.md` | Replaced stale auth-only instructions; clarified local/upstream paths and missing root AGENTS.md. |
| `architecture.md` | Preserved Flutter architecture; separated camera/map client gaps from existing APIs and added consent semantics. |
| `design-courier.md` | Preserved Flutter design; clarified proof-to-intent and disabled-consent UX. |
| `domain/Courier.md` | Compared with backend; kept current role contract and localized domain references. |
| `domain/Logistics.md` | Refreshed implemented hub operations and hub-location wording. |
| `features/courier/README.md` | Updated availability index, dashboard/map proxy omissions and capability prerequisites. |
| `features/courier/accept-delivery-requests/specs.md` | Synced first-mile versus final-mile fields, rejection and pagination boundaries. |
| `features/courier/account-management/specs.md` | Compared with backend account/photo Resource; kept current API and private delivery contract. |
| `features/courier/auth/spec.md` | Corrected nonexistent pending-status check and server-controlled consent gating. |
| `features/courier/chat-messaging/specs.md` | Quarantined historical backlog; no implemented API or authority for its legacy routes. |
| `features/courier/complete-delivery/specs-from-webapp.md` | Marked duplicate comparison snapshot non-canonical; use specs.md. |
| `features/courier/complete-delivery/specs.md` | Synced nullable initial state and revisions; preserved defensive client response recovery. |
| `features/courier/dashboard/specs.md` | Kept aggregation unavailable and client navigation distinct; retained deferred tests. |
| `features/courier/delivery-history/specs.md` | Synced bounded reads; made cursor/date filtering explicitly deferred. |
| `features/courier/delivery-order/specs.md` | Synced exact movement request and supported aliases; route/location examples remain deferred. |
| `features/courier/flutter-handoff.md` | Labeled prior review as historical; current audit supersedes its review status. |
| `features/courier/incident-reporting/specs.md` | Quarantined historical backlog; Mapbox/incident recovery assumptions do not authorize implementation. |
| `features/courier/pick-up-order/specs.md` | Synced both-leg contract and explicit client camera/map limitations. |
| `features/courier/profit-dashboard/specs.md` | Quarantined historical backlog; unapproved payout/rate/legacy-source assumptions remain historical. |
| `features/courier/proof-of-delivery/specs.md` | Synced proof_id handoff and no-wait-for-validation intent sequence. |
| `features/courier/rules.md` | Adapted backend-source/test instructions and local paths for external Flutter; checklist no longer inherited as proof. |
| `features/orders/logistics-pickups/spec.md` | Refreshed scheduling/availability owner reference; not a Flutter Logistics screen. |
| `features/orders/waybill/spec.md` | Compared with backend; preserved shared immutable QR identity. |
| `features/shared/policy-viewing-consent/spec.md` | Refreshed enforcement toggle; documented current descriptor/envelope and server-derived gate. |
| `features/shared/shipment-fulfillment/spec.md` | Refreshed P0 implemented boundaries; remains a guide, not a callable API. |
| `maps-location-api.md` | Refreshed shared provider/hub-pin policy; no new Flutter provider authorization. |
| `order-logistics-flow-decisions.md` | Historical worksheet explicitly isolated from implementation authority. |
| `references/file-upload-requirements.md` | Compared with backend; shared upload policy preserved. |
| `references/seller-shop-catagories.md` | Compared with backend; unchanged optional non-Courier reference. |
| `references/user-registration-requirements.md` | Refreshed upstream requirements without adding Courier coordinate fields. |
| `requirements.md` | Refreshed canonical copy: implemented sole-hub pinning. |
| `schema.md` | Refreshed hub-location and feature-control schema/migration records; Flutter does not implement migrations. |
| `workspace.md` | Refreshed canonical flow and hub-location copy. |

## Verification and remaining work

- Relative Markdown links and fenced JSON examples were checked; active Courier specs remain 200–230 lines.
- Imported progress and historical artifacts were preserved. No new API, migration, provider, Courier web UI, or business decision was introduced.
- [ ] Record the exact Flutter source commit/build for this bundle.
- [ ] Run the latest Flutter analyzer/test suite with writable SDK caches; supplied reports still describe blocked full execution.
- [ ] Run real Flutter → Logistics proof/intent/finalization integration and capture safe HTTP error/correlation details for the reported failure. Documents alone cannot establish its cause.
- [ ] Complete PostgreSQL release verification independently from SQLite or client reports.
- [ ] Before implementing chat, incidents, or profit, revise their explicitly historical drafts and obtain owning backend contracts.

The temporary bundle is ignored by this repository's Git configuration. Review/copy these files directly; a normal tracked Git diff does not show their edits. This audit does not stage or commit them.
