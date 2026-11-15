# AGENTS.md: MyNotchApp handoff

Read this whole file before you touch code. Then read `docs/ROADMAP.md` and pick up the first item that is not done.

## What this is
MyNotchApp is a personal macOS notch / Dynamic Island app for **one developer** (the owner). It is never distributed.
It is a **developer cockpit**. When the owner switches to another window, the notch still tells them:
- whether the build, test, or AI agent finished, failed, or is waiting for input
- which dev servers are running
- what is in the clipboard or screenshot shelf

The owner writes TS/Node, C#, and Swift and uses several AI coding agents every day.

## Non-negotiable quality bar
- **It must feel native, like Apple built it.** Use one black shape that morphs between states, with single-level Control Center-style Bento containers (`white.opacity(0.06...0.08)` rounded tiles) for clean visual grouping and easy click targets. No deep nested cards, no gradients-for-the-sake-of-it, no emoji, no placeholder "lorem" UI, no generic AI dashboard look.
- On a hardware notch the collapsed island is **exactly** the notch size, so it is invisible until something happens. Nothing is ever drawn under the camera area: content goes in the "ears" or below the notch height.
- Motion: one spring, `.spring(response: 0.42, dampingFraction: 0.8)`. Content fades in **after** the shape starts growing (short delay) and fades out **before** it shrinks. Text must never reflow mid-animation.
- Type: SF Pro / SF Mono (for commands, ports, and paths). Use SF Symbols only. Colors are white at various opacities plus one semantic tint per state (green ok, red fail, orange waiting, blue info).
- No polling faster than needed. Idle CPU should be about 0%. Prefer event sources (DistributedNotifications, DispatchSource file watchers, IOKit callbacks, the local Event Bus).

## Constraints (personal use)
- No App Sandbox and no notarization. Ad-hoc sign the `.app` so TCC grants survive rebuilds.
- Private APIs are allowed only behind a protocol with a public-API fallback, because they break on OS updates.
- Never fake data. If a source isn't available, hide that module.

## Architecture
```
Sources/MyNotchApp/main.swift    thin executable. Boots NotchAppDelegate. Nothing else.
Sources/NotchKit/                all real code (library, so it can be tested)
  App/       NotchAppDelegate, AppCoordinator (composition root / DI), StatusBarController
  Window/    NotchPanel (NSPanel), NotchWindowController (positioning, screen choice, hit-testing, hover)
  Geometry/  ScreenGeometry (pure: notch rect from NSScreen metrics), IslandLayout (pure: size/radii per mode)
  State/     Toast, NotchState + NotchReducer (pure), NotchStore (@MainActor @Observable)
  Services/  one folder per source. Each exposes an AsyncStream or calls store.send. No SwiftUI imports.
  Views/     SwiftUI only. Views read the store and call store methods. They never call services.
Tests/NotchKitTests/             Swift Testing (`import Testing`)
```

### State rules (keep these or races come back)
1. **There is one way in:** `NotchStore.send(NotchEvent)` on the MainActor. Services hop to the MainActor before sending.
2. `NotchReducer.reduce(&state, event) -> [NotchEffect]` is **pure**. Timers and IO are effects that the store executes.
3. `NotchState.mode` is **derived**, never stored. Precedence: `fileDrop > toast > expanded > collapsed`.
4. Toasts carry an `id` and an optional `key`. Posting a toast with the same `key` updates it in place, which is how progress updates work. An expiry for a stale `id` is ignored. Higher priority preempts the current toast, and the preempted one goes back into the queue.
5. Hover is computed by `NotchWindowController` from the global mouse position against `IslandLayout` rects, not by SwiftUI `onHover`. The same rect toggles `panel.ignoresMouseEvents`, so transparent areas click through.

## Build / run / test
```bash
swift build
swift test
swift run MyNotchApp       # menu bar icon appears, no Dock icon
```
In a restricted sandbox, SwiftPM may fail writing the clang module cache. Rerun outside the sandbox. This is not a code bug.

## Working rules for the next agent
- Do one roadmap item at a time. Write tests first for pure logic. Meet the item's Gate, then tick it in `docs/ROADMAP.md` and append a line to the Changelog there.
- Keep `swift build` warning-free under Swift 6 strict concurrency. Don't use `@unchecked Sendable` or `nonisolated(unsafe)` unless you add a comment that justifies it.
- If you change an architecture rule, update this file in the same change.

