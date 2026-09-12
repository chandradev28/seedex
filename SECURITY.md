# Security policy

## Reporting

Please report vulnerabilities privately through GitHub's security advisory feature for this repository. Do not open a public issue containing an exploit, private tracker URL, magnet identifier, user path, IP address, signing key, Telegram bot token, chat ID, or other credential.

## Scope

High-priority areas include path traversal in torrent metadata, unintended file deletion, content-URI handling, source attribution spoofing, Android intent injection, foreground-service control, Telegram chat authorization, secret storage, long-polling replay behavior, and native dependency supply-chain integrity.

## Telegram secrets

Seedex never needs a shared project bot. Each user supplies their own Bot API token and one approved chat ID inside the app. The token and chat ID are stored through Android encrypted storage, are not included in normal preferences, and must never be committed, logged, pasted into issue reports, or sent to support chat. Android application backup is disabled to avoid invalid encrypted-value restoration.

The foreground task ignores every Telegram message whose chat ID is not an exact match for the approved ID. Remote `/add` accepts only a magnet link and does not scrape indexes or expose an HTTP listener.

## User privacy

BitTorrent is not anonymous. Seedex does not conceal a device's peer IP and must never claim that it does. Users should treat tracker, peer, filename, source, Telegram, and chat data as sensitive. Telegram is an external cloud service whenever the optional integration is enabled.
