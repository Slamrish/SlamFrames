# SlamFrames

**SlamFrames 2.0** is a complete custom unit-frame replacement for **OctoWoW**, built for the Vanilla 1.12-style client environment.

It replaces the default Player, Target, and Target-of-Target frames with configurable custom frames while adding modern conveniences such as target aura timers, predictive healing, a custom Ornate cast bar, combat/resting effects, CC alerts, special Rare/Elite/Boss portrait frames, and Light/Dark skins.

## Features

- Custom Player, Target, and Target-of-Target frames
- Independent movement, scale, width, and portrait zoom
- Circular portraits and level medallions
- Configurable health/resource/name/level text
- Independent horizontal name positioning for Player, Friendly targets, normal Enemy targets, and Rare/Elite/Boss targets
- Target buffs and debuffs with multi-row wrapping
- Numeric target aura timers with adjustable size
- Aura-duration refresh reconciliation for refreshed and stacked effects
- Predictive incoming-heal display with HealComm support and local fallback behavior
- Custom **Ornate** player cast bar with spell/item icons, timer, latency display, and flavor text
- Legacy Vanilla/Turtle-style cast pushback handling
- Correct interrupted/failed cast arbitration and cast-state rendering
- Support for channels, bandages, gathering, tradeskills, and world-object interactions
- Special two-layer Rare/Elite and Boss portrait decorations with clean portrait masking
- Automatic target classification for special portrait frames
- Optional mirrored Rare/Elite or Boss decoration on the Player frame
- Light and Dark special-frame artwork matched to the active SlamFrames skin
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

   `Interface\\AddOns\\`

4. The final path should be:

   `Interface\\AddOns\\SlamFrames\\SlamFrames.toc`

5. Launch OctoWoW.
6. Open settings with the minimap button or:

   `/sf settings`

## Updating

Replace the existing `SlamFrames` addon folder with the new release.

Existing SavedVariables are preserved during normal updates. SlamFrames 2.0 adds new settings without requiring an existing profile reset.

## SlamFrames 2.0 Highlights

### Special Rare / Elite / Boss Frames

Rare/Elite and Boss targets can now receive dedicated dragon portrait decorations. The artwork uses a two-layer system so the portrait remains cleanly masked inside the circular opening. The optional Player version is automatically mirrored so the dragon faces inward toward the Player bars.

The Special Portrait Frames settings include separate horizontal name-position sliders for:

- Player
- Friendly targets
- Normal Enemy targets
- Rare / Elite / Boss targets

Each slider ranges from `-150` to `+150` in 5-pixel steps and is saved independently.

### Predictive Healing

SlamFrames can display incoming healing directly on supported unit frames. HealComm is supported when available, with local prediction behavior used where appropriate.

### Ornate Cast Bar

The new Ornate cast bar includes improved cast timing, latency visualization, spell/item icons, profession/world-interaction flavor text, channel handling, legacy pushback support, and safer interrupt/failure arbitration.

### Aura Refresh Handling

Aura timing now reconciles server-side duration refreshes exposed by Nampower, allowing refreshed effects to reset their timers instead of becoming icon-only after the original duration expires.

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
/sf specialtarget on
/sf specialtarget off
/sf specialplayer on
/sf specialplayer off
/sf specialstyle rare
/sf specialstyle boss
```

Most configuration is available directly through the in-game settings panel.

## Current Stable Release

**SlamFrames 2.0**

## Credits

SlamFrames was built for the OctoWoW community. Development also benefited from studying established Vanilla UI projects and compatibility layers including pfUI / Shagu-style implementations, SuperWoW, Nampower, HealComm-compatible healing communication, and DragonflightUI-Reforged's Vanilla/Turtle cast-timing behavior.
