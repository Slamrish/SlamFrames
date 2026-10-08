# SlamFrames 3.3

**Custom unit frames for OctoWoW and compatible Vanilla / WoW 1.12-style clients.**

SlamFrames provides Player, Target, Target-of-Target, Pet, Focus, Party and Raid frames in matching Light and Dark themes, with configurable layouts and high-resolution artwork.

## What's new in 3.3

- **Rogue and Druid combo trackers:** five-point Player tracker with normal, Rare/Elite and Boss appearance variants; separate Target portrait arc, each with individual enable and size controls. Dark/Light themes preserve their distinct materials and socket layouts.
- **Improved Focus Frame:** matched Light and Dark health-fill behavior, smooth depletion and a dark empty-health backing.
- **Click-casting defaults:** new characters start with no spell/item bindings. All Left, Right and Middle Click assignments are Normal until configured; existing character assignments remain intact. `/sf clickreset` clears one character's click-cast bindings.
- **Cleaner world-object casts:** legacy target-dependent interaction sentences are replaced by readable action text such as `Using`, while common professions retain their names.
- **Refined settings:** dedicated Target combo controls and clearer Player X/Y offset labels.
- **Cast bar choice:** V1 and Ornate, with no third cast-bar skin.

## Other features

- Movable, independently sized Player, Target, Target-of-Target, Pet and Focus frames
- Party and Raid frames, including Compact Raid layouts and 5/10/15/20/40-player groups
- Click casting for spells and usable items with Shift, Ctrl and Alt modifiers
- Incoming-heal prediction and HealComm-compatible integration
- Class-color text, Main Tank indicators, Raid debuff notifications and party resources
- Configurable buffs/debuffs and numeric aura durations
- Rare/Elite/Boss frame artwork, combat highlights, CC indicators and resting effect
- Adjustable cast bar timers, icon, latency zone, casting/channel support and interruption reporting
- Light and Dark art with dedicated 1080p and 4K texture options
- Per-character settings and in-game **Test Frames** preview mode

## Install

1. Exit World of Warcraft completely.
2. Extract `SlamFrames-3.3.zip`.
3. Copy the **SlamFrames** folder into your game's `Interface\AddOns` directory.
4. Confirm this exact file exists:

   ```text
   World of Warcraft\Interface\AddOns\SlamFrames\SlamFrames.toc
   ```

5. Start the game and enable SlamFrames in the AddOns list (if necessary).
6. Type `/sf settings` to configure it. Set your artwork resolution to **1080**, **4K**, or **4K Compatible** as appropriate, then `/reload` when changing art modes.

The archive includes all necessary SlamFrames code and textures; it **does not require an earlier SlamFrames installation**. SuperWoW, Nampower and HealComm-compatible integrations are used where supported by your client; they are not bundled.

### Upgrading

Delete or move your **old `Interface\AddOns\SlamFrames` folder** first, then copy in the new one. **Do not merge the folders**, as leftover files may cause problems. Your existing game SavedVariables are stored separately from the addon folder and should be preserved; backing up your WTF folder is still recommended.

### Useful commands

| Command | Action |
|---|---|
| `/sf settings` | Open SlamFrames settings |
| `/sf lock` / `/sf unlock` | Lock or unlock frame positioning |
| `/sf focus` | Focus current target |
| `/sf clearfocus` | Clear the Focus Frame |
| `/sf clickreset` | Reset click-cast bindings for the current character |
| `/sf partypower on` / `/sf partypower off` | Toggle Party resource bars |

## Compatibility

Built for **OctoWoW / Vanilla 1.12-style clients**. This is not a Retail or modern Classic addon. Some advanced capabilities require compatible client extensions.

## Source

https://github.com/Slamrish/SlamFrames

**SlamFrames 3.3**
