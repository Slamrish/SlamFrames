# SlamFrames 3.1

SlamFrames 3.1 is the current stable release for OctoWoW / Vanilla 1.12-style clients.

## Highlights

- Major Party Frame performance overhaul to reduce combat and group-join hitching.
- Party health, aura, and resource traffic now updates only the affected member/subsystem instead of rebuilding all Party Frames.
- Party roster bursts are coalesced and initial Party Frame population is staggered across rendered frames.
- Circular party portraits are populated incrementally to reduce the large one-frame cost when joining a group.
- Added optional Party-only Mana, Rage, Energy, and Focus resource bars.
- Added **Party -> Resource Bar** toggle and `/sf partypower on/off`.
- Preserves the stable 3.0.1 Normal click/right-click menu fix.
- Preserves the 3.0.2 blank click-casting defaults and refined Ornate cast-bar artwork.

## Installation

Use the packaged release asset `SlamFrames-v3.1.0.zip`. Completely replace the existing `Interface\AddOns\SlamFrames` folder rather than merging versions. SavedVariables are stored separately.

The 3.1.0 release ZIP is a complete standalone addon package and does not require any previous SlamFrames installation.

## GitHub Release

Tag: `3.1`  
Release name: `SlamFrames 3.1 — Party Performance & Resource Bars`  
Asset: `SlamFrames-v3.1.0.zip`
