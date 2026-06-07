# Contributing to Nexus

Nexus is intentionally small: native SwiftUI UI, native Apple Silicon telemetry, and no always-on server.

## Local Setup

```bash
git clone https://github.com/francoeur003/Nexus.git
cd Nexus
open Nexus.xcodeproj
```

Use the `Nexus` scheme in Xcode. The scheme name is kept for build continuity, while the shipped app is `Nexus.app`.

## Key Files

| File | Purpose |
| --- | --- |
| `Nexus/PopoverView.swift` | Main menu-bar panel UI |
| `Nexus/SystemStatsModel.swift` | Sampling, timers, state, Hermes/Codex usage |
| `Nexus/AppDelegate.swift` | Menu-bar icon, popover, settings |
| `Nexus/IOReportWrapper.m` | Native IOReport and HID sampling |
| `Nexus/SMC.c` / `Nexus/SMC.h` | Apple SMC read interface |
| `helper/nexus-helper.m` | Native helper compiled into `nexus-helper` |
| `scripts/build-dmg.sh` | Release DMG builder |

## Pull Requests

Please keep changes focused. A useful PR usually includes:

- What changed and why
- Which Apple Silicon hardware was tested
- Screenshot or screen recording for UI changes
- Notes for sensors that may vary by chip generation

## Design Direction

Nexus should feel compact, readable, and operational. Prefer dense but calm UI, clear Chinese labels, and fast-refresh metrics over decorative screens.

## Release

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

The release workflow builds `Nexus-<version>.dmg`, publishes it to GitHub Releases, and updates `Casks/nexus.rb`.
