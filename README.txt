SlamFrames 3.0

SlamFrames is a custom unit-frame suite for OctoWoW / Vanilla 1.12-style clients. It is designed around SuperWoW/Nampower-compatible environments and is not intended for Retail or modern Classic clients.

#3.0 highlights

- Custom Player, Target, Target-of-Target, Party, and Raid frames.
- Raid layouts for 5/10/15/20/40 players, including 8-across, 4+4, and 2-across group arrangements.
- Compact raid mode for healing-focused layouts, with Light/Dark variants, opacity control, class-colored names, main-tank indication, and configurable debuff glow.
- Click casting for Party/Raid frames, including supported item use.
- Predictive healing with HealComm bridge support plus local fallback prediction.
- Per-character settings profiles with migration from older shared profiles.
- 4K and 1080 artwork modes. The 1080 pack uses Vanilla-compatible power-of-two texture dimensions.
- Light and Dark skins.
- Custom player cast bar with icons, timer, latency region, interruption/failure feedback, channels, bandages, gathering, professions, and world interactions.
- Optional suppression of Blizzard's redundant red error text.
- Target aura timers and Nampower duration-refresh reconciliation.
- Rare/Elite/Boss portrait decorations, combat glow, resting Zzz, CC alerts, test-frame mode, and a scrollable settings UI.

#Fresh installation

1. Close World of Warcraft.
2. Extract the release ZIP.
3. Copy the included SlamFrames folder to Interface\AddOns\.
4. Confirm the final path is Interface\AddOns\SlamFrames\SlamFrames.toc.
5. Launch OctoWoW.
6. Open the settings with /sf settings.

Do not install the repository ZIP from GitHub's automatic Source Code download as your normal addon package. Use the packaged release ZIP.

#Updating

Delete or replace the existing Interface\AddOns\SlamFrames folder with the new release folder. Normal updates preserve SavedVariables.

#Useful diagnostics

- /sf settings — open settings.
- /sf healpredict status — report HealComm/prediction bridge status.
- /sf healpredict test 2000 — visual incoming-heal test.

#Compatibility

- OctoWoW
- WoW 1.12-style API (#Interface: 11200)
- SuperWoW-compatible environments
- Nampower enhancements when available
- HealComm when available

#Release

Current stable release: 3.0.0
