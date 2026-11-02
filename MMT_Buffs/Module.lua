-- MMT module: Buffs.
--
-- Two keys, one buff per press, so a team of boxed characters can be buffed
-- with the usual round-robin hotkeys:
--
-- * Target key (default Alt+Insert): casts the first buff from this
--   character's list that the TARGET is missing. A mage with Arcane Intellect
--   needs one press, a druid with Mark of the Wild and Thorns needs two.
-- * Group key (default Alt+Page Up): looks at you and your party members in
--   turn and casts the first buff from the list that somebody is missing.
--   Press until nothing is left to do.
--
-- Nothing is recast while it is still up, so extra presses do nothing. Spells
-- are cast by name, which uses the highest rank you know: a new rank is picked
-- up as soon as it is learned. Out of combat only.
--
-- /mmtbuff                 status and the buff list
-- /mmtbuff add <spell>     add a spell to this class's list
-- /mmtbuff remove <spell>  remove one
-- /mmtbuff reset           back to the default list
-- /mmtbuff test            say what the next press of each key would cast

local MMT = MMT

local DEFAULT_BUFFS = {
    MAGE   = { "Arcane Intellect" },
    DRUID  = { "Mark of the Wild", "Thorns" },
    PRIEST = { "Power Word: Fortitude" },
}

local M = MMT.NewModule({
    name = "Buffs",
    title = "Buffs",
    description = "One key buffs your target, another buffs the group one person at a time.",
    sync = true,
    defaults = {
        buffs = {},                  -- [CLASS] = { spell names }; empty = the defaults above
        keyTarget = "ALT-INSERT",
        keyGroup = "ALT-PAGEUP",
    },
})

BINDING_HEADER_MMT_BUFFS = "Buffs"
_G["BINDING_NAME_CLICK MMTBuffTarget:LeftButton"] = "Buff target"
_G["BINDING_NAME_CLICK MMTBuffGroup:LeftButton"] = "Buff group"

local function ClassToken() return (select(2, UnitClass("player"))) end

function M.List(class)
    class = class or ClassToken()
    local l = M.db and M.db.buffs and M.db.buffs[class]
    if l and #l > 0 then return l end
    return DEFAULT_BUFFS[class] or {}
end

local function Known(spell)
    local ok, info = pcall(C_Spell.GetSpellInfo, spell)
    if not ok or not info then return false end
    if C_SpellBook and C_SpellBook.IsSpellKnown and info.spellID then
        local ok2, known = pcall(C_SpellBook.IsSpellKnown, info.spellID)
        if ok2 then return known and true or false end
    end
    return true
end

-- true / false, or nil when the auras can't be read right now
local function HasBuff(unit, spell)
    local ok, res = pcall(function()
        if C_UnitAuras.GetAuraDataBySpellName then
            return C_UnitAuras.GetAuraDataBySpellName(unit, spell, "HELPFUL") ~= nil
        end
        for i = 1, 255 do
            local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not a then return false end
            if a.name == spell then return true end
        end
        return false
    end)
    if ok then return res end
    return nil
end

local function InRange(spell, unit)
    local ok, r = pcall(C_Spell.IsSpellInRange, spell, unit)
    if not ok then return true end
    return r ~= false
end

local function CanBuff(unit)
    return UnitExists(unit) and UnitIsFriend("player", unit) and UnitIsPlayer(unit)
        and not UnitIsDeadOrGhost(unit) and UnitIsConnected(unit)
end

-- The first (spell, unit) that needs casting among the units, or nil.
-- Spells are the outer loop: the first buff for everybody, then the second.
local function Pick(units)
    for _, spell in ipairs(M.List()) do
        if Known(spell) then
            for _, unit in ipairs(units) do
                if CanBuff(unit) and HasBuff(unit, spell) == false and InRange(spell, unit) then
                    return spell, unit
                end
            end
        end
    end
end

