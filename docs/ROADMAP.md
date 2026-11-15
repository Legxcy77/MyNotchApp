# Roadmap

Each item has a **Gate**. An item is done only when its Gate passes. Do items in order unless noted.
Legend: `[x]` done · `[ ]` todo · (U) unit-tested · (V) verified by eye on a real machine

## Foundation
- [x] **F1** Split into `MyNotchApp` (exe) + `NotchKit` (lib) + `NotchKitTests`. Gate: `swift build` + `swift test` green.
- [x] **F2** `ScreenGeometry`: notch rect from safeAreaInsets + auxiliaryTopLeft/Right, floating fallback. Prefer the built-in notch screen. Gate: (U) notch / no-notch / degenerate cases. (V) collapsed island exactly covers the notch.
- [x] **F3** Hit-testing via a global mouse monitor that toggles `ignoresMouseEvents`. Menu bar item with show/hide, display picker, debug toasts, quit. Gate: (V) you can click through transparent panel areas and there is no Dock icon.
- [x] **F4** `NotchReducer` + `NotchStore` with a toast queue (priority, key-update, stale-expiry guard) and hover-exit debounce. Gate: (U) reducer tests.
- [x] **F5** `scripts/bundle.sh` → `build/MyNotchApp.app` (Info.plist: LSUIElement, NSAppleEventsUsageDescription, NSCameraUsageDescription, NSCalendarsFullAccessUsageDescription), ad-hoc codesign, `SMAppService.mainApp` launch-at-login toggle in the menu. Gate: (V) open from Finder, no Dock icon, survives reboot.

## Core: Event Bus (most features build on this)
- [x] **E1** `NWListener` HTTP/1.1 on 127.0.0.1:7777 (port configurable). Token in `~/.mynotch/token` (0600) is required as `Authorization: Bearer`. Endpoints:
  - `POST /toast {title, subtitle?, symbol?, tint?, priority?, ttl?, key?}`
  - `POST /progress {key, title, value 0..1, subtitle?}` (key-updated toast, auto-dismissed at 1.0)
  - `POST /activity {source, session, state: working|waiting|done|failed, title?, cwd?}` (feeds Agent Inbox)
  - `GET /health`
  Also ship `scripts/notch` (a tiny zsh CLI wrapping curl, e.g. `notch toast "Deployed" --tint ok`).
  Gate: (U) request parser + auth. (V) curl shows a toast, a wrong token returns 401.

