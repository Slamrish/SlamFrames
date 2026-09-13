# SlamFrames

**SlamFrames 1.0.0** is a complete custom unit-frame replacement for **OctoWoW**, built for the Vanilla 1.12-style client environment.

It replaces the default Player, Target, and Target-of-Target frames with configurable custom frames while adding modern conveniences such as target aura timers, a custom cast bar, combat/resting effects, CC alerts, and Light/Dark skins.

## Features

- Custom Player, Target, and Target-of-Target frames
- Independent movement, scale, width, and portrait zoom
- Circular portraits and level medallions
- Configurable health/resource/name/level text
- Target buffs and debuffs with multi-row wrapping
- Numeric target aura timers with adjustable size
- Custom player cast bar with spell/item icons and timing
- Support for channels, interrupted/failed casts, bandages, gathering, tradeskills, and world-object interactions
- Combat portrait glow
- Resting / Inn Zzz effect
- Crowd-control alerts with remaining time
- Optional click-to-self-target
- Light and Dark skins
- Player-portrait minimap launcher
- Built-in Test Frames mode
- Scrollable in-game settings

## Compatibility

SlamFrames is developed specifically for:

- OctoWoW
- Vanilla / WoW 1.12-style APIs
- SuperWoW-compatible environments
- Nampower-enhanced APIs when available

It is **not** intended for Retail WoW or modern Classic clients.

## Installation

1. Download the latest release ZIP.
2. Close World of Warcraft.
3. Extract the `SlamFrames` folder into:

   `Interface\AddOns\`

4. The final path should be:

   `Interface\AddOns\SlamFrames\SlamFrames.toc`

5. Launch OctoWoW.
6. Open settings with the minimap button or:

   `/sf settings`

## Updating

Replace the existing `SlamFrames` addon folder with the new release.

Existing SavedVariables are preserved during normal updates.

## Default Configuration

Version 1.0.0 ships with the author's preferred stable configuration as the fresh-install default, including:

- Dark skin
- 60% unit-frame scale
- Compact frame widths
- Enlarged readable health/resource text
- Target aura timers enabled
- Larger target aura icons
- Tight aura row spacing
- Combat glow
- Resting effects
- CC alerts
- Custom player cast bar

Everything remains configurable in-game.

## Useful Commands

```text
/sf settings
/sf lock
/sf unlock
/sf skin dark
/sf skin light
/sf auratimer on
/sf auratimer off
/sf auratimerscale 1.00
/sf aurarowgap 1
```

Most configuration is available directly through the in-game settings panel.

## Current Stable Release

**SlamFrames 1.0.0**

This is the first stable release and the baseline for future development.

## Credits

SlamFrames was built for the OctoWoW community. Development also benefited from studying established Vanilla UI projects and compatibility layers including pfUI / Shagu-style implementations, SuperWoW, and Nampower.
