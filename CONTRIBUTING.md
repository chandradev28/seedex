# Contributing to Seedex

Thank you for helping improve lawful, privacy-preserving peer-to-peer sharing.

## Development

1. Install Flutter 3.44+, Java 17, and Android SDK 36.
2. Run `flutter pub get`.
3. Run `dart format .`, `flutter analyze`, and `flutter test` before submitting a change.
4. Build an Android release APK when changing dependencies, Gradle, the foreground service, storage, or engine code.

## Pull requests

- Keep changes focused and explain user-visible behavior.
- Add tests for ratio, goal, source parsing, ledger, or persistence changes.
- Include before/after screenshots for visual work.
- Test light/dark appearance and large font scale.
- Never include real copyrighted torrent identifiers, private tracker URLs, credentials, keystores, or downloaded payloads.

## Safety

Seedex must not misrepresent anonymity, bypass Android runtime restrictions, scrape torrent indexes, or weaken the legal-use onboarding. Security reports should follow `SECURITY.md`.