## Tier S: dev cockpit (daily use)
- [x] **S1 Terminal Finished**: `scripts/notch.zsh` with preexec/precmd hooks. Posts when a command runs ≥10s **and** the terminal is not frontmost. Shows cmd, duration, exit code, green/red. Clicking it activates the originating terminal app (TERM_PROGRAM → bundle id). Gate: (V) `sleep 12; false` from another app shows a red toast with 12s.
- [x] **S2 Agent Inbox**: hook configs for Claude Code (`hooks` Stop/Notification), Codex, and Antigravity → `/activity`. The island shows a persistent mini indicator in the ears while any agent is `working` (spinner, count). `waiting` gets a high-priority orange toast. Expanded view lists sessions with cwd basename and elapsed time. Gate: (V) run an agent task and watch working → waiting → done.
- [x] **S3 Dev Server Radar**: `lsof -iTCP -sTCP:LISTEN -nP -F pcn` every 5s, only while expanded or when the menu is open. Map known ports and process names (node/vite/next/dotnet/python). Actions: open in browser, copy URL, kill (SIGTERM, then SIGKILL after 3s). Gate: (U) lsof parser. (V) `npx serve` appears and kill works.
- [x] **T1 File Tray**: `.onDrop` onto the island (drag over → `fileDrop` mode), stage URLs (keep the reference, don't copy), `.onDrag` out, clear button. Gate: (V) Finder → tray → Slack/VS Code.
- [ ] **S5 Screenshot Shelf**: watch the screenshot dir (`defaults read com.apple.screencapture location`, fallback ~/Desktop) with DispatchSource. New shot → thumbnail toast → goes to the tray. Gate: (V) ⌘⇧4 shows in the tray within 1s.
- [ ] **S4 Clipboard History**: changeCount poll at 0.5s (no public event exists). Keep the last 50 items, text + images. Skip items from password managers (`org.nspasteboard.ConcealedType`). Global hotkey ⌥⌘V (Carbon RegisterEventHotKey) opens a searchable list in the island. Enter pastes (needs Accessibility to synthesize ⌘V). Gate: (U) store/dedupe. (V) paste an older item.

## Tier D: extra dev features (owner approved "all")
- [ ] **D1 Error Lens**: `n <cmd>` wrapper (in notch.zsh) tees stderr and, on failure, sends the last 30 lines. The failure toast expands to a monospaced error panel with **Copy** and **Ask AI** (sends to A6). Gate: (V) `n npx tsc` with an error shows the error lines.
- [ ] **D2 Smart Clipboard**: detect JWT / JSON / Unix epoch / base64 / UUID / hex color / URL-encoded text in the latest copy. Offer one-click actions (decode JWT header+payload, pretty-print JSON, epoch→local time, color swatch). Gate: (U) detectors with fixtures.
- [ ] **D3 Git Glance**: for the frontmost terminal/editor cwd (from S1/S2 reports or the last `/activity` cwd), show branch, dirty count, and ahead/behind. Use FSEvents on `.git/HEAD` + index, no polling. Gate: (V) edit a file and the count updates.
- [ ] **D4 Log Pin**: pin a file path or a command (`docker logs -f api`). Regex rules (default `ERROR|Exception|FATAL`) flash a red toast with the matching line. Gate: (V) `echo ERROR >> pinned.log` flashes.
- [ ] **D5 Command Palette**: hotkey ⌥Space opens a fuzzy list of package.json scripts / Makefile targets / `dotnet` tasks for the last active repo. Run in background; the result goes to S1-style toasts. Gate: (V) run `npm test` from the palette.
- [ ] **D6 Run Timeline**: history of the last 30 commands/agent runs with duration, exit status, and cwd, in an expanded tab. Gate: (V).
- [ ] **D7 Haptic + sound polish**: trackpad haptic (`NSHapticFeedbackManager`) on high-priority toasts, optional subtle sound per tint. Gate: (V).

## Media
- [ ] **M1** `LRCParser` (pure). Gate: (U) multi-timestamp lines, offsets, metadata, blank lines, binary-search current line.
- [ ] **M2** `LRCLibClient` (`GET https://lrclib.net/api/get?artist_name=&track_name=&album_name=&duration=`) + `actor LyricsCache` (memory + `~/Library/Caches/MyNotchApp/lyrics/*.json`). Gate: (U) via a URLProtocol mock: 200/404/timeout, the second hit comes from cache.
- [ ] **M3** NowPlaying: Spotify (`com.spotify.client.PlaybackStateChanged`) + Music (`com.apple.Music.playerInfo`) DistributedNotifications. AppleScript for artwork/position/controls. Optional `MediaRemoteAdapterProvider` behind a protocol. Position = anchor + elapsed in `TimelineView`. Gate: (V) play/pause/skip are reflected within 300ms.
- [ ] **M4** Compact media in the ears (artwork left, live bars right) and expanded media with lyrics, current line bright, neighbors dimmed, auto-scroll. Gate: (V).

## Tier A
- [ ] **A1 Meeting Countdown**: EventKit, next event with a Meet/Zoom/Teams URL. At T-5min a persistent ear countdown with a Join button. Gate: (V).
- [ ] **A2 Camera Mirror**: an expanded tab with an AVCaptureSession preview clipped to the island shape. The session only runs while visible. Gate: (V) the camera light turns off when collapsed.
- [ ] **A3 Focus Ring**: Pomodoro drawn as a progress stroke around the island outline (`Shape.trim`). Optionally toggle a Focus mode via `shortcuts run "<name>"`. Gate: (V).
- [ ] **A4 GitHub Pulse**: `gh api` every 60s for the owner's open PRs (checks status) + review requests. Toast on state change only. Gate: (V).
- [ ] **A5 System Pulse**: CPU/RAM/net sparkline in the expanded view. Alert when a process is >90% CPU for 30s, with a Kill action. Gate: (V).
- [ ] **A6 Quick AI**: hotkey opens a prompt in the island and streams answers from the Gemini API (key in Keychain). Presets: translate TH↔EN, explain error (from D1), explain regex/clipboard. Gate: (V).

## Tier B
- [ ] **B1 Volume/Brightness HUD** in the island (CGEventTap on media keys, needs Accessibility). Gate: (V).
- [ ] **B2 Phone Web Drop**: `GET /drop` serves an upload page and the menu shows a QR code. Uploads land in the File Tray. LAN only, one-time token. Gate: (V) from an Android phone.
- [ ] **B3 Docker Glance**: containers via `/var/run/docker.sock` with status, restart, and tail logs (reuses D4). Gate: (V).

## Changelog
- 2026-11-15: F1–F4 implemented (NotchKit split, geometry, hit-testing + menu bar, reducer/store with tests). 17/17 tests green, app launches. F2/F3 verified by eye by owner.
- 2026-11-15: F5 implemented (`scripts/bundle.sh` producing ad-hoc signed `build/MyNotchApp.app` with `LSUIElement` + usage descriptions, `LaunchAtLoginService` via `SMAppService.mainApp` wired into menu bar). 17/17 tests green, bundle smoke test alive. **(V) check for Finder launch / reboot persistence pending on the owner's machine.**
- 2026-11-15: E1 implemented (`HTTPRequestParser`, `EventBusRouter`, `TokenStore`, `EventBusServer` on `127.0.0.1:7777`, `scripts/notch` CLI). 27/27 tests green; live `/health`, `/toast`, and 401 auth verified.
- 2026-11-15: S1 implemented (`Toast.Action.activateApp`, `NotchStore.activate`, clickable `ToastView`, `--bundle-id` in `scripts/notch`, `scripts/notch.zsh` preexec/precmd hooks). 28/28 tests green, bundle rebuilt. **(V) check for `sleep 12; false` from another app pending on the owner's machine.**
- 2026-11-15: S2 implemented (`AgentSession`, `NotchReducer` activity state, ear indicator in `CollapsedEarsView`, live session list in `ExpandedView`, Claude/Codex/Antigravity hook configs in `scripts/hooks/`). 32/32 tests green, bundle rebuilt. S1 (V) verified by owner; S2 (V) pending.
- 2026-11-15: S3 implemented (`LsofParser`, `DevServerMonitor` polling 5s only while expanded or menu open, open/copy/kill actions in `ExpandedView` and `StatusBarController`). 34/34 tests green, bundle rebuilt. S2 (V) verified by owner; S3 (V) pending.
- 2026-11-15: T1 implemented (`stagedFiles` in `NotchState`, `.onDrop` → `fileDrop` mode in `NotchRootView`, `StagedFileChip` with Finder icon, `.onDrag` out, and Clear button in `ExpandedView`). 36/36 tests green, bundle rebuilt. S3 (V) verified by owner; T1 (V) pending.
