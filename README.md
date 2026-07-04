# ClaudeMeter

A tiny native macOS menu bar app that shows Claude Code token usage at a glance — no app or settings to open.

Reads transcripts directly from `~/.claude/projects/**/*.jsonl` and shows:

- **5-hour limit window** — the rolling window Claude resets on, with a live countdown
- **This week (7-day)** and **Opus this week** usage, each against an adjustable token target
- **Today's** tokens and estimated cost
- Per-model breakdown (Opus / Sonnet / Haiku)
- Menu bar label toggle: tokens, %, or $

The cost shown is an *estimate of equivalent API list price* for the tokens used — useful for comparing which sessions/models are heavier, not an actual bill (Claude subscriptions are flat-rate).

Anthropic doesn't expose your exact plan cap locally, so every limit bar uses a **target you set** (+/- steppers in the panel, persisted). Tune each until it matches where you actually hit that limit.

## Screenshot

<img src="screenshots/claudemeter-popover.png" width="600" alt="ClaudeMeter menu bar icon and popover">

## Download

Grab the latest `ClaudeMeter.dmg` from [Releases](../../releases), or build it yourself below.

## Build & run

```bash
./build.sh                                  # builds build/ClaudeMeter.app
cp -R build/ClaudeMeter.app /Applications/   # install
open /Applications/ClaudeMeter.app
```

Requires Xcode command line tools (`swiftc`). No third-party dependencies.

Enable **Launch at login** from the panel footer, or add it manually via System Settings → General → Login Items.

## Notes

- Compiled with `-target arm64-apple-macos13.0` in `build.sh` — pinning this avoids macOS rejecting the app with `kLSIncompatibleSystemVersionErr` (-10825) when the default toolchain deployment target is newer than the running OS.
- Ad-hoc code signed (`codesign --sign -`) — fine for local use; no Developer ID required.
