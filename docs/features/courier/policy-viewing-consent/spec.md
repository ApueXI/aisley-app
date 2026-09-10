---
feature: courier-policy-viewing-consent
title: Courier Policy Viewing and Consent (Flutter Client)
system: AISLEY
type: Feature Specification
version: 1.0
status: Backend contract implemented; Flutter client contract
role: Courier / Rider
platform: External Flutter mobile app consuming the Laravel API
canonical: false
authority: Derived client contract; shared policy spec remains authoritative
backend_contract_commit: c3b9cad
source_contract: docs/features/shared/policy-viewing-consent/spec.md
---

# Courier Policy Viewing and Consent

> This is a Courier-specific Flutter companion to the shared policy contract. It does not create a second policy, audience, acceptance table, endpoint, or enforcement rule. If this file differs from `docs/features/shared/policy-viewing-consent/spec.md`, `docs/requirements.md`, `docs/workspace.md`, `docs/schema.md`, or `docs/domains/Courier.md`, the shared documents and server behavior win.

## WHAT

- **Purpose:** Let an approved Courier read the current platform-wide Terms of Service and Privacy Policy, inspect published history, and record explicit acceptance from the mobile app.
- **Audience:** An authenticated, active Courier with an approved affiliation to an active Logistics organization and a valid sole hub. Guests may read public documents but cannot use the Courier consent API.
- **Shared policy identity:** There is exactly one platform-wide Terms stream and one platform-wide Privacy stream. Every account role sees the same current version; there is no Courier-specific or Logistics-specific policy copy.
- **Current baseline:** The Laravel API implements public reads, private consent status, exact-current-version acceptance, stale-version conflicts, idempotent immutable rows, and rate limits. The external Flutter UI is not implemented in this repository.
- **Enforcement boundary:** `required: true` reports an action requirement, but a global registration, login, session, or protected-action gate is deferred. This screen must remain reachable so a future gate cannot trap the Courier.
- **Non-goals:** Admin policy editing, publishing, Internal Platform Rules, role-specific policy text, automatic acceptance, email or push delivery, subscription consent, or a Courier web/React screen.

```text
authenticated Courier opens Policy & consent
→ fetch private status
→ fetch each current public document
→ read full content and optional history
→ explicitly confirm one required version
→ accept exact current version
→ refresh status and show the committed timestamp
```

## MUST

### Authority and eligibility

- The server is authoritative for policy type, current version, publication status, required flag, User identity, acceptance time, and the shared policy matrix.
- The Flutter client must not submit `user_id`, role, policy ID, version metadata, `accepted_at`, Logistics ID, hub ID, or approval decisions.
- Consent calls use a Sanctum bearer token over TLS. Never use browser cookies, a client-selected identity, or a locally fabricated acceptance.
- `policy.actor` requires persisted role `courier`, `users.status = active`, an approved Courier affiliation, an active Logistics account, and a valid sole hub.
- A pending, rejected, revoked, suspended, deactivated, or orphaned Courier receives a server error and must not be treated as consent-ready.
- First-mile/final-mile shipment states and any operational task assignment are unrelated to reading or accepting policy.

### Shared catalogue and rendering

- Request only `terms_of_service` and `privacy_policy`. `internal_rules` is not a Courier document and returns not-found on public or consent acceptance routes.
- Show only the current `published` version in the primary view. History may show `published` and `superseded` versions; Drafts are never shown.
- Preserve server content as text. Render plain text safely; do not execute HTML, scripts, arbitrary links, or unapproved Markdown components.
- Display the policy label, integer version, publication time, change summary when present, and the complete content returned by the server.
- The acceptance control starts unchecked, requires an explicit confirmation, and is never preselected from local storage or a previous version.
- A previous acceptance covers a new version only when the status response says `required: false`; a flagged `requires_reconsent` version requires its exact version.
- One successful acceptance creates one immutable User/version/timestamp record. Repeating the same request returns the same canonical acceptance and must not create a duplicate.
- Acceptance is not automatic after viewing, scrolling, opening history, sign-in, or restoring an offline session.

### Endpoint contract

