# ClaudeMeter

A tiny native macOS menu bar app that shows Claude Code token usage at a glance — no app or settings to open.

Reads transcripts directly from `~/.claude/projects/**/*.jsonl` and shows:

- **5-hour limit window** — the rolling window Claude resets on, with a live countdown
- **This week (7-day, all models)** usage against an adjustable token target
- **Context window** — how full the current conversation is versus the model's context limit
- **Usage by model this week** — a collapsible table with a mini progress bar per model, using real model/version names (e.g. "Opus 4.8", "Sonnet 5") pulled straight from the transcript, so you can see which model is eating your weekly budget
- **Today's** tokens and estimated cost
- Menu bar label toggle: tokens, %, or $

Token counts are read directly from the same local log files Claude Code writes (`~/.claude/projects/**/*.jsonl`), deduped by request ID — they are exact, not estimates. The **cost** shown is a modeled *estimate of equivalent API list price* using published per-model rates (including the 1.25x / 2x / 0.1x multipliers for 5-min cache write, 1-hour cache write, and cache read) — useful for comparing which sessions or models are heavier, not an actual bill (Claude subscriptions are flat-rate).

Anthropic doesn't expose your exact plan quota via any local API, so the 5-hour and weekly targets are **calibrated, not guessed**: solved algebraically from a real reading of Claude's own app (e.g. "5h = 79%, weekly = 12%") against the exact token counts ClaudeMeter computed at that same instant. The +/- steppers in the panel let you re-tune either target if your plan changes or the numbers drift. If usage exceeds the target, the percentage is shown uncapped (e.g. 132%) even though the bar itself maxes out visually at 100%.

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
