-- MMT module: Heal.
--
-- Heal keys for a boxed healer. The client hides health from addons ("secret
-- values"), so this module cannot see who is hurt: YOU choose, by key and by
-- modifier, and the module handles which unit and which spell.
--
-- Each key (default F1-F4 = party1-4, F5-F8 = party pets 1-4, F9 = yourself)
-- heals one unit. The spell depends on the modifier held, all configurable:
--   plain press   Rejuvenation        (cheap HoT, top-up)
--   Shift         Healing Touch       (the big heal)
--   Ctrl          Regrowth            (skipped when not learned or left empty)
--   Alt           empty
-- Spells are cast by name (highest rank known). Everything is plain secure
-- attributes, so it works IN COMBAT. The price: no aura logic in combat (Rejuvenation
-- is simply recast, which refreshes it).
--
-- A unit is "party1".."party4", "partypet1".., "player", "pet", or a character name
-- ("Wokka-Zha"), which is looked up in your group and re-resolved when the group changes
-- (out of combat) so a key keeps following the same character.
--
-- /mmtheal                       show keys and spells
-- /mmtheal spell <plain|shift|ctrl|alt> <spell>   set (no spell = empty)
-- /mmtheal key <slot#> <KEY> [unit]               e.g. /mmtheal key 1 F1 party1
-- /mmtheal slot <slot#> <unit>                    change only the unit
-- /mmtheal unbind <slot#>     /mmtheal add <KEY> <unit>
-- /mmtheal reset | on | off | test
-- /mmtheal check | combat | clear   (diagnostics: can health be read?)

local MMT = MMT

local DEFAULT_SLOTS = {
    { key = "F1", unit = "party1" }, { key = "F2", unit = "party2" },
    { key = "F3", unit = "party3" }, { key = "F4", unit = "party4" },
    { key = "F5", unit = "partypet1" }, { key = "F6", unit = "partypet2" },
    { key = "F7", unit = "partypet3" }, { key = "F8", unit = "partypet4" },
    { key = "F9", unit = "player" },
}
local DEFAULT_SPELLS = { plain = "Rejuvenation", shift = "Healing Touch", ctrl = "", alt = "" }
local PRESS = { { "plain", "" }, { "shift", "shift-" }, { "ctrl", "ctrl-" }, { "alt", "alt-" } }
local HEALERS = { DRUID = true, PRIEST = true, PALADIN = true, SHAMAN = true }
local MAXSLOTS = 16

local M = MMT.NewModule({
    name = "Heal",
    title = "Heal",
    description = "Heal keys for a boxed healer: F-keys pick the unit, the modifier picks the spell.",
    sync = false,
    defaults = { active = nil, slots = nil, spells = nil },
})

BINDING_HEADER_MMT_HEAL = "Heal"

local function Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function Class() return (select(2, UnitClass("player"))) end

function M.Active()
    if not M.db then return false end
    if M.db.active ~= nil then return M.db.active end
    return HEALERS[Class()] or false
end

function M.Slots()
    return (M.db and M.db.slots) or DEFAULT_SLOTS
end

function M.Spells()
    local t = {}
    for k, v in pairs(DEFAULT_SPELLS) do t[k] = v end
    if M.db and M.db.spells then
        for k, v in pairs(M.db.spells) do t[k] = v end
    end
    return t
end

local function EditSlots(fn)
    local s = {}
    for i, v in ipairs(M.Slots()) do s[i] = { key = v.key, unit = v.unit } end
    fn(s)
    M.db.slots = s
end

---------------------------------------------------------------------------
-- Unit resolution
---------------------------------------------------------------------------
local LITERAL = { player = true, pet = true, target = true, focus = true, mouseover = true }
local function IsLiteral(spec)
    local s = spec:lower()
    return LITERAL[s] or s:match("^party%d$") or s:match("^partypet%d$") or s:match("^raid%d+$") or s:match("^raidpet%d+$")
end

-- "Wokka-Zha" -> "party2" (or nil when that character is not in the group right now)
local function Resolve(spec)
    spec = Trim(spec)
    if spec == "" then return nil end
    if IsLiteral(spec) then return spec:lower() end
    local want = spec:lower()
    local units = { "player" }
    for i = 1, 4 do units[#units + 1] = "party" .. i end
    for _, u in ipairs(units) do
        if UnitExists(u) then
            local ok, full = pcall(GetUnitName, u, true)
            local ok2, name, realm = pcall(UnitName, u)
            if ok and type(full) == "string" and not (issecretvalue and issecretvalue(full)) and full:lower() == want then return u end
            if ok2 and type(name) == "string" and not (issecretvalue and issecretvalue(name)) then
                if name:lower() == want then return u end
                if type(realm) == "string" and realm ~= "" and (name .. "-" .. realm):lower() == want then return u end
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Secure buttons: one per slot, configured out of combat
---------------------------------------------------------------------------
local buttons = {}
local function Button(i)
    if not buttons[i] then
        local b = CreateFrame("Button", "MMTHeal" .. i, UIParent, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyDown", "AnyUp")
        buttons[i] = b
        _G["BINDING_NAME_CLICK MMTHeal" .. i .. ":LeftButton"] = "Heal slot " .. i
    end
    return buttons[i]
end

local owner = CreateFrame("Frame")
local pending = false
local resolved = {}                         -- [slot] = unit actually used, for /mmtheal

local function Apply()
    if InCombatLockdown() then pending = true return end
    pending = false
    ClearOverrideBindings(owner)
    wipe(resolved)
    local slots = M.Slots()
    for i = 1, MAXSLOTS do
        local b = Button(i)
        for _, p in ipairs(PRESS) do
            b:SetAttribute(p[2] .. "type1", nil)
            b:SetAttribute(p[2] .. "macrotext1", nil)
        end
        b:SetAttribute("type1", nil)
        local s = slots[i]
        if M.enabled and M.Active() and s and s.key and s.key ~= "" then
            local unit = Resolve(s.unit)
            resolved[i] = unit
            if unit then
                local spells = M.Spells()
                for _, p in ipairs(PRESS) do
                    local sp = Trim(spells[p[1]])
                    if sp == "" then
                        b:SetAttribute(p[2] .. "type1", "")          -- "" (not nil): no fallback to the plain press
                    else
                        b:SetAttribute(p[2] .. "type1", "macro")
                        b:SetAttribute(p[2] .. "macrotext1", ("/cast [@%s,help,nodead] %s"):format(unit, sp))
                    end
                end
                local key = s.key:upper()
                SetOverrideBindingClick(owner, true, key, "MMTHeal" .. i, "LeftButton")
                for _, p in ipairs(PRESS) do
                    if p[2] ~= "" and Trim(spells[p[1]]) ~= "" and not key:find("-", 1, true) then
                        SetOverrideBindingClick(owner, true, p[2]:upper() .. key, "MMTHeal" .. i, "LeftButton")
                    end
                end
            end
        end
    end
end
M.Apply = Apply

owner:RegisterEvent("PLAYER_LOGIN")
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:RegisterEvent("GROUP_ROSTER_UPDATE")
owner:RegisterEvent("UNIT_NAME_UPDATE")
owner:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    C_Timer.After(1, Apply)
end)
M.OnEnable = function() C_Timer.After(1, Apply) end
M.OnDisable = function() Apply() end
M.OnProfileChanged = function() C_Timer.After(0.5, Apply) end

---------------------------------------------------------------------------
-- Diagnostics: can health be read? (the answer on this client: no, it is secret)
---------------------------------------------------------------------------
local function Log(fmt, ...)
    local line = ("%s " .. fmt):format(date("%H:%M:%S"), ...)
    MMT.Print("%s", line)
    MMTDB = MMTDB or {}
    MMTDB.healLog = MMTDB.healLog or {}
    local l = MMTDB.healLog
    l[#l + 1] = line
    while #l > 300 do table.remove(l, 1) end
end

local function Show(v)
    if v == nil then return "nil" end
    if issecretvalue and issecretvalue(v) then return "SECRET" end
    return tostring(v)
end

local function Check(tag)
    Log("== %s  combat=%s", tag, tostring(UnitAffectingCombat("player")))
    for _, u in ipairs({ "player", "target", "party1", "party2", "party3", "party4", "pet",
                         "partypet1", "partypet2", "partypet3", "partypet4" }) do
        if UnitExists(u) then
            local okH, h = pcall(UnitHealth, u)
            local okM, m = pcall(UnitHealthMax, u)
            Log("%s %s hp=%s max=%s", u, Show(UnitName(u)), okH and Show(h) or "err", okM and Show(m) or "err")
        end
    end
end

local armed
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:SetScript("OnEvent", function()
    if not (armed and M.enabled) then return end
    armed = false
    Check("combat start")
    for _, t in ipairs({ 1, 3, 6 }) do C_Timer.After(t, function() Check("combat +" .. t .. "s") end) end
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
local function Status()
    MMT.Print("Heal is %s (%s).", M.Active() and "ACTIVE" or "inactive on this character (/mmtheal on)", Class() or "?")
    local sp = M.Spells()
    for _, p in ipairs(PRESS) do
        MMT.Print("  %s: %s", p[1], sp[p[1]] ~= "" and sp[p[1]] or "(empty)")
    end
    for i, s in ipairs(M.Slots()) do
        MMT.Print("  slot %d: %s -> %s%s", i, s.key, s.unit, resolved[i] and resolved[i] ~= s.unit:lower() and (" (now " .. resolved[i] .. ")") or (resolved[i] and "" or "  [not in group]"))
    end
end

SLASH_MMTHEAL1 = "/mmtheal"
SlashCmdList.MMTHEAL = function(msg)
    if not M.enabled then MMT.Print("Heal is switched off (/mmt > Modules).") return end
    local cmd, rest = Trim(msg):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "check" then Check("manual")
    elseif cmd == "combat" then armed = true MMT.Print("armed: the check runs at the start of the next fight.")
    elseif cmd == "clear" then if MMTDB then MMTDB.healLog = {} end MMT.Print("log cleared.")
    elseif cmd == "spell" then
        local kind, sp = rest:match("^(%S+)%s*(.-)$")
        kind = kind and kind:lower()
        if not (kind and DEFAULT_SPELLS[kind]) then MMT.Print("/mmtheal spell <plain|shift|ctrl|alt> <spell name, empty to clear>") return end
        M.db.spells = M.db.spells or {}
        M.db.spells[kind] = Trim(sp)
        Apply() Status()
    elseif cmd == "key" then
        local n, key, unit = rest:match("^(%d+)%s+(%S+)%s*(.-)$")
        n = tonumber(n)
        if not n or n < 1 or n > MAXSLOTS then MMT.Print("/mmtheal key <slot#> <KEY> [unit]") return end
        EditSlots(function(s)
            for i = #s + 1, n - 1 do s[i] = s[i] or { key = "", unit = "" } end
            s[n] = { key = key:upper(), unit = unit ~= "" and unit or (s[n] and s[n].unit) or "party" .. n }
        end)
        Apply() Status()
    elseif cmd == "slot" then
        local n, unit = rest:match("^(%d+)%s+(.+)$")
        n = tonumber(n)
        if not n or not M.Slots()[n] then MMT.Print("/mmtheal slot <slot#> <unit or character name>") return end
        EditSlots(function(s) s[n].unit = Trim(unit) end)
        Apply() Status()
    elseif cmd == "unbind" then
        local n = tonumber(rest)
        if not n or not M.Slots()[n] then MMT.Print("/mmtheal unbind <slot#>") return end
        EditSlots(function(s) table.remove(s, n) end)
        Apply() Status()
    elseif cmd == "add" then
        local key, unit = rest:match("^(%S+)%s+(.+)$")
        if not key then MMT.Print("/mmtheal add <KEY> <unit>") return end
        if #M.Slots() >= MAXSLOTS then MMT.Print("At most %d slots.", MAXSLOTS) return end
        EditSlots(function(s) s[#s + 1] = { key = key:upper(), unit = Trim(unit) } end)
        Apply() Status()
    elseif cmd == "reset" then M.db.slots, M.db.spells = nil, nil Apply() Status()
    elseif cmd == "on" then M.db.active = true Apply() Status()
    elseif cmd == "off" then M.db.active = false Apply() Status()
    elseif cmd == "test" then
        for i, s in ipairs(M.Slots()) do
            local b = Button(i)
            MMT.Print("slot %d %s -> %s: plain=[%s] shift=[%s] ctrl=[%s]", i, s.key, tostring(resolved[i]),
                tostring(b:GetAttribute("macrotext1")), tostring(b:GetAttribute("shift-macrotext1")), tostring(b:GetAttribute("ctrl-macrotext1")))
        end
    else Status() end
end

---------------------------------------------------------------------------
-- Settings page
---------------------------------------------------------------------------
M.Page = function(self, page)
    local UI = MMT.UI
    local col = UI.Column(page, 0, 0, MMT.ConfigHelpers.COL_W)
    col:Header("Active on this character")
    col:Check("Heal keys on (default: only on healer classes)", function() return M.Active() end,
        function(v) M.db.active = v and true or false; Apply() end)
    col:Header("Spell for each kind of press")
    local labels = { plain = "Plain press", shift = "Shift + key", ctrl = "Ctrl + key", alt = "Alt + key" }
    for _, p in ipairs(PRESS) do
        local box = col:Add(UI.EditBox(page, col.width, labels[p[1]] .. " (spell name; empty = nothing)", function(text, b)
            M.db.spells = M.db.spells or {}
            M.db.spells[p[1]] = Trim(text); Apply(); b:ClearFocus()
        end))
        box:SetText(M.Spells()[p[1]])
    end
    col:Header("Keys (key and unit)")
    for i = 1, 12 do
        local s = M.Slots()[i]
        local box = col:Add(UI.EditBox(page, col.width, ("Slot %d:  KEY  unit   (e.g. F1 party1; empty = unused)"):format(i), function(text, b)
            local key, unit = Trim(text):match("^(%S+)%s*(.-)$")
            EditSlots(function(t)
                for j = #t + 1, i - 1 do t[j] = { key = "", unit = "" } end
                if key then t[i] = { key = key:upper(), unit = unit ~= "" and unit or "party" .. i }
                else t[i] = { key = "", unit = "" } end
            end)
            Apply(); b:ClearFocus()
        end))
        box:SetText(s and s.key ~= "" and (s.key .. " " .. s.unit) or "")
    end
    col:Note("The game hides health from addons, so the module can't pick who needs healing: you choose with the key, and the press kind (plain / Shift / Ctrl / Alt) picks the spell. Works in combat. A unit is party1-4, partypet1-4, player, pet, or a character name like Wokka-Zha (kept pointing at that character as the group changes). Also /mmtheal.")
end
