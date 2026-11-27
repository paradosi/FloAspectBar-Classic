-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------
-- Settings panel (Esc > Options > AddOns > FloAspectBar), minimap button and
-- addon compartment entry (WoW Forever). Not upstream code (added in 1.3.0).
--
-- Every control is a proxy setting: it reads the live options and writes
-- through the same functions the slash commands and the bar menu use, so the
-- three can never disagree. Anything that moves, scales or rebuilds the bar
-- touches secure buttons and is refused in combat.
-------------------------------------------------------------------------------

local category;
local minimapButton;

-- Both from the TOC, so `wowdev bump` keeps the version current here.
local VERSION = C_AddOns.GetAddOnMetadata("FloAspectBar", "Version") or "?";
local WEBSITE = C_AddOns.GetAddOnMetadata("FloAspectBar", "X-Website");

-- Addons can't open a browser, so the support link is shown selected in an
-- edit box for Ctrl+C. Typing in the box puts the link back.
StaticPopupDialogs["FLOASPECTBAR_SUPPORT_LINK"] = {
	text = "FloAspectBar on GitHub: report a problem or ask a question.\nPress Ctrl+C to copy the link.",
	button1 = CLOSE,
	hasEditBox = true,
	editBoxWidth = 340,
	OnShow = function(dialog, url)
		local editBox = dialog:GetEditBox();
		editBox:SetText(url);
		editBox:HighlightText();
		editBox:SetFocus();
	end,
	EditBoxOnTextChanged = function(editBox, url)
		if editBox:GetText() ~= url then
			editBox:SetText(url);
			editBox:HighlightText();
		end
	end,
	EditBoxOnEnterPressed = function(editBox) editBox:GetParent():Hide(); end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
};

function FloAspectBar_ShowSupportLink()
	if WEBSITE then
		StaticPopup_Show("FLOASPECTBAR_SUPPORT_LINK", nil, nil, WEBSITE);
	end
end

local MINIMAP_DEFAULT_ANGLE = 200;
local ICON = "Interface\\AddOns\\FloAspectBar\\media\\textures\\troll_hunter_64";

local function Say(msg)
	DEFAULT_CHAT_FRAME:AddMessage("FloAspectBar: "..msg);
end

local function NotInCombat()
	if InCombatLockdown() then
		Say(ERR_NOT_IN_COMBAT or "You can't do that while in combat");
		return false;
	end
	return true;
end

-- Open the Settings panel on our page, or close it if it is already open
function FloAspectBar_OpenOptions()

	CloseDropDownMenus();
	if not category then
		-- the addon only sets itself up for hunters
		Say("there is nothing to set up on this character.");
		return;
	end
	if SettingsPanel and SettingsPanel:IsShown() then
		HideUIPanel(SettingsPanel);
	else
		Settings.OpenToCategory(category:GetID());
	end
end

-- Unlocked shows the borders and lets the bar be dragged
function FloAspectBar_ToggleLock()

	if not FloAspectBar.settings then
		return;
	end
	local mode = (FloAspectBar.settings.position == "unlock") and "lock" or "unlock";
	FloAspectBar_SetPosition(nil, FloAspectBar, mode);
end

-- Minimap button, and the TOC's AddonCompartmentFunc (addonName, mouseButton)
function FloAspectBar_OnMinimapClick(_, mouseButton)

	if mouseButton == "RightButton" then
		FloAspectBar_ToggleLock();
	else
		FloAspectBar_OpenOptions();
	end
end

local function MinimapTooltip(tooltip)

	local unlocked = FloAspectBar.settings and FloAspectBar.settings.position == "unlock";
	tooltip:AddLine("FloAspectBar");
	tooltip:AddLine("Left-click: settings", 1, 1, 1);
	tooltip:AddLine(unlocked and "Right-click: lock the bar" or "Right-click: unlock the bar to move it", 1, 1, 1);
	tooltip:AddLine("Drag: move this button", 1, 1, 1);
end

function FloAspectBar_SetMinimapButton(show)

	FLOASPECTBAR_OPTIONS.minimap.hide = (not show) or nil;
	if minimapButton then
		FloLib_UpdateMinimapButton(minimapButton);
	end
end

