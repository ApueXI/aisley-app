---
role: Logistics
feature: Vehicle Fleet Management
system: AISLEY
type: Feature Specification
version: 2.0
status: Revised MVP contract; registration/review foundation implemented; fleet editing deferred
canonical: true
scope: Logistics-scoped registry of each Courier's sole vehicle
source_coverage: requirements.md, workspace.md, schema.md, Logistics.md, Courier.md
---

# Courier Vehicle Registry

## WHAT

- Maintain vehicle information for Couriers affiliated with the authenticated Logistics organization.
- Keep this Logistics feature path; Courier Auth owns vehicle submission during registration.
- MVP: exactly one registered vehicle per Courier, not one active vehicle plus spare or historical vehicles.
- Each vehicle belongs to one Courier; multiple vehicles, sharing, and reassignment between Couriers are out of scope.
- Couriers provide vehicle information and OR/CR; associated Logistics reviews the application.
- Logistics sees many vehicles only because its organization has many Couriers.
- One Logistics account operates the organization's sole hub; no staff or sub-hub credentials are introduced.
- Registration and Courier application review exist; dedicated fleet management endpoints/UI are not established by them.

### Deferred scope

- Maintenance scheduling, reminders, repairs, and maintenance workflows.
- Vehicle history screens, replacement history, and vehicle-to-Courier assignment history.
- Capacity values, capacity units, volumetric matching, and capacity-based dispatch gates.
- Vehicle replacement, transfer, unassignment, extra vehicles, and independent fleet creation.
- Government verification APIs, insurance, inspection automation, and document-expiry workflows.
- Deferring vehicle history does not delete existing registration decisions, evidence-access logs, or shipment/custody history.

## MUST

### Required information

- Require vehicle type and plate number for the Courier's single vehicle.
- Preserve current type values: `motorcycle`, `car`, and `van`.
- Preserve the current plate input maximum of 64 characters and database-wide plate uniqueness.
- Do not invent jurisdiction-specific plate patterns or new required make/model fields.
- Existing nullable make/model columns do not imply supported registration inputs.
- Require OR/CR evidence for that same vehicle; unrelated evidence does not satisfy review.
- OR/CR means Official Receipt and Certificate of Registration, not a profile photograph.
- ID/driver-license evidence remains separately required by the registration reference.
- Do not require capacity, maintenance dates, or vehicle-history entries to register or approve a Courier.

### Ownership and approval

- Derive vehicle ownership from the Courier profile and Logistics scope from its affiliation and sole hub.
- Never trust a submitted organization, hub, Courier owner, approval flag, or storage path as authority.
- Only the associated Logistics organization reviews its Courier's application and private evidence.
- Registration does not approve the application or issue a bearer token.
- Fleet actions must not approve Couriers, assign Orders, change custody, or make a Courier online.
- Keep active account, approved affiliation, and task authorization independent of this registry.
- Require exactly one vehicle when hardening approval; do not silently select the first duplicate row.
- The existing active-vehicle existence check does not establish exactly-one enforcement.
- Courier self-service vehicle/evidence replacement remains unavailable until its update/review contract is defined.

### Private OR/CR

- Use `docs/references/file-upload-requirements.md` as the mandatory upload/storage/access policy.
- Define only vehicle ownership and lifecycle here; do not duplicate or override shared validation.
- The current registration API uses one multipart image part named `vehicle_registration`.
- It is separate from `government_id`; neither accepts Base64 JSON or arbitrary storage paths.
- The existing API does not accept separate OR and CR fields or a document array.
- Review must establish that both required documents are represented and readable.
- Separate OR/CR image fields or multiple-image submission require an explicit additive API contract first.
- Presence of one uploaded image alone does not verify both documents.
- Retain private registration evidence in the existing Document/storage abstraction.
- Authorize every preview; never expose OR/CR in public Courier cards or dispatch/route DTOs.
- Missing or inaccessible evidence shows a review-blocked state, not successful verification.
- Preserve committed evidence; do not introduce deletion/replacement through a generic fleet form.

