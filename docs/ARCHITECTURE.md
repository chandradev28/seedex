# Seedex architecture

## Product boundaries

Seedex is Android-only and standalone. It has no Seedex account, custom backend, cloud sync, hosted database, or telemetry. The device is the trust boundary for portfolio and torrent metadata. Optional Telegram integration uses Telegram's external Bot API directly from the phone; it does not introduce a Seedex-hosted service.

The phone is the BitTorrent peer. A magnet or `.torrent` file supplies metadata only. The payload must either be downloaded by Seedex or already exist in a user-selected folder before the phone can seed it.

## Layers

### Presentation

Flutter screens use a small visual system with 4/8/12/16/24/32 spacing, 44+ logical-pixel targets, semantic status text, restrained spring-like transitions, and light/dark palettes. Cupertino symbols and page transitions provide the Apple-like character without pretending to be an iOS application.

The add sheet separates metadata type from start mode:

- **Download & seed:** use the configured download folder.
- **I already have the files:** require an existing-content folder and explain the 100% hash-check gate.

The UI surfaces `Getting metadata`, `Checking files`, `Downloading`, `Files incomplete`, and `Seeding` rather than implying metadata can be seeded by itself.

### App controller

`SeedexController` owns view state and serializes a bounded snapshot through `SharedPreferencesAsync`. It maps engine updates to stable local torrent IDs, records activity every ten seconds, computes weighted portfolio values, bridges Android share intents, and sends goal-completion messages to the foreground task.

Telegram enablement and notification switches live in normal settings. The bot token and approved chat ID never enter the app snapshot.

### Foreground engine

`SeedexTaskHandler` owns `LibtorrentFlutter` inside the foreground task isolate. The UI sends primitive map commands. The task returns primitive snapshots, updates the Android notification, rechecks connectivity policy, and writes an engine ledger every fifteen seconds.

The foreground service is declared as `dataSync`, includes wake/Wi-Fi locks while active, and does not auto-run at boot because current Android versions restrict that behavior.

### Existing-data verification

Every torrent record persists a `TorrentStartMode` and save path. Existing-data records point at the user-selected content folder.

- `.torrent` metadata can be rechecked immediately.
- A magnet first fetches metadata, then enters recheck.
- The engine pauses the torrent around verification.
- A 100% result allows normal seeding.
- An incomplete result remains paused and is reported as `Files incomplete`; resuming or choosing recheck retries verification instead of intentionally downloading missing data.

The native binding's recheck is authoritative. Seedex does not infer a match from filenames or byte counts.

### Telegram control plane

`TelegramCredentialsStore` uses `flutter_secure_storage`. Android application backup is disabled to avoid restoring encrypted values without their keys.

`TelegramBotClient` talks only to `https://api.telegram.org` using the official Bot API:

1. The user creates a bot and enters its token plus one numeric approved chat ID.
2. Seedex calls `getMe` and sends a test message before saving the credentials.
3. The foreground task uses `getUpdates` long polling while remote commands are enabled.
4. The update offset is persisted locally so commands are not replayed after restart.
5. Every non-approved chat ID is ignored without a reply.
6. `/add` accepts only a syntactically valid BitTorrent magnet; Seedex does not search or scrape indexes.
7. Completion markers are stored separately so a torrent does not generate repeated “now seeding” messages across engine restarts.

There is no webhook, listening HTTP server, shared bot, or unauthenticated public endpoint. Telegram cannot improve peer reachability or bypass Android service timeouts.

### Upload ledger

A libtorrent session can restart and report session-local uploaded bytes. Seedex assigns every service run a session ID and stores the maximum payload bytes and seeding seconds observed for every local torrent/session pair. The controller merges only positive deltas, preventing repeated snapshots from double-counting portfolio totals.

### Torrent restoration

The registry stores the original magnet or an app-private copy of the `.torrent` metadata. When the foreground task begins, it re-adds each record using its save path. Paused records are immediately paused. Existing-data records are rechecked again because the binding does not expose fast-resume serialization.

## Source attribution

1. Android `ACTION_SEND` and `ACTION_VIEW` are bridged in `MainActivity`.
2. Shared text is inspected locally for a magnet and a web URL/referrer.
3. Shared `.torrent` content URIs are copied to app-private metadata storage.
4. Magnet tracker parameters and bencoded `.torrent` announce fields are reduced to domains.
5. The model stores both source confidence and tracker domains.
6. Tracker-derived domains are never described as exact source websites.

## Storage

- App state: Android DataStore through `SharedPreferencesAsync`.
- Engine ledger: separate DataStore key for safe cross-isolate reads.
- Telegram update offset and completion markers: local DataStore keys.
- Telegram bot token and approved chat ID: encrypted Android storage.
- `.torrent` metadata: application support directory.
- Payload files: selected download directory or existing-content folder.

No broad all-files permission is requested.

## Network policy

The engine task checks Android connectivity periodically as well as listening for changes. Wi-Fi-only mode accepts Wi-Fi and Ethernet. Cellular mode includes mobile and carrier satellite transports. Connectivity type is only a policy hint; torrent and Telegram operations still handle network failures normally.

## Known constraints

- Android 15+ applies the documented six-hour-per-day timeout to `dataSync` foreground services.
- Force Stop is authoritative and ends Telegram polling too.
- Current native bindings do not expose fast-resume save/load APIs.
- Exact originating sites are only available when the browser/user supplies them.
- Incoming peer reachability depends on NAT, UPnP/NAT-PMP, IPv6, router policy, and carrier CGNAT.
- Wi-Fi and cellular are not aggregated into one connection.
- Telegram is an external cloud dependency when enabled; it is not a payload store or BitTorrent relay.