local function GroupUnits()
    local t = { "player" }
    for i = 1, 4 do t[#t + 1] = "party" .. i end
    return t
end

function M.NextTarget() return Pick({ "target" }) end
function M.NextGroup() return Pick(GroupUnits()) end

---------------------------------------------------------------------------
-- Secure buttons
---------------------------------------------------------------------------
local function MakeButton(name, pick)
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetAttribute("type", nil)
    b:SetScript("PreClick", function(self)
        if InCombatLockdown() then return end
        if not M.enabled then self:SetAttribute("type", nil) return end
        local spell, unit = pick()
        if spell then
            self:SetAttribute("type", "spell")
            self:SetAttribute("spell", spell)
            self:SetAttribute("unit", unit)
        else
            self:SetAttribute("type", nil)
        end
    end)
    return b
end

MakeButton("MMTBuffTarget", M.NextTarget)
MakeButton("MMTBuffGroup", M.NextGroup)

-- Keys: override bindings, re-applied at login and after combat, so no manual
-- keybinding setup is needed on each character. Remove a key in /mmt > Buffs.
local owner = CreateFrame("Frame")
local function ApplyKeys()
    if InCombatLockdown() then return end
    ClearOverrideBindings(owner)
    if not M.enabled or not M.db then return end
    if M.db.keyTarget ~= "" then SetOverrideBindingClick(owner, true, M.db.keyTarget, "MMTBuffTarget") end
    if M.db.keyGroup ~= "" then SetOverrideBindingClick(owner, true, M.db.keyGroup, "MMTBuffGroup") end
end
owner:RegisterEvent("PLAYER_LOGIN")
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:SetScript("OnEvent", function() C_Timer.After(1, ApplyKeys) end)
M.OnEnable = function() C_Timer.After(1, ApplyKeys) end
M.OnDisable = function() ApplyKeys() end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
local function Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function Edit(fn, class)
    class = class or ClassToken()
    local l = {}
    for _, s in ipairs(M.List()) do l[#l + 1] = s end
    fn(l)
    M.db.buffs[class] = l
end

SLASH_MMTBUFF1 = "/mmtbuff"
SlashCmdList.MMTBUFF = function(msg)
    if not M.enabled then MMT.Print("Buffs is switched off (/mmt > Modules).") return end
    local cmd, rest = Trim(msg):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "add" and rest ~= "" then
        Edit(function(l) for _, s in ipairs(l) do if s:lower() == rest:lower() then return end end l[#l + 1] = rest end)
        MMT.Print("Buff list: %s", table.concat(M.List(), ", "))
    elseif cmd == "remove" and rest ~= "" then
        Edit(function(l) for i = #l, 1, -1 do if l[i]:lower() == rest:lower() then table.remove(l, i) end end end)
        MMT.Print("Buff list: %s", #M.List() > 0 and table.concat(M.List(), ", ") or "(empty)")
    elseif cmd == "reset" then
        M.db.buffs[ClassToken()] = nil
        MMT.Print("Buff list: %s", #M.List() > 0 and table.concat(M.List(), ", ") or "(empty)")
    elseif cmd == "test" then
        local s, u = M.NextTarget()
        MMT.Print("Target key would cast: %s", s and (s .. " on " .. UnitName(u)) or "nothing")
        s, u = M.NextGroup()
        MMT.Print("Group key would cast: %s", s and (s .. " on " .. UnitName(u)) or "nothing")
    else
        MMT.Print("Buffs (%s): %s", ClassToken() or "?", #M.List() > 0 and table.concat(M.List(), ", ") or "(nothing for this class)")
        MMT.Print("Keys: target %s, group %s. /mmtbuff add|remove <spell>, reset, test", M.db.keyTarget, M.db.keyGroup)
    end
end

---------------------------------------------------------------------------
-- Settings page
---------------------------------------------------------------------------
M.Page = function(self, page)
    local UI = MMT.UI
    local col = UI.Column(page, 0, 0, MMT.ConfigHelpers.COL_W)
    col:Header("Keys")
    col:Add(UI.EditBox(page, col.width, "Target key (e.g. ALT-INSERT; empty = none)", function(text, box)
        M.db.keyTarget = Trim(text):upper(); ApplyKeys(); box:ClearFocus()
    end)):SetText(M.db.keyTarget)
    col:Add(UI.EditBox(page, col.width, "Group key (e.g. ALT-PAGEUP; empty = none)", function(text, box)
        M.db.keyGroup = Trim(text):upper(); ApplyKeys(); box:ClearFocus()
    end)):SetText(M.db.keyGroup)
    col:Note("Target key: buffs your target, one buff per press. Group key: buffs you and your party one person at a time, one buff per press. Nothing already buffed is recast, and nothing is cast in combat.")
    col:Header("Buffs by class")
    local CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
    local SUGGEST = {
        DRUID   = { "Mark of the Wild", "Thorns" },
        MAGE    = { "Arcane Intellect", "Dampen Magic", "Amplify Magic" },
        PALADIN = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation" },
        PRIEST  = { "Power Word: Fortitude", "Divine Spirit", "Shadow Protection" },
        WARLOCK = { "Detect Invisibility", "Unending Breath" },
        SHAMAN  = { "Water Breathing", "Water Walking" },
    }
    local function ClassName(c) return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or c end
    local class, picked, chosen = ClassToken() or "MAGE", nil, nil
    local classDrop, buffDrop, suggestDrop, addBox, allText

    -- right-hand column: every class's list, as the team will use them
    local right = UI.Column(page, MMT.ConfigHelpers.COL2_X, 0, MMT.ConfigHelpers.COL_W)
    right:Header("Buffs set up for the team")
    allText = UI.Label(page, "")
    allText:SetWidth(right.width)
    allText:SetJustifyH("LEFT")
    allText:SetJustifyV("TOP")
    allText:SetPoint("TOPLEFT", page, "TOPLEFT", right.x, right.y)
    local function ShowAll()
        local lines = {}
        for _, c in ipairs(CLASSES) do
            local l = M.List(c)
            if #l > 0 then lines[#lines + 1] = ("|cffffd100%s|r: %s"):format(ClassName(c), table.concat(l, ", ")) end
        end
        allText:SetText(#lines > 0 and table.concat(lines, "\n\n") or "(no buffs set up)")
    end
    local function Changed()
        picked, chosen = nil, nil
        if buffDrop then buffDrop.Refresh() end
        if suggestDrop then suggestDrop.Refresh() end
        ShowAll()
    end

    classDrop = col:Cycle("Class", function()
        local t = {}
        for _, c in ipairs(CLASSES) do t[#t + 1] = { text = ClassName(c), value = c } end
        return t
    end, function() return class end, function(v) class = v; Changed() end)
    buffDrop = col:Cycle("Current buffs (cast order)", function()
        local t = {}
        for _, n in ipairs(M.List(class)) do t[#t + 1] = { text = n, value = n } end
        return t
    end, function() return picked end, function(v) picked = v end)
    col:Button("Remove the selected buff", function()
        if not picked then MMT.Print("Pick a buff in the list first.") return end
        Edit(function(l) for i = #l, 1, -1 do if l[i] == picked then table.remove(l, i) end end end, class)
        Changed()
    end)
    suggestDrop = col:Cycle("Suggested buffs to add", function()
        local t, have = {}, {}
        for _, n in ipairs(M.List(class)) do have[n] = true end
        for _, n in ipairs(SUGGEST[class] or {}) do if not have[n] then t[#t + 1] = { text = n, value = n } end end
        return t
    end, function() return chosen end, function(v) chosen = v end)
    addBox = col:Add(UI.EditBox(page, col.width, "...or type a spell name", function() end))
    col:Button("Add buff", function()
        local text = Trim(addBox:GetText())
        if text == "" then text = chosen or "" end
        if text == "" then MMT.Print("Pick a suggested buff or type a spell name first.") return end
        Edit(function(l) for _, s in ipairs(l) do if s:lower() == text:lower() then return end end l[#l + 1] = text end, class)
        addBox:SetText(""); addBox:ClearFocus()
        MMT.Print("%s: added %s.", ClassName(class), text)
        Changed()
    end)
    col:Button("Reset this class to the default list", function() M.db.buffs[class] = nil; Changed() end)
    col:Note("Add new buffs as you learn them. Each character uses its own class's list; use Sync to team to copy the lists to the other toons. Spells are cast by name, so the highest rank you know is used. Also /mmtbuff add <spell>, and /mmtbuff test shows what each key would cast next.")
    ShowAll()
end
