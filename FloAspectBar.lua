-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

-- Printed in the login banner. NOT read from the TOC -- bump it here AND in
-- both .toc files on every release. It silently drifted to 1.1.0 while the
-- TOCs said 1.2.0, so the addon announced the wrong version for two releases.
-- FloTotemBar has the same hand-maintained string; check both.
local VERSION = "1.2.8"

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------

local _
local SHOW_WELCOME = true;
-- WoW Forever renamed the main action bar frame
local MainMenuBar = MainMenuBar or MainActionBar;
local FLOASPECTBAR_BARSETTINGS_DEFAULT = { position = "auto", buttonsOrder = {}, color = { 0, 0.49, 0, 0.7 }, hiddenSpells = {} };
local FLOASPECTBAR_OPTIONS_DEFAULT = { [1] = { scale = 1, borders = true, barSettings = FLOASPECTBAR_BARSETTINGS_DEFAULT }, active = 1 };
FLOASPECTBAR_OPTIONS = FLOASPECTBAR_OPTIONS_DEFAULT;
local ACTIVE_OPTIONS = FLOASPECTBAR_OPTIONS[1];

local GetSpecialization = function()
	return 1
end

-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

-- Executed on load, calls general set-up functions
function FloAspectBar_OnLoad(self)

	-- Class-based setup, abort if not supported
	local temp, classFileName = UnitClass("player");
	classFileName = strupper(classFileName);

	local classSpells = FLO_ASPECT_SPELLS[classFileName];
	if classSpells == nil then
		return;
	end

	self.hideCooldowns = true;
	self.masqueGroup = "FloAspectBar";

	-- Store the spell list for later
	self.availableSpells = classSpells;
	if self.availableSpells == nil then
		return;
	end

	self.spells = {};
	self.SetupSpell = FloAspectBar_SetupSpell;
	self.OnSetup = FloAspectBar_OnSetup;
	self.UpdateState = FloAspectBar_UpdateState;
	self.menuHooks = { SetPosition = FloAspectBar_SetPosition, SetBorders = FloAspectBar_SetBorders };
	self:EnableMouse(1);

	if SHOW_WELCOME then
		DEFAULT_CHAT_FRAME:AddMessage( "|cffd78900FloAspectBar v"..VERSION.."|r loaded." );
		SHOW_WELCOME = nil;

		SLASH_FLOASPECTBAR1 = "/floaspectbar";
		SLASH_FLOASPECTBAR2 = "/fab";
		SlashCmdList["FLOASPECTBAR"] = FloAspectBar_ReadCmd;

		self:RegisterEvent("ADDON_LOADED");
	end

	self:RegisterEvent("CHARACTER_POINTS_CHANGED");
	self:RegisterEvent("SPELLS_CHANGED");
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN");
	self:RegisterEvent("ACTIONBAR_UPDATE_USABLE");
	self:RegisterEvent("UNIT_AURA");
	if C_Secrets then
		self:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED");
	end
	self:RegisterEvent("UPDATE_BINDINGS");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	if not C_EventUtils or C_EventUtils.IsEventValid("EDIT_MODE_LAYOUTS_UPDATED") then
		self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED");
	end
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player");
end

