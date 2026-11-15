# MyNotchApp

A native macOS Dynamic Island / Notch **Developer Cockpit** built with **Swift 6** and **SwiftUI** (`AppKit` `NSPanel` + pure state reducer architecture).

Designed for one developer working across **Swift**, **TypeScript/Node**, and **C#/.NET** with multiple AI coding agents running concurrently. When you switch windows, the notch keeps critical engineering signals visible at a glance—without polling loops, fake data, or clutter.

---

## Key Capabilities

### Core Cockpit & Event Bus
- **Hardware-Exact Notch Geometry (`ScreenGeometry`, `IslandLayout`):** Measures `NSScreen` auxiliary areas so the collapsed island matches the physical notch and never draws under the camera housing.
- **Pure State Machine (`NotchState`, `NotchReducer`, `NotchStore`):** Single-entry `NotchStore.send(_:)` on `@MainActor`, pure reducer returning `NotchEffect`s, priority-based toast preemption, and key-based in-place progress updates.
- **Local Authenticated Event Bus (`EventBusServer`, `EventBusRouter`):** Loopback HTTP server with bearer token auth supporting `/health`, `/toast`, `/progress`, `/activity`, `/build`, `/terminal`, `/ci`, and `/logpin`.
- **Control Center Bento UI (`ToastView`, `NotchRootView`):** Native black morphing surface with `.spring(response: 0.42, dampingFraction: 0.8)`, SF Pro / SF Mono typography, SF Symbols, and semantic state tints.

### Engineering Intelligence (Phases 0.5 – 10)
1. **Build & Test Intelligence (`BuildTestIntelligence`):** Multi-toolchain deterministic log parser (`swift`, `TypeScript/Node`, `C#/.NET`) with `BuildEventCorrelator` and `ErrorLens`.
2. **Multi-Agent Conflict Radar (`AgentConflictDetector`):** Detects confirmed same-file overlaps, shared worktrees, same-branch edits, and stale agent sessions across Claude Code, Codex, and Antigravity.
3. **Daily Worklog & Terminal Parser (`WorklogStore`, `TerminalOutputParser`):** Persists daily developer/AI activity by date (`Today`, `Yesterday`, `7D`, `30D`, `1Y`) and explains failed builds/commands in Thai via Gemini (`Deterministic First, AI Second`).
4. **Process & Dev Server Intelligence (`ProcessInspector`, `LsofParser`):** Maps listening ports to real PIDs, project names, and protected-process guardrails.
5. **Change Impact Intelligence (`ChangeImpactAnalyzer`):** Analyzes `git diff` changes to separate direct manifest/config impacts from inferred code/test targets and risk levels.
6. **Service Health & Docker (`DockerGlanceMonitor`, `ServiceHealthInspector`):** Distinguishes unavailable Docker engines from unhealthy containers and tracks dependency impact.
7. **CI/CD Watchtower (`CIWatchtowerParser`):** Parses GitHub workflow runs with explicit `isLive` and `syncedAt` freshness tracking.
8. **Database & Migration Inspector (`ConnectionStringRedactor`, `DatabaseMigrationInspector`):** Read-only inspection of local migrations and automatic redaction of credentials in connection strings.
9. **Dependency & Environment Guard (`DependencySecurityWatcher`, `EnvGuard`, `SafeAPIHealthCheck`):** Detects package ecosystems and `npm audit` findings, compares `.env.example` vs `.env` keys without ever reading or displaying secret values, and enforces safe `GET`/`HEAD` health checks.
10. **Release Readiness Evaluator (`ReleaseReadinessEvaluator`):** Combines build/test status, git working tree cleanliness, agent conflicts, CI status, env drift, and security findings—never treating `.unknown` checks as `.passed`.

---

## Architecture

```text
Sources/
├── MyNotchApp/
│   └── main.swift                 # Thin executable entrypoint booting NotchAppDelegate
├── MediaRemoteBridge/             # MediaRemote bridge support
└── NotchKit/
    ├── App/                       # NotchAppDelegate, AppCoordinator (DI root), StatusBarController
    ├── Geometry/                  # ScreenGeometry, IslandLayout (pure layout math)
    ├── Services/                  # EventBus, BuildIntelligence, AgentInbox, ChangeImpact,
    │                              # CIWatchtower, DatabaseIntelligence, SecurityWatcher,
    │                              # EnvironmentGuard, ReleaseReadiness, DevServers, Git, etc.
    ├── State/                     # Toast, NotchState, NotchReducer, NotchStore
    ├── Views/                     # Pure SwiftUI views (NotchRootView, ToastView, LockScreenView)
    └── Window/                    # NotchPanel, NotchWindowController (global hover & hit-testing)
Tests/
└── NotchKitTests/                 # Swift Testing suites (142 tests across 45 suites)
scripts/
└── bundle.sh                      # Release build + ad-hoc/local codesign for build/MyNotchApp.app
```

---

## Build, Test & Run

Requirements: **macOS 14+**, **Xcode / Swift 6** (`swift build`, `swift test`).

```bash
# Build debug target (Swift 6 strict concurrency, 0 warnings)
swift build

# Run full test suite (Swift Testing)
swift test

# Run directly from CLI
swift run MyNotchApp

# Build & sign release .app bundle into build/MyNotchApp.app
./scripts/bundle.sh
```

---

## Design Principles

- **Deterministic First, AI Second:** Parsers, impact rules, env key diffing, and readiness gates are pure deterministic Swift functions; AI is only invoked for optional error explanation and quick queries.
- **Zero Fake Data:** Modules hide cleanly when their backing source (repo, `.env.example`, Docker, migrations, CI) is unavailable.
- **Strict Concurrency:** Warning-free under Swift 6 strict concurrency (`Sendable` state, `@MainActor` store).