- **Implemented public current read:** `GET /api/v1/platform/policies/{type}`.
  - Auth: none; path type is `terms_of_service` or `privacy_policy`.
  - `200`: `{ "data": { "type", "label", "version": { "id", "version", "title", "content", "status", "change_summary", "requires_reconsent", "published_at" } } }`.
  - `404`: unknown type or no current published version. `429`: retry after the server-provided delay.
  - Cache: public, short-lived (`max-age=300`); Flutter may use an in-memory copy only and must refresh before acceptance.
- **Implemented public history list:** `GET /api/v1/platform/policies/{type}/history`.
  - Auth: none; same type allow-list.
  - `200`: `{ "data": { "type", "label", "versions": [ { "id", "version", "title", "status", "change_summary", "published_at" } ] } }`.
  - Content is intentionally omitted from list rows; fetch an exact entry to read it. Cache is public and short-lived (`max-age=60`).
- **Implemented public exact history read:** `GET /api/v1/platform/policies/{type}/history/{version}`.
  - Auth: none; version is an integer and must belong to the requested policy identity.
  - `200` returns the same safe version projection as the current read, including content. `404` covers unknown, Draft, or unavailable versions.
  - This read never changes consent or the current pointer; it may use a public short-lived cache (`max-age=300`).
- **Implemented private status:** `GET /api/v1/policy-consent/status`.
  - Auth: `Authorization: Bearer <sanctum-token>` plus `policy.actor`; no request body.
  - `200`: `{ "data": { "policies": [PolicyConsentItem], "all_required_accepted": boolean } }` with `Cache-Control: private, no-store` and `Pragma: no-cache`.
  - Each item contains `type`, `label`, `required`, `accepted`, `accepted_at`, `current_version`, and `accepted_version`. A current version may be `null` only when no published version exists.
- **Implemented private acceptance:** `POST /api/v1/policy-consent/{type}/versions/{version}/accept`.
  - Auth: the same bearer token and `policy.actor`; type is a shared Terms/Privacy type and version is an integer.
  - Body is exactly `{ "confirmation": true }`. Extra fields, false confirmation, client identity, or client timestamps return `422`.
  - `200`: `{ "data": { "type", "label", "version": PolicyVersion, "accepted_at" } }` with private no-store headers.
  - `401` means missing/invalid token; `403` means role, account, affiliation, Logistics, or hub failure; `404` means a disallowed policy type; `409 POLICY_VERSION_STALE` means the requested version is no longer the current published version; `429` is retryable.
  - A same User/version retry is idempotent. The client must refresh status/current content after `409` and never retry a stale version indefinitely.

### Mobile state and security behavior

- Model separate states: `signedOut`, `loadingStatus`, `loadingDocument`, `ready`, `historyLoading`, `consentRequired`, `accepting`, `accepted`, `validationError`, `unauthorized`, `forbidden`, `staleVersion`, `rateLimited`, `timeout`, `offline`, and `retryableError`.
- Keep the current screen and safe, non-secret form state on recoverable errors. Do not claim acceptance until the `200` response is received.
- On `401`, clear the access token from secure storage, reset authenticated state, and route to Courier sign-in. Do not silently create a new account or repeat a failed accept.
- On `403`, show the server message and an affiliation/account-help action; do not allow local bypass or present the Courier as approved.
- On `409`, discard the stale document, reload status and current content, explain that the policy changed, and require a new explicit confirmation.
- On `422`, identify the confirmation problem without exposing raw server internals. On `429`, honor `Retry-After` and disable the action until retry is safe.
- On timeout or offline, show a retry action and keep the last safely displayed public document labeled as possibly stale. Offline data cannot authorize acceptance.
- Store Sanctum tokens only in platform secure storage. Never log tokens, full policy content, private response bodies, or account identifiers; use redacted diagnostics.
- Use bounded in-memory caching for public content. Never shared-cache private status or acceptance, and clear private state on logout, token replacement, or account switch.

### Flutter experience

- Provide a reachable Policy & consent entry from the Courier account/settings area and from any future consent gate. Do not implement this UI under Laravel `src/`.
- Use semantic headings, labeled checkboxes/buttons, visible focus/pressed states, readable contrast, large text support, and minimum 48dp tap targets. Test with TalkBack and VoiceOver.
- Show loading placeholders, no-published-version empty state, not-found state, retryable error, and a success message containing the accepted policy label/version.
- Keep history separate from the current document. Navigating to history must not change the acceptance checkbox or create a consent row.
- Prevent double taps while an acceptance request is pending, but make a retry after an unknown network result safe because the endpoint is idempotent.
- Do not add a map, route, shipment, scan, proof, notification, or policy-editing dependency to this feature.