function FloAspectBar_OnEvent(self, event, arg1, ...)

	if event == "CHARACTER_POINTS_CHANGED" or event == "SPELLS_CHANGED" then
		if GetSpecialization() ~= FLOASPECTBAR_OPTIONS.active then
			FloAspectBar_CheckTalentGroup(GetSpecialization());
		else
			FloLib_Setup(self);
		end

	elseif event == "ADDON_LOADED" and arg1 == "FloAspectBar" then
		FloAspectBar_CheckTalentGroup(FLOASPECTBAR_OPTIONS.active);

		-- Hook the UIParent_ManageFramePositions function
		-- Forever (Retail's UI) has no UIParent_ManageFramePositions; Blizzard's
		-- edit-mode layout places its bars there.
		if UIParent_ManageFramePositions then
			hooksecurefunc("UIParent_ManageFramePositions", FloAspectBar_UpdatePosition);
		end
		FloLib_UpdateBindings(self, "SHAPESHIFT");

	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if arg1 == "player" then
			FloLib_StartTimer(self, ...);
		end

	elseif event == "UPDATE_BINDINGS" then
		FloLib_UpdateBindings(self, "SHAPESHIFT");

	elseif event == "PLAYER_ENTERING_WORLD" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
		-- ADDON_LOADED placed the bar before Blizzard (and any action bar addon)
		-- had laid out the main bars; Forever has no UIParent_ManageFramePositions
		-- to re-run it, so place it again once the layout is final.
		FloAspectBar_UpdatePosition();

	elseif event == "UNIT_AURA" then
		if arg1 == PlayerFrame.unit then
			FloLib_UpdateState(self);
		end

	else
		FloLib_UpdateState(self);
	end
end

function FloAspectBar_TalentGroupChanged(grp)

	-- Save old spec position
	if ACTIVE_OPTIONS.barSettings.position ~= "auto" then
		ACTIVE_OPTIONS.barSettings.refPoint = { FloAspectBar:GetPoint() };
	end
	FloAspectBar_CheckTalentGroup(grp);
	FloLib_Setup(FloAspectBar);
	-- Restore position
	if ACTIVE_OPTIONS.barSettings.position ~= "auto" and ACTIVE_OPTIONS.barSettings.refPoint then
		FloAspectBar:ClearAllPoints();
		FloAspectBar:SetPoint(unpack(ACTIVE_OPTIONS.barSettings.refPoint));
	end
end

function FloAspectBar_CheckTalentGroup(grp)

	FLOASPECTBAR_OPTIONS.active = grp;
	ACTIVE_OPTIONS = FLOASPECTBAR_OPTIONS[grp];
	-- first time talent activation ?
	if not ACTIVE_OPTIONS then
		-- Copy primary spec options into other spec
		FLOASPECTBAR_OPTIONS[grp] = {};
		FloLib_CopyPreserve(FLOASPECTBAR_OPTIONS[1], FLOASPECTBAR_OPTIONS[grp]);
		ACTIVE_OPTIONS = FLOASPECTBAR_OPTIONS[grp];
	end

	FloAspectBar.globalSettings = ACTIVE_OPTIONS;
	FloAspectBar.settings = ACTIVE_OPTIONS.barSettings;
	FloAspectBar_SetPosition(nil, FloAspectBar, ACTIVE_OPTIONS.barSettings.position);
	FloAspectBar_SetScale(ACTIVE_OPTIONS.scale);
	FloAspectBar_SetBorders(nil, ACTIVE_OPTIONS.borders);

end

function FloAspectBar_ReadCmd(line)

	local cmd, var = strsplit(' ', line or "");

	if InCombatLockdown() and (cmd == "scale" or cmd == "lock" or cmd == "unlock" or cmd == "auto" or cmd == "show") then
		-- moving or scaling the bar moves its secure buttons: blocked in combat
		DEFAULT_CHAT_FRAME:AddMessage("FloAspectBar: "..(ERR_NOT_IN_COMBAT or "You can't do that while in combat"));
	elseif cmd == "scale" and tonumber(var) then
		FloAspectBar_SetScale(var);
	elseif cmd == "lock" or cmd == "unlock" or cmd == "auto" then
		FloAspectBar_SetPosition(nil, FloAspectBar, cmd);
	elseif cmd == "borders" then
		FloAspectBar_SetBorders(nil, true);
	elseif cmd == "noborders" then
		FloAspectBar_SetBorders(nil, false);
	elseif cmd == "show" then
		FloAspectBar_ShowAllSpells();
	elseif cmd == "status" then
		FloAspectBar_PrintStatus();
	elseif cmd == "panic" or cmd == "reset" then
		FloLib_ResetAddon("FloAspectBar");
	else
		DEFAULT_CHAT_FRAME:AddMessage( "FloAspectBar usage :" );
		DEFAULT_CHAT_FRAME:AddMessage( "/fab lock|unlock : lock/unlock position" );
		DEFAULT_CHAT_FRAME:AddMessage( "/fab borders|noborders : show/hide borders" );
		DEFAULT_CHAT_FRAME:AddMessage( "/fab auto : Automatic positioning" );
		DEFAULT_CHAT_FRAME:AddMessage( "/fab scale <num> : Set scale" );
		DEFAULT_CHAT_FRAME:AddMessage( "/fab show : Bring back aspects hidden from the bar" );
		DEFAULT_CHAT_FRAME:AddMessage( "/fab status : What the bar shows and where it is" );
		DEFAULT_CHAT_FRAME:AddMessage( "/fab panic||reset : Reset FloAspectBar" );
		return;
	end
end

function FloAspectBar_SetupSpell(self, spell, pos)

	-- Avoid tainting
	if not InCombatLockdown() then
		local name, button, icon;
		name = self:GetName();
		button = _G[name.."Button"..pos];
		icon = _G[name.."Button"..pos.."Icon"];

		button:SetAttribute("type1", "spell");
		button:SetAttribute("spell", spell.name);

		icon:SetTexture(spell.texture);
	end

	self.spells[pos] = { id = spell.id, name = spell.name, addName = spell.addName, talented = spell.talented, duration = spell.duration };

	if spell.modifier then spell.modifier(self.spells[pos]) end

end

function FloAspectBar_OnSetup(self)

	-- Avoid tainting
	if not InCombatLockdown() then
		if next(self.spells) == nil then
			UnregisterStateDriver(self, "visibility")
		else
			RegisterStateDriver(self, "visibility", "show")
		end
	end

	-- Hiding the last aspect from the right-click menu hides the bar, and with
	-- it the only way to open that menu. Say so, once, instead of vanishing.
	local numHidden = FloAspectBar_CountHidden();
	if next(self.spells) == nil and numHidden > 0 then
		if not self.allHiddenNotified then
			DEFAULT_CHAT_FRAME:AddMessage("FloAspectBar: the bar is hidden because it has no aspects to show ("..numHidden.." hidden). Type /fab show to bring them back.");
			self.allHiddenNotified = true;
		end
	else
		self.allHiddenNotified = nil;
	end
end

function FloAspectBar_CountHidden()

	local n = 0;
	for _ in pairs(ACTIVE_OPTIONS.barSettings.hiddenSpells) do
		n = n + 1;
	end
	return n;
end

function FloAspectBar_SpellName(spell)

	return spell.name or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell.id)) or ("spell "..spell.id);
