-- MMT: saved variables, profiles, export/import and conversion of older
-- saved data (MMT 0.1.x, MMT 2.0.0 test build, OMT).
--
-- MMTDB is account-wide. Every character picks a profile (default
-- "Default"), so all characters of an account share settings by default.
-- Profiles reach other accounts by export/import; /mmt sync sends the core
-- settings of the active profile (Sync.lua).

local _, ns = ...

ns.defaults = {
    -- Team & roles ---------------------------------------------------------
    team  = {},   -- [key "First-Last"] = { name, last, class, order, roles = {[role]=true} }
    roles = {},   -- [role name] = { rules = { rule, ... } }
    trade = { enabled = true, shareRoles = {} },   -- shareRoles: [role] = true, shared evenly among its members

    -- XP window ------------------------------------------------------------
    xp = {
        enabled     = true,
        locked      = false,
        showSelf    = true,
        showLevel   = true,
        clickThrough = false,    -- mouse passes through (no mouseover details)
        showRested  = true,
        layerHopNotify = true,   -- pulsing "Layer Hop" when a layer/phase switch is offered
        layerHopAuto   = false,  -- accept it automatically ...
        layerHopDelay  = 5,      -- ... after this many seconds
        followCheck    = true,   -- watch whether team characters keep following
        followWarn     = true,   -- raid warning "<Name> stopped following"
        followSound    = true,   -- raid warning sound
        followIgnoreCombat = true, -- breaks in combat only count if still not following after combat
        followCombatDelay  = 5,    -- ... this many seconds after combat
        showBars    = true,
        classColors = true,
        showGold    = true,
        goldFormat  = "GOLD",    -- GOLD: 1234g | FULL: gold, silver, copper
        showBags    = true,      -- free bag slots
        showDurability = true,
        durability  = "LOWEST",  -- LOWEST: item with the least durability | AVERAGE: all items
        font        = "Friz Quadrata",
        size        = 12,
        outline     = "OUTLINE",
        align       = "SPLIT",   -- SPLIT (name left, values right) | LEFT | CENTER | RIGHT
        pieceAlign  = "CENTER",  -- pieces lined up in columns, inside them LEFT | CENTER | RIGHT; OFF: each row flows
        width       = 325,
        barMode     = "XP",      -- XP | REP: what the bar (and its % value) shows
        barHeight   = 18,
        rowGap      = 3,         -- pixels between the rows
        bgAlpha     = 0.35,
        alpha       = 1,
        scale       = 1,
        point       = { "LEFT", "LEFT", 300, 0 },   -- vertically centred, 300 from the left edge (grows up and down)
    },

    -- FTL: macros with {FTL} = the character you are playing (FTL.lua)
    ftl = {
        enabled    = true,
        detect     = "MANUAL",  -- MANUAL: click, key, command | MOVE: moving a character on its own makes it the leader
        nameFormat = "FULL",    -- FULL "First Last" | FIRST "First" | UNIT party/raid unit ("party2")
        skipSelf   = true,      -- leave {FTL} lines out on the leader's own client
        crown      = true,      -- crown in front of the leader in the XP window
        crownSide  = "LEFT",    -- LEFT of the name | RIGHT of it
        announce   = true,      -- chat line when the leader changes
        macros = {
            { name = "FTL Follow", body = "/follow {FTL}\n/focus {FTL}" },
            { name = "FTL Assist", body = "/assist {FTL}\n/focus {FTL}" },
            -- examples for ability macros (names: at most 16 characters)
            { name = "Pri: Lesser Heal", body = "/cast [@{FTL},nodead] Lesser Heal", since = 1 },
            { name = "Dru: Heal Touch", body = "/cast [@{FTL},nodead] Healing Touch", since = 1 },
            { name = "Sha: Light Bolt", body = "/cast [@focustarget,nodead,harm] Lightning Bolt", since = 3 },
        },
    },

    -- flight paths with the team (Taxi.lua)
    taxi = {
        enabled = true,   -- take the flight path a team member picks (flight map open here)
        report  = true,   -- chat line when following a flight
        tellLeader = true, -- the leader's chat says who followed (or couldn't)
    },

    -- privacy (Privacy.lua): how characters are shown
    privacy = {
        nameMode    = "FIRST",   -- FIRST | LAST | FULL | CLASS ("Druid 1") | SLOT ("Slot 1"); everywhere in MMT
        debugFull   = true,      -- keep full names in debug logs and reports
        hideOutside = false,     -- also replace names in Blizzard frames, chat and tooltips
    },

    -- room warnings (Warnings.lua): shown on the leader's client
    warn = {
        bags        = true,   -- bags almost full
        bagsAt      = 2,      -- ... at this many free slots or fewer
        quests      = true,   -- quest log almost full
        questsAt    = 3,      -- ... at this many free quest slots or fewer
        raidWarning = true,
        sound       = false,
    },

    -- crowd control check (CC.lua)
    cc = {
        enabled     = true,   -- report when a team character can't move
        warn        = true,   -- raid warning "<Name> is stunned" (on the FTL leader's client)
        sound       = true,   -- raid warning sound
        stun        = true,   -- stuns
        fear        = true,   -- fears, charms, mind control
        incap       = true,   -- incapacitates: polymorph, sap, sleep ...
        root        = true,   -- roots
        minDuration = 2,      -- ignore effects shorter than this many seconds
    },

    -- team communication
    comm = {
        guild = false,   -- send team messages on the guild channel (all characters in one guild)
        fast  = false,   -- 1200 instead of 800 bytes per second
    },

    -- settings of modules: [moduleName] = { ... } (defaults come from the module)
    modules = {},

    -- Automations ----------------------------------------------------------
    shiftBypass = true,
    -- quest settings moved to the Quest Tracker module (profile.quests of older
    -- profiles is copied over by the module once)
    gossip   = { vendor = true, taxi = true, dialog = true },
    merchant = { sellGrey = true, repair = true, guildRepair = false, report = true, tellLeader = true, moneyFormat = "text",
                 sellRole = "", neverRole = "",          -- sell list / never-sell list (role names)
                 buy = false, buyList = {} },            -- buy list: { itemID, name, count, who }
    mail     = { enabled = true, goldTo = "", keepGold = 100 },     -- mailbox button: role items to the team, gold above keepGold
    gbank    = { enabled = true, role = "", tab = 1, gold = false, keepGold = 100 },   -- guild bank button
    -- automations
    mount    = { mount = true, dismount = true },               -- with the leader
    death    = { release = true, revive = true,                 -- team buttons under the death / corpse dialogs
                 acceptRes = { team = true, friends = false, guild = false, anyone = false },
                 acceptSummon = { team = true, friends = false, guild = false, anyone = false } },
    invites  = { friends = true, bnet = true, guild = true, team = true, whisper = true, keyword = "mybox" },
    camera   = { enabled = true, factor = 2.6 },
    distance = {
        enabled = true, locked = false, hideNoTarget = false, colorize = false,
        font = "Friz Quadrata", size = 14, outline = "OUTLINE", align = "CENTER",
        bgAlpha = 0.25, width = 90, point = { "CENTER", "CENTER", 0, -160 },
    },
}