## HOW

- Implement a typed `PolicyApi` with the five exact paths above, a bearer-auth interceptor, JSON envelope parsing, and typed errors for `401`, `403`, `404`, `409`, `422`, `429`, timeout, and offline.
- Map `PolicyType` to a Dart sealed/enum value with only `termsOfService` and `privacyPolicy`; preserve unknown server types as an unsupported result rather than guessing.
- Map nullable `change_summary`, `published_at`, `accepted_at`, `current_version`, and `accepted_version` explicitly. Treat timestamps as ISO-8601 UTC and format them in the device locale.
- Keep acceptance UI state separate from `PolicyConsentItem`; the server projection is replaced after every status response.
- Sequence the first load as status, then current documents for items with a current version. Parallel document reads are allowed, but a partial failure must remain visible and retryable.
- Use an in-flight request guard per policy type and disable duplicate submissions. A successful response is the only source for the accepted timestamp.
- Add contract fixtures for current, history, exact history, status, accepted, stale, forbidden, validation, rate-limit, and network-failure responses.
- Add Flutter tests for state transitions, secure-token clearing on `401`, stale-version refresh, idempotent retry, no-store status handling, safe text rendering, and accessibility labels.
- Verify against backend commit `c3b9cad` (API `/api/v1`). Record a newer backend commit in this header whenever route, response, middleware, or policy behavior changes.
- Keep this companion spec synchronized with the shared spec; do not modify server behavior, migrations, canonical role rules, or policy decisions from the Flutter project.

### Contract field mapping

- `type` is a stable string discriminator; map `terms_of_service` to `termsOfService` and `privacy_policy` to `privacyPolicy`.
- `label` is display text from the server and must not be used as an authorization key or parsed to infer policy type.
- `version.id` is an opaque UUID/string. Preserve it for display or diagnostics, but never construct routes from it.
- `version.version` is the integer path value used by acceptance. Do not derive it from a list index or local counter.
- `version.title` and `version.content` are server-authored text and may be localized only by the server contract.
- `version.status` is expected to be `published` for current/accepted responses and `published` or `superseded` for exact history.
- `version.change_summary` is nullable; an absent summary is not an error and should not be replaced with a guessed explanation.
- `version.requires_reconsent` is a server flag, not a client-side policy decision. The client displays the status result.
- `version.published_at` and every acceptance timestamp are nullable ISO-8601 strings in responses; preserve null distinctly from an invalid date.
- `accepted_version` is a summary and may be null before any acceptance. It does not authorize the current version by itself.
- `all_required_accepted` is an aggregate convenience value; still inspect each policy item before rendering its action state.
- Unknown fields must be ignored for forward compatibility; missing required fields or malformed envelopes are typed protocol errors.

### Request and response handling

- Set `Accept: application/json` on every request and send `Content-Type: application/json` only for the acceptance request.
- Attach `Authorization: Bearer <token>` to private routes; public document reads must not require a token and must work after logout.
- Treat a non-JSON response, an HTML error page, or a missing `data` envelope as a protocol error with a safe retry message.
- Do not send an `Idempotency-Key` unless a future backend contract adds and documents that field; current idempotency is server-side User/version uniqueness.
- Public history has no client-controlled page size, cursor, or ordering parameter in the current contract. Do not invent them.
- Keep request timeouts bounded and configurable; a timeout does not prove that acceptance failed or succeeded.
- If an acceptance timeout leaves the result unknown, reload private status before offering another confirmation.
- Refresh status after app resume when the previous status is stale, but avoid an unbounded polling loop.
- A public document cached in memory may be reused for display, but the version in the acceptance action must come from the latest status/current read.

### Error and retry matrix

