# Installing Nexus

Nexus is a native Apple Silicon menu-bar monitor for Hermes Agent and Codex workflows.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon Mac
- Admin approval once if you want full power and temperature sampling

## Recommended Install

Download the newest DMG from [Releases](../../releases/latest), open it, and drag `Nexus.app` into Applications.

If macOS blocks first launch:

1. Open Finder → Applications.
2. Double-click `Nexus.app`.
3. If Gatekeeper blocks it, click Cancel.
4. Open System Settings → Privacy & Security.
5. Click Open Anyway for Nexus.
6. Launch `Nexus.app` again.

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/francoeur003/Nexus/main/install.sh | bash
```

## Homebrew

```bash
brew tap francoeur003/nexus https://github.com/francoeur003/Nexus
brew install --cask nexus
```

## Helper

Nexus ships a tiny native helper named `nexus-helper`. It is copied to:

```text
/Users/Shared/Nexus/nexus-helper
```

The helper samples Apple telemetry through SMC and IOReport, prints sensor data, and exits. It does not keep a background daemon running.

## Uninstall

```bash
osascript -e 'quit app "Nexus"'
sudo rm -rf /Applications/Nexus.app
sudo rm -rf /Users/Shared/Nexus
sudo rm -f /etc/sudoers.d/nexus-helper
rm -f ~/Library/Preferences/com.francoeur003.Nexus.plist
rm -rf ~/Library/Application\ Support/Nexus
rm -rf ~/Library/Caches/com.francoeur003.Nexus
```

## Troubleshooting

- If the menu-bar icon does not appear, launch `Nexus.app` from Applications again.
- If charts are empty at first launch, wait a few seconds for the first sampling window.
- If power or fan data is missing, run `Install.command` from the DMG once.
- If Codex quota is unavailable, make sure Codex Desktop is signed in locally.
