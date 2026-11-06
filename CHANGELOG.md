# Changelog

All notable changes to FloAspectBar-Classic will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.2.4]

### Fixed
- **WoW Forever: Lua errors at login and when casting**, and the bar could stay empty. Forever has no `GetSpellInfo`, `GetSpellCooldown` or `IsUsableSpell`; the bar now uses the newer spell API there.
- **WoW Forever: the bar could not position itself** ("attempt to index global 'MainMenuBar'"). Forever renamed the main action bar; the bar now anchors to it.
- **WoW Forever: dragging a spell from the spellbook onto the bar** now works with the new spellbook.
- Cooldown swirls are skipped instead of erroring when the game hides cooldown values from addons.
- Shared library FloLib updated to 1.49 (same fix in FloTotemBar and FloAspectBar; update both if you use both).

## [1.2.3]

### Added
- **WoW Forever support.**

### Fixed
- **`/fab borders` and `/fab noborders` did nothing useful**: both hid the borders. They now show and hide them as described.
- **Moving or rescaling the bar in combat** (`/fab lock`, `unlock`, `auto`, `scale`, or the right-click Position menu) could cause "Interface action failed because of an AddOn". These now say you can't do that in combat and wait for you to leave it.
- **Dragging a hidden aspect from the spellbook onto the bar caused a Lua error.** It is now ignored.
- **"Lock Action Bars" was ignored**: aspects could be dragged off the bar without Shift. The bar now honours the setting and the pick-up modifier, like Blizzard's action bars.

### Changed
- Removed unused code and translations
- FloLib 1.46 (shared with FloTotemBar): the active-aspect check uses `C_UnitAuras` instead of the deprecated `UnitBuff`; unused glyph and talent helpers removed.

## [1.2.2]

### Changed
- Updated for the current clients (TBC Anniversary 2.5.6 and Classic Era 1.15.9), so the addon no longer shows as out of date
- Release notes on CurseForge and Wago are now this changelog instead of the commit log

## [1.2.1]

### Fixed
- **Tooltips and cooldown/usable state showed rank 1** — `data.lua` stores the rank-1 spell id for each aspect (e.g. 13165 for Aspect of the Hawk, which reaches rank 9 on TBC), and that id was used directly. Tooltips therefore described rank 1 and `IsUsableSpell`/`GetSpellCooldown` reported rank 1 mana cost and state. Ported `FloLib_GetMaxRankId` from FloTotemBar-Classic to resolve the highest rank the player actually knows.
- **Login banner reported the wrong version** — `FloAspectBar.lua` hardcoded `VERSION = "1.1.0"` while the TOC files said 1.2.0, so the addon announced itself as 1.1.0 on load. Now synced, and worth grepping for on every future bump since this string is not read from the TOC.

### Changed
- FloLib bumped to 1.45. `FloLib.lua` is now byte-identical to FloTotemBar-Classic's copy; the two had diverged since that addon's 1.2.2. The XML templates still differ deliberately (`...A` vs `...T` suffixes) so both addons can be loaded together without frame-name collisions.

## [1.2.0]

### Added
- Initial tracked release on GitLab

## [1.1.1]

### Fixed
- TBC Anniversary client compatibility