| Server result              | Flutter interpretation                   | Safe action                                                 |
| -------------------------- | ---------------------------------------- | ----------------------------------------------------------- |
| `200`                      | Authoritative success                    | Replace local projection and show timestamp.                |
| `401`                      | Token invalid/expired                    | Clear secure token and sign in again.                       |
| `403`                      | Courier/account affiliation not eligible | Show support/approval guidance; do not retry automatically. |
| `404`                      | Type/version unavailable                 | Remove stale route target and reload the catalogue.         |
| `409 POLICY_VERSION_STALE` | Current version changed                  | Reload status/current content and reconfirm.                |
| `422`                      | Request confirmation invalid             | Keep document open and correct the explicit control.        |
| `429`                      | Rate limit                               | Honor `Retry-After`; disable repeated attempts temporarily. |
| Timeout/offline            | Result unknown or unavailable            | Show retry; status remains unaccepted until confirmed.      |

### Navigation and lifecycle

- The policy entry is reachable from Courier settings/account navigation after sign-in and from any future gate response.
- Deep links may identify `terms_of_service` or `privacy_policy` and an optional historical version, but a deep link never bypasses authentication for private status.
- Back navigation from history returns to the same current-document view without changing confirmation state.
- On logout, clear private status, accepted-version summaries, and pending acceptance state; public documents may remain in memory only until app termination.
- On account switch, discard all old Courier consent data before loading the new token's status.
- On app resume, refresh only when the status TTL has elapsed or a prior request failed; do not refresh on every widget rebuild.
- A future auth gate must route to this screen with a resumable return destination and must not discard an active first-mile/final-mile task view.

### Verification and handoff

- Backend integration tests are evidence for `[x]` items; they do not mark Flutter acceptance criteria complete.
- Flutter tests must use a fake transport, never production credentials, and must assert exact paths, methods, headers, body, and envelope parsing.
- Include fixtures for both shared policies, no published version, prior acceptance, exact re-consent, stale acceptance, and every listed error.
- Exercise airplane mode, network recovery, app background/resume, token expiry, double tap, and process restart during acceptance.
- Verify that screenshots/logs redact tokens, private status, full content where inappropriate, and account identifiers.
- Run TalkBack and VoiceOver checks, large-text layout checks, contrast checks, and 48dp target checks before release.
- The external Flutter repository should record the API base URL, backend commit `c3b9cad`, and date of the last contract verification.
- When the backend changes, compare this file with the shared spec and update the header before changing Dart models or routes.
- Do not copy Laravel models, migrations, Eloquent names, or database assumptions into the Flutter app.
- A contract gap is reported to the backend owner; it is not filled with a guessed endpoint or locally persisted policy acceptance.

### Acceptance criteria

- [x] The Laravel API exposes the documented public current/history/exact reads and private status/acceptance routes at `/api/v1`.
- [x] Active approved Couriers receive the same platform-wide Terms/Privacy status as other account roles.
- [x] Ineligible or inactive Couriers cannot read private consent status or accept a version.
- [x] Acceptance is explicit, server-owned, exact-current-version, immutable, and idempotent.
- [x] Private status and acceptance responses are not shared-cached; public policy reads remain safe and bounded.
- [x] Drafts, Internal Rules, client identity fields, and raw private metadata are unavailable to this contract.
- [x] Flutter uses secure bearer-token storage and implements every listed loading, success, error, timeout, and offline state.
- [x] Flutter renders safe complete content, history navigation, explicit confirmation, accessibility semantics, and retry-safe acceptance.
- [x] Flutter contract tests pass against the recorded backend commit and detect response/path drift.
- [x] Logout/account switching clears private consent state and no acceptance is fabricated offline.

### Deferred decisions

- The owning Courier auth specification must decide whether a missing consent blocks registration, sign-in, session restoration, or a protected action. This file must not invent that gate.
- If a future gate is approved, it must still allow this status/read/accept flow and return a stable machine-readable requirement response.
- Push/email reminders, policy notification retention, and Internal Platform Rules access require separate approved contracts.

### References

- Canonical shared contract: `docs/features/shared/policy-viewing-consent/spec.md`.
- Courier boundaries: `docs/domains/Courier.md`, `docs/requirements.md`, `docs/workspace.md`, `docs/schema.md`.
- Backend evidence: `src/api/routes/api.php`, `PolicyConsentController`, `PolicyConsentService`, `EnsureActivePolicyActor`, `PolicyConsentTest`.
- Flutter networking guidance: https://docs.flutter.dev/data-and-backend/networking
- Flutter accessibility guidance: https://docs.flutter.dev/ui/accessibility
