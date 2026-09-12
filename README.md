# Seedex

**Seedex** is a standalone Android torrent client focused on responsible seeding. It combines a real libtorrent engine with a private contribution portfolio, per-torrent ratio targets, custom upload goals, source attribution, optional Telegram control, and a polished Apple-inspired Flutter interface.

> Seedex is intended only for content you have the legal right to download and distribute. A BitTorrent swarm exposes participants' IP addresses to peers.

## Highlights

- Add magnet links and `.torrent` files from the app or Android share sheet.
- Choose **Download & seed** or **I already have the files** for every torrent.
- Download and seed through native libtorrent 2.x bindings.
- Hash-check an existing content folder and seed only after verification reaches 100%.
- Keep active transfers in an Android foreground service with an ongoing notification.
- Track payload upload, weighted lifetime ratio, 1:1 progress, peers, seeds, and seeding time.
- Create goals such as “Seed 1 TB,” “Reach a 2.0 ratio,” or “Share back on 20 torrents.”
- Attribute exact source pages when Android shares them and label tracker-only attribution as inferred.
- Enforce Wi-Fi-only/cellular preferences and global speed limits.
- Optionally control Seedex through a private Telegram bot using long polling.
- Store app state and activity locally—no account, custom backend, Firebase, analytics, or hosted database.
- Support light and dark themes with an accessible Cupertino-inspired design.

## Torrent data is required

A magnet link or `.torrent` file contains metadata; it is not the content being seeded. Seedex offers two explicit start modes:

1. **Download & seed** — Seedex downloads the payload, can upload verified pieces while downloading, and becomes a complete seeder at 100%.
2. **I already have the files** — select the exact folder containing the torrent's files. Seedex rechecks every piece and keeps the torrent from downloading missing data. It starts seeding only after the existing payload verifies to 100%.

For `.torrent` imports, Seedex reads the declared payload size before starting when the metadata is valid. A magnet's size is unknown until its metadata arrives.

## Telegram integration

Telegram is an optional control and notification plane. The Android phone remains the full BitTorrent peer: it stores or downloads the payload and communicates directly with trackers and peers. Telegram does not seed the files, provide a hosted Seedex server, bypass NAT, or override Android background limits.

Seedex uses the official Telegram Bot API with `getUpdates` long polling, so no webhook server or custom hosted database is needed. Configure your own bot token and one approved chat ID in **Settings → Telegram**. Credentials are stored with Android encrypted storage and Android backup is disabled for the app. Tokens are never written to Seedex's normal preferences or repository.

Supported commands from the approved chat only:

- `/status`
- `/add <magnet>`
- `/pauseall`
- `/resumeall`
- `/help`

The bot can also notify the approved chat when a torrent begins seeding or a portfolio goal completes. Messages from every other chat ID are ignored. Telegram cloud remains an external service, and remote control works only while Android permits Seedex's foreground service to run.

## Screens

- **Torrents:** live transfer card, filters, status, source, ratio, and torrent controls.
- **Portfolio:** weighted ratio, lifetime data, custom goals, completed milestones, and source totals.
- **Activity:** local speed history and transfer statistics.
- **Settings:** network policy, limits, download directory, Telegram, sharing behavior, and appearance.
- **Torrent details:** transfer health, 1:1 progress, source confidence, trackers, recheck, and safe removal.

## Architecture

```text
Flutter presentation + local controller
              │ foreground-task messages
              ▼
Android dataSync foreground isolate ── HTTPS long polling ── Telegram Bot API
              │ Dart FFI
              ▼
libtorrent_flutter → libtorrent 2.x
              │
              ├── app-private JSON state
              ├── engine upload/session ledger
              ├── encrypted Telegram credentials
              ├── persisted .torrent metadata
              └── downloaded or user-selected existing payload files
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
dart format --output=none lib test
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

Generated APKs are placed in `build/app/outputs/flutter-apk/`.

## GitHub Actions

Every push to `main` and every pull request runs formatting, analysis, tests, and a release APK build. Version tags such as `v0.2.0` also build an Android App Bundle.

The checked-in release configuration uses Android's debug signing key so CI artifacts can be installed for testing. Before distributing a production release, configure a private release keystore and never commit it or its passwords.

## Android and networking limitations

Seedex uses a declared `dataSync` foreground service and a persistent notification. Closing the Flutter activity can leave the transfer service active, but:

- Force Stop always terminates transfers and Telegram polling.
- Device vendors may impose additional battery restrictions.
- Apps targeting Android 15+ receive a total of six hours of `dataSync` foreground-service runtime per 24 hours; bringing the app to the foreground resets that allowance.
- Android does not guarantee automatic restart after reboot for this service type.
- “Unlimited” removes Seedex's own speed cap; peers, routing, storage, thermals, the carrier, and Android still control actual throughput.
- The phone can accept incoming peer traffic only when its route, NAT, IPv6, UPnP/NAT-PMP, and carrier permit it. Outgoing peer connections can still upload.
- Normal Android routing does not combine Wi-Fi and cellular into one faster BitTorrent route.

Seedex does not try to evade platform restrictions.

## Source attribution

A magnet link normally does not contain its original web page. Seedex therefore uses explicit confidence labels:

- **Exact:** a page URL was shared with the magnet.
- **Manual:** the user supplied a page or domain.
- **Tracker:** inferred from `announce` metadata and not claimed as the source website.
- **Unknown:** the original website cannot be determined.

Seedex does not query public info-hash search services or scrape torrent indexes.

## Privacy

- No hosted database or user profile.
- No magnet, info-hash, filename, tracker, or source analytics.
- No automatic remote tracker-list fetches.
- Activity history is retained locally and bounded.
- Telegram is disabled until the user supplies a bot and approved chat.
- Telegram secrets use encrypted Android storage and are excluded from Android backup.
- Network traffic goes directly to Telegram when enabled and to trackers and peers required for BitTorrent operation.

## Dependency and license note

`libtorrent_flutter` is distributed under GPL-3.0. Seedex is therefore licensed under GPL-3.0 as well. Review every dependency and its native binary provenance before publishing a signed production build.

## Current engine limitation

The selected Flutter binding does not currently expose libtorrent fast-resume serialization. Seedex persists magnet links and `.torrent` metadata, re-adds them when the foreground engine restarts, and lets libtorrent verify existing files. The UI and upload ledger are persistent, but a very large dataset may take time to recheck after an unclean process stop.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Please do not use real copyrighted torrent identifiers, bot tokens, or chat IDs in bug reports and tests.
