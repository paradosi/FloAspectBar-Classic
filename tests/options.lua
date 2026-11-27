-- luacheck: ignore
-- (this file stubs the WoW API by assigning its globals; nothing here ships)
--
-- Headless test of the settings panel (Options.lua) against a stubbed WoW API
-- and a stand-in bar: builds the panel, opens it, works every control and the
-- help dialog, and checks each one calls through to the addon's own setters.
-- The bar itself is built from XML (FloLib.xml) and is not loaded here, so its
-- setters are recorded rather than run. Widget stubs come from
-- ForeverQuestItemBar's tests/smoke.lua.
--
--   cd FloAspectBar-Forever && lua5.1 tests/options.lua

local failures = 0
local function check(cond, msg)
    if cond then print("ok   " .. msg) else failures = failures + 1; print("FAIL " .. msg) end
end

---- A permissive widget: unknown CamelCase methods are no-ops; the ones the
---- addon reads keep real state

local methods = {}
local Widget = {
    __index = function(_, k)
        if methods[k] then return methods[k] end
        if type(k) == "string" and k:match("^%u") then return function() end end
    end,
}
local function NewWidget(kind, name)
    return setmetatable({ kind = kind, name = name, scripts = {}, shown = true, points = {},
                          w = 100, h = 100, alpha = 1, value = 0, scale = 1, attrs = {},
                          enabled = true, children = {} }, Widget)
end
function methods.SetScript(self, k, fn) self.scripts[k] = fn end
function methods.GetScript(self, k) return self.scripts[k] end
function methods.HookScript(self, k, fn)
    local before = self.scripts[k]
    self.scripts[k] = function(...) if before then before(...) end fn(...) end
end
function methods.Show(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods.Hide(self)
    local was = self.shown
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods.SetShown(self, on) if on then self:Show() else self:Hide() end end
function methods.IsShown(self) return self.shown end
function methods.SetSize(self, w, h) self.w, self.h = w, h end
function methods.SetWidth(self, w) self.w = w end
function methods.SetHeight(self, h) self.h = h end
function methods.GetWidth(self) return self.w end
function methods.GetHeight(self) return self.h end
function methods.GetLeft() return 400 end
function methods.GetRight(self) return 400 + self.w end
function methods.GetTop() return 300 end
function methods.GetFrameLevel() return 1 end
function methods.ClearAllPoints(self) self.points = {} end
function methods.SetPoint(self, ...) table.insert(self.points, { ... }) end
function methods.GetPoint(self, i) return unpack(self.points[i or 1] or {}) end
function methods.SetAlpha(self, a) self.alpha = a end
function methods.SetScale(self, s) self.scale = s end
function methods.GetScale(self) return self.scale end
function methods.IsMouseOver() return false end
function methods.HasFocus(self) return self.focus end
function methods.SetFocus(self) self.focus = true end
function methods.ClearFocus(self) self.focus = false end
function methods.SetText(self, t) self.text = t end
function methods.GetText(self) return self.text end
function methods.SetEnabled(self, on) self.enabled = on end
function methods.GetName(self) return self.name end
function methods.GetID(self) return self.id end
function methods.SetAttribute(self, k, v) self.attrs[k] = v end
function methods.GetAttribute(self, k) return self.attrs[k] end
function methods.CreateTexture(self) return NewWidget("Texture") end
function methods.CreateFontString(self) return NewWidget("FontString") end
function methods.GetThumbTexture(self)
    self.thumb = self.thumb or NewWidget("Texture")
    return self.thumb
end
function methods.SetMinMaxValues(self, a, b) self.min, self.max = a, b end
function methods.SetValue(self, v)
    self.value = v
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
end
function methods.GetValue(self) return self.value end
function methods.RegisterEvent(self, e) self.events = self.events or {}; self.events[e] = true end
function methods.UnregisterEvent(self, e) if self.events then self.events[e] = nil end end
function methods.Click(self, button)
    if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end
end

---- Globals

local frames = {}
function CreateFrame(kind, name, parent, template)
    local f = NewWidget(kind, name)
    if name then _G[name] = f end
    if parent then table.insert(parent.children, f) end
    if template and template:find("ActionButtonTemplate") then
        f.icon, f.Count, f.HotKey, f.cooldown =
            NewWidget("Texture"), NewWidget("FontString"), NewWidget("FontString"), NewWidget("Cooldown")
    end
    table.insert(frames, f)
    return f
end
UIParent = NewWidget("Frame", "UIParent")
UISpecialFrames = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) LAST_PRINT = m end }
SOUNDKIT = { U_CHAT_SCROLL_BUTTON = 1115 }
ATTRIBUTE_NOOP = ""
GameTooltip = NewWidget("GameTooltip")
function PlaySound() end
function CreateColor(r, g, b, a) return { r, g, b, a } end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function tinsert(t, v) table.insert(t, v) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function GetBindingKey() return nil end
function GetBindingText(k) return k end
function CooldownFrame_Set() end
function ActionButton_UpdateRangeIndicator() end
function UnitExists() return false end
function UnitCanAttack() return false end
function IsAltKeyDown() return false end
function IsModifiedClick() return false end
function HandleModifiedItemClick() end
function GetQuestLogSpecialItemInfo() return nil end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5

