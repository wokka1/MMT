-- MMT module: Team Launch.
--
-- * Named team presets: save the current team, load one later, delete it.
-- * Restores the last team at login if the team is empty (a new profile,
--   or a client whose saved variables were reset).
-- * One key, button or /mmtteam invite that invites every team member who
--   isn't in the group yet. Nothing is invited automatically.
-- * Adds characters by name, including single-name characters (the core's
--   "add by name" insists on a first and last name).
--
-- Presets live in the module settings (M.db), so "Sync to team" copies them to
-- the other clients: each of your accounts has its own saved variables.
--
-- /mmtteam                         help
-- /mmtteam save|load|delete <name> presets
-- /mmtteam list                    the presets
-- /mmtteam invite                  invite the team
-- /mmtteam add <name> [<name>...]  add characters by name
-- /mmtteam group                   add everybody in the current group
-- /mmtteam last                    restore the last team

local MMT = MMT

local M = MMT.NewModule({
    name = "TeamLaunch",
    title = "Team Launch",
    description = "Named team presets, restore the last team, and one key or button to invite the team.",
    sync = true,
    syncExclude = { "last" },
    defaults = {
        presets = {},          -- [name] = { count = n, members = { {key, class, name, last, roles}, ... } }
        restoreLast = true,    -- fill an empty team from the last one at login
    },
})

BINDING_HEADER_MMT_TEAMLAUNCH = "Team Launch"
BINDING_NAME_MMT_TEAMLAUNCH_INVITE = "Invite the team"

local applying = false     -- true while a team is being loaded: don't save "last" then
local restored = false

---------------------------------------------------------------------------
-- Snapshot and apply
---------------------------------------------------------------------------
local function Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function TeamCount()
    local n = 0
    for _ in pairs(MMT.db.team) do n = n + 1 end
    return n
end

