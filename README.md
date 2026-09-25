# SlamFrames

**SlamFrames 3.1** is a custom unit, party, and raid frame suite for **OctoWoW**, built for the Vanilla 1.12-style client environment.

It replaces the default Player, Target, and Target-of-Target frames while adding configurable Party Frames, Raid Frames, Compact Raid Frames, click casting, predictive healing, custom cast bars, combat/resting effects, CC alerts, special Rare/Elite/Boss portrait frames, and Light/Dark skins.

## What Changed in 3.1

### Party Frame Performance Overhaul

Party Frames were reworked to avoid expensive full-frame rebuilds during normal combat and group roster changes.

- Health events update only the affected party member.
- Mana, Rage, Energy, and other resource events update only that member's resource bar.
- Aura events update the relevant debuff alert instead of rebuilding portraits, names, levels, and healing data.
- Repeated party-join roster events are coalesced into one refresh path.
- Initial party population is staggered instead of rebuilding all four members at once.
- Circular portrait slices are populated incrementally to reduce the hitch when joining a party.
- Blizzard party-frame suppression is no longer forced repeatedly during the normal UI reconciliation loop.

These changes substantially reduce the combat and party-join stalls that could occur with Party Frames enabled.

### Party Resource Bars

Party Frames can now display a compact resource bar for Mana, Rage, Energy, and Focus.

- Enabled by default on fresh installs.
- Can be toggled from **Settings -> Party -> Resource Bar**.
- Can also be toggled with `/sf partypower on` or `/sf partypower off`.
- Resource traffic is isolated from the expensive Party Frame identity/portrait update path.

### Includes the 3.0.1 / 3.0.2 Hotfixes

- Normal left/right unit-frame behavior and Vanilla-compatible right-click menus.
- Blank factory/reset click-casting spell/item fields.
- Refined Ornate cast-bar Light/Dark artwork.
- Removal of the unwanted Ornate cast-bar internal guide/divider lines.
- Cast Bar settings-page spacing cleanup.

## Major Features

- Custom Player, Target, and Target-of-Target frames
- Party Frames with optional Mana/Rage/Energy/Focus resource bars
- 5/10/15/20/40-player Raid Frames
- Standard and Compact Raid layouts
- Multiple raid group arrangements
- Click casting for spells and usable items
- HealComm-compatible incoming-heal prediction plus local fallback
- Main Tank indicators
- Per-character settings
- 4K and dedicated 1080p artwork modes
- Light and Dark skins
- Custom Classic and Ornate cast bars
- Cast timers, spell/item icons, latency display, pushback, channels, failures, professions, gathering, bandages, and world interactions
- Target aura timers and Nampower refresh reconciliation
- Rare/Elite/Boss portrait decorations
- Combat glow, resting Zzz, CC alerts, minimap launcher, and Test Frames

## Compatibility

SlamFrames is developed specifically for:

- OctoWoW
- Vanilla / WoW 1.12-style APIs
- SuperWoW-compatible environments
- Nampower-enhanced APIs when available

It is **not** intended for Retail WoW or modern Classic clients.

## Fresh Installation

1. Close World of Warcraft.
2. Extract `SlamFrames-v3.1.0.zip`.
3. Place the included `SlamFrames` folder inside `Interface\AddOns\`.
4. Confirm the final path is `Interface\AddOns\SlamFrames\SlamFrames.toc`.
5. Launch OctoWoW and make sure SlamFrames is enabled.
6. Open settings with `/sf settings`.

The release ZIP is complete and does not require files from any previous SlamFrames version.

## Updating

For the cleanest update, delete or move the old `Interface\AddOns\SlamFrames` folder and replace it with the folder from the new ZIP. Do not merge old and new addon folders.

SavedVariables are stored separately, so normal upgrades preserve existing character settings.

## Useful Commands

```text
/sf settings
/sf lock
/sf unlock
/sf partypower on
/sf partypower off
/sf healpredict status
/sf healpredict test 2000
```

## Current Stable Release

**SlamFrames 3.1.0**

## Credits

SlamFrames was built for the OctoWoW community. Development also benefited from studying established Vanilla/Turtle UI projects and compatibility layers, including Dragonflight: Reloaded, pfUI / Shagu-style implementations, SuperWoW, Nampower, HealComm-compatible healing communication, and legacy cast-timing behavior.