end

function FloAspectBar_ShowAllSpells()

	local numHidden = FloAspectBar_CountHidden();
	ACTIVE_OPTIONS.barSettings.hiddenSpells = {};
	FloLib_Setup(FloAspectBar);
	FloAspectBar_UpdatePosition();

	if next(FloAspectBar.spells) == nil then
		DEFAULT_CHAT_FRAME:AddMessage("FloAspectBar: no aspects learned yet, so there is nothing to show.");
	else
		DEFAULT_CHAT_FRAME:AddMessage("FloAspectBar: "..numHidden.." hidden aspect(s) back on the bar.");
	end
end

-- One-look diagnosis for "my bar is gone": what is on it, what is hidden or
-- not learned, and where the bar actually is.
function FloAspectBar_PrintStatus()

	local bar = FloAspectBar;
	local settings = ACTIVE_OPTIONS.barSettings;
	local function say(msg)
		DEFAULT_CHAT_FRAME:AddMessage("|cffd78900FloAspectBar|r "..msg);
	end

	say("v"..VERSION..", position "..tostring(settings.position)..", scale "..tostring(ACTIVE_OPTIONS.scale));

	local onBar, onBarNames = {}, {};
	for i = 1, #bar.spells do
		onBar[bar.spells[i].name] = true;
		onBarNames[#onBarNames + 1] = bar.spells[i].name;
	end
	local hidden, missing = {}, {};
	for n, spell in ipairs(bar.availableSpells) do
		local name = FloAspectBar_SpellName(spell);
		if settings.hiddenSpells[n] then
			hidden[#hidden + 1] = name;
		elseif not onBar[name] then
			missing[#missing + 1] = name;
		end
	end
	say("On the bar ("..#onBarNames.."): "..(#onBarNames > 0 and table.concat(onBarNames, ", ") or "none"));
	say("Hidden ("..#hidden.."): "..(#hidden > 0 and table.concat(hidden, ", ") or "none"));
	say("Not learned ("..#missing.."): "..(#missing > 0 and table.concat(missing, ", ") or "none"));

	local where;
	local left, bottom, width, height = bar:GetRect();
	local offScreen;
	if not left then
		where = "has no position";
		offScreen = true;
	else
		-- GetRect is in the bar's own scale; convert to UIParent's
		local s = bar:GetEffectiveScale() / UIParent:GetEffectiveScale();
		local l, b, r, t = left * s, bottom * s, (left + width) * s, (bottom + height) * s;
		offScreen = r < 0 or t < 0 or l > UIParent:GetWidth() or b > UIParent:GetHeight();
		where = string.format("%s at %.0f, %.0f", offScreen and "OFF SCREEN" or "on screen", l, b);
	end
	local point, rel, relPoint, x, y = bar:GetPoint(1);
	local relName = rel and rel.GetName and rel:GetName() or "screen";
	say("Bar is "..(bar:IsShown() and "shown" or "hidden")..", "..where
		..(point and string.format(" (%s of %s %s, %.0f, %.0f)", point, relName, tostring(relPoint), x or 0, y or 0) or ""));

	if #onBarNames == 0 and #hidden > 0 then
		say("Nothing is on the bar and some aspects are hidden: /fab show brings them back.");
	elseif offScreen then
		say("Type /fab auto to put the bar back above your action bars.");
	end
end

function FloAspectBar_UpdateState(self, pos)

	local button = _G[self:GetName().."Button"..pos];
	local spell = self.spells[pos];

	local hasBuff = FloLib_UnitHasBuff("player", spell.name);
	if hasBuff == nil then
		-- Auras are hidden from addons right now: keep the button as it is.
		-- ADDON_RESTRICTION_STATE_CHANGED refreshes it when they return.
		return;
	elseif hasBuff then
		FloLib_StartTimer(self, nil, spell.id);
	elseif self["activeSpell"..pos] == pos then
        FloLib_ResetTimer(self, pos);
    else
		button:SetChecked(false);
	end
end

function FloAspectBar_UpdatePosition()

	-- Avoid tainting when in combat
	if ACTIVE_OPTIONS.barSettings.position ~= "auto" or InCombatLockdown() then
		return;
	end

	local yOffset = 0;
	local xOffset = 512;
	local anchorFrame;

	-- IsVisible, not IsShown, and the main bar must have a position. Action bar
	-- addons (Dominos, Bartender, ElvUI) hide Blizzard's bar by reparenting it to
	-- a hidden frame or clearing its points, which leaves IsShown() true:
	-- anchoring to it then parked this bar off screen, or left it with no
	-- position at all, and the bar simply vanished.
	local mainBarUsable = MainMenuBar and MainMenuBar:IsVisible() and MainMenuBar:GetLeft() ~= nil;

	if not mainBarUsable then
		anchorFrame = UIParent;
		yOffset = 110 - UIParent:GetHeight();
	else
		anchorFrame = MainMenuBar;
		xOffset = 326;
		if MultiBarBottomLeft and MultiBarBottomLeft:IsShown() then
			yOffset = yOffset + 50;
		end
		if MultiBarBottomRight and MultiBarBottomRight:IsShown() then
			yOffset = yOffset + 50;
		end
	end

	FloAspectBar:ClearAllPoints();
	FloAspectBar:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", xOffset/ACTIVE_OPTIONS.scale, yOffset/ACTIVE_OPTIONS.scale);
end

function FloAspectBar_SetBorders(self, visible)

	ACTIVE_OPTIONS.borders = visible;
	if visible or ACTIVE_OPTIONS.barSettings.position == "unlock" then
		FloLib_ShowBorders(FloAspectBar);
	else
		FloLib_HideBorders(FloAspectBar);
	end

end

function FloAspectBar_SetPosition(self, bar, mode)

	local unlocked = (mode == "unlock");

	-- Close all dropdowns
	CloseDropDownMenus();

	-- Moving the bar moves its secure buttons, which is blocked in combat
	if InCombatLockdown() then
		DEFAULT_CHAT_FRAME:AddMessage("FloAspectBar: "..(ERR_NOT_IN_COMBAT or "You can't do that while in combat"));
		return;
	end

	if bar.settings then
		local savePoints = bar.settings.position ~= mode;
	        bar.settings.position = mode;
	        DEFAULT_CHAT_FRAME:AddMessage(bar:GetName().." position "..mode);

	        if unlocked then
		        FloLib_ShowBorders(bar);
		        bar:RegisterForDrag("LeftButton");
	        else
		        if ACTIVE_OPTIONS.borders then
			        FloLib_ShowBorders(bar);
		        else
			        FloLib_HideBorders(bar);
		        end
	        end

	        if mode == "auto" then
		        -- Force the auto positionning
		        FloAspectBar_UpdatePosition();
	        else
		        -- Force the game to remember position
		        bar:StartMoving();
		        bar:StopMovingOrSizing();
			if savePoints then
				bar.settings.refPoint = { bar:GetPoint() };
			end
	        end
        end
end

function FloAspectBar_SetScale(scale)

	scale = tonumber(scale);
	if ( not scale or scale <= 0 ) then
		DEFAULT_CHAT_FRAME:AddMessage( "FloAspectBar : scale must be >0 ("..tostring(scale)..")" );
		return;
	end

	ACTIVE_OPTIONS.scale = scale;

	local v = FloAspectBar;
	local p, a, rp, ox, oy = v:GetPoint();
	local os = v:GetScale();
	v:SetScale(scale);
	if a == nil or a == UIParent or a == MainMenuBar then
		v:SetPoint(p, a, rp, ox*os/scale, oy*os/scale);
	end

end