### Cardinality and compatibility

- Registration creates one initial Vehicle, but the database currently permits multiple rows per Courier.
- Enforce the target using a unique `vehicles.courier_profile_id` constraint in a new migration.
- Uniqueness enforces at most one; transactional registration and completeness checks enforce required existence.
- Audit missing/duplicate vehicles before rollout; do not delete rows or select a winner automatically.
- Resolve anomalies through an explicitly reviewed data-correction plan before applying uniqueness.
- Preserve IDs, private documents, plates, foreign keys, and operational references.
- Never modify an executed migration or use fresh migrations/reseeding to reconcile existing data.
- Existing `capacity` columns and `maintenance` enum values remain compatible storage, not MVP requirements.
- This documentation revision does not remove their values or change PHP enums.

### Dispatch boundary

- Deploy Rider owns assignments and consumes only supported vehicle identity information.
- No capacity unit is approved; do not infer capacity from vehicle type or treat null as unlimited.
- Missing capacity or maintenance data must not introduce a new MVP dispatch block.
- Schedule parcel limits and Courier overlap rules are separate operational contracts, not vehicle capacity.
- One vehicle does not mean one lifetime Order or one parcel per schedule.
- Preserve one Order per task and schedules grouping multiple Orders.

### Acceptance criteria

- [ ] Registration/approval require exactly one Courier-owned vehicle with type, plate, and OR/CR.
- [ ] Concurrent writes cannot create a second vehicle for a Courier or duplicate a plate.
- [ ] Existing missing/duplicate vehicle rows are safely reconciled before uniqueness rollout.
- [ ] Review distinguishes valid OR/CR from mere file presence and blocks incomplete evidence.
- [ ] Foreign-role and cross-organization requests cannot reveal or modify vehicle evidence.
- [ ] Flutter uses supported multipart fields and does not claim unavailable vehicle editing exists.
- [ ] No maintenance, vehicle history, capacity input/unit, or capacity matching is required in the MVP.
- [ ] Existing approval decisions, shipment history, schedules, and task transitions remain intact.

## HOW

### Reuse current owners

- Courier Auth owns implemented `POST /api/v1/courier/auth/register`.
- Preserve its public multipart request, field validation, throttling, pending response, and no-token boundary.
- Logistics Courier Approval owns the implemented list/detail, private document, and approve/reject endpoints.
- Read `docs/features/logistics/courier-approval/spec.md` for exact authorization, DTOs, errors, and retries.
- Read `docs/features/courier/auth/spec.md` for Flutter registration/session and multipart contracts.
- This spec does not make a new fleet CRUD, maintenance, or assign/unassign endpoint available.
- Define allowed updates, review impact, request/response/errors, and retries before enabling fleet editing.

### Verification and client behavior

- Inspect Vehicle, CourierProfile, registration, approval completeness, and their tests before implementation.
- Add SQLite/PostgreSQL migration tests for existing data, uniqueness, and non-destructive rollout.
- Test concurrent vehicle creation, missing records, wrong ownership, and private evidence delivery.
- Test shared upload validation and transaction-failure cleanup through the registration owner.
- Logistics review shows Courier, type, plate, and OR/CR preview—not maintenance/capacity tabs.
- Flutter registration shows vehicle fields and OR/CR requirements, upload progress, and field errors.
- Preserve loading, forbidden, unavailable evidence, validation, timeout, and retry states without false success.
- Do not ordinary-cache private evidence; clear private previews on session loss.
- No new package, map provider, or government service is required.
- Update external Flutter copies when the actual API contract changes; this revision changes no endpoint.
- Keep new acceptance criteria unchecked until implementation and tests establish the behavior.
- Append documentation and implementation results separately to `docs/PROGRESS.md`.
