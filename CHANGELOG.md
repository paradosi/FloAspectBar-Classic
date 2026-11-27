# Changelog

All notable changes to FloAspectBar-Classic will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Changed
- New icon, in the same style as the other WoW Forever addons, in the AddOns list, the settings panel and the minimap button
- Renamed FloAspectBar Forever. The AddOns folder is still `FloAspectBar`, so your settings carry over

## [1.5.0] - 2026-11-27

### Changed
- New look for the settings panel, in the same style as the other WoW Forever addons: navy panel, gold accents, two columns. Every setting is still there. Reset all settings now asks for a second click, since it reloads the interface
- The GitHub link opens in a matching window, selected and ready to copy
- TBC spells WoW Forever doesn't have no longer show in the settings or in the bar's Spells menu
- Slightly larger small text in the settings panel

## [1.4.0] - 2026-11-27

### Added
- The settings panel shows the installed version and a button with the GitHub link for help and bug reports

### Changed
- WoW Forever only. 1.3.0 was the last version for Classic Era and TBC Anniversary, and it stays available for download

## [1.3.0] - 2026-11-23

### Added
- **Settings panel** under Esc > Options > AddOns > FloAspectBar: position, scale, borders, the minimap button, and a checkbox for each aspect. `/fab options` opens it, and so does **Options...** in the bar's right-click menu.
- **Minimap button.** Left-click opens the settings, right-click locks or unlocks the bar so you can move it, and dragging moves the button around the minimap. Turn it off in the settings or with `/fab minimap`.
- **WoW Forever: an entry in the addon compartment** (the addon list next to the minimap) that does the same, so the settings are still one click away with the minimap button off.
- Shared library FloLib updated to 1.53 (same change in FloTotemBar and FloAspectBar; update both if you use both).

## [1.2.8] - 2026-11-22

### Fixed
- **The bar could disappear when automatic positioning was on**, most often with an action bar addon (Dominos, Bartender, ElvUI) that hides Blizzard's main bar. The aspect bar now only sits above the main bar when that bar is actually on screen, falls back to the bottom of the screen otherwise, and positions itself again once the game has finished laying out its bars.

### Added
- **`/fab show`** brings back every aspect hidden from the bar's right-click menu. Hiding the last aspect hides the whole bar, and with it the menu, so there was no way back short of `/fab reset`.
- **A chat message when the bar hides itself** because every aspect on it is hidden, saying how to get them back.
- **`/fab status`** prints what is on the bar, what is hidden or not learned yet, and where the bar is (including whether it is off screen). If your bar goes missing, paste its output in your report.

## [1.2.7] - 2026-11-17

### Fixed
- **WoW Forever: a Lua error when dragging a spell off the bar** (Shift-drag, or with action bars unlocked). The spell is now picked up correctly.
- **Masque skinning works again.** The bar looked for Masque before Masque had loaded, so skins were never applied. The aspect bar now has its own Masque group, "FloAspectBar", instead of sharing FloTotemBar's.
- Shared library FloLib updated to 1.52 (same change in FloTotemBar and FloAspectBar; update both if you use both).

## [1.2.6] - 2026-11-15

### Changed
- Shared library FloLib updated to 1.51 (same change in FloTotemBar and FloAspectBar; update both if you use both). Nothing changes in FloAspectBar itself.

## [1.2.5] - 2026-11-10

### Fixed
- **WoW Forever: "Auras cannot be accessed when secret" errors** while auras are hidden from addons in combat. The bar now leaves the active aspect highlighted as it was and catches up once auras are visible again.
- Shared library FloLib updated to 1.50 (same fix in FloTotemBar and FloAspectBar; update both if you use both).

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
