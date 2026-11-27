-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.

-- notOnForever: TBC spells WoW Forever doesn't have. They stay in these lists
-- because saved buttonsOrder/hiddenSpells index into them by position (removing
-- one would scramble saved bars); the settings panel and the bar menu skip them.
FLO_ASPECT_SPELLS = {
	["HUNTER"] = {
		{ id = 13163 }, -- Aspect of the Monkey
		{ id = 13165 }, -- Aspect of the Hawk
		{ id = 34074, notOnForever = true }, -- Aspect of the Viper (TBC)
		{ id = 5118 },  -- Aspect of the Cheetah
		{ id = 13161 }, -- Aspect of the Beast
		{ id = 13159 }, -- Aspect of the Pack
		{ id = 20043 }, -- Aspect of the Wild
	}
};
