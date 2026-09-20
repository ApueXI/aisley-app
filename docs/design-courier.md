---
title: Courier Flutter Design Guide
system: AISLEY
type: Design Guide
platform: Flutter / Dart
role: Courier / Rider
status: Active — core Courier UI, notification inbox, and Android/web-server camera scanning implemented; route/location/media extensions deferred
---

# Courier Flutter Design Guide

## Scope

This guide applies to the external Flutter Courier application on Android and to local browser testing of that same app through Flutter `web-server`. It does not define the separate webapp's Customer storefront or React Admin, Seller, or Logistics dashboards. Laravel remains authoritative for identity, approval, ownership, and operational state.

The current API supports Logistics discovery, Courier registration, approval-gated login, `me`, logout, generic password-recovery acknowledgement, Phase 1 account management, policy consent, the Courier notification inbox, the approved first-mile/final-mile pickup workflow, final-mile movement, P0 QR/tracking-ID/Order-reference proof, completion intent, and read-only delivered history. Android APK and Flutter web camera scanning are implemented client work; background push, route/location telemetry, photo/signature proof media, earnings, and offline task screens remain deferred.

## Design goals

- Make a Courier's next action obvious on a small screen and in poor network conditions.
- Keep registration and approval states understandable without exposing private review data.
- Use consistent, calm professional surfaces for work-related information and strong contextual emphasis for safety or blocking states.
- Prefer simple, fast, touch-friendly interactions over dense desktop dashboard patterns.
- Never let visual state imply permission or operational authority that the API has not granted.

## Visual language

### Brand colors

- Primary accent: `#E6007A`.
- Secondary/deep purple: `#4C1268`.
- Error: `#FF3B30`.
- Warning: `#FF8800`.
- Use a neutral background and readable foreground for the majority of the screen; accents should guide attention, not fill every surface.
- Use the 60/30/10 balance as a starting point: neutral surfaces, secondary structure, and small primary/contextual accents.

### Themes

- Support light and dark themes and follow the device's system preference by default.
- Define colors through Flutter `ColorScheme`/theme extensions rather than inline values. Every semantic color must have a readable foreground in both themes.
- Keep destructive, warning, pending, and success meanings consistent across screens. Pair color with text, iconography, or shape; never rely on color alone.

### Typography and spacing

- Use one app-wide `TextTheme` with a clear hierarchy for screen titles, section labels, body copy, helper text, and errors.
- Support system text scaling without clipping, overlap, or hiding required actions. Long server messages must wrap or become scrollable.
- Use a small, consistent spacing and radius scale. Keep form sections visually separated and avoid decorative density.
- Respect `SafeArea`, keyboard insets, display cutouts, and platform navigation bars.

## Navigation and layout

- Use a single, predictable authentication stack: Logistics selection → registration → pending result, or login → authenticated state.
- Navigate to the implemented Notifications, Pickup orders, Delivery work, and Delivery history screens from the dashboard. Deferred route/location and media capabilities must state that they are unavailable rather than showing fabricated jobs or controls.
- Use Flutter's adaptive navigation primitives. Phones are the primary target; tablets may use wider constrained content but must not become a desktop sidebar clone.
- Preserve user input when validation or a recoverable network error returns. Confirm before discarding a partially completed registration.
- Keep primary actions reachable above the keyboard when possible; use bottom action areas only when they do not obscure content or accessibility focus.

## Components and interaction patterns

