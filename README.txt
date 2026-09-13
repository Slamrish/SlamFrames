SlamFrames 1.0.0 - OctoWoW / 1.12-style replacement unit frames

ABOUT
SlamFrames replaces the stock Player, Target and Target-of-Target frames with a
high-resolution, movable and scalable layout designed for OctoWoW / SuperWoW.
Version 1.0 marks the first stable release baseline.

INSTALL
1. Exit WoW.
2. Replace the entire Interface\AddOns\SlamFrames folder with this one.
3. Launch OctoWoW.

IMPORTANT FOR UPGRADES
Existing SlamFrames SavedVariables are preserved. The 1.0 defaults apply to new
installs and when using Reset. Delete/move SlamFrames.lua from SavedVariables
only if you intentionally want a completely fresh profile.

1.0 DEFAULT PROFILE
- Skin: Dark
- Player / Target / ToT scale: 0.60
- Player / Target / ToT bar length: ~90%
- Player portrait zoom: 1.00
- Target portrait zoom: 1.00
- ToT portrait zoom: 1.08
- Main health text: Amount
- ToT health text: Percent
- Name text: 1.30x
- Health text: 1.80x
- Resource text: 1.30x
- Level text: 1.00x
- Target aura size: 1.30x
- Aura row spacing: 1.0
- Aura timer: ON, 100% size
- Combat glow: ON, 130% intensity
- Resting / Inn effect: ON
- CC alerts: ON
- Player cast bar: ON, 0.80 scale, width 360
- Spell icon / timer / latency region: ON
- Blizzard unit frames and Blizzard cast bar: hidden
- Player-frame self-targeting: ON
- Frames locked by default

FEATURES
- Independent Player, Target and Target-of-Target movement and scaling.
- Four safe bar-length presets without stretching portraits/endcaps.
- Independent portrait zoom controls.
- Dark and Light visual skins.
- Health/resource/name/level text controls.
- Target buff/debuff icons with automatic multi-row wrapping.
- Adjustable target-aura row spacing and numeric aura countdown timers.
- Aura timing support built around OctoWoW/SuperWoW/Nampower observation.
- Resting Zzz effect, combat portrait glow, and CC notifications.
- Matching player cast bar with item/world-interaction fallbacks and icon lookup.
- Right-click unit menus while frames are locked.
- Optional left-click self-targeting from the Player frame.
- SlamPlates-style minimap launcher.
- Scrollable settings pages so footer controls remain accessible.

MINIMAP LAUNCHER
- Left-click: open SlamFrames settings.
- Right-click: lock/unlock unit frames.
- Drag: move the launcher around the minimap.

CORE COMMANDS
/sf settings
/sf lock
/sf unlock
/sf reset
/sf reset player
/sf reset target
/sf reset tot
/sf skin dark
/sf skin light
/sf test

FRAME COMMANDS
/sf scale player 0.60
/sf scale target 0.60
/sf scale tot 0.60
/sf width player 1
/sf width target 1
/sf width tot 1
/sf portraitzoom player 1.00
/sf portraitzoom target 1.00
/sf portraitzoom tot 1.08

AURA COMMANDS
/sf aurascale 1.30
/sf aurarowgap 1.0
/sf auratimer on
/sf auratimer off
/sf auratimerscale 1.00
/sf auradiag

CAST BAR COMMANDS
/sf castbar on
/sf castbar off
/sf castbar move
/sf castbar reset
/sf castbar scale 0.80
/sf castbar width 360
/sf castbar cast
/sf castbar channel
/sf castbar interrupt
/sf castbar fail
/sf castbar latency on|off
/sf castbar icon on|off

NOTES
The experimental ornate Style 2 cast-bar artwork remains preserved in Sources /
Textures for future development, but Style 2 is not selectable in the 1.0 UI.
The experimental radial aura Sweep feature is retired in 1.0; the supported aura
time display is the numeric Timer.
