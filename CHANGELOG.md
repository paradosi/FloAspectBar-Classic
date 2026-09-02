# Changelog

All notable changes to FloAspectBar-Classic will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

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
