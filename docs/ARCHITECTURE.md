# Seedex architecture

## Product boundaries

Seedex is Android-only and standalone. It has no authentication, backend, cloud sync, remote control, hosted database, or telemetry. The device is the complete trust boundary for portfolio metadata.

## Layers

### Presentation

Flutter screens use a small visual system with 4/8/12/16/24/32 spacing, 44+ logical-pixel targets, semantic status text, restrained spring-like transitions, and light/dark palettes. Cupertino symbols and page transitions provide the Apple-like character without pretending to be an iOS application.

### App controller

`SeedexController` owns view state and serializes a bounded snapshot through `SharedPreferencesAsync`. It maps engine updates to stable local torrent IDs, records activity every ten seconds, and computes weighted portfolio values.

### Foreground engine

`SeedexTaskHandler` owns `LibtorrentFlutter` inside the foreground task isolate. The UI sends primitive map commands. The task returns primitive snapshots, updates the Android notification, rechecks connectivity policy, and writes an engine ledger every fifteen seconds.

The foreground service is declared as `dataSync`, includes wake/Wi-Fi locks while active, and does not auto-run at boot because current Android versions restrict that behavior.

### Upload ledger

A libtorrent session can restart and report session-local uploaded bytes. Seedex assigns every service run a session ID and stores the maximum payload bytes and seeding seconds observed for every local torrent/session pair. The controller merges only positive deltas, preventing repeated snapshots from double-counting portfolio totals.

### Torrent restoration

The registry stores the original magnet or an app-private copy of the `.torrent` metadata. When the foreground task begins, it re-adds each record using its save path. Paused records are immediately paused. Existing files are reused and may be verified by libtorrent.

## Source attribution

1. Android `ACTION_SEND` and `ACTION_VIEW` are bridged in `MainActivity`.
2. Shared text is inspected locally for a magnet and a web URL/referrer.
3. Magnet tracker parameters and bencoded `.torrent` announce fields are reduced to domains.
4. The model stores both source confidence and tracker domains.
5. Tracker-derived domains are never described as exact source websites.

## Storage

- App state: Android DataStore through `SharedPreferencesAsync`.
- Engine ledger: separate DataStore key for safe cross-isolate reads.
- `.torrent` metadata: application support directory.
- Payload files: selected download directory; app-specific external storage by default.

No broad all-files permission is requested.

## Network policy

The engine task checks Android connectivity periodically as well as listening for changes. Wi-Fi-only mode accepts Wi-Fi and Ethernet. Cellular mode includes mobile and carrier satellite transports. Connectivity type is only a policy hint; torrent operations still handle network failures normally.

## Known constraints

- Android 15+ applies the documented six-hour-per-day timeout to `dataSync` foreground services.
- Force Stop is authoritative.
- Current native bindings do not expose fast-resume save/load APIs.
- Exact originating sites are only available when the browser/user supplies them.
- Wi-Fi and cellular are not aggregated into one connection.
