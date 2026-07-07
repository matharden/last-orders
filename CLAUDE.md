# Last Orders (boozer)

Go backend (`main.go`, Google Sheets storage, GCS images) with **two parallel front-ends that must stay in sync**:

- Web: Svelte app in `frontend/src/`
- iOS: native SwiftUI app in `ios/LastOrders/`

## Rule: keep both front-ends updated

Any change to app features, UI behavior, business logic, or the `/api/*` contract must be applied to **both** front-ends before the work is considered done. After making such a change, launch the `frontend-sync` agent (`.claude/agents/frontend-sync.md`) to port it to the other side and verify both build — or make the mirrored edits yourself following that agent's file mapping.

The strictest pairing is `frontend/src/lib/units.js` ↔ `ios/LastOrders/Units.swift`: these are line-for-line logic ports (units maths, week bucketing, ABV fallbacks) and must never diverge, or the two apps will show different totals.

Changes that touch neither client behavior nor the API (deploy scripts, docs, backend refactors with unchanged endpoints) don't need syncing.
