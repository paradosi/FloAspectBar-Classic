-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------
-- Settings panel (Esc > Options > AddOns > FloAspectBar), minimap button and
-- addon compartment entry (WoW Forever). Not upstream code (added in 1.3.0).
--
-- The panel is in wowdb.dev's look (Theme.lua and Widgets.lua, shared with the
-- other Forever addons; 2026-11-27). Every control writes through the same
-- functions the slash commands and the bar menu use, so the three can never
-- disagree, and the panel reads the live options each time it opens. Anything
-- that moves, scales or rebuilds the bar touches secure buttons and is refused
-- in combat; the control then springs back.
-------------------------------------------------------------------------------

local _, ns = ...;
local W = ns.W;

local category;
local minimapButton;

-- Both from the TOC, so `wowdev bump` keeps the version current here.
local VERSION = C_AddOns.GetAddOnMetadata("FloAspectBar", "Version") or "?";
local WEBSITE = C_AddOns.GetAddOnMetadata("FloAspectBar", "X-Website");

-- Addons can't open a browser: the link opens selected, for Ctrl+C
function FloAspectBar_ShowSupportLink()
	if WEBSITE then
		W.CopyDialog("Help and bug reports", WEBSITE);
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

	if category then
		return;
	end

	local panel, host, fit = W.Panel({
		name = "FloAspectBarOptions",
		title = "FloAspectBar",
		sub = "hunter aspects on one bar  ·  originally by Floraline",
		logo = ICON,
		version = VERSION,
	});
	local COL_W = W.COL_W;

	local function ColumnTop(x)
		local f = CreateFrame("Frame", nil, host);
		f:SetSize(1, 1);
		f:SetPoint("TOPLEFT", host, "TOPLEFT", x, -8);
		return f;
	end
	local left, right = ColumnTop(18), ColumnTop(18 + COL_W + 40);
	local Sync;

	---- Left column: the bar

	local barSec = W.Section(host, left, 0, "Bar");
	local position = W.Segment(host, barSec, -12, {
		{ "auto", FLOLIB_POSITIONS.auto }, { "lock", FLOLIB_POSITIONS.lock }, { "unlock", FLOLIB_POSITIONS.unlock },
	}, function(value)
		FloAspectBar_SetPosition(nil, bar, value);
		Sync();
	end);
	local positionNote = W.Note(host, position.first, -6, "auto sits above your action bars; unlocked can be dragged");

	local scale = W.Slider(host, positionNote, -14, "Scale", 50, 200, 5, 5, "%");
	scale.onChange = function(value)
		if NotInCombat() then
			FloAspectBar_SetScale(value / 100);
		end
		Sync();
	end;

	local borders = W.Check(host, scale, -12, FLOLIB_SHOWBORDERS);
	borders.onChange = function(value)
		FloAspectBar_SetBorders(nil, value);
		Sync();
	end;
	local minimap = W.Check(host, borders, -6, "Show minimap button");
	minimap.onChange = function(value)
		FloAspectBar_SetMinimapButton(value);
	end;
	local minimapNote = W.Note(host, minimap, -4, "left-click: settings  ·  right-click: lock or unlock");

	---- Right column: which aspects the bar shows (the bar menu's Spells)

	local aspectsSec = W.Section(host, right, 0, "Aspects");
	local aspectChecks = {};
	local last = aspectsSec;
	for i, spell in ipairs(bar.availableSpells) do
		if not spell.notOnForever then  -- TBC spells (data.lua)
			local name = spell.name or C_Spell.GetSpellName(spell.id) or ("Spell "..spell.id);
			local check = W.Check(host, last, last == aspectsSec and -10 or -6, name);
			check.onChange = function(value)
				local shown = not bar.settings.hiddenSpells[i];
				if shown ~= value and NotInCombat() then
					FloLib_ToggleSpell(nil, bar, i);
				end
				Sync();
			end;
			aspectChecks[i] = check;
			last = check;
		end
	end
	local aspectsNote = W.Note(host, last, -6, "aspects you learn later appear on the bar by themselves");

	---- Footer: reset, help, the slash command

	-- A hairline under whichever column ends lower (measured on show)
	local foot = host:CreateTexture(nil, "BORDER");
	foot:SetColorTexture(1, 1, 1, 0.06);
	foot:SetHeight(1);
	foot:SetWidth(COL_W * 2 + 40);
	local function PlaceFoot()
		local a, b = minimapNote:GetBottom(), aspectsNote:GetBottom();
		local lower = (a and b and a < b) and minimapNote or aspectsNote;
		foot:ClearAllPoints();
		foot:SetPoint("TOP", lower, "BOTTOM", 0, -18);
		foot:SetPoint("LEFT", host, "LEFT", 18, 0);
	end
	PlaceFoot();

	local reset = W.Button(host, "Reset all settings", 150);
	reset:SetPoint("TOPLEFT", foot, "BOTTOMLEFT", 0, -12);
	reset:SetScript("OnClick", function(self)
		-- Two clicks: it wipes every setting and reloads the interface
		if self.armed then
			FloLib_ResetAddon("FloAspectBar");
			return;
		end
		self.armed = true;
		self:SetLabel("Click again to reset");
		C_Timer.After(3, function()
			self.armed = nil;
			self:SetLabel("Reset all settings");
		end);
	end);

	local help = W.Button(host, "Help and bug reports", 170);
	help:SetPoint("LEFT", reset, "RIGHT", 10, 0);
	help:SetScript("OnClick", FloAspectBar_ShowSupportLink);
	help:SetShown(WEBSITE ~= nil);

	local hint = W.Note(host, reset, -10, "/fab for commands  ·  right-click the bar for its menu", COL_W * 2 + 40);

	Sync = function()
		position:Set(bar.settings.position);
		scale:SetValue(math.floor(bar.globalSettings.scale * 100 + 0.5));
		borders:SetChecked(bar.globalSettings.borders);
		minimap:SetChecked(not FLOASPECTBAR_OPTIONS.minimap.hide);
		for i, check in pairs(aspectChecks) do
			check:SetChecked(not bar.settings.hiddenSpells[i]);
		end
	end;
	panel:SetScript("OnShow", function()
		Sync();
		PlaceFoot();
		fit(hint);
	end);

	category = Settings.RegisterCanvasLayoutCategory(panel, panel.name);
	Settings.RegisterAddOnCategory(category);
end
