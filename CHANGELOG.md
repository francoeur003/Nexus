# Changelog

## Unreleased

## 2.0.61

- Made Nexus a fully independent macOS app identity with bundle id `com.abo.Nexus`.
- Renamed the shipped executable to `Nexus` and the bundled sensor helper to `nexus-helper`.
- Replaced the app icon and source logo with the new Nexus `N` brand mark.
- Updated internal logging, sampler queues, release packaging, and local deployment scripts to use the Nexus identity.
- This version intentionally requires fresh macOS microphone and screen recording authorization.

## 2.0.60

- Renamed the shipped macOS app bundle and release assets to `Nexus`.
- Kept the existing bundle identifier and stable signing path to preserve local macOS permissions.

## 2.0.59

- Redesigned the Hermes Agent popover around the current compact widget UI.
- Added live pocket WiFi status for SSID, carrier/network type, signal, battery, connected devices, and monthly traffic usage.
- Added click-through WiFi title linking to `https://192.168.0.1`.
- Added four-hour CPU, GPU, charging input, and chip power wave charts with left-side axes.
- Added performance state badges for CPU, GPU, charging, chip, and fan speed while keeping the original chart colors.
- Integrated charging, chip power, energy meter, SSD, fan speed, network speed, battery, and temperature into the system resource panel.
- Added the dual-column Hermes meeting board, transcription controls, translation panel, and screen recording entry.
- Prevented the meeting/recording panel from opening automatically after app updates.
- Added stable local signing deployment and Hermes release packaging scripts.

## 2.x Lineage

Nexus is derived from MIT-licensed Apple Silicon monitoring work and keeps the required copyright notice in `LICENSE`.
