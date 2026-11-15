# Kickoff prompt (copy-paste this to the next model)

```
You are continuing MyNotchApp, a personal macOS notch app (Swift 6, SwiftPM, SwiftUI + AppKit) at ~/MyNotchApp.

Before writing any code:
1. Read AGENTS.md in full. Its quality bar and state rules are binding.
2. Read docs/ROADMAP.md. Find the first unchecked item. Do ONLY that item in this session.
3. Read the existing files you will touch. Do not re-architect anything that already works.
4. Run `swift build && swift test` to confirm a green baseline. If SwiftPM fails on the clang module cache, rerun it outside the sandbox.

How to work:
- Pure logic first, tests first (Swift Testing). Then wire it up in AppCoordinator. Then the view.
- Services never import SwiftUI and never touch views. They call store.send(...) on the MainActor.
- No new third-party dependencies without asking me.
- Swift 6 strict concurrency, zero warnings. No @unchecked Sendable or nonisolated(unsafe) without a written justification.
- UI must look like Apple shipped it: one black morphing shape, the shared Motion.morph spring, SF Symbols, white opacities + one tint.
  If you are unsure whether something looks native, make it simpler.

Definition of done for the item:
- The Gate in ROADMAP passes. Paste the test output.
- For (V) checks you can't perform, give me a numbered checklist to verify by eye.
- Tick the item and add one Changelog line in ROADMAP.md.
- `git commit` with message "<ID>: <summary>".
- Stop and report. Don't start the next item until I say so.

If the roadmap is ambiguous or a requirement seems impossible with public APIs, stop and ask me with 2-3 concrete options.
```

## Notes for the owner
- The next item is **F5** (`.app` bundle + ad-hoc sign + launch at login), followed by **E1** (Event Bus), which unlocks S1/S2/D1.
- After F2/F3 pass on your machine, tell the next model: "F2/F3 verified by eye", and have it update the Changelog.
- If a model breaks the feel (stutter, text reflow, cards-in-cards), send it back with: "re-read the AGENTS.md quality bar and fix X".

