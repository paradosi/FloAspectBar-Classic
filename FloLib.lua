-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.

-- =============================================================================
-- FloLib -- shared button/bar engine, VENDORED SEPARATELY INTO BOTH ADDONS.
--
-- FloAspectBar-Forever/FloLib.lua and FloTotemBar-Forever/FloLib.lua are two
-- copies of this file. They are NOT symlinked and nothing syncs them; they had
-- silently diverged once already (FloAspectBar was left on 1.44 without
-- FloLib_GetMaxRankId, so aspect tooltips showed rank 1). As of FLOLIB_VERSION
-- 1.45 the two .lua copies are byte-identical -- keep them that way: change
-- both, bump FLOLIB_VERSION in both, and diff them before releasing either.
--
-- FloLib.xml is the deliberate exception. Its template names differ by addon
-- (FloButtonTemplateA / FloCountdownA / FloBarTemplateA in FloAspectBar versus
-- ...T in FloTotemBar) so both addons can be loaded at once without colliding
-- on global frame names. Do NOT "fix" that difference.
-- =============================================================================


-- Some shared functions
-- Prevent multi-loading
-- Compare against this copy's own version, so a newer FloLib loaded second
-- replaces an older one instead of the first-loaded copy always winning.
if not FLOLIB_VERSION or FLOLIB_VERSION < 1.55 then

	local _
	local NUM_SPELL_SLOTS = 10;
	local SCHOOL_COLORS = { 1.0, 0.7, 0.0 };

	-- WoW Forever runs Retail's API: the flat spell functions are gone, and
	-- C_Spell returns tables. These keep the old return shapes the rest of
	-- this file was written against. The old globals returned nil for a nil
	-- or unknown spell; C_Spell raises a usage error instead.
	local GetSpellInfo = function(spell)
		if spell == nil then return; end
		local info = C_Spell.GetSpellInfo(spell);
		if info then
			return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID;
		end
	end;
	local GetSpellCooldown = function(spell)
		if spell == nil then return; end
		local cd = C_Spell.GetSpellCooldown(spell);
		if cd then
			return cd.startTime, cd.duration, cd.isEnabled and 1 or 0;
		end
	end;
	local IsUsableSpell = function(spell)
		if spell == nil then return; end
		return C_Spell.IsSpellUsable(spell);
	end;
	local TOOLTIP_BG = TOOLTIP_DEFAULT_BACKGROUND_COLOR;

	FLOLIB_VERSION = 1.55;

	FLOLIB_ACTIVATE_SPEC = nil; -- retail spell 200749, not available on Classic

	StaticPopupDialogs["FLOLIB_CONFIRM_RESET"] = {
		text = FLOLIB_CONFIRM_RESET,
		button1 = YES,
		button2 = NO,
		OnAccept = function(self, varName)
			_G[varName] = nil;
			ReloadUI();
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
	};

	-- Masque skinning, looked up when a bar is set up rather than when this
	-- file loads: Masque sorts after both Flo addons, so at load time it was
	-- never there unless a TOC listed it as a dependency.
	local function FloLib_GetMasque()
		return LibStub and LibStub('Masque', true);
	end

	-- Reset addon
	function FloLib_ResetAddon(addonName)

		local dialog = StaticPopup_Show("FLOLIB_CONFIRM_RESET", addonName);
		if dialog then
			dialog.data = string.upper(addonName.."_OPTIONS");
		end

	end

	-- Show borders on a frame
	function FloLib_ShowBorders(self)

		if not self.SetBackdrop then
			Mixin(self, BackdropTemplateMixin)
		end
		self:SetBackdrop( { bgFile = "Interface/Tooltips/UI-Tooltip-Background",
							edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
							tile = true,
							tileSize = 16,
							edgeSize = 16,
							insets = { left = 5, right = 5, top = 5, bottom = 5 } });
		-- Cosmetic
		if self.settings and self.settings.color then
			local r, g, b, a = unpack(self.settings.color);
			self:SetBackdropBorderColor((r + 1.0)/2.0, (g + 1.0)/2.0, (b + 1.0)/2.0);
			self:SetBackdropColor(r, g, b, a);
		else
			self:SetBackdropBorderColor(0.5, 0.5, 0.5);
			self:SetBackdropColor(TOOLTIP_BG.r, TOOLTIP_BG.g, TOOLTIP_BG.b, 0.7);
		end

	end

	-- Hide borders on a frame
	function FloLib_HideBorders(self)

		if not self.SetBackdrop then
			Mixin(self, BackdropTemplateMixin)
		end
		self:SetBackdrop(nil);
	end

	-- Copy content of src into dst, preserve existing values, recursive
	function FloLib_CopyPreserve(src, dst)

		local k, v;
		for k, v in pairs(src) do
			if dst[k] == nil then
				if type(v) == "table" then
					dst[k] = {};
					FloLib_CopyPreserve(v, dst[k]);
				else
					dst[k] = v;
				end
			elseif type(v) == "table" and type(dst[k]) == "table" then
				FloLib_CopyPreserve(v, dst[k]);
			end
		end
	end


	-- Swap 2 vals in an integer indexed array
	function FloLib_Swap(tab, val1, val2)

		local idx1, idx2, i;

		for i = 1, #tab do
			if tab[i] == val1 then
				idx1 = i;
			end
			if tab[i] == val2 then
				idx2 = i;
			end
		end

		-- Parenthesised on purpose: "not idx1 and idx2" let a missing idx2
		-- through to tab[nil] = val1, a Lua error when a hidden spell was
		-- dropped from the spellbook onto its bar.
		if not (idx1 and idx2) then
			-- one of the value not found, do nothing
			return;
		end
		tab[idx2] = val1;
		tab[idx1] = val2;

	end


	-- Update the bindings
	function FloLib_UpdateBindings(self, bindingPrefix)

		if InCombatLockdown() then
			return;
		end

		local key1, key2, i;
		local buttonPrefix = self:GetName().."Button";

		ClearOverrideBindings(self);

		for i = 1, 10 do
			key1, key2 = GetBindingKey(bindingPrefix.."BUTTON"..i);
			if key1 then
				SetOverrideBindingClick(self, true, key1, buttonPrefix..i);
			end
			if key2 then
				SetOverrideBindingClick(self, true, key2, buttonPrefix..i);
			end
		end
	end

	-- Common receive drag function
	function FloLib_ReceiveDrag(self, releaseCursor)

		if InCombatLockdown() then
			return;
		end

		local cursorType, index, info, spellID, i;

		cursorType, index, info, spellID = GetCursorInfo();

		if cursorType ~= "spell" then
			return;
		end

		local button = self;
		local newspell;
		if spellID then
			newspell = C_Spell.GetSpellName(spellID);
		end
		self = self:GetParent();

		-- find the spell in the curent list
		for i = 1, #self.availableSpells do
			if self.availableSpells[i].name == newspell then
				if releaseCursor then
					ClearCursor();
				end
				FloLib_Swap(self.settings.buttonsOrder, self.settings.buttonsOrder[button:GetID()], i);
				FloLib_Setup(self);
				break;
			end
		end

	end

	-- Show/hide a spell
	function FloLib_ToggleSpell(self, bar, idx)

		if bar.settings.hiddenSpells[idx] then
			bar.settings.hiddenSpells[idx] = nil;
		else
			bar.settings.hiddenSpells[idx] = 1;
		end

		FloLib_Setup(bar);
	end

	-- Setup the spell in a FloBar
	function FloLib_Setup(self)

		-- Protection if no settings
		if not self.settings then
			return;
		end

		local numSpells = 0;
		local button, coutdown;
		local isKnown, spell;
		local i = 1;
		local id, j, n;

		self.spells = {};

		-- Check already positionned spells
		while self.settings.buttonsOrder[i] do

			local n = self.settings.buttonsOrder[i];

			isKnown = false;
			if not self.settings.hiddenSpells[n] then
				spell = self.availableSpells[n];
				isKnown = spell and GetSpellInfo(GetSpellInfo(spell.id)) ~= nil;
			end

			if isKnown then
				spell.name, spell.addName, spell.texture = GetSpellInfo(spell.id);
				if spell.talented and not spell.talentedName then
					spell.talentedName = GetSpellInfo(spell.talented);
				end
				self:SetupSpell(spell, i);
				i = i + 1;
			else
				-- this spell is unavailable, shift the remaining indexes by 1
				for j = i, #self.settings.buttonsOrder do
					self.settings.buttonsOrder[j] = self.settings.buttonsOrder[j+1];
				end
			end

		end

		numSpells = i - 1;

		for n = 1, #self.availableSpells do

			if numSpells >= NUM_SPELL_SLOTS then
				break;
			end

			spell = self.availableSpells[n];
			spell.name, spell.addName, spell.texture = GetSpellInfo(spell.id);
			if spell.talented and not spell.talentedName then
				spell.talentedName = GetSpellInfo(spell.talented);
			end

			-- Check if this spell is already positionned
			i = nil;
			for j = 1, #self.settings.buttonsOrder do
				if self.settings.buttonsOrder[j] == n then
					i = 1;
					break;
				end
			end

			if not i then
				isKnown = false;
				if not self.settings.hiddenSpells[n] then
					isKnown = GetSpellInfo(GetSpellInfo(spell.id)) ~= nil;
				end
				if isKnown then

					numSpells = numSpells + 1;

					self:SetupSpell(spell, numSpells);
					self.settings.buttonsOrder[numSpells] = n;
				end
			end
		end

		-- Avoid tainting
		if not InCombatLockdown() then
			if numSpells > 0 then

				self:Show();
				if self.hideCooldowns then
					self:SetWidth(numSpells * 35 + 9 );
				elseif self.sharedCooldown then
					self:SetWidth(numSpells * 35 + 21 );
				else
					self:SetWidth(numSpells * 42 + 12 );
				end

				-- One Masque group per addon (the bar sets masqueGroup), so a
				-- lone FloAspectBar no longer skins under "FloTotemBar".
				local group;
				local LBF = FloLib_GetMasque();
				if LBF then
					group = LBF:Group(self.masqueGroup or 'FloTotemBar');
				end

				for i=1, NUM_SPELL_SLOTS do
					button = _G[self:GetName().."Button"..i];
					local countdown = _G[self:GetName().."Countdown"..i];

					if self.sharedCooldown and i == 1 then
						countdown:SetWidth(6);
					end

					-- Add the button to ButtonFacade
					if group then
						group:AddButton(button);
					end

					if self.hideCooldowns or self.sharedCooldown and i > 1 then
						button:SetPoint("LEFT", countdown, "LEFT", 0, 0);
					end
					if i <= numSpells then
						button:Show();
						if self.hideCooldowns or self.sharedCooldown and i > 1 then
							countdown:Hide();
						else
							countdown:Show();
						end
					else
						button:Hide();
						countdown:Hide();
					end
				end
			else
				self:Hide();
			end
		end

		if self.OnSetup then
			self:OnSetup();
		end
		FloLib_UpdateState(self);
	end

	-- Resolve the spell id of the highest rank the player currently knows.
	-- data.lua stores the rank-1 id, so using it directly would show a rank-1
	-- tooltip and mis-report usability/cost for higher ranks.
	function FloLib_GetMaxRankId(spell)

		if spell.name then
			local info = C_Spell.GetSpellInfo(spell.name);
			if info and info.spellID then
				return info.spellID;
			end
		end
		-- No name yet: querying by the rank-1 id's name returns the highest
		-- known rank's id as the 7th value.
		return select(7, GetSpellInfo(GetSpellInfo(spell.id))) or spell.id;
	end

	-- Update the state of the buttons in a FloBar
	function FloLib_UpdateState(self)

		local numSpells = #self.spells;
		local spell, cooldown, normalTexture, icon;
		local start, duration, enable, charges, maxCharges, isUsable, noMana;
		local start2, duration2, enable2;
		local i;

		for i=1, numSpells do

			if self.UpdateState then
				self:UpdateState(i);
			end

			spell = self.spells[i];

			--Cooldown stuffs
			cooldown = _G[self:GetName().."Button"..i.."Cooldown"];
			local maxRankId = FloLib_GetMaxRankId(spell);
			start, duration, enable, charges, maxCharges = GetSpellCooldown(maxRankId);
			-- WoW Forever hides cooldowns from addons when restricted; leave the
			-- swipe as it is rather than compare secret values
			local cooldownReadable = canaccessvalue(start) and canaccessvalue(duration);
			-- Talent-modified spell variants. Dead on TBC/Era: no entry in
			-- data.lua sets `talented`, so this branch never runs. Kept because
			-- it is upstream FloLib behaviour and would work correctly if
			-- talent variants were ever added to the data. (enable2 is fetched
			-- but unused -- the base spell decides whether the swipe shows.)
			if cooldownReadable and spell.talented then
				start2, duration2, enable2 = GetSpellCooldown(spell.talented);
				if start > 0 and start2 > 0 then
					start = math.min(start, start2);
				else
					start = start + start2;
				end
				duration = math.max(duration, duration2);
			end

			if cooldown.currentCooldownType ~= COOLDOWN_TYPE_NORMAL then
				cooldown:SetEdgeTexture("Interface\\Cooldown\\edge");
				cooldown:SetSwipeColor(0, 0, 0);
				cooldown:SetHideCountdownNumbers(false);
				cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL;
			end
			if cooldownReadable then
				CooldownFrame_Set(cooldown, start, duration, enable, charges, maxCharges);
			end

			--Castable stuffs
			normalTexture = _G[self:GetName().."Button"..i.."NormalTexture"];
			icon = _G[self:GetName().."Button"..i.."Icon"];
			isUsable, noMana = IsUsableSpell(maxRankId);

			if isUsable then
				icon:SetVertexColor(1.0, 1.0, 1.0);
				normalTexture:SetVertexColor(1.0, 1.0, 1.0);
			elseif noMana then
				icon:SetVertexColor(0.5, 0.5, 1.0);
				normalTexture:SetVertexColor(0.5, 0.5, 1.0);
			else
				icon:SetVertexColor(0.4, 0.4, 0.4);
				normalTexture:SetVertexColor(1.0, 1.0, 1.0);
			end

		end

	end

	function FloLib_Button_SetTooltip(self)
		if GetCVar("UberTooltips") == "1" then
			if self:GetParent().settings.position ~= "auto" then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
				--GameTooltip_SetDefaultAnchor(GameTooltip, self);
			else
				GameTooltip:SetOwner(self, "ANCHOR_NONE");
				local offsetX = CONTAINER_OFFSET_X or 0;
			local offsetY = CONTAINER_OFFSET_Y or 0;
			GameTooltip:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -offsetX - 13, offsetY + self:GetHeight());
				GameTooltip.default = 1;
			end
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		end
		local spell = self:GetParent().spells[self:GetID()];
		if spell then
			-- get id of max rank
			local maxRankId = FloLib_GetMaxRankId(spell);
			--Display the tooltip
			if maxRankId then
				GameTooltip:SetSpellByID(maxRankId);
			end
			GameTooltip:Show();
		end
	end

	function FloLib_StartTimer(self, guid, spellid)

		-- a secret spell id (WoW Forever) cannot be matched against the bar
		if not canaccessvalue(spellid) then
			return;
		end

		local founded = false;
		local name, startTime, duration;
		local countdown;
		local i;

		name = GetSpellInfo(spellid)
		-- Find spell
		for i = 1, #self.spells do
			if self.spells[i].name == name or self.spells[i].talentedName == name then
				founded = i;
				duration = self.spells[i].duration;
				startTime = GetTime();
				break;
			end
		end

		if founded then

			if self.sharedCooldown then
				i = 1
			else
				i = founded
			end
			self["activeSpell"..i] = founded;
			self["startTime"..i] = startTime;

			countdown = _G[self:GetName().."Countdown"..i];
			if countdown and not self.hideCooldowns then
				countdown:SetMinMaxValues(0, duration);
				countdown:SetStatusBarColor(unpack(SCHOOL_COLORS));
			end
			FloLib_OnUpdate(self);
		end
	end

	function FloLib_ResetTimer(self, pos)

		if self.sharedCooldown then
			pos = 1
		end
		self["startTime"..pos] = 0;
		FloLib_OnUpdate(self);
	end

	function FloLib_OnUpdate(self)

		for i=1, #self.spells do

			local name = self:GetName();
			local button = _G[name.."Button"..i];
			button:SetButtonState("NORMAL")

			local spell = self.spells[i];

			local isActive = false;

			local pos
			if self.sharedCooldown then
				pos = 1
			else
				pos = i
			end
			if self["activeSpell"..pos] == i then

				local countdown = _G[name.."Countdown"..pos];
				if countdown then
					local timeleft = self["startTime"..pos];
					if not self.hideCooldowns then
						local _, duration = countdown:GetMinMaxValues();

						timeleft = timeleft + duration - GetTime();
					end
					isActive = timeleft > 0;

					if (isActive) then
						countdown:SetValue(timeleft);
					else
						self["activeSpell"..pos] = nil;
						countdown:SetValue(0);
					end
				else
					isActive = self["startTime"..pos] ~= 0;
				end
			end
			if isActive then
				button:SetChecked(true);
			else
				button:SetChecked(false);
			end
		end
	end

	-- Bar Dropdown
	function FloLib_BarDropDown_OnLoad(self)
		UIDropDownMenu_Initialize(self, FloLib_BarDropDown_Initialize, "MENU");
		UIDropDownMenu_SetButtonWidth(self, 20);
		UIDropDownMenu_SetWidth(self, 20);
	end

	function FloLib_BarDropDown_Initialize(frame, level, menuList)

		local info, i, spell;
		local bar = frame:GetParent();

		-- If level 3
		if UIDROPDOWNMENU_MENU_LEVEL == 3 then
			return;
		end

		-- If level 2
		if UIDROPDOWNMENU_MENU_LEVEL == 2 then

			-- If this is the position menu
			if UIDROPDOWNMENU_MENU_VALUE == "position" then

				-- Add the possible values to the menu
				for value, text in pairs(FLOLIB_POSITIONS) do
					info = UIDropDownMenu_CreateInfo();
					info.text = text;
					info.value = value;
					info.func = bar.menuHooks.SetPosition;
					info.arg1 = bar;
					info.arg2 = value;

					if value == bar.settings.position then
						info.checked = 1;
					end
					UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
				end

			-- If this is the layout menu
			elseif UIDROPDOWNMENU_MENU_VALUE == "layout" then

				-- Use the provided hook to populate the menu
				bar.menuHooks.SetLayoutMenu();

			-- If this is the spell menu
			elseif UIDROPDOWNMENU_MENU_VALUE == "spells" then

				-- Add the possible values to the menu
				-- (skipping the TBC spells WoW Forever doesn't have: data.lua)
				for i, spell in ipairs(bar.availableSpells) do
					if not spell.notOnForever then
						info = UIDropDownMenu_CreateInfo();
						info.text = spell.name;
						info.value = i;
						info.func = FloLib_ToggleSpell;
						info.arg1 = bar;
						info.arg2 = i;

						if not bar.settings.hiddenSpells[i] then
							info.checked = 1;
						end
						UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
					end
				end

			end
			return;
		end

		-- Position menu
		if bar.menuHooks and bar.menuHooks.SetPosition then
			info = UIDropDownMenu_CreateInfo();
			info.text = FLOLIB_POSITION;
			info.value = "position";
			info.hasArrow = 1;
			info.func = nil;
			UIDropDownMenu_AddButton(info);
		end

		-- Layout menu
		if bar.menuHooks and bar.menuHooks.SetLayoutMenu then
			info = UIDropDownMenu_CreateInfo();
			info.text = FLOLIB_LAYOUT;
			info.value = "layout";
			info.hasArrow = 1;
			info.func = nil;
			UIDropDownMenu_AddButton(info);
		end

		-- Spells menu
		if bar.menuHooks then
			info = UIDropDownMenu_CreateInfo();
			info.text = SPELLS;
			info.value = "spells";
			info.hasArrow = 1;
			info.func = nil;
			UIDropDownMenu_AddButton(info);
		end

		-- Border options
		if bar.menuHooks and bar.menuHooks.SetBorders then
			info = UIDropDownMenu_CreateInfo();
			info.text = FLOLIB_SHOWBORDERS;
			info.func = bar.menuHooks.SetBorders;
			info.arg1 = not bar.globalSettings.borders;

			if bar.globalSettings.borders then
				info.checked = 1;
			end
			UIDropDownMenu_AddButton(info);
		end

		-- Optional addon-defined toggle (FloTotemBar: hide Blizzard's totem
		-- bar). The hook carries its own label, so it needs no FloLib string:
		-- FloLib_localization.lua is skipped when an older FloLib loaded first.
		if bar.menuHooks and bar.menuHooks.Toggle then
			local hook = bar.menuHooks.Toggle;
			info = UIDropDownMenu_CreateInfo();
			info.text = hook.text;
			info.func = hook.set;
			info.arg1 = not hook.get();

			if hook.get() then
				info.checked = 1;
			end
			UIDropDownMenu_AddButton(info);
		end

		-- Background
		if bar.menuHooks then
			info = UIDropDownMenu_CreateInfo();
			info.text = BACKGROUND;
			info.hasColorSwatch = 1;
			info.r = bar.settings.color[1];
			info.g = bar.settings.color[2];
			info.b = bar.settings.color[3];
			-- Done because the slider is reversed
			info.opacity = 1.0 - bar.settings.color[4];
			info.swatchFunc = FloLib_BarDropDown_SetBackGroundColor;
			info.func = UIDropDownMenuButton_OpenColorPicker;
			info.hasOpacity = 1;
			info.opacityFunc = FloLib_BarDropDown_SetOpacity;
			info.cancelFunc = FloLib_BarDropDown_CancelColorSettings;
			UIDropDownMenu_AddButton(info);
		end

		-- Optional link to the addon's Settings panel. Like Toggle, the hook
		-- carries its own label.
		if bar.menuHooks and bar.menuHooks.Options then
			info = UIDropDownMenu_CreateInfo();
			info.text = bar.menuHooks.Options.text;
			info.func = bar.menuHooks.Options.func;
			info.notCheckable = 1;
			UIDropDownMenu_AddButton(info);
		end

	end

	function FloLib_BarDropDown_SetBackGroundColor()
		local r,g,b = ColorPickerFrame:GetColorRGB();
		local bar = UIDropDownMenu_GetCurrentDropDown():GetParent();

		bar.settings.color[1] = r;
		bar.settings.color[2] = g;
		bar.settings.color[3] = b;

		if bar.globalSettings.borders then
			FloLib_ShowBorders(bar)
		end
	end

	function FloLib_BarDropDown_SetOpacity()
		local a = ColorPickerFrame:GetColorAlpha();
		local bar = UIDropDownMenu_GetCurrentDropDown():GetParent();

		bar.settings.color[4] = a;

		if bar.globalSettings.borders then
			FloLib_ShowBorders(bar)
		end
	end

	function FloLib_BarDropDown_CancelColorSettings(previous)
		local bar = UIDropDownMenu_GetCurrentDropDown():GetParent();

		bar.settings.color[1] = previous.r;
		bar.settings.color[2] = previous.g;
		bar.settings.color[3] = previous.b;
		bar.settings.color[4] = 1.0 - (previous.opacity or previous.a or 0);

		if bar.globalSettings.borders then
			FloLib_ShowBorders(bar)
		end
	end

	function FloLib_BarDropDown_Show(self, button)

		-- If Rightclick bring up the options menu
		if button == "RightButton" then
			GameTooltip:Hide();
			self:StopMovingOrSizing();
			ToggleDropDownMenu(1, nil, _G[self:GetName().."DropDown"], self:GetName(), 0, 0);
			return;
		end

		-- Close all dropdowns
		CloseDropDownMenus();
	end

	-- Name of the unit's i-th buff. nil past the last
	-- buff; false for a buff whose name is a secret value (WoW Forever), which
	-- addon code may not compare; true when the buff is secret and must not be
	-- queried at all: GetBuffDataByIndex raises an error, not a secret value,
	-- when tainted code asks for a secret aura.
	local function FloLib_BuffName(unit, i)
		if C_Secrets.ShouldUnitAuraIndexBeSecret(unit, i, "HELPFUL") then
			return true;
		end
		local aura = C_UnitAuras.GetBuffDataByIndex(unit, i);
		if not aura then
			return nil;
		end
		return canaccessvalue(aura.name) and aura.name or false;
	end

	-- true or false, or nil when the game is hiding auras from addons (WoW
	-- Forever, in restricted combat) and the answer cannot be known.
	function FloLib_UnitHasBuff(unit, name)

		if C_Secrets.ShouldAurasBeSecret() then
			return nil;
		end

		local i = 1;
		local buff = FloLib_BuffName(unit, i);
		while buff ~= nil do
			if buff == true then
				return nil;
			elseif buff == name then
				return true;
			end
			i = i + 1;
			buff = FloLib_BuffName(unit, i);
		end
		return false;
	end

	-- Minimap button, one per addon. Drawn like LibDBIcon's (same textures and
	-- geometry) so it sits with other addons' buttons, but without the library:
	-- the Flo addons ship none. db is a saved table: db.angle (degrees around
	-- the minimap) and db.hide. onClick(button, mouseButton) and
	-- onTooltip(GameTooltip) come from the addon, so no FloLib strings.
	local function FloLib_MinimapButton_Place(button)

		local angle = math.rad(button.db.angle or 225);
		local x, y = math.cos(angle), math.sin(angle);
		local w = (Minimap:GetWidth() / 2) + 5;
		local h = (Minimap:GetHeight() / 2) + 5;
		-- GetMinimapShape is not Blizzard's: minimap addons define it
		local shape = GetMinimapShape and GetMinimapShape() or "ROUND";
		if shape ~= "ROUND" then
			-- square (or any other shape): ride the edge of the box
			local d = math.max(math.abs(x), math.abs(y));
			x, y = x / d, y / d;
		end
		button:ClearAllPoints();
		button:SetPoint("CENTER", Minimap, "CENTER", x * w, y * h);
	end

	local function FloLib_MinimapButton_OnUpdate(button)

		local mx, my = Minimap:GetCenter();
		local px, py = GetCursorPosition();
		local scale = Minimap:GetEffectiveScale();
		button.db.angle = math.deg(math.atan2(py / scale - my, px / scale - mx)) % 360;
		FloLib_MinimapButton_Place(button);
	end

	function FloLib_CreateMinimapButton(name, db, icon, onClick, onTooltip)

		local button = CreateFrame("Button", name, Minimap);
		button.db = db;
		button:SetFrameStrata("MEDIUM");
		button:SetFrameLevel(8);
		button:SetSize(31, 31);
		button:RegisterForClicks("AnyUp");
		button:RegisterForDrag("LeftButton");
		button:SetHighlightTexture(136477); -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

		local overlay = button:CreateTexture(nil, "OVERLAY");
		overlay:SetSize(53, 53);
		overlay:SetTexture(136430); -- Interface\Minimap\MiniMap-TrackingBorder
		overlay:SetPoint("TOPLEFT");
		local background = button:CreateTexture(nil, "BACKGROUND");
		background:SetSize(20, 20);
		background:SetTexture(136467); -- Interface\Minimap\UI-Minimap-Background
		background:SetPoint("TOPLEFT", 7, -5);
		local texture = button:CreateTexture(nil, "ARTWORK");
		texture:SetSize(17, 17);
		texture:SetTexture(icon);
		texture:SetPoint("TOPLEFT", 7, -6);
		button.icon = texture;

		button:SetScript("OnClick", function(self, mouseButton)
			onClick(self, mouseButton);
		end);
		button:SetScript("OnDragStart", function(self)
			self:LockHighlight();
			GameTooltip:Hide();
			self:SetScript("OnUpdate", FloLib_MinimapButton_OnUpdate);
		end);
		button:SetScript("OnDragStop", function(self)
			self:SetScript("OnUpdate", nil);
			self:UnlockHighlight();
		end);
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_LEFT");
			onTooltip(GameTooltip);
			GameTooltip:Show();
		end);
		button:SetScript("OnLeave", function()
			GameTooltip:Hide();
		end);

		FloLib_UpdateMinimapButton(button);
		return button;
	end

	-- Show or hide (db.hide) and place the button
	function FloLib_UpdateMinimapButton(button)

		if button.db.hide then
			button:Hide();
		else
			FloLib_MinimapButton_Place(button);
			button:Show();
		end
	end

	end
