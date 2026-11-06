-- MMT module: Buffs.
--
-- Two keys, one buff per press, so a team of boxed characters can be buffed
-- with the usual round-robin hotkeys:
--
-- * Target key (default Alt+Insert): casts the first buff from this
--   character's list that the TARGET is missing (ISBoxer assists the master first). A mage with Arcane Intellect
--   needs one press, a druid with Mark of the Wild and Thorns needs two.
-- * Group key (default Alt+Page Up): looks at you and your party members in
--   turn and casts the first buff from the list that somebody is missing.
--   Press until nothing is left to do.
--
-- Self buffs (Demon Skin, Frost Armor, ...) are a second list per class and are
-- cast on you only. The Group key does them first, then the team buffs.
--
-- Nothing is recast while it is still up, so extra presses do nothing. Spells
-- are cast by name, which uses the highest rank you know: a new rank is picked
-- up as soon as it is learned. Out of combat only.
--
-- /mmtbuff                 status and the buff list
-- /mmtbuff add <spell>     add a spell to this class's list
-- /mmtbuff remove <spell>  remove one
-- /mmtbuff addself <spell> add a spell to this class's self buff list
-- /mmtbuff removeself <spell>  remove one
-- /mmtbuff resetself       empty the self buff list
-- /mmtbuff reset           back to the default list
-- /mmtbuff debug          print every buff key press that reaches this character
-- /mmtbuff test            say what the next press of each key would cast

local MMT = MMT
local VERSION = "1.1.6"      -- keep in step with MMT_Buffs.toc; shown at the top of /mmt > Buffs

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
        selfBuffs = {},              -- [CLASS] = { spell names } cast on yourself only; no defaults
        keyTarget = "ALT-INSERT",
        keyGroup = "ALT-PAGEUP",
        sayOom = true,               -- say in party chat when out of mana for the next buff
    },
})

BINDING_HEADER_MMT_BUFFS = "Buffs"
_G["BINDING_NAME_CLICK MMTBuffTarget:LeftButton"] = "Buff target"
_G["BINDING_NAME_CLICK MMTBuffGroup:LeftButton"] = "Buff group"

local function ClassToken() return (select(2, UnitClass("player"))) end

function M.List(class)
    class = class or ClassToken()
    local l = M.db and M.db.buffs and M.db.buffs[class]
    if l then return l end                  -- an explicit list, even an empty one
    return DEFAULT_BUFFS[class] or {}
end

function M.SelfList(class)
    class = class or ClassToken()
    local t = M.db and M.db.selfBuffs
    return (t and t[class]) or {}
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

-- The first self buff you are missing, or nil. Cast on yourself, so no range check.
local function PickSelf()
    for _, spell in ipairs(M.SelfList()) do
        if Known(spell) and CanBuff("player") and HasBuff("player", spell) == false then
            return spell, "player"
        end
    end
end

-- Out of mana for this spell? (only mana costs are checked)
local function ShortOfMana(spell)
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spell)
    if not ok or type(costs) ~= "table" then return false end
    for _, c in ipairs(costs) do
        if c.type == 0 and (c.cost or 0) > 0 then
            -- Newer clients return "secret" numbers here; comparing one is a Lua error
            -- (that error used to abort the whole key press). Can't compare -> not short.
            local power = UnitPower("player", 0)
            if issecretvalue and (issecretvalue(power) or issecretvalue(c.cost)) then return false end
            return (power or 0) < c.cost
        end
    end
    return false
end

local lastOom = 0
local function SayOom(spell)
    if not (M.db and M.db.sayOom) or not IsInGroup() then return end
    local now = GetTime()
    if now - lastOom < 30 then return end       -- the keys get pressed many times in a row
    lastOom = now
    pcall(SendChatMessage, ("Out of mana, can't cast %s."):format(spell), "PARTY")
end

