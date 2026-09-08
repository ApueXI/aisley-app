# Courier Flutter documentation bundle

This directory is a documentation bundle for the external Courier Flutter application. Copy `AGENTS.md` to the Flutter project root and copy the `docs/` directory into that project. Do not copy Laravel, React, Next.js, or database source code into the Flutter project.

## Authority order

1. The live, versioned Laravel API contract.
2. The copied `docs/requirements.md`, `docs/workspace.md`, and `docs/schema.md` sections relevant to Courier.
3. `docs/domain/Courier.md` and `docs/domain/Logistics.md`.
4. The matching Courier feature specification.
5. `docs/order-logistics-flow-decisions.md` only as historical rationale; it is not canonical.

If these sources disagree, stop and resolve the backend contract before implementing behavior.

## Current implementation

Only Courier authentication is currently available. Use `docs/features/courier/auth/spec.md` for the implemented endpoints and `docs/features/courier/README.md` for the deferred-feature gate. The other Courier specs are planning drafts and must not be treated as API documentation.

## Synchronization

The bundle was checked against backend commit `d817a10` on 2026-09-08. The agent must automatically update `docs/PROGRESS.md` in the same task after implementation, test, backend-contract, or material project-documentation changes. Record the actual change and verification; do not add entries for read-only reviews or unfinished work.
