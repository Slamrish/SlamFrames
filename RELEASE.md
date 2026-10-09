# SlamFrames 3.3.1 — Optional HealComm Hotfix

A compatibility fix for users running SlamFrames without **HealComm-1.0** installed.

- Check `AceLibrary:HasInstance()` before requesting optional HealComm-1.0, AceEvent-2.0, RosterLib-2.0 or ItemBonusLib-1.0 libraries.
- Prevent missing-library lookups from repeatedly generating the `Cannot find a library instance of HealComm-1.0` message while the incoming-heal system polls.
- HealComm is **optional**. Other unit frames, click casting, cast bars and combo-point tracking remain functional without it.
- Compatible HealComm addons remain supported for incoming-heal prediction; late-loaded libraries can still be detected.
- Added an in-game tooltip clarification and documented installation/diagnostics in README.md.
- No changes to the approved 3.3 artwork, cast bars, Focus, Pet, or combo-point layouts.

### Installation

Extract `SlamFrames-3.3.1.zip` and copy the included `SlamFrames` folder into `World of Warcraft\Interface\AddOns\`. Remove/replace the previous `SlamFrames` folder rather than merging. SavedVariables remain separate.

### Optional HealComm

The library is not bundled and not needed for ordinary addon use. To enable cooperative incoming-heal prediction, install a compatible Vanilla 1.12 addon that actually provides `HealComm-1.0` through AceLibrary. Run `/sf healpredict status` to check detection.

Source: https://github.com/Slamrish/SlamFrames