local function GroupUnits()
    local t = { "player" }
    for i = 1, 4 do t[#t + 1] = "party" .. i end
    return t
end

-- The unit the Target key buffs: this character's own target. The ISBoxer Buff Target key assists
-- the master first (Auto-Assist Master), which is what gives this character a target AND live
-- buff data for it. (1.1.0-1.1.5 tried reading the master's target directly; the client only
-- sends buff data for your own target and party, so it kept recasting. Rolled back in 1.1.6.)
function M.TargetUnit() return "target" end
function M.NextTarget() return Pick({ M.TargetUnit() }) end
function M.NextGroup()
    local spell, unit = PickSelf()
    if spell then return spell, unit end
    return Pick(GroupUnits())
end

---------------------------------------------------------------------------
-- Secure buttons
---------------------------------------------------------------------------
-- Debug lines go to chat AND to MMTDB.buffLog (saved on /reload or logout), so
-- they can be read from disk when the chat text can't be copied out of the game.
local function BLog(always, fmt, ...)
    if not always and not (M.db and M.db.debug) then return end
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    if M.db and M.db.debug then MMT.Print("[buff debug] %s", msg) end
    if MMTDB then
        MMTDB.buffLog = MMTDB.buffLog or {}
        local log = MMTDB.buffLog
        log[#log + 1] = date("%H:%M:%S") .. " " .. msg
        if #log > 200 then table.remove(log, 1) end
    end
end

local function MakeButton(name, pick)
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetAttribute("type", nil)
    b:SetScript("PreClick", function(self, button, down)
        BLog(false, "%s %s at %.1f, combat=%s, enabled=%s", name, down and "down" or "up", GetTime(), tostring(InCombatLockdown()), tostring(M.enabled))
        if InCombatLockdown() then return end
        if not M.enabled then self:SetAttribute("type", nil) return end
        local spell, unit = pick()
        BLog(false, "  -> %s", spell and (spell .. " on " .. tostring(UnitName(unit))) or "nothing to do")
        if M.db and M.db.debug then
            -- why: state of the unit this key looks at, and the buffs it can see on it
            local u = (name == "MMTBuffTarget") and M.TargetUnit() or (unit or "player")
            local auras = {}
            pcall(function()
                for i = 1, 40 do
                    local a = C_UnitAuras.GetAuraDataByIndex(u, i, "HELPFUL")
                    if not a then break end
                    auras[#auras + 1] = tostring(a.name)
                end
            end)
            BLog(false, "     unit=%s exists=%s name=%s friend=%s player=%s dead=%s auras=[%s] list=[%s]", u,
                tostring(UnitExists(u)), tostring(UnitName(u)), tostring(UnitIsFriend("player", u)),
                tostring(UnitIsPlayer(u)), tostring(UnitIsDeadOrGhost(u)), table.concat(auras, ","),
                table.concat(M.List(), ","))
        end
        -- A Lua error here used to abort this handler before the cast was armed (no error
        -- popup, no cast). Fail open: if the mana check breaks, cast anyway and log why.
        local short = false
        if spell then
            local okm, res = pcall(ShortOfMana, spell)
            if okm then short = res else BLog(true, "ShortOfMana ERROR: %s", tostring(res)) end
        end
        if spell and short then
            local okc, costs = pcall(C_Spell.GetSpellPowerCost, spell)
            local parts = {}
            if okc and type(costs) == "table" then
                for _, c in ipairs(costs) do parts[#parts + 1] = tostring(c.type) .. ":" .. tostring(c.cost) end
            end
            BLog(false, "     SKIPPED: short of mana. mana=%s costs=[%s]", tostring(UnitPower("player", 0)), table.concat(parts, ","))
            SayOom(spell)
            self:SetAttribute("type", nil)
        elseif spell then
            BLog(false, "     set type=spell spell=%s unit=%s (button now: %s/%s/%s)", spell, tostring(unit), tostring(self:GetAttribute("type")), tostring(self:GetAttribute("spell")), tostring(self:GetAttribute("unit")))
            self:SetAttribute("type", "spell")
            self:SetAttribute("spell", spell)
            self:SetAttribute("unit", unit)
            M.lastSpell, M.lastTime = spell, GetTime()
        else
            self:SetAttribute("type", nil)
        end
    end)
    return b
end

MakeButton("MMTBuffTarget", M.NextTarget)
MakeButton("MMTBuffGroup", M.NextGroup)

-- Debug only: what happens to the cast after the button picks a spell (who it
-- was sent at, whether it failed and why). Written to MMTDB.buffLog too.
local castLog = CreateFrame("Frame")
for _, ev in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
                      "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED",
                      "UI_ERROR_MESSAGE" }) do
    castLog:RegisterEvent(ev)
end
castLog:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
    -- The client reports "Not enough mana" right after the click that cast. Use that to
    -- warn the party, since the mana level itself may be unreadable (secret value).
    if event == "UI_ERROR_MESSAGE" and M.lastSpell and GetTime() - (M.lastTime or 0) < 2 then
        local okm, isOom = pcall(function() return a2 == ERR_OUT_OF_MANA end)
        if okm and isOom then SayOom(M.lastSpell) end
    end
    if not (M.db and M.db.debug) then return end
    if event == "UI_ERROR_MESSAGE" then
        BLog(false, "     [%s] code=%s text=%s", event, tostring(a1), tostring(a2))
    elseif a1 == "player" then
        local sp = a4 and C_Spell.GetSpellName and C_Spell.GetSpellName(a4) or tostring(a4)
        BLog(false, "     [%s] spell=%s target/arg=%s", event, tostring(sp), tostring(a2))
    end
end)

-- Keys: override bindings, re-applied at login and after combat, so no manual
-- keybinding setup is needed on each character. Remove a key in /mmt > Buffs.
local owner = CreateFrame("Frame")
local function ApplyKeys()
    if InCombatLockdown() then BLog(true, "ApplyKeys skipped: in combat") return end
    ClearOverrideBindings(owner)
    BLog(true, "ApplyKeys: enabled=%s keyTarget=%s keyGroup=%s", tostring(M.enabled), tostring(M.db and M.db.keyTarget), tostring(M.db and M.db.keyGroup))
    if not M.enabled or not M.db then return end
    if M.db.keyTarget ~= "" then SetOverrideBindingClick(owner, true, M.db.keyTarget, "MMTBuffTarget") end
    if M.db.keyGroup ~= "" then SetOverrideBindingClick(owner, true, M.db.keyGroup, "MMTBuffGroup") end
    -- ISBoxer can only send these as the numpad scancodes (Num 0 / Num 9), which the game sees as NUMPAD keys
    if M.db.keyTarget == "ALT-INSERT" then SetOverrideBindingClick(owner, true, "ALT-NUMPAD0", "MMTBuffTarget") end
    if M.db.keyGroup == "ALT-PAGEUP" then SetOverrideBindingClick(owner, true, "ALT-NUMPAD9", "MMTBuffGroup") end
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
    for _, s in ipairs(M.List(class)) do l[#l + 1] = s end
    fn(l)
    M.db.buffs[class] = l
end

local function EditSelf(fn, class)
    class = class or ClassToken()
    local l = {}
    for _, s in ipairs(M.SelfList(class)) do l[#l + 1] = s end
    fn(l)
    M.db.selfBuffs = M.db.selfBuffs or {}
    M.db.selfBuffs[class] = l
end

local function AddTo(l, spell)
    for _, s in ipairs(l) do if s:lower() == spell:lower() then return end end
    l[#l + 1] = spell
end

local function RemoveFrom(l, spell)
    for i = #l, 1, -1 do if l[i]:lower() == spell:lower() then table.remove(l, i) end end
end

local function Listing(l) return #l > 0 and table.concat(l, ", ") or "(empty)" end

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
    elseif cmd == "addself" and rest ~= "" then
        EditSelf(function(l) AddTo(l, rest) end)
        MMT.Print("Self buff list: %s", Listing(M.SelfList()))
    elseif cmd == "removeself" and rest ~= "" then
        EditSelf(function(l) RemoveFrom(l, rest) end)
        MMT.Print("Self buff list: %s", Listing(M.SelfList()))
    elseif cmd == "resetself" then
        EditSelf(function(l) wipe(l) end)
        MMT.Print("Self buff list: %s", Listing(M.SelfList()))
    elseif cmd == "reset" then
        M.db.buffs[ClassToken()] = nil
        MMT.Print("Buff list: %s", #M.List() > 0 and table.concat(M.List(), ", ") or "(empty)")
    elseif cmd == "debug" then
        M.db.debug = not M.db.debug
        MMT.Print("Buff key debug is %s. Every press of the buff keys that reaches this character is printed.", M.db.debug and "ON" or "off")
    elseif cmd == "why" then
        local out = {}
        local function Say(fmt, ...)
            local line = fmt:format(...)
            out[#out + 1] = line
            MMT.Print("%s", line)
        end
        Say("MMT_Buffs code version %s", VERSION)
        Say("%s, class %s, level %s", UnitName("player"), tostring(ClassToken()), tostring(UnitLevel("player")))
        do   -- the Target key: whose target does it look at, and why would it pick nothing?
            local lk = MMT.FTLLeader and MMT.FTLLeader()
            local tu = M.TargetUnit()
            local okf, fu = pcall(MMT.UnitForMember or function() end, lk)
            Say("TARGET KEY: leader=%s isSelf=%s UnitForMember=%s -> looks at '%s'", tostring(lk),
                tostring(MMT.IsSelf and lk and MMT.IsSelf(lk)), okf and tostring(fu) or ("err " .. tostring(fu)), tu)
            Say("  exists=%s name=%s friend=%s player=%s dead=%s connected=%s", tostring(UnitExists(tu)), tostring(UnitName(tu)),
                tostring(UnitIsFriend("player", tu)), tostring(UnitIsPlayer(tu)), tostring(UnitIsDeadOrGhost(tu)), tostring(UnitIsConnected(tu)))
            for _, spell in ipairs(M.List()) do
                Say("  %s: known=%s buffed=%s inRange=%s canBuff=%s", spell, tostring(Known(spell)),
                    tostring(HasBuff(tu, spell)), tostring(InRange(spell, tu)), tostring(CanBuff(tu)))
            end
            local function AuraNames(u)
                local names = {}
                pcall(function()
                    for i = 1, 40 do
                        local a = C_UnitAuras.GetAuraDataByIndex(u, i, "HELPFUL")
                        if not a then break end
                        names[#names + 1] = tostring(a.name) .. "#" .. tostring(a.spellId) .. (a.sourceUnit and "" or "")
                    end
                end)
                return table.concat(names, ", ")
            end
            for _, u in ipairs({ "player", "party1", "party2", "party3", tu }) do
                if UnitExists(u) then Say("  AURAS on %s (%s): %s", u, tostring(UnitName(u)), AuraNames(u)) end
            end
            for _, spell in ipairs(M.List()) do
                local okI, info = pcall(C_Spell.GetSpellInfo, spell)
                Say("  spell '%s' -> name=%s id=%s", spell, okI and info and tostring(info.name) or "?", okI and info and tostring(info.spellID) or "?")
            end
            local s1, u1 = M.NextTarget()
            Say("  Target key would cast: %s", s1 and (s1 .. " on " .. tostring(UnitName(u1))) or "nothing")
        end
        Say("self list: %s", Listing(M.SelfList()))
        for _, spell in ipairs(M.SelfList()) do
            Say("  %s: known=%s buffed=%s", spell, tostring(Known(spell)), tostring(HasBuff("player", spell)))
        end
        Say("list: %s", table.concat(M.List(), ", "))
        for _, spell in ipairs(M.List()) do
            Say("%s: known=%s", spell, tostring(Known(spell)))
            for _, unit in ipairs(GroupUnits()) do
                if UnitExists(unit) then
                    Say("  %s: friend=%s player=%s dead=%s buffed=%s inRange=%s", UnitName(unit),
                        tostring(UnitIsFriend("player", unit)), tostring(UnitIsPlayer(unit)),
                        tostring(UnitIsDeadOrGhost(unit)), tostring(HasBuff(unit, spell)), tostring(InRange(spell, unit)))
                end
            end
        end
        M.db.lastWhy = out      -- saved with the settings on /reload or logout, so it can be read from the file
    elseif cmd == "test" then
        local s, u = M.NextTarget()
        MMT.Print("Target key would cast: %s", s and (s .. " on " .. UnitName(u)) or "nothing")
        s, u = M.NextGroup()
        MMT.Print("Group key would cast: %s", s and (s .. " on " .. UnitName(u)) or "nothing")
    else
        MMT.Print("MMT_Buffs version %s", VERSION)
        MMT.Print("Buffs (%s): %s", ClassToken() or "?", #M.List() > 0 and table.concat(M.List(), ", ") or "(nothing for this class)")
        MMT.Print("Self buffs (%s): %s", ClassToken() or "?", Listing(M.SelfList()))
        MMT.Print("Keys: target %s, group %s. /mmtbuff add|remove <spell>, addself|removeself <spell>, reset, resetself, test", M.db.keyTarget, M.db.keyGroup)
    end
end

---------------------------------------------------------------------------
-- Settings page
---------------------------------------------------------------------------
M.Page = function(self, page)
    local UI = MMT.UI
    local col = UI.Column(page, 0, 0, MMT.ConfigHelpers.COL_W)
    col:Header("Buffs  -  version " .. VERSION)
    col:Header("Keys")
    col:Add(UI.EditBox(page, col.width, "Target key (e.g. ALT-INSERT; empty = none)", function(text, box)
        M.db.keyTarget = Trim(text):upper(); ApplyKeys(); box:ClearFocus()
    end)):SetText(M.db.keyTarget)
    col:Add(UI.EditBox(page, col.width, "Group key (e.g. ALT-PAGEUP; empty = none)", function(text, box)
        M.db.keyGroup = Trim(text):upper(); ApplyKeys(); box:ClearFocus()
    end)):SetText(M.db.keyGroup)
    col:Check("Say in party chat when out of mana for a buff", function() return M.db.sayOom end, function(v) M.db.sayOom = v and true or false end)
    col:Note("Target key: buffs your target, one buff per press. Group key: casts your self buffs first, then buffs you and your party one person at a time, one buff per press. Nothing already buffed is recast, and nothing is cast in combat.")
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
    local SELF_SUGGEST = {
        DRUID   = { "Thorns", "Omen of Clarity" },
        HUNTER  = { "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah" },
        MAGE    = { "Frost Armor", "Ice Armor", "Mage Armor", "Ice Barrier", "Mana Shield" },
        PALADIN = { "Devotion Aura", "Retribution Aura", "Seal of Righteousness" },
        PRIEST  = { "Inner Fire", "Shadowguard" },
        SHAMAN  = { "Lightning Shield", "Water Shield" },
        WARLOCK = { "Demon Skin", "Demon Armor", "Fel Armor", "Unending Breath" },
        WARRIOR = { "Battle Shout" },
    }
    local function ClassName(c) return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or c end
    local class, picked, chosen = ClassToken() or "MAGE", nil, nil
    local classDrop, buffDrop, suggestDrop, addBox

    -- right-hand column: every class's list, as the team will use them
    local right = UI.Column(page, MMT.ConfigHelpers.COL2_X, 0, MMT.ConfigHelpers.COL_W)
    right:Header("Buffs set up for the team")
    local pool, used = {}, 0
    local ROWH = 20
    local function Row()
        used = used + 1
        local r = pool[used]
        if not r then
            r = CreateFrame("Frame", nil, page)
            r:SetSize(right.width, ROWH)
            r.bg = r:CreateTexture(nil, "BACKGROUND")
            r.bg:SetAllPoints()
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(16, 16)
            r.icon:SetPoint("LEFT", 6, 0)
            r.text = UI.Label(r, "", "GameFontHighlight")
            r.text:SetPoint("LEFT", 28, 0)
            r.del = UI.TextButton(r, "x", nil, 22)
            r.del:SetPoint("RIGHT", -2, 0)
            pool[used] = r
        end
        r:Show()
        r.del:Show()
        return r
    end
    local ShowAll
    local selfPicked
    local selfDrop, selfAddBox, selfSuggestDrop, selfChosen
    local function Changed()
        selfPicked, selfChosen = nil, nil
        if selfDrop then selfDrop.Refresh() end
        if selfSuggestDrop then selfSuggestDrop.Refresh() end
        picked, chosen = nil, nil
        if buffDrop then buffDrop.Refresh() end
        if suggestDrop then suggestDrop.Refresh() end
        ShowAll()
    end
    ShowAll = function()
        used = 0
        for _, r in ipairs(pool) do r:Hide() end
        local y, any = right.y, false
        local function Section(title, get, edit, clear)
            local rows = {}
            for _, c in ipairs(CLASSES) do
                if #get(c) > 0 then rows[#rows + 1] = c end
            end
            if title then
                local r = Row()
                r:SetPoint("TOPLEFT", page, "TOPLEFT", right.x, y)
                r.bg:SetColorTexture(0, 0, 0, 0)
                r.icon:SetTexture(nil)
                r.text:SetText("|cffffd100" .. title .. "|r")
                r.text:SetPoint("LEFT", 6, 0)
                r.del:Hide()
                y = y - ROWH - 2
            end
            for _, c in ipairs(rows) do
                any = true
                local l = get(c)
                local col = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]) or { r = 1, g = 1, b = 1 }
                local h = Row()
                h:SetPoint("TOPLEFT", page, "TOPLEFT", right.x, y)
                h.bg:SetColorTexture(col.r, col.g, col.b, 0.22)
                h.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                local co = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[c]
                if co then h.icon:SetTexCoord(unpack(co)) else h.icon:SetTexCoord(0, 1, 0, 1) end
                h.text:SetPoint("LEFT", 28, 0)
                h.text:SetText(("|cff%02x%02x%02x%s|r  |cff888888(%d)|r"):format(math.floor(col.r * 255), math.floor(col.g * 255), math.floor(col.b * 255), ClassName(c), #l))
                h.del.label:SetText("clear")
                h.del:SetWidth(40)
                h.del:SetScript("OnClick", function() clear(c); Changed() end)
                y = y - ROWH - 2
                for _, n in ipairs(l) do
                    local r = Row()
                    r:SetPoint("TOPLEFT", page, "TOPLEFT", right.x, y)
                    r.bg:SetColorTexture(1, 1, 1, 0.04)
                    local ok, tex = pcall(C_Spell.GetSpellTexture, n)
                    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    r.icon:SetTexture((ok and tex) or "Interface\\Icons\\INV_Misc_QuestionMark")
                    r.text:SetPoint("LEFT", 28, 0)
                    r.text:SetText(n)
                    r.del.label:SetText("x")
                    r.del:SetWidth(22)
                    r.del:SetScript("OnClick", function()
                        edit(function(t) for i = #t, 1, -1 do if t[i] == n then table.remove(t, i) end end end, c)
                        Changed()
                    end)
                    y = y - ROWH
                end
                y = y - 8
            end
            return #rows > 0
        end
        Section(nil, M.List, Edit, function(c) M.db.buffs[c] = {} end)
        y = y - 4
        local anySelf = Section("Self buffs (cast on yourself first)", M.SelfList, EditSelf, function(c) EditSelf(function(t) wipe(t) end, c) end)
        if not any then
            local r = Row()
            r:SetPoint("TOPLEFT", page, "TOPLEFT", right.x, y)
            r.bg:SetColorTexture(0, 0, 0, 0)
            r.icon:SetTexture(nil)
            r.text:SetPoint("LEFT", 28, 0)
            r.text:SetText("|cff888888No buffs set up.|r")
            r.del:Hide()
        end
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
    col:Button("Reset this class to the default list (undoes a clear)", function() M.db.buffs[class] = nil; Changed() end)
    col:Header("Self buffs for this class")
    selfDrop = col:Cycle("Current self buffs (cast order)", function()
        local t = {}
        for _, n in ipairs(M.SelfList(class)) do t[#t + 1] = { text = n, value = n } end
        return t
    end, function() return selfPicked end, function(v) selfPicked = v end)
    col:Button("Remove the selected self buff", function()
        if not selfPicked then MMT.Print("Pick a self buff in the list first.") return end
        EditSelf(function(l) RemoveFrom(l, selfPicked) end, class)
        Changed()
    end)
    selfSuggestDrop = col:Cycle("Suggested self buffs to add", function()
        local t, have = {}, {}
        for _, n in ipairs(M.SelfList(class)) do have[n] = true end
        for _, n in ipairs(SELF_SUGGEST[class] or {}) do if not have[n] then t[#t + 1] = { text = n, value = n } end end
        return t
    end, function() return selfChosen end, function(v) selfChosen = v end)
    selfAddBox = col:Add(UI.EditBox(page, col.width, "...or type a spell name", function() end))
    col:Button("Add self buff", function()
        local text = Trim(selfAddBox:GetText())
        if text == "" then text = selfChosen or "" end
        if text == "" then MMT.Print("Pick a suggested self buff or type a spell name first.") return end
        EditSelf(function(l) AddTo(l, text) end, class)
        selfAddBox:SetText(""); selfAddBox:ClearFocus()
        MMT.Print("%s: added self buff %s.", ClassName(class), text)
        Changed()
    end)
    col:Note("Self buffs are cast on you only, before any team buff, when you press the Group key. You choose them for each class; there are no defaults. Also /mmtbuff addself <spell>.")
    col:Note("Add new buffs as you learn them. Each character uses its own class's list; use Sync to team to copy the lists to the other toons. Spells are cast by name, so the highest rank you know is used. Also /mmtbuff add <spell>, and /mmtbuff test shows what each key would cast next.")
    ShowAll()
end