local function Snapshot()
    local list = {}
    for _, key in ipairs(MMT.SortedMembers()) do
        local m = MMT.db.team[key]
        if m then
            local roles = {}
            for k, v in pairs(m.roles or {}) do roles[k] = v end
            list[#list + 1] = { key = key, class = m.class, name = m.name, last = m.last, roles = roles }
        end
    end
    return list
end

local function Apply(list)
    applying = true
    MMT.ClearTeam()
    for i, e in ipairs(list) do
        MMT.AddMember(e.key, e.class, e.name, e.last)
        local m = MMT.db.team[e.key]
        if m then
            m.order = i
            if e.roles then
                m.roles = {}
                for k, v in pairs(e.roles) do m.roles[k] = v end
            end
        end
    end
    applying = false
    MMT.Fire("TEAM_CHANGED")
end

---------------------------------------------------------------------------
-- Presets
---------------------------------------------------------------------------
function M.PresetNames()
    local t = {}
    for name in pairs(M.db.presets) do t[#t + 1] = name end
    table.sort(t, function(a, b) return a:lower() < b:lower() end)
    return t
end

function M.SavePreset(name)
    name = Trim(name)
    if name == "" then return false, "Enter a name for the preset." end
    local list = Snapshot()
    if #list == 0 then return false, "The team is empty: nothing to save." end
    M.db.presets[name] = { count = #list, members = list }
    return true, ("Saved team \"%s\" (%d characters)."):format(name, #list)
end

function M.LoadPreset(name)
    name = Trim(name)
    local p = M.db.presets[name]
    if not p then return false, ("No preset called \"%s\"."):format(name) end
    Apply(p.members)
    return true, ("Loaded team \"%s\" (%d characters)."):format(name, #p.members)
end

function M.DeletePreset(name)
    name = Trim(name)
    if not M.db.presets[name] then return false, ("No preset called \"%s\"."):format(name) end
    M.db.presets[name] = nil
    return true, ("Deleted team \"%s\"."):format(name)
end

---------------------------------------------------------------------------
-- Last team
---------------------------------------------------------------------------
local saveTimer
local function SaveLast()
    saveTimer = nil
    if applying then return end
    local list = Snapshot()
    if #list > 0 then M.db.last = list end    -- never overwrite with an empty team
end

M:Listen("TEAM_CHANGED", function()
    if applying or saveTimer then return end
    saveTimer = true
    C_Timer.After(2, SaveLast)
end)

function M.RestoreLast(force)
    local list = M.db.last
    if not list or #list == 0 then return false, "There is no last team saved yet." end
    if not force and TeamCount() > 0 then return false end
    Apply(list)
    return true, ("Restored the last team (%d characters)."):format(#list)
end

local function TryRestoreAtLogin()
    if restored or not M.enabled then return end
    restored = true
    if not M.db.restoreLast then return end
    local ok, msg = M.RestoreLast(false)
    if ok then MMT.Print("%s", msg) end
end

M:Listen("LOGIN", function() C_Timer.After(2, TryRestoreAtLogin) end)
M.OnEnable = function() if MMT.db then C_Timer.After(3, TryRestoreAtLogin) end end

---------------------------------------------------------------------------
-- Invite the team
---------------------------------------------------------------------------
local function CanLead()
    return not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function M.InviteTeam()
    if not CanLead() then MMT.Print("Only the group leader can invite.") return end
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    local sent, inGroup, total = 0, 0, 0
    for _, key in ipairs(MMT.SortedMembers()) do
        if not MMT.IsSelf(key) then
            total = total + 1
            if MMT.UnitForMember(key) then
                inGroup = inGroup + 1
            elseif pcall(invite, MMT.WhisperTarget(key)) then
                sent = sent + 1
            end
        end
    end
    if total == 0 then
        MMT.Print("The team has no other members. Add some in /mmt > Team or with /mmtteam add <name>.")
    elseif sent > 0 then
        MMT.Print("Invited %d team member(s).", sent)
    elseif inGroup == total then
        MMT.Print("The whole team is in your group already.")
    else
        MMT.Print("Couldn't invite anybody. Are they online?")
    end
    if total + 1 > 5 then
        MMT.Print("The team has more than 5 characters: convert the group to a raid to invite the rest.")
    end
end

function MMT_TeamLaunchInvite()          -- global: the key binding calls it
    if M.enabled then M.InviteTeam() end
end

---------------------------------------------------------------------------
-- Add by name
---------------------------------------------------------------------------
local function Cap(s)
    return (s:gsub("^(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

function M.AddNames(text)
    local added, skipped = 0, {}
    for tok in tostring(text or ""):gmatch("[^%s,]+") do
        local name = MMT.StripRealm and MMT.StripRealm(tok) or tok
        name = Cap(name)
        if name ~= "" then
            if MMT.Resolve(name) then
                skipped[#skipped + 1] = name
            elseif MMT.AddMember(name, nil, name) then
                added = added + 1
            end
        end
    end
    return added, skipped
end

local function ReportAdd(added, skipped)
    if added > 0 then MMT.Print("Added %d character(s) to the team.", added) end
    if #skipped > 0 then MMT.Print("Already in the team: %s", table.concat(skipped, ", ")) end
    if added == 0 and #skipped == 0 then MMT.Print("Type one or more character names.") end
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
local function Help()
    MMT.Print("Team Launch: /mmtteam save|load|delete <name>, list, invite, add <names>, group, last")
end

SLASH_MMTTEAM1 = "/mmtteam"
SlashCmdList.MMTTEAM = function(msg)
    if not M.enabled then MMT.Print("Team Launch is switched off (/mmt > Modules).") return end
    local cmd, rest = Trim(msg):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    local ok, text
    if cmd == "save" then ok, text = M.SavePreset(rest)
    elseif cmd == "load" then ok, text = M.LoadPreset(rest)
    elseif cmd == "delete" or cmd == "del" then ok, text = M.DeletePreset(rest)
    elseif cmd == "last" then ok, text = M.RestoreLast(true)
    elseif cmd == "invite" then M.InviteTeam() return
    elseif cmd == "add" then ReportAdd(M.AddNames(rest)) return
    elseif cmd == "group" then
        MMT.Print("Added %d character(s) from the group.", MMT.AddGroupMembers() or 0) return
    elseif cmd == "list" then
        local names = M.PresetNames()
        if #names == 0 then MMT.Print("No team presets saved yet.") return end
        for _, n in ipairs(names) do MMT.Print("%s (%d)", n, M.db.presets[n].count or 0) end
        return
    else Help() return end
    if text then MMT.Print("%s", text) end
end

---------------------------------------------------------------------------
-- Settings page
---------------------------------------------------------------------------
local selected

M.Page = function(self, page)
    local UI = MMT.UI
    local col = UI.Column(page, 0, 0, MMT.ConfigHelpers.COL_W)
    local presetBox, drop

    local function Say(ok, text) if text then MMT.Print("%s", text) end if drop then drop.Refresh() end end

    col:Header("Team presets")
    drop = col:Cycle("Preset",
        function()
            local t = {}
            for _, n in ipairs(M.PresetNames()) do t[#t + 1] = { text = n, value = n } end
            return t
        end,
        function() return selected end,
        function(v) selected = v; if presetBox then presetBox:SetText(v or "") end end)
    col:Button("Load selected preset", function()
        if not selected then MMT.Print("Pick a preset first.") return end
        Say(M.LoadPreset(selected))
    end)
    presetBox = col:Add(UI.EditBox(page, col.width, "Preset name (to save the current team)", function(text, box)
        Say(M.SavePreset(text)); selected = Trim(text) ~= "" and Trim(text) or selected; box:ClearFocus()
    end))
    col:Button("Save current team as preset", function()
        local name = Trim(presetBox:GetText())
        if name == "" then name = selected or "" end
        local ok, text = M.SavePreset(name)
        if ok then selected = name end
        Say(ok, text)
    end)
    col:Button("Delete selected preset", function()
        if not selected then MMT.Print("Pick a preset first.") return end
        local ok, text = M.DeletePreset(selected)
        if ok then selected = nil; presetBox:SetText("") end
        Say(ok, text)
    end)
    col:Check("Restore the last team at login when the team is empty",
        function() return M.db.restoreLast end,
        function(v) M.db.restoreLast = v and true or false end)

    col:Header("Invite")
    col:Button("Invite the team now", function() M.InviteTeam() end)
    col:Note("Also: /mmtteam invite, or a key in Esc > Options > Keybindings > MMT > Team Launch. Only characters that aren't in your group yet are invited.")

    col:Header("Add characters by name")
    col:Add(UI.EditBox(page, col.width, "Names, e.g. Wok Wokk Wo (Enter to add)", function(text, box)
        ReportAdd(M.AddNames(text)); box:SetText(""); box:ClearFocus()
    end))
    col:Note("Single names are fine. \"Add group members\" in /mmt > Team also works.")
end