-- Called once from ADDON_LOADED, after the saved options are in place
function FloAspectBar_InitOptions()

	local bar = FloAspectBar;

	-- Minimap button. Its settings are per character but not per talent group.
	FLOASPECTBAR_OPTIONS.minimap = FLOASPECTBAR_OPTIONS.minimap or { angle = MINIMAP_DEFAULT_ANGLE };
	if not minimapButton then
		minimapButton = FloLib_CreateMinimapButton("FloAspectBarMinimapButton", FLOASPECTBAR_OPTIONS.minimap,
			ICON, FloAspectBar_OnMinimapClick, MinimapTooltip);
	end

	if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then
		return;
	end
	local layout;
	category, layout = Settings.RegisterVerticalLayoutCategory("FloAspectBar");

	-- Setting names are global to the Settings registry: keep the prefix
	local function Proxy(key, varType, name, default, get, set)
		return Settings.RegisterProxySetting(category, "FloAspectBar_"..key, varType, name, default, get, set);
	end
	local function Header(text)
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text));
	end

	---- Bar

	Header("Bar");

	local function PositionChoices()
		local list = Settings.CreateControlTextContainer();
		list:Add("auto", FLOLIB_POSITIONS.auto);
		list:Add("lock", FLOLIB_POSITIONS.lock);
		list:Add("unlock", FLOLIB_POSITIONS.unlock);
		return list:GetData();
	end
	Settings.CreateDropdown(category, Proxy("position", "string", FLOLIB_POSITION, "auto",
			function() return bar.settings.position; end,
			function(value) FloAspectBar_SetPosition(nil, bar, value); end),
		PositionChoices,
		"Automatic places the bar above your action bars. Unlocked shows its border so you can drag it; Locked keeps it where you left it.");

	local scaleOptions = Settings.CreateSliderOptions(0.5, 2, 0.05);
	scaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return string.format("%d%%", math.floor(value * 100 + 0.5));
	end);
	Settings.CreateSlider(category, Proxy("scale", "number", "Scale", 1,
			function() return bar.globalSettings.scale; end,
			function(value) if NotInCombat() then FloAspectBar_SetScale(value); end end),
		scaleOptions, "Size of the bar.");

	Settings.CreateCheckbox(category, Proxy("borders", "boolean", FLOLIB_SHOWBORDERS, true,
			function() return bar.globalSettings.borders and true or false; end,
			function(value) FloAspectBar_SetBorders(nil, value); end),
		"Draw a border and background behind the bar. An unlocked bar always shows one.");

	Settings.CreateCheckbox(category, Proxy("minimap", "boolean", "Show minimap button", true,
			function() return not FLOASPECTBAR_OPTIONS.minimap.hide; end,
			function(value) FloAspectBar_SetMinimapButton(value); end),
		"Left-click the button for these settings, right-click to lock or unlock the bar, drag it to move it around the minimap. /fab minimap also turns it on and off.");

	---- Aspects: the same switches as Spells in the bar's right-click menu

	Header("Aspects");

	for i, spell in ipairs(bar.availableSpells) do
		local name = spell.name or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell.id)) or ("Spell "..spell.id);
		Settings.CreateCheckbox(category, Proxy("spell"..spell.id, "boolean", name, true,
				function() return not bar.settings.hiddenSpells[i]; end,
				function(value)
					local shown = not bar.settings.hiddenSpells[i];
					if shown ~= value and NotInCombat() then
						FloLib_ToggleSpell(nil, bar, i);
					end
				end),
			"Show this aspect on the bar. Aspects you have not learned yet appear once you learn them.");
	end

	---- Reset

	Header("Reset");
	layout:AddInitializer(CreateSettingsButtonInitializer("Reset all settings", "Reset", function()
		FloLib_ResetAddon("FloAspectBar");
	end, "Put every FloAspectBar setting back to its default. The interface reloads.", true));

	---- About

	Header("Version "..VERSION);
	if WEBSITE then
		layout:AddInitializer(CreateSettingsButtonInitializer("Help and bug reports", "GitHub link",
			FloAspectBar_ShowSupportLink,
			"Show the link to the addon's GitHub page, where you can report a problem or ask a question.", true));
	end

	Settings.RegisterAddOnCategory(category);
end