local DEFAULT = "Default"

---------------------------------------------------------------------------
-- Table helpers
---------------------------------------------------------------------------
local function Copy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = Copy(v) end
    return t
end
ns.CopyTable = Copy

local function IsArray(t) return next(t) == nil or t[1] ~= nil end

-- Fills in missing keys. Arrays (frame points) and the team/role maps are
-- copied whole when missing, never merged element by element.
local function MergeDefaults(dst, src)
    if type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = Copy(v)
            elseif not IsArray(v) then
                MergeDefaults(dst[k], v)
            end
        elseif dst[k] == nil or type(dst[k]) ~= type(v) then
            dst[k] = v
        end
    end
end

---------------------------------------------------------------------------
-- Conversion of older profile layouts (runs on every activation/import;
-- does nothing for profiles that are already current)
---------------------------------------------------------------------------
local function KeyFromName(full)
    local first, last = full:match("^(%S+)%s+(.+)$")
    if first then return first .. "-" .. last:gsub("%s", "-"), first, last end
    first, last = full:match("^([^-]+)-(.+)$")
    if first then return full, first, last end
    return full, full, nil
end

local function ConvertProfile(p)
    -- MMT 2.0.0 test build: team = { "First Last", ... }, roles = { {name, members, grey, boe, items} }
    if type(p.team) == "table" and type(p.team[1]) == "string" then
        local team = {}
        for i, full in ipairs(p.team) do
            local key, first, last = KeyFromName(full)
            team[key] = { name = first, last = last, order = i, roles = {} }
        end
        p.team = team
    end
    if type(p.roles) == "table" and type(p.roles[1]) == "table" and p.roles[1].name then
        local roles = {}
        for _, r in ipairs(p.roles) do
            local rules = {}
            for _, id in ipairs(r.items or {}) do rules[#rules + 1] = { type = "item", itemID = id } end
            if r.grey then rules[#rules + 1] = { type = "quality", quality = 0 } end
            if r.boe then rules[#rules + 1] = { type = "boe" } end
            roles[r.name] = { rules = rules }
            for memberName in pairs(r.members or {}) do
                local key = KeyFromName(memberName)
                if p.team[key] then p.team[key].roles[r.name] = true end
            end
        end
        p.roles = roles
    end

    -- MMT 0.1.x: separate font/window tables, xp.shown, xp.point as string
    if type(p.xp) == "table" then
        local xp = p.xp
        if xp.shown ~= nil then xp.enabled = xp.shown; xp.shown = nil end
        if type(xp.point) == "string" then
            xp.point = { xp.point, xp.point, xp.x or 30, xp.y or -250 }
            xp.x, xp.y = nil, nil
        end
        if type(p.font) == "table" then
            if p.font.path then xp.font = ns.FontNameForPath(p.font.path) end
            if p.font.size then xp.size = p.font.size end
            if p.font.outline then xp.outline = (p.font.outline == "") and "NONE" or p.font.outline end
            p.font = nil
        end
        if type(p.window) == "table" then
            xp.scale = p.window.scale or xp.scale
            xp.alpha = p.window.alpha or xp.alpha
            xp.width = p.window.width or xp.width
            xp.barHeight = p.window.barHeight or xp.barHeight
            p.window = nil
        end
    end

    -- up to 0.4.2 "locked" also meant click-through
    if type(p.xp) == "table" and p.xp.clickThrough == nil and p.xp.locked ~= nil then
        p.xp.clickThrough = p.xp.locked and true or false
    end

    -- 0.1.1 stored the last name in a "realm" field
    for _, m in pairs(p.team or {}) do
        if type(m) == "table" and m.realm then
            m.last = m.last or m.realm
            m.realm = nil
        end
    end

    -- MMT 0.3.0: Item Compare settings lived in the core profile
    if type(p.compare) == "table" then
        p.modules = type(p.modules) == "table" and p.modules or {}
        p.modules.ItemCompare = p.modules.ItemCompare or p.compare
        p.compare = nil
    end

    -- give every member an order (0.1.x sorted alphabetically)
    if type(p.team) == "table" then
        local keys = {}
        for key, m in pairs(p.team) do
            if type(m) == "table" then
                m.roles = m.roles or {}
                if not m.order then keys[#keys + 1] = key end
            end
        end
        table.sort(keys)
        local max = 0
        for _, m in pairs(p.team) do if type(m) == "table" and m.order and m.order > max then max = m.order end end
        for _, key in ipairs(keys) do max = max + 1; p.team[key].order = max end
    end
end
ns.ConvertProfile = ConvertProfile
ns.MergeDefaults = MergeDefaults

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------
function ns.ProfileNames()
    local names = {}
    for name in pairs(MMTDB.profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        if a == DEFAULT then return true elseif b == DEFAULT then return false end
        return a:lower() < b:lower()
    end)
    return names
end

function ns.CurrentProfileName() return ns.profileName or DEFAULT end

-- default macros added later (since = n) go once into older profiles:
-- 1 = heal examples (0.9.40), 3 = Sha: Light Bolt (0.9.42). A macro the
-- player deleted afterwards stays deleted. (2 was "FTL Focus", 0.9.41-0.9.42.)
-- 0.9.42 also: Follow and Assist set the focus too, and "Pal: Holy Light" is
-- gone; both only where the player left the macro as MMT made it.
local OLD_DEFAULTS = {
    ["FTL Follow"] = { "/follow {FTL}", "/follow {FTL}\n/focus {FTL}" },
    ["FTL Assist"] = { "/assist {FTL}", "/assist {FTL}\n/focus {FTL}" },
    ["Pal: Holy Light"] = { "/cast [@{FTL},nodead] Holy Light", false },
}
-- 0.9.43: the standalone "FTL Focus" is gone (Follow and Assist set the focus)
local OLD_DEFAULTS_4 = { ["FTL Focus"] = { "/focus {FTL}", false } }
local function AddMacroExamples(p)
    local ftl = p.ftl
    if type(ftl) ~= "table" or type(ftl.macros) ~= "table" then return end
    local done = tonumber(ftl.examples) or 0
    local function Change(list)
        for i = #ftl.macros, 1, -1 do
            local m = ftl.macros[i]
            local change = m.name and list[m.name]
            if change and ns.Trim(m.body or "") == change[1] then
                if change[2] then m.body = change[2] else table.remove(ftl.macros, i) end
            end
        end
    end
    if done < 3 then Change(OLD_DEFAULTS) end
    if done < 4 then Change(OLD_DEFAULTS_4) end
    local have, newest = {}, done
    for _, m in ipairs(ftl.macros) do if m.name then have[m.name] = true end end
    for _, m in ipairs(ns.defaults.ftl.macros) do
        if m.since and m.since > done then
            if not have[m.name] then ftl.macros[#ftl.macros + 1] = { name = m.name, body = m.body } end
            newest = math.max(newest, m.since)
        end
    end
    ftl.examples = math.max(newest, 4)
end

local function Activate(name)
    if not MMTDB.profiles[name] then name = DEFAULT end
    local p = MMTDB.profiles[name]
    ConvertProfile(p)
    MergeDefaults(p, ns.defaults)
    AddMacroExamples(p)
    ns.db = p
    ns.profileName = name
    ns.Fire("PROFILE_CHANGED")
end

local function CharKey() return ns.PlayerFull() or "?" end

function ns.SetProfile(name)
    if not MMTDB.profiles[name] then return false end
    MMTDB.profileKeys[CharKey()] = name
    Activate(name)
    ns.Refresh()
    return true
end

-- source = table to copy, or nil for an empty profile
function ns.CreateProfile(name, source)
    name = ns.Trim(name)
    if name == "" or MMTDB.profiles[name] then return false end
    MMTDB.profiles[name] = source and Copy(source) or {}
    return true
end

function ns.CopyProfileInto(sourceName)
    local src = MMTDB.profiles[sourceName]
    if not src or sourceName == ns.profileName then return false end
    MMTDB.profiles[ns.profileName] = Copy(src)
    Activate(ns.profileName)
    ns.Refresh()
    return true
end

function ns.ResetProfile()
    MMTDB.profiles[ns.profileName] = {}
    Activate(ns.profileName)
    ns.Refresh()
end

function ns.DeleteProfile(name)
    if name == DEFAULT or not MMTDB.profiles[name] then return false end
    MMTDB.profiles[name] = nil
    for char, p in pairs(MMTDB.profileKeys) do
        if p == name then MMTDB.profileKeys[char] = DEFAULT end
    end
    if ns.profileName == name then Activate(DEFAULT) ns.Refresh() end
    return true
end

---------------------------------------------------------------------------
-- Serializer (plain text, length-prefixed; nothing is ever executed)
-- Same format as MMT 0.1.x, so old export strings still import.
---------------------------------------------------------------------------
local function ser(v, out, depth)
    if depth > 20 then return end
    local t = type(v)
    if t == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "number" then
        out[#out + 1] = "n" .. tostring(v) .. ";"
    elseif t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, x in pairs(v) do
            local kt, xt = type(k), type(x)
            if (kt == "string" or kt == "number")
                and (xt == "string" or xt == "number" or xt == "boolean" or xt == "table") then
                ser(k, out, depth + 1)
                ser(x, out, depth + 1)
            end
        end
        out[#out + 1] = "}"
    end
end

function ns.Serialize(v)
    local out = {}
    ser(v, out, 0)
    return table.concat(out)
end

local function deser(s, i, depth)
    if depth > 20 then error("too deep") end
    local c = s:sub(i, i)
    if c == "s" then
        local len, e = s:match("^(%d+):()", i + 1)
        if not len then error("bad string") end
        len = tonumber(len)
        local str = s:sub(e, e + len - 1)
        if #str ~= len then error("truncated") end
        return str, e + len
    elseif c == "n" then
        local num, e = s:match("^([^;]*);()", i + 1)
        local n = num and tonumber(num)
        if not n then error("bad number") end
        return n, e
    elseif c == "T" then
        return true, i + 1
    elseif c == "F" then
        return false, i + 1
    elseif c == "{" then
        local t = {}
        i = i + 1
        while s:sub(i, i) ~= "}" do
            if i > #s then error("unterminated") end
            local k, v
            k, i = deser(s, i, depth + 1)
            if type(k) ~= "string" and type(k) ~= "number" then error("bad key") end
            v, i = deser(s, i, depth + 1)
            t[k] = v
        end
        return t, i + 1
    end
    error("bad token")
end

function ns.Deserialize(s)
    s = ns.Trim(s)
    local ok, v, pos = pcall(deser, s, 1, 0)
    if ok and pos == #s + 1 then return v end
    return nil
end

function ns.ExportProfile()
    return "MMT1:" .. ns.Serialize({ name = ns.CurrentProfileName(), data = ns.db })
end

-- returns name, data (or nil)
function ns.ParseExport(str)
    local body = ns.Trim(str):match("^MMT1:(.*)$")
    if not body then return nil end
    local t = ns.Deserialize(body)
    if type(t) ~= "table" then return nil end
    if type(t.name) == "string" and type(t.data) == "table" then
        return t.name, t.data, type(t.modules) == "table" and t.modules or nil,
            type(t.moduleSettings) == "table" and t.moduleSettings or nil
    end
    if t.team or t.xp then return "Imported", t end -- 2.0.0 test build strings
    return nil
end

-- Stores data under name (overwrites a profile with that name) and,
-- if wanted, activates it for this character.
function ns.ImportProfile(name, data, activate)
    name = ns.Trim(name)
    if name == "" or type(data) ~= "table" then return false end
    MMTDB.profiles[name] = data
    ConvertProfile(data)
    MergeDefaults(data, ns.defaults)
    if activate then ns.SetProfile(name) end
    return true
end

-- Core settings only (team sync): the active profile without the settings
-- of modules. Window positions (XP, distance) are part of it.
-- withModules: also the settings of the modules that share theirs (sync = true);
-- the team sync adds them when every recipient is in the guild (guild channel)
function ns.ExportCoreSettings(withModules)
    local data = {}
    for k, v in pairs(ns.db) do
        if k ~= "modules" then data[k] = Copy(v) end
    end
    local moduleSettings
    if withModules and ns.SyncableModules then
        moduleSettings = {}
        for _, m in ipairs(ns.SyncableModules()) do moduleSettings[m.name] = m:SyncData() end
    end
    -- the on/off state of the modules goes along (applied, not stored in the profile)
    return "MMT1:" .. ns.Serialize({ name = ns.CurrentProfileName(), data = data, core = true,
        modules = ns.ModuleStates and ns.ModuleStates() or nil, moduleSettings = moduleSettings })
end

-- Stores core settings under name and activates that profile. The module
-- settings already in a profile of that name stay as they are (also when
-- an older MMT sent its full profile).
function ns.ImportCoreSettings(name, data)
    name = ns.Trim(name)
    if name == "" or type(data) ~= "table" then return false end
    local existing = MMTDB.profiles[name]
    data.modules = (existing and type(existing.modules) == "table") and Copy(existing.modules) or {}
    return ns.ImportProfile(name, data, true)
end

---------------------------------------------------------------------------
-- Init & migration
---------------------------------------------------------------------------
local OMT_KEYS = { "shiftBypass", "quests", "gossip", "merchant", "invites", "camera", "distance" }

local function MigrateOMT()
    if MMTDB.migratedOMT or type(OMTDB) ~= "table" or next(OMTDB) == nil then return end
    local target = MMTDB.profiles[DEFAULT]
    for _, key in ipairs(OMT_KEYS) do
        if OMTDB[key] ~= nil then target[key] = Copy(OMTDB[key]) end
    end
    MMTDB.migratedOMT = true
    ns.migratedOMT = true
    ns.justMigrated = true
end

function ns.InitDB()
    MMTDB = MMTDB or {}
    MMTDB.profiles = MMTDB.profiles or {}
    MMTDB.profileKeys = MMTDB.profileKeys or {}
    -- 2.0.0 test build used "chars" with "First Last" keys
    if type(MMTDB.chars) == "table" then
        for char, profile in pairs(MMTDB.chars) do
            local key = KeyFromName(char)
            MMTDB.profileKeys[key] = MMTDB.profileKeys[key] or profile
        end
        MMTDB.chars = nil
    end
    -- MMT 0.3.0: Item Compare's equipment database lived in MMTDB.equipment
    if type(MMTDB.equipment) == "table" then
        MMTDB.moduleData = MMTDB.moduleData or {}
        MMTDB.moduleData.ItemCompare = MMTDB.moduleData.ItemCompare or {}
        MMTDB.moduleData.ItemCompare.equipment = MMTDB.moduleData.ItemCompare.equipment or MMTDB.equipment
        MMTDB.equipment = nil
    end
    MMTDB.profiles[DEFAULT] = MMTDB.profiles[DEFAULT] or {}
    Activate(DEFAULT) -- usable right away; the character's profile is picked at login
end

function ns.SelectCharacterProfile()
    MigrateOMT() -- OMT loads after MMT, so its settings are only available now
    local key = CharKey()
    local name = MMTDB.profileKeys[key] or DEFAULT
    if not MMTDB.profiles[name] then name = DEFAULT end
    MMTDB.profileKeys[key] = name
    Activate(name)
    if ns.migratedOMT then
        ns.Print("Your OMT settings were moved into the \"Default\" profile. You can now disable OMT.")
        ns.migratedOMT = nil
    end
end