local state = { combat = false }
function InCombatLockdown() return state.combat end

local timers = {}
C_Timer = { After = function(_, fn) table.insert(timers, fn) end }
local function RunAfters()
    while #timers > 0 do table.remove(timers, 1)() end
end

function methods.GetVerticalScrollRange() return 0 end
function methods.GetVerticalScroll() return 0 end
function methods.GetBottom() return 100 end
function methods.SetLabel(self, t) self.label.text = t:upper() end

C_AddOns = {
    GetAddOnMetadata = function(_, field)
        if field == "Version" then return "9.9.9" end
        if field == "X-Website" then return "https://github.com/paradosi/FloAspectBar-Forever" end
    end,
}
local opened
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        return { panel = panel, name = name, GetID = function() return 42 end }
    end,
    RegisterAddOnCategory = function(cat) Settings.category = cat end,
    OpenToCategory = function(id) opened = id end,
}
C_Spell = { GetSpellName = function(id) return "Spell " .. id end }
FLOLIB_POSITIONS = { auto = "Automatic", lock = "Locked", unlock = "Unlocked" }
FLOLIB_SHOWBORDERS = "Show borders"
ERR_NOT_IN_COMBAT = "You can't do that while in combat"
function CloseDropDownMenus() end

---- A stand-in bar and the addon's setters, recording what they were asked

local calls = {}
local function Record(name) return function(...) table.insert(calls, { name, ... }) end end
FloAspectBar = {
    settings = { position = "auto", hiddenSpells = {} },
    globalSettings = { scale = 1, borders = true },
    availableSpells = { { id = 13163, name = "Aspect of the Monkey" }, { id = 13165, name = "Aspect of the Hawk" },
                        { id = 34074, name = "Aspect of the Viper", notOnForever = true }, { id = 5118 } },
}
FLOASPECTBAR_OPTIONS = {}
function FloAspectBar_SetPosition(_, bar, mode) bar.settings.position = mode; Record("SetPosition")(mode) end
function FloAspectBar_SetScale(v) FloAspectBar.globalSettings.scale = v; Record("SetScale")(v) end
function FloAspectBar_SetBorders(_, v) FloAspectBar.globalSettings.borders = v; Record("SetBorders")(v) end
function FloLib_ToggleSpell(_, bar, i)
    bar.settings.hiddenSpells[i] = not bar.settings.hiddenSpells[i] or nil
    Record("ToggleSpell")(i)