- Use Material components (or the project's approved equivalent) with a centralized theme: buttons, text fields, dropdowns, searchable lists, dialogs, banners, progress indicators, cards, and navigation controls.
- Give every interactive control a visible label, meaningful semantics label, disabled state, pressed/focused state, and clear success/error feedback.
- Use at least a 44 × 44 logical-pixel touch target. Avoid gesture-only actions; provide visible controls for back, retry, remove, and submit.
- Keep forms single-column on phones. Group related fields into named sections and show required markers and input examples before submission.
- Use confirmation dialogs for sign-out, destructive local-data removal, or abandoning a completed form; do not add confirmation friction to ordinary navigation.

## Authentication and registration screens

### Logistics selection

- Present active Logistics organizations as a searchable, bounded list using the safe organization name returned by the API.
- Do not show or let the Courier choose a hub/sub-hub ID. The selected organization owns one sole operational hub, derived by the server.
- Show loading, no-results, unavailable, and retry states distinctly.

### Registration

- Organize personal, address, vehicle, and evidence sections in a scrollable form with progress or section headings.
- Display age as a read-only value derived from the entered birth date; never ask the user to edit age.
- Use Region → Province → City/Municipality → Barangay cascading selectors backed by the bundled PSGC data, plus a complete manual fallback for address fields.
- Current registration does not require a map pin or coordinates. Do not add Geoapify, Mapbox, or another map dependency without an approved API contract.
- Evidence pickers must clearly show accepted JPEG/JPG/PNG/WebP formats and the strict under-10-MiB limit. Show selected filename, size, replace/remove controls, and a readable validation error.
- Apply the same evidence-picker and error states on Android and local Flutter web-server; a browser-selected file must remain available for multipart submission without requiring a disk path. Follow [`flutter-file-uploads.md`](flutter-file-uploads.md); do not claim browser upload success before server confirmation.
- Keep the submit action disabled only for locally known invalid/incomplete fields; the API remains the final validator.

### Approval and login

- After registration, show a clear pending-approval screen and explain that the selected Logistics organization must decide. Do not expose reviewer notes or promise an email that the backend does not send.
- Login requires email, password, and a device name. Never display role, ability, hub, or reviewer fields as editable inputs.
- Use explicit states for checking session, signed out, authenticated, pending, rejected, suspended/deactivated, invalid affiliation, and recoverable network failure.
- The current `/me` endpoint is protected and succeeds only for an approved active Courier. Do not use it as a pending-status endpoint; cross-device approval refresh requires a future backend contract.
- The current forgot-password response is generic and does not complete a reset flow. Do not present a reset form until the backend endpoint and notification contract exist.

### Account management

- Show the authenticated Courier's private account projection and keep email, status, legal identity fields, affiliation, and sole hub read-only.
- Allow only the documented first name, middle name, last name, and contact number profile edits. Keep unsaved profile text local during recoverable failures and show field-level server validation.
- Allow profile-photo selection only when the server capability flag is true. Show the JPEG/JPG/PNG/WebP and under-10-MB policy before opening the picker, keep the local preview separate from the saved private photo, and show upload progress, cancellation, retry, missing-photo fallback, and server rejection states.
- Fetch the saved profile photo through the authenticated private URL with the bearer token; never use a browser-style public URL, raw storage path, or unauthenticated network image widget. Confirm success only after the server response and private refresh succeed.
- Confirm photo removal and reconcile uncertain upload/removal responses with a fresh account/photo read. Do not queue photo writes offline or expose the original filename as storage identity.
- Use the same photo and independent OR/CR document controls on Android and local web-server. Browser selection, upload cancellation, CORS failure, and authenticated private preview need explicit feedback; keep Android's existing picker/upload behavior and verify both targets before marking web uploads supported.
- Require current password confirmation before a password change. Clear password fields after every attempt and explain that a successful change revokes all sessions and returns to sign-in.

### Pickup orders

- Show server-assigned Seller pickups and hub pickups in separate sections. The task list is read-only until the Courier explicitly accepts an assigned task.
- Keep schedule, Seller/hub, authorized pickup address, Order reference, waybill reference, destination area, and lowercase server status visible without exposing Buyer contact details, prices, or private evidence.
- Require an explicit confirmation after the QR/manual identifier candidate is entered. A waybill QR payload is untrusted text; the current client supports camera, scanner keyboard/paste input, and a manual Order ID/reference fallback.
- **Scan** opens the camera only when selected, works in the installed Android release APK and in the same Flutter app at `http://localhost:8765` through the fixed-port web-server run, and displays a visible manual-input control. Show permission denied, unavailable, busy, unsupported, and insecure-origin states with a manual alternative; release the stream when leaving the screen or switching tasks. Linux remains manual-input only.
- Decode QR payload as `qr` and the waybill Code 128 tracking ID as `tracking_id`; do not route tracking IDs through the QR-only resolver. Suppress repeated-frame candidates and show the matched task before the explicit pickup or hub-evidence action. Do not log or copy raw decoded values into analytics.
- Use the documented idempotency key for physical first-mile confirmation and preserve the same key and identifier after an uncertain response. Final-mile hub evidence must remain visibly “Awaiting Logistics validation” until the server reports validated custody.
- Present the schedule route manifest as an ordered, accessible stop list. It is not a Buyer delivery route, and the client does not add map credentials, provider calls, or turn-by-turn navigation.

### Delivery work

- Show only server-returned final-mile tasks. Keep `delivery_assigned`/`delivery_accepted` visibly separate from hub custody; accepting an offer does not mean the parcel was picked up.
- After the server records `picked_up_from_hub`, show one explicit movement action at a time: `in_transit`, then `out_for_delivery`. Each action confirms the server-authorized transition and revision; it never writes an Order status locally.
- Show the authorized hub, destination, recipient contact, instructions, and optional advisory metrics returned by the delivery-context endpoint. Missing route metrics remain visibly unavailable; no map, GPS, local ETA, or fabricated zero distance is shown.
- At `out_for_delivery`, offer only the live P0 QR/reference proof input. Show `awaiting_validation` after the 202 response, map the returned proof reference to completion, and never treat a scan or completion intent as delivered.
- Delivery-proof camera scanning reuses the Flutter barcode capture behavior on Android APK and local web-server. It fills a candidate for explicit proof submission; camera access does not enable photo or signature proof media.
- Completion is an explicit intent followed by a fresh completion read. Display delivered only when the server returns the committed `delivered` projection.

### Delivery history

- Present delivered final-mile records as read-only cards with order reference, delivered time, pickup/destination areas, item count, and safe proof/completion status.
- History detail may show immutable item snapshots and opaque proof references, but never street addresses, contact phone numbers, raw proof bytes, storage paths, or mutation controls.
- Keep cursor pagination unavailable when the server does not provide a usable cursor; distinguish an empty successful list from unavailable, unauthorized, offline, and retryable states.

## Status, error, and network presentation

- Every API-backed screen has loading, empty, validation, unauthorized, forbidden, timeout/offline, retry, and success states appropriate to its operation.
- Use server error codes such as `INVALID_CREDENTIALS`, `ACCOUNT_PENDING_APPROVAL`, `ACCOUNT_REJECTED`, `ACCOUNT_SUSPENDED`, `ACCOUNT_INACTIVE`, and `LOGISTICS_ASSOCIATION_INVALID` as state inputs, not as permission decisions made locally.
- Explain what the Courier can do next. Do not expose another account's existence, private rejection reason, raw storage path, or sensitive server details.
- Retry safe reads with bounded backoff. Do not blindly replay multipart registration, token issuance, or future operational writes after an uncertain response.
- Preserve the last known authenticated UI during a transient network failure, but block protected mutations until the server confirms authorization.

## Privacy and mobile security

- Store Sanctum bearer tokens only in platform secure storage (Keychain/Keystore or the approved Flutter secure-storage implementation).
- Never put tokens, passwords, private evidence, full addresses, or raw API payloads in logs, analytics, crash reports, URLs, clipboard data, or ordinary preferences.
- Redact sensitive fields from debug tooling and disable verbose network logging in release builds.
- Keep notification previews and screenshots privacy-conscious. Sensitive delivery details require an explicit approved product decision.
- Use HTTPS in every non-local environment and retain normal platform certificate validation.

## Accessibility and quality

- Test with TalkBack/VoiceOver, large text, high-contrast settings, dark mode, reduced motion where available, and one-handed use.
- Announce validation results, loading completion, authentication changes, and retry outcomes to assistive technology without stealing focus unexpectedly.
- Keep focus order logical, labels associated with fields, and errors adjacent to the field or action they explain.
- Do not communicate state through animation, color, or icons alone; include readable text.

## Testing and implementation notes

- Centralize API calls in a client/repository layer and map responses into immutable Dart models and explicit authentication states.
- Unit-test validation, multipart field names, PSGC cascading behavior, JSON parsing, status mapping, secure-storage failures, and theme semantics.
- Run integration/contract tests against the Laravel API for Logistics options, registration, login, `/me`, logout, role isolation, status denial, upload limits, and error codes. Mocks may support deterministic widget tests but cannot replace contract verification.
- Add golden or screenshot tests only for stable, approved screens; verify text scaling and light/dark variants before accepting them.
- Before marking physical scanning acceptance complete, exercise QR and Code 128 capture, permission denial, manual fallback, task mismatch, duplicate-frame suppression, and camera cleanup in an installed Android release APK and the local fixed-port browser run.
- Keep this guide and the copied Courier feature specs synchronized with the backend API version. Changes to deferred delivery UI require the matching API/schema decision first.

**Related documents:** `../AGENTS.md`, `docs/features/courier/auth/spec.md`, `docs/domain/Courier.md`, `docs/domain/Logistics.md`, `docs/requirements.md`, `docs/workspace.md`, `docs/schema.md`, `docs/references/user-registration-requirements.md`, and `docs/references/file-upload-requirements.md`.
