# Seedex

**Seedex** is a standalone Android torrent client focused on responsible seeding. It combines a real libtorrent engine with a private contribution portfolio, per-torrent ratio targets, custom upload goals, source attribution, and a polished Apple-inspired Flutter interface.

> Seedex is intended only for content you have the legal right to download and distribute. A BitTorrent swarm exposes participants' IP addresses to peers.

## Highlights

- Add magnet links and `.torrent` files.
- Download and seed through native libtorrent 2.x bindings.
- Keep active transfers in an Android foreground service with an ongoing notification.
- Track payload upload, weighted lifetime ratio, 1:1 progress, peers, seeds, and seeding time.
- Create goals such as “Seed 1 TB,” “Reach a 2.0 ratio,” or “Share back on 20 torrents.”
- Attribute exact source pages when Android shares them and label tracker-only attribution as inferred.
- Enforce Wi-Fi-only/cellular preferences and global speed limits.
- Store all app state and activity locally—no account, backend, Firebase, analytics, or hosted database.
- Support light and dark themes with an accessible Cupertino-inspired design.

## Screens

- **Torrents:** live transfer card, filters, status, source, ratio, and torrent controls.
- **Portfolio:** weighted ratio, lifetime data, custom goals, completed milestones, and source totals.
- **Activity:** local speed history and transfer statistics.
- **Settings:** network policy, limits, download directory, sharing behavior, and appearance.
- **Torrent details:** transfer health, 1:1 progress, source confidence, trackers, recheck, and safe removal.

## Architecture

```text
Flutter presentation + local controller
              │ foreground-task messages
              ▼
Android dataSync foreground isolate
              │ Dart FFI
              ▼
libtorrent_flutter → libtorrent 2.x
              │
              ├── app-private JSON state
              ├── engine upload/session ledger
              ├── persisted .torrent metadata
              └── user-selected download directory
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for details.

## Requirements

- Flutter 3.44 or newer.
- Dart 3.5 or newer.
- Java 17.
- Android SDK 36.
- Android 7.0 (API 24) or newer.

The first Android build downloads the native binaries used by `libtorrent_flutter`. GitHub Actions has network access and performs this automatically.

## Build locally

```bash
flutter pub get
flutter test
flutter analyze
flutter build apk --release --split-per-abi
```

Generated APKs are placed in `build/app/outputs/flutter-apk/`.

## GitHub Actions

Every push and pull request runs formatting, analysis, tests, and a release APK build. Version tags such as `v0.1.0` also build an Android App Bundle.

The checked-in release configuration uses Android's debug signing key so CI artifacts can be installed for testing. Before distributing a production release, configure a private release keystore and never commit it or its passwords.

## Android background limitations

Seedex uses a declared `dataSync` foreground service and a persistent notification. Closing the Flutter activity can leave the transfer service active, but:

- Force Stop always terminates it.
- Device vendors may impose additional battery restrictions.
- Apps targeting Android 15+ receive a total of six hours of `dataSync` foreground-service runtime per 24 hours; bringing the app to the foreground resets that allowance.
- Android does not guarantee automatic restart after reboot for this service type.
- “Unlimited” removes Seedex's own speed cap; peers, routing, storage, thermals, the carrier, and Android still control actual throughput.

Seedex does not try to evade platform restrictions.

## Source attribution

A magnet link normally does not contain its original web page. Seedex therefore uses explicit confidence labels:

- **Exact:** a page URL was shared with the magnet.
- **Manual:** the user supplied a page or domain.
- **Tracker:** inferred from `announce` metadata and not claimed as the source website.
- **Unknown:** the original website cannot be determined.

Seedex does not query public info-hash search services.

## Privacy

- No hosted database or user profile.
- No magnet, info-hash, filename, tracker, or source analytics.
- No automatic remote tracker-list fetches.
- Activity history is retained locally and bounded.
- Network traffic goes directly to trackers and peers required for BitTorrent operation.

## Dependency and license note

`libtorrent_flutter` is distributed under GPL-3.0. Seedex is therefore licensed under GPL-3.0 as well. Review every dependency and its native binary provenance before publishing a signed production build.

## Current engine limitation

The selected Flutter binding does not currently expose libtorrent fast-resume serialization. Seedex persists magnet links and `.torrent` metadata, re-adds them when the foreground engine restarts, and lets libtorrent verify existing files. The UI and upload ledger are persistent, but a very large dataset may take time to recheck after an unclean process stop.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Please do not use real copyrighted torrent identifiers in bug reports or tests.