end
FloLib_ResetAddon = Record("ResetAddon")
FloLib_CreateMinimapButton = function() return NewWidget("Button") end
FloLib_UpdateMinimapButton = Record("UpdateMinimap")
local function Last() return calls[#calls] or {} end

---- Load Theme, Widgets and Options as the TOC and XML do

local ns = {}
for _, file in ipairs({ "Theme.lua", "Widgets.lua", "Options.lua" }) do
    assert(loadfile(file))("FloAspectBar", ns)
end
FloAspectBar_InitOptions()
check(Settings.category and Settings.category.name == "FloAspectBar Forever", "panel registered under Options > AddOns")
FloAspectBar_OpenOptions()
check(opened == 42, "FloAspectBar_OpenOptions opens it")

local panel = FloAspectBarOptions
panel:Show()

local function Walk(f, out)
    out = out or {}
    for _, c in ipairs(f.children) do table.insert(out, c); Walk(c, out) end
    return out
end
local checks, buttons, sliders = {}, {}, {}
for _, f in ipairs(Walk(panel)) do
    if f.kind == "Button" and f.label and f.label.text then
        if rawget(f, "checked") ~= nil then checks[f.label.text] = f else buttons[f.label.text] = f end
    elseif f.kind == "Slider" then table.insert(sliders, f) end
end

check(checks["Show borders"] and checks["Show borders"].checked, "borders shown as on")
check(checks["Show minimap button"] and checks["Show minimap button"].checked, "minimap button shown as on")
check(checks["Aspect of the Hawk"] and checks["Aspect of the Hawk"].checked, "aspects listed and ticked")
check(checks["Spell 5118"], "an aspect without a cached name falls back to C_Spell")
check(checks["Aspect of the Viper"] == nil, "a TBC aspect (notOnForever) is not listed")
check(buttons["AUTOMATIC"] and buttons["AUTOMATIC"].selected, "position Automatic selected")

buttons["UNLOCKED"]:Click()
check(Last()[1] == "SetPosition" and Last()[2] == "unlock", "Unlocked calls SetPosition")
check(buttons["UNLOCKED"].selected and not buttons["AUTOMATIC"].selected, "and becomes the selected one")

sliders[1]:SetValue(150)
check(Last()[1] == "SetScale" and math.abs(Last()[2] - 1.5) < 1e-9, "scale 150% calls SetScale(1.5)")

state.combat = true
sliders[1]:SetValue(80)
check(Last()[1] == "SetScale" and math.abs(Last()[2] - 1.5) < 1e-9, "in combat the scale is refused")
local shownValue = sliders[1].value
check(shownValue == 150, "and the slider springs back to 150%")
checks["Aspect of the Hawk"]:Click()
check(Last()[1] ~= "ToggleSpell" and checks["Aspect of the Hawk"].checked, "in combat an aspect can't be hidden, the tick comes back")
state.combat = false

checks["Show borders"]:Click()
check(Last()[1] == "SetBorders" and Last()[2] == false, "unticking borders calls SetBorders(false)")
checks["Aspect of the Hawk"]:Click()
check(Last()[1] == "ToggleSpell" and Last()[2] == 2 and FloAspectBar.settings.hiddenSpells[2], "unticking an aspect hides it")
checks["Show minimap button"]:Click()
check(FLOASPECTBAR_OPTIONS.minimap.hide == true, "unticking the minimap button hides it")

local reset = buttons["RESET ALL SETTINGS"]
reset:Click()
check(Last()[1] ~= "ResetAddon" and reset.label.text == "CLICK AGAIN TO RESET", "reset asks for a second click")
reset:Click()
check(Last()[1] == "ResetAddon" and Last()[2] == "FloAspectBar", "second click resets")

checks["Spell 5118"]:Click()
check(Last()[1] == "ToggleSpell" and Last()[2] == 4, "the aspect after it still toggles its own position (4)")
buttons["HELP AND BUG REPORTS"]:Click()
local dialog = FloAspectBarCopyDialog
check(dialog and dialog.shown and dialog.box.text == "https://github.com/paradosi/FloAspectBar-Forever", "help opens the link")

print(failures == 0 and "\nall passed" or ("\n" .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
