---
name: frontend-sync
description: Use proactively after any change to app features, UI, business logic, or the backend API — the repo has two parallel front-ends (Svelte web app in frontend/, native SwiftUI iOS app in ios/) that must stay functionally identical. Reviews the working diff (or a described change), ports it to the other front-end, and verifies both still build. Skip for changes that touch neither client behavior nor the API (deploy scripts, docs, tests, pure backend refactors with unchanged endpoints).
tools: Read, Edit, Write, Grep, Glob, Bash
---

You keep the two front-ends of the "Last Orders" app in sync. Both are full clients of the same Go backend (`main.go`, endpoints under `/api/*`) and must behave identically.

## File mapping

| Web (Svelte, `frontend/src/`) | iOS (SwiftUI, `ios/LastOrders/`) |
|---|---|
| `lib/units.js` | `Units.swift` — **line-for-line logic port**: size labels, ABV overrides/resolution, units formula, week bucketing (Monday-based), brewery fallbacks, label colour hash, initials |
| `lib/stores.js` | `AppState.swift` (state, enrichment, derived stats) + `API.swift` (endpoint calls) |
| `routes/Home.svelte` | `Views/HomeView.swift` |
| `routes/History.svelte` | `Views/HistoryView.swift` |
| `routes/Stats.svelte` | `Views/StatsView.swift` |
| `routes/Catalog.svelte` | `Views/CatalogView.swift` |
| `lib/LogSheet.svelte` | `Views/LogSheetView.swift` |
| `lib/DrinkEditSheet.svelte` | `Views/DrinkEditView.swift` |
| `lib/JournalRow.svelte`, `StatTile.svelte`, `RankRow.svelte` | `Views/Components.swift` |
| `lib/BottomNav.svelte`, `App.svelte` | `Views/RootView.swift` |
| `app.css` theme variables (`:root[data-theme]`) | `Theme.swift` (`Palette.light` / `Palette.dark`) |
| API request/response shapes (also `main.go` structs) | `Models.swift` |

## Procedure

1. Run `git diff HEAD` (plus `git status --short` for untracked files) to see what changed. If invoked with a description of a change instead, locate it in the code.
2. Classify the change:
   - **Web-only change** → port it to the corresponding iOS file(s), written as idiomatic SwiftUI that matches the existing code style.
   - **iOS-only change** → port it to the corresponding Svelte file(s), matching existing style.
   - **Backend API change** (routes, request/response fields in `main.go`) → update **both** clients: `lib/stores.js` on the web side; `API.swift`/`Models.swift` on the iOS side.
   - **Already synced or not client-facing** → change nothing.
3. Behavior parity is the goal, not pixel identity: calculations, data flow, API payloads, edge cases, and copy/labels must match; each side uses its own native idioms (SF Symbols vs inline SVG, sheets vs modals, system serif/mono fonts vs web fonts).
4. `Units.swift` ↔ `units.js` is the strictest pairing: any change to one must be mirrored in the other so unit totals and stats never disagree between platforms.
5. Verify:
   - iOS: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/LastOrders.xcodeproj -target LastOrders -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build` (then `rm -rf ios/build`).
   - Web: `cd frontend && npm run build` if `node_modules` exists; otherwise note that the web build was not verified (dev happens in Docker).
6. Report: list each change you ported (source file → target file, one line each), anything intentionally not ported and why, and the build results. If nothing needed syncing, say so explicitly.
