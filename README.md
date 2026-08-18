# Keep Awake

A native macOS menu-bar-only utility (Swift + SwiftUI, zero external dependencies,
macOS 13+) that prevents system or display sleep on demand.

## Features

- Menu-bar only — `LSUIElement` is set, no Dock icon.
- Dynamic status-bar icon reflecting active/idle state and mode.
- On/Off toggle.
- Duration presets: Indefinite, 15m, 30m, 1h, 2h, and a Custom duration window
  with a live countdown shown in the menu.
- Two prevention modes: System Sleep only, or Display + System Sleep.
- Battery safeguard — auto-disables when unplugged and battery drops below 20%,
  with a local notification.
- Launch at Login via `SMAppService` (`ServiceManagement`, macOS 13+ API).
- All preferences persisted (`UserDefaults`, mirrored by `@AppStorage` reads
  in the views and a typed `PreferencesStore`).
- Power management via `IOPMAssertionCreateWithName` (fine-grained
  system-vs-display control) *and* `ProcessInfo.processInfo.beginActivity`
  (redundant, Swift-native activity token) held simultaneously while active.
  Both are released on manual stop, timeout, and app termination / system
  shutdown (`NSApplication.willTerminateNotification`,
  `NSWorkspace.willPowerOffNotification`).

## Project layout

```
KeepAwake/
├── Package.swift                  # SwiftPM manifest, macOS 13 target, zero deps
├── Sources/KeepAwake/
│   ├── KeepAwakeApp.swift         # @main App: MenuBarExtra + Custom Duration Window
│   ├── StatusIconLabel.swift      # Dynamic menu bar glyph
│   ├── MenuContentView.swift      # Menu body: toggle, duration, mode, prefs, quit
│   ├── CustomDurationView.swift   # Stepper window for arbitrary minute counts
│   ├── AppState.swift             # Coordinator: prefs, countdown, battery safeguard
│   ├── PowerManager.swift         # IOPMAssertionCreateWithName + ProcessInfo activity
│   ├── BatteryMonitor.swift       # IOPowerSources polling
│   ├── LoginItemManager.swift     # SMAppService wrapper
│   ├── PreferencesStore.swift     # Typed UserDefaults accessors
│   └── DurationPreset.swift       # Duration enum
├── Resources/
│   ├── Info.plist                 # LSUIElement=true, bundle id one.fede.keepawake
│   └── KeepAwake.entitlements
├── Scripts/build.sh                # swift build -> .app bundle -> codesign -> dmg
└── .github/workflows/build.yml     # macOS CI: runs build.sh, uploads wakeup.dmg
```

## Building locally (on a Mac)

```sh
git clone <this repo>
cd KeepAwake
./Scripts/build.sh
# -> dist/wakeup.dmg
```

Requires Xcode command line tools (`xcode-select --install`). No third-party
dependencies are fetched — `swift build` only needs the platform SDK.

The build is **ad-hoc signed** (`codesign --sign -`), not notarized — no Apple
Developer ID was available in this pipeline. On first launch, either right-click
→ Open, or run:

```sh
xattr -dr com.apple.quarantine "/Applications/Keep Awake.app"
```

## Building via GitHub Actions

Pushing to `main` (or running the workflow manually) builds on `macos-14`
and uploads `wakeup.dmg` as a workflow artifact named `wakeup-dmg`.

## Deployment note

`wakeup.dmg` produced by CI was copied to `/var/www/fede.one/wakeup.dmg`
(mode 644) for public download at `https://fede.one/wakeup.dmg`.
