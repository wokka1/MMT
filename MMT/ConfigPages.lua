-- MMT: the pages of the configuration window.
-- Order of registration = order of the tabs.

local _, ns = ...
local UI = ns.UI
local A = UI.ACCENT
local PAGE_W = 698
local COL_W = 330
local COL2_X = 366

local function Opt(section, key)
    return function() return ns.db[section][key] end,
           function(v) ns.db[section][key] = v end
end

-- Status line for feedback (errors in red, success in grey).
local function StatusLine(parent)
    local fs = UI.Label(parent, "")
    fs:SetJustifyH("LEFT")
    fs.Show_ = function(text, isError)
        fs:SetText(text or "")
        if isError then fs:SetTextColor(1, 0.4, 0.4) else fs:SetTextColor(0.6, 0.6, 0.6) end
    end
    return fs
end

-- Buttons that need a second click within 3 seconds to run.
local function ConfirmButton(parent, width, text, action)
    local b
    local armed = false
    b = UI.Button(parent, width, text, function()
        if armed then
            armed = false
            b.label:SetText(text)
            action()
        else
            armed = true
            b.label:SetText("Click again")
            C_Timer.After(3, function()
                if armed then armed = false; b.label:SetText(text) end
            end)
        end
    end)
    return b
end

-- A fixed pool of list rows with mouse-wheel scrolling.
local function List(parent, width, rows, rowHeight, makeRow, fillRow)
    local list = CreateFrame("Frame", nil, parent)
    list:SetSize(width, rows * rowHeight)
    list.offset = 0
    list.rows = {}
    for i = 1, rows do
        local row = makeRow(list, i)
        row:SetSize(width, rowHeight)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        list.rows[i] = row
    end
    -- arrows at the top / bottom edge while there is more to scroll to
    list.up = UI.ScrollArrow(list, "UP", function() list:GetScript("OnMouseWheel")(list, 1) end)
    list.up:SetPoint("BOTTOM", list, "TOP", 0, -1)
    list.down = UI.ScrollArrow(list, "DOWN", function() list:GetScript("OnMouseWheel")(list, -1) end)
    list.down:SetPoint("TOP", list, "BOTTOM", 0, 1)
    function list:Render(data)
        self.data = data
        self.offset = math.max(0, math.min(self.offset, #data - rows))
        self.up:SetShown(self.offset > 0)
        self.down:SetShown(self.offset < #data - rows)
        for i, row in ipairs(self.rows) do
            local index = i + self.offset
            if data[index] then
                fillRow(row, data[index], index)
                row:Show()
            else
                row:Hide()
            end
        end
    end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(self, delta)
        self.offset = self.offset - delta
        self:Render(self.data or {})
    end)
    return list
end

local function RowBackground(row, index)
    local bg = UI.Fill(row, 1, 1, 1, (index % 2 == 0) and 0.025 or 0)
    return bg
end

-- shared with modules for their own settings pages
ns.ConfigHelpers = {
    PAGE_W = PAGE_W, COL_W = COL_W, COL2_X = COL2_X,
    StatusLine = StatusLine, ConfirmButton = ConfirmButton, List = List, RowBackground = RowBackground,
}

---------------------------------------------------------------------------
-- Team
---------------------------------------------------------------------------
ns.RegisterPage("team", "Team", function(page)
    local col = UI.Column(page, 0, 0, PAGE_W)
    col:Header("Team members")
    col:Note("The characters of your team, in the order the XP window shows them. Green dot = online with MMT.")

    local list = List(page, PAGE_W, 8, 22, function(parent, i)
        local row = CreateFrame("Frame", nil, parent)
        RowBackground(row, i)
        row.dot = row:CreateTexture(nil, "ARTWORK")
        row.dot:SetSize(6, 6)
        row.dot:SetPoint("LEFT", 8, 0)
        row.name = UI.Label(row, "")
        row.name:SetPoint("LEFT", 22, 0)
        row.roles = UI.Label(row, "")
        row.roles:SetPoint("LEFT", 220, 0)
        row.roles:SetWidth(330)
        row.roles:SetJustifyH("LEFT")
        row.roles:SetWordWrap(false)
        row.roles:SetTextColor(0.55, 0.55, 0.55)
        row.remove = UI.TextButton(row, "x", function() ns.RemoveMember(row.key); ns.Refresh() end)
        row.remove:SetPoint("RIGHT", -2, 0)
        row.down = UI.TextButton(row, "Dn", function() ns.MoveMember(row.key, 1); ns.Refresh() end, 26)
        row.down:SetPoint("RIGHT", row.remove, "LEFT", -2, 0)
        row.up = UI.TextButton(row, "Up", function() ns.MoveMember(row.key, -1); ns.Refresh() end, 26)
        row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
        ns.HoverMember(row, function() return row.key end, function(tip, key)
            tip:AddLine("Team key: " .. key, 0.5, 0.5, 0.5)
        end)
        return row
    end, function(row, key)
        row.key = key
        local m = ns.db.team[key]
        row.name:SetText(ns.FirstName(key))
        local c = m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
        if c then row.name:SetTextColor(c.r, c.g, c.b) else row.name:SetTextColor(1, 1, 1) end
        if ns.IsOnline(key) then row.dot:SetColorTexture(0.3, 1, 0.3, 1) else row.dot:SetColorTexture(0.3, 0.3, 0.3, 1) end
        local roles = table.concat(ns.MemberRoleList(key), ", ")
        row.roles:SetText(roles ~= "" and roles or "no roles")
    end)
    col:Add(list, 8 * 22)
    local empty = UI.Label(page, "No team members yet. Group up and press \"Add group\", or type a name below.")
    empty:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -4)
    empty:SetTextColor(0.5, 0.5, 0.5)

    col:Space(8)
    local status
    local group = UI.Button(page, 120, "Add group", function()
        local n = ns.AddGroupMembers()
        status.Show_(n > 0 and ("Added " .. n .. " character(s) from your group.") or "Nobody new in your group.")
        ns.Refresh()
    end)
    col:Add(group, 0)
    UI.Tooltip(group, "Add group", "Adds you and everybody in your party or raid.")
    local me = UI.Button(page, 90, "Add me", function() ns.AddUnit("player"); ns.Refresh() end)
    me:SetPoint("LEFT", group, "RIGHT", 8, 0)
    local target = UI.Button(page, 100, "Add target", function()
        if UnitExists("target") and UnitIsPlayer("target") then
            ns.AddUnit("target")
            status.Show_("")
        else
            status.Show_("Target a player first.", true)
        end
        ns.Refresh()
    end)
    target:SetPoint("LEFT", me, "RIGHT", 8, 0)
    local clear = ConfirmButton(page, 120, "Remove all", function() ns.ClearTeam(); ns.Refresh() end)
    clear:SetPoint("LEFT", target, "RIGHT", 8, 0)
    col:Space(UI.ROW + 6)

    local input = UI.EditBox(page, 300, "First Last", function(text, box)
        local ok, err = ns.AddManual(text)
        if ok then box:SetText(""); box:ClearFocus(); status.Show_("Added " .. ns.Trim(text) .. ".") else status.Show_(err, true) end
        ns.Refresh()
    end)
    col:Add(input, 0)
    local add = UI.Button(page, 90, "Add", function() input:GetScript("OnEnterPressed")(input) end)
    add:SetPoint("LEFT", input, "RIGHT", 8, 0)
    col:Space(UI.ROW + 6)

    status = StatusLine(page)
    col:Add(status, UI.ROW)
    local youHover = CreateFrame("Frame", nil, page)
    youHover:SetSize(PAGE_W, UI.ROW)
    local you = UI.Label(youHover, "")
    you:SetPoint("LEFT")
    you:SetTextColor(0.5, 0.5, 0.5)
    ns.HoverMember(youHover, function() return ns.PlayerFull() end)
    col:Add(youHover, UI.ROW)
    col:Note("Every account keeps its own team. Add the team on each client, or send it with Profiles > Sync to team (/mmt sync).")

    -- two columns: communication left, privacy right
    local C = UI.Column(page, 0, col.y, COL_W)
    C:Header("Communication")
    local gg, sg = Opt("comm", "guild")
    C:Check("Use guild channel", gg, function(v)
        if v and not IsInGuild() then
            ns.Print("\"Use guild channel\" needs a guild: this character isn't in one.")
            return
        end
        sg(v)
        if v and ns.ReadGuildRoster then
            ns.ReadGuildRoster()
            if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        end
    end, "One message on the guild channel reaches every team member in your guild, grouped or not, and the guild roster shows who is online. Team members outside the guild still get whispers. Every guild member running MMT receives the messages too (and ignores them). Turn it on on every client. Needs a guild; switched off at login when this character isn't in one. With it, /mmt sync also sends the settings of the modules when everybody is in your guild.")
    local gf, sf = Opt("comm", "fast")
    C:Check("Faster sending (1200 bytes/s)", gf, sf,
        "Large transfers (settings sync, item and quest data) go out at up to 1200 instead of 800 bytes per second. Faster, but very large amounts at once can get a client disconnected.")
    local commInfo = C:Note("")

    local P = UI.Column(page, COL2_X, col.y, COL_W)
    P:Header("Privacy")
    -- "Hide names outside MMT too" hooks other addons' frames at load: switching
    -- it on or off only works fully after a UI reload, so it reloads right away
    local function AskReload(what, apply)
        UI.AskReload(what .. "\n\nOther addons only pick this up after a UI reload. Reload now?",
            function() ns.privacyReloading = true apply() end)
    end
    local gm, sm = Opt("privacy", "nameMode")
    local function SetMode(v)
        sm(v) ns.Fire("STATUS_CHANGED") if ns.PrivacyChanged then ns.PrivacyChanged() end
    end
    P:Cycle("Show characters by", {
        { value = "FIRST", text = "First name" },
        { value = "LAST", text = "Last name" },
        { value = "FULL", text = "Full name" },
        { value = "CLASS", text = "Class (Druid 1, Druid 2)" },
        { value = "SLOT", text = "Slot (Slot 1, Slot 2)" },
    }, gm, function(v)
        -- with hiding on, "Full name" switches the hiding off (and back on)
        local p = ns.db.privacy
        if p.hideOutside and (v == "FULL") ~= (p.nameMode == "FULL") then
            AskReload(v == "FULL" and "\"Full name\" switches \"Hide names outside MMT too\" off."
                or "This switches \"Hide names outside MMT too\" on again.", function() SetMode(v) end)
            return
        end
        SetMode(v)
    end)
    local gd, sd = Opt("privacy", "debugFull")
    P:Check("Keep full names in debug logs", gd, sd,
        "Off: names in the debug log and report are replaced by the names shown above (\"Slot 1\" when that is the full name). For reports you post somewhere.")
    local gh, sh = Opt("privacy", "hideOutside")
    local hideCheck = P:Check("Hide names outside MMT too", gh, function(v)
            AskReload(v and "Hide your team's names outside MMT too." or "Show your team's real names outside MMT again.",
                function() sh(v) if ns.PrivacyChanged then ns.PrivacyChanged() end end)
        end,
        "Replaces your team's names in chat, unit frames (player, target, focus, party, raid), nameplates, unit tooltips and the frames of other addons (e.g. their raid frames) with the names shown above, where the game allows it. Not with \"Full name\". Switching it on or off reloads the UI.")
    P:Note("Everything in MMT uses this. Macros, invites and whispers keep the real names.")

    page.OnRefresh = function()
        local members = ns.SortedMembers()
        list:Render(members)
        empty:SetShown(#members == 0)
        you:SetText("You are playing " .. ns.FirstName(ns.PlayerFull()) .. ".")
        local full = ns.db.privacy.nameMode == "FULL"
        hideCheck:SetAlpha(full and 0.4 or 1)
        if hideCheck.SetEnabled then hideCheck:SetEnabled(not full) end
        if ns.db.comm.guild then
            if not IsInGuild() then
                commInfo:SetText("|cffff6666Not in a guild:|r messages go to the group and by whisper as usual.")
            else
                local outside = ns.TeamOutsideGuild()
                local names = {}
                for _, k in ipairs(outside) do names[#names + 1] = ns.FirstName(k) end
                commInfo:SetText(#outside == 0 and "Guild mode: all team members are in your guild."
                    or ("Not in your guild (reached by whisper): " .. table.concat(names, ", ")))
            end
        else
            commInfo:SetText("Team messages go to your group, and by whisper to members outside it. Large transfers go by whisper outside instances.")
        end
    end
    ns.Listen("STATUS_CHANGED", function() if page:IsVisible() then list:Render(ns.SortedMembers()) end end)
end)

---------------------------------------------------------------------------
-- Roles
---------------------------------------------------------------------------
local LEFT_W, RIGHT_X, RIGHT_W = 220, 250, 440

ns.RegisterPage("roles", "Roles", function(page)
    local selected
    local quality, itemGroup = 0, "cloth"

    local top = { y = 0 }   -- trade switch: Trade / Mail / Vendor page

    -- left: roles --------------------------------------------------------
    local L = UI.Column(page, 0, top.y, LEFT_W)
    L:Header("Roles")
    local roleList = List(page, LEFT_W, 12, 22, function(parent, i)
        local row = CreateFrame("Button", nil, parent)
        RowBackground(row, i)
        row.sel = UI.Fill(row, A[1], A[2], A[3], 0.18, "BORDER")
        row.name = UI.Label(row, "")
        row.name:SetPoint("LEFT", 8, 0)
        row.name:SetPoint("RIGHT", -44, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.count = UI.Label(row, "")
        row.count:SetPoint("RIGHT", -26, 0)
        row.count:SetTextColor(0.5, 0.5, 0.5)
        row.remove = UI.TextButton(row, "x", function() ns.RemoveRole(row.role); ns.Refresh() end)
        row.remove:SetPoint("RIGHT", -2, 0)
        row:SetScript("OnClick", function() selected = row.role; ns.RefreshConfig() end)
        return row
    end, function(row, role)
        row.role = role
        row.name:SetText(role)
        row.count:SetText(ns.MembersWithRole(role))
        row.sel:SetShown(role == selected)
    end)
    L:Add(roleList, 12 * 22 + 6)

    local roleStatus
    local roleInput = UI.EditBox(page, LEFT_W - 50, "New role", function(text, box)
        local name, err = ns.AddRole(text)
        if name then selected = name; box:SetText(""); box:ClearFocus(); roleStatus.Show_("") else roleStatus.Show_(err, true) end
        ns.Refresh()
    end)
    L:Add(roleInput, 0)
    local roleAdd = UI.Button(page, 44, "Add", function() roleInput:GetScript("OnEnterPressed")(roleInput) end)
    roleAdd:SetPoint("LEFT", roleInput, "RIGHT", 6, 0)
    L:Space(UI.ROW + 4)
    roleStatus = StatusLine(page)
    roleStatus:SetWidth(LEFT_W)
    L:Add(roleStatus, 16)
    L:Note("Soulbound and quest items are never traded. A trade holds 6 stacks.")

    -- right: members & rules ----------------------------------------------
    local R = UI.Column(page, RIGHT_X, top.y, RIGHT_W)
    local membersHeader = R:Header("Members")
    local memberChecks, memberKeys = {}, {}
    local half = RIGHT_W / 2
    for i = 1, 10 do
        local cb = UI.Check(page, half - 8, "",
            function() return selected and memberKeys[i] and ns.HasRole(memberKeys[i], selected) end,
            function(v) if selected and memberKeys[i] then ns.SetMemberRole(memberKeys[i], selected, v) end end)
        cb:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT_X + ((i - 1) % 2) * half, R.y - math.floor((i - 1) / 2) * 22)
        ns.HoverMember(cb, function() return memberKeys[i] end)
        memberChecks[i] = cb
    end
    local noTeam = UI.Label(page, "Add team members on the Team tab first.")
    noTeam:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT_X, R.y - 2)
    noTeam:SetTextColor(0.5, 0.5, 0.5)
    R:Space(5 * 22)

    local rulesHeader = R:Header("Items")
    local ruleList = List(page, RIGHT_W, 7, 20, function(parent, i)
        local row = CreateFrame("Frame", nil, parent)
        RowBackground(row, i)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(14, 14)
        row.icon:SetPoint("LEFT", 6, 0)
        row.text = UI.Label(row, "")
        row.text:SetPoint("LEFT", 26, 0)
        row.text:SetPoint("RIGHT", -26, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row.remove = UI.TextButton(row, "x", function() ns.RemoveRule(selected, row.i); ns.Refresh() end)
        row.remove:SetPoint("RIGHT", -2, 0)
        return row
    end, function(row, rule, index)
        row.i = index
        local text, icon, r, g, b = ns.DescribeRule(rule)
        row.text:SetText(text)
        row.text:SetTextColor(r, g, b)
        row.icon:SetTexture(icon or "Interface\\Buttons\\WHITE8x8")
        if icon then row.icon:SetVertexColor(1, 1, 1) else row.icon:SetVertexColor(0.3, 0.3, 0.3) end
    end)
    R:Add(ruleList, 7 * 20 + 6)
    local noRules = UI.Label(page, "No items or rules on this role yet.")
    noRules:SetPoint("TOPLEFT", ruleList, "TOPLEFT", 6, -4)
    noRules:SetTextColor(0.5, 0.5, 0.5)

    local ruleStatus
    local function AddRule(rule)
        if not selected then ruleStatus.Show_("Select or create a role first.", true) return false end
        local ok, err = ns.AddRule(selected, rule)
        ruleStatus.Show_(ok and "" or err, not ok)
        ns.Refresh()
        return ok
    end

    local drop = UI.Button(page, RIGHT_W, "Drop an item from your bags here", function()
        local kind, id = GetCursorInfo()
        if kind == "item" then
            AddRule({ type = "item", itemID = id, name = (ns.ItemInfo(id)) })
            ClearCursor()
        end
    end)
    drop:SetScript("OnReceiveDrag", drop:GetScript("OnClick"))
    R:Add(drop, UI.ROW + 2)

    local itemInput = UI.EditBox(page, RIGHT_W - 52, "Click, then shift-click an item", function(text, box)
        local rule = ns.RuleFromText(text)
        if rule and AddRule(rule) then box:SetText(""); box:ClearFocus() end
    end)
    UI.AcceptItemLinks(itemInput, function(link)
        ruleStatus.Show_(link .. "  - press Enter or Add.")
    end)
    UI.Tooltip(itemInput, "Add an item", "Click into the field, then shift-click an item in your bags, the loot window, a chat link or any other window. Item IDs and exact item names work too.")
    R:Add(itemInput, 0)
    local itemAdd = UI.Button(page, 44, "Add", function() itemInput:GetScript("OnEnterPressed")(itemInput) end)
    itemAdd:SetPoint("LEFT", itemInput, "RIGHT", 8, 0)
    R:Space(UI.ROW + 2)

    local grey = UI.Button(page, half - 4, "All grey items", function() AddRule({ type = "quality", quality = 0 }) end)
    R:Add(grey, 0)
    local boe = UI.Button(page, half - 4, "All Bind on Equip", function() AddRule({ type = "boe" }) end)
    boe:SetPoint("LEFT", grey, "RIGHT", 8, 0)
    R:Space(UI.ROW + 2)

    local qualities = {}
    for q = 0, 5 do qualities[#qualities + 1] = { value = q, text = ns.QualityName(q) } end
    local qCycle = UI.Cycle(page, RIGHT_W - 52, "Quality", qualities,
        function() return quality end, function(v) quality = v end)
    R:Add(qCycle, 0)
    local qAdd = UI.Button(page, 44, "Add", function() AddRule({ type = "quality", quality = quality }) end)
    qAdd:SetPoint("LEFT", qCycle, "RIGHT", 8, 0)
    R:Space(UI.ROW + 2)

    local groups = {}
    for _, g in ipairs(ns.ITEM_GROUPS) do
        groups[#groups + 1] = g.header and { header = true, text = g.header } or { value = g.id, text = g.name }
    end
    local cCycle = UI.Dropdown(page, RIGHT_W - 52, "Item group", groups,
        function() return itemGroup end, function(v) itemGroup = v end)
    R:Add(cCycle, 0)
    UI.Tooltip(cCycle, "Item group", "Ready-made groups by item category, e.g. Cloth (Linen, Wool, Silk, Mageweave, Runecloth and their bolts), Herbs, Potions, Food & drink or Reagents.")
    local cAdd = UI.Button(page, 44, "Add", function() AddRule({ type = "group", group = itemGroup }) end)
    cAdd:SetPoint("LEFT", cCycle, "RIGHT", 8, 0)
    R:Space(UI.ROW + 2)

    ruleStatus = StatusLine(page)
    R:Add(ruleStatus, 16)

    local noRole = UI.Label(page, "Create a role on the left (e.g. Cloth), then tick its members and add items.")
    noRole:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT_X, top.y - 30)
    noRole:SetWidth(RIGHT_W)
    noRole:SetJustifyH("LEFT")
    noRole:SetTextColor(0.5, 0.5, 0.5)
    local rightSide = { membersHeader, rulesHeader, ruleList, drop, itemInput, itemAdd, grey, boe, qCycle, qAdd, cCycle, cAdd, ruleStatus }

    page.OnRefresh = function()
        local roles = ns.SortedRoleNames()
        if selected and not ns.db.roles[selected] then selected = nil end
        if not selected then selected = roles[1] end
        roleList:Render(roles)

        for _, region in ipairs(rightSide) do region:SetShown(selected ~= nil) end
        noRole:SetShown(selected == nil)
        membersHeader:SetText(selected and ("Members of " .. selected) or "Members")
        rulesHeader:SetText(selected and ("Items for " .. selected) or "Items")

        local rules = selected and ns.db.roles[selected].rules or {}
        ruleList:Render(rules)
        noRules:SetShown(selected ~= nil and #rules == 0)

        local members = ns.SortedMembers()
        for i, cb in ipairs(memberChecks) do
            memberKeys[i] = members[i]
            cb.label:SetText(members[i] and ns.FirstName(members[i]) or "")
            cb:SetShown(selected ~= nil and members[i] ~= nil)
            cb.Refresh()
        end
        noTeam:SetShown(selected ~= nil and #members == 0)
    end
    ns.On("GET_ITEM_INFO_RECEIVED", function()
        if page:IsVisible() then ruleList:Render(ruleList.data or {}) end
    end)
end)

---------------------------------------------------------------------------
-- XP window
---------------------------------------------------------------------------
ns.RegisterPage("xp", "XP Window", function(page)
    local L = UI.Column(page, 0, 0, COL_W)
    L:Header("XP window")
    L:Check("Show window", Opt("xp", "enabled"))
    local glk, slk = Opt("xp", "locked")
    L:Check("Lock position", glk, slk, "Unlocked, Shift + drag or the tab above the window's corner (shown while the mouse is over the window) moves it.")
    local gct, sct = Opt("xp", "clickThrough")
    L:Check("Click-through", gct, sct, "Clicks go through the window to the game world. No mouseover details or click actions then. Otherwise: click a member to make them the FTL leader, right-click to invite, Ctrl-click to inspect, Ctrl-right-click for talents, middle-click to invite the whole team, Shift-right-click for settings.")
    L:Check("Show your own character", Opt("xp", "showSelf"))
    L:Check("Show bars", Opt("xp", "showBars"))
    local gbm, sbm = Opt("xp", "barMode")
    L:Cycle("Bar shows", {
        { value = "XP", text = "Experience" },
        { value = "REP", text = "Reputation (watched faction)" },
    }, gbm, sbm)
    L:Check("Class colours", Opt("xp", "classColors"))

    -- pieces of a row (XPPieces.lua): left of the bar first, then on the bar; drag the dots to
    -- reorder within a side, "left" / "bar" switches the side, "on" / "off" shows it
    L:Header("Pieces")
    local pieces
    local function Shown()
        local out = {}
        for _, side in ipairs({ "LEFT", "RIGHT" }) do
            for _, e in ipairs(ns.XPPieceOrder()) do
                if e.side == side and ns.xpPieces[e.id] then out[#out + 1] = e end
            end
        end
        return out
    end
    local function Redraw() pieces:Render(Shown()) end
    local PIECE_ROWS, PIECE_H = 6, 20
    pieces = List(page, COL_W, PIECE_ROWS, PIECE_H, function(parent, i)
        local row = CreateFrame("Frame", nil, parent)
        RowBackground(row, i)
        -- the side's colour: a strip at the left edge and a faint tint
        row.tint = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.tint:SetAllPoints()
        row.strip = row:CreateTexture(nil, "ARTWORK")
        row.strip:SetPoint("TOPLEFT"); row.strip:SetPoint("BOTTOMLEFT")
        row.strip:SetWidth(2)
        row.grip = CreateFrame("Frame", nil, row)
        row.grip:SetSize(6, 10)
        row.grip:SetPoint("LEFT", 4, 0)
        for c = 0, 1 do
            for r = 0, 2 do
                local d = row.grip:CreateTexture(nil, "OVERLAY")
                d:SetSize(2, 2)
                d:SetPoint("TOPLEFT", c * 4, -r * 4)
                d:SetColorTexture(1, 1, 1, 0.35)
                row.grip[#row.grip + 1] = d
            end
        end
        row.toggle = UI.TextButton(row, "", function()
            if row.entry then ns.SetXPPiece(row.entry.id, not row.entry.on); Redraw() end
        end, 26)
        row.toggle:SetPoint("RIGHT", -2, 0)
        UI.Tooltip(row.toggle, "On / off", "Switched-off pieces stay in the list but aren't shown.")
        row.side = UI.TextButton(row, "", function()
            local e = row.entry
            if e then ns.MoveXPPiece(e.id, e.side == "LEFT" and "RIGHT" or "LEFT"); Redraw() end
        end, 30)
        row.side:SetPoint("RIGHT", row.toggle, "LEFT", -4, 0)
        UI.Tooltip(row.side, "Left or on the bar", "Left: in the column left of the bar (gold, bags, ...). Bar: on the bar, right side (level, XP %, ...).")
        row.text = UI.Label(row, "")
        row.text:SetPoint("LEFT", row.grip, "RIGHT", 6, 0)
        row.text:SetPoint("RIGHT", row.side, "LEFT", -4, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            local d = self.entry and ns.xpPieces[self.entry.id]
            for _, t in ipairs(self.grip) do t:SetColorTexture(1, 1, 1, 0.9) end
            if not d then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(d.title)
            if d.tip then GameTooltip:AddLine(d.tip, 1, 1, 1, true) end
            GameTooltip:AddLine("Drag to move it among the pieces of its side.", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            for _, t in ipairs(self.grip) do t:SetColorTexture(1, 1, 1, 0.35) end
            GameTooltip:Hide()
        end)
        return row
    end, function(row, e, index)
        row.entry, row.index = e, index
        local d = ns.xpPieces[e.id]
        row.text:SetText(d and d.title or e.id)
        row.text:SetTextColor(e.on and 1 or 0.5, e.on and 1 or 0.5, e.on and 1 or 0.5)
        local c = ns.XP_SIDE_COLOUR[e.side]
        row.strip:SetColorTexture(c[1], c[2], c[3], e.on and 0.9 or 0.4)
        row.tint:SetColorTexture(c[1], c[2], c[3], 0.07)
        row.side.label:SetText(e.side == "LEFT" and "left" or "bar")
        row.side.label:SetTextColor(c[1], c[2], c[3], e.on and 1 or 0.5)
        row.toggle.label:SetText(e.on and "|cff55ff55on|r" or "|cff777777off|r")
    end)
    L:Add(pieces, PIECE_ROWS * PIECE_H + 6)

    -- dragging a row of the list: only among the pieces of its side
    do
        local marker = pieces:CreateTexture(nil, "OVERLAY")
        marker:SetColorTexture(A[1], A[2], A[3], 1)
        marker:SetHeight(2)
        marker:Hide()
        local from, nextScroll
        local function Slot()
            local data, top = pieces.data, pieces:GetTop()
            if not data or not top or not from then return end
            local _, y = GetCursorPosition()
            local dy = top - y / pieces:GetEffectiveScale()
            local gap = math.max(0, math.min(PIECE_ROWS, math.floor(dy / PIECE_H + 0.5)))
            local side, first, last = data[from].side
            for i, e in ipairs(data) do if e.side == side then first = first or i; last = i end end
            local slot = math.max(first, math.min(last + 1, pieces.offset + gap + 1))
            return slot, dy, side, last
        end
        local function Stop()
            pieces:SetScript("OnUpdate", nil)
            marker:Hide()
            from = nil
        end
        pieces:SetScript("OnUpdate", nil)
        for _, row in ipairs(pieces.rows) do
            row:RegisterForDrag("LeftButton")
            row:SetScript("OnDragStart", function(self)
                if not self.index then return end
                GameTooltip:Hide()
                from, nextScroll = self.index, nil
                pieces:SetScript("OnUpdate", function()
                    local slot, dy = Slot()
                    if not slot then return end
                    local now = GetTime()
                    if (dy < 0 or dy > pieces:GetHeight()) and (not nextScroll or now >= nextScroll) then
                        nextScroll = now + 0.15
                        pieces:GetScript("OnMouseWheel")(pieces, dy < 0 and 1 or -1)
                        slot = Slot()
                    end
                    if slot == from or slot == from + 1 then marker:Hide() return end
                    local y = -(slot - 1 - pieces.offset) * PIECE_H + 1
                    marker:ClearAllPoints()
                    marker:SetPoint("TOPLEFT", pieces, "TOPLEFT", 0, y)
                    marker:SetPoint("TOPRIGHT", pieces, "TOPRIGHT", 0, y)
                    marker:Show()
                end)
            end)
            row:SetScript("OnDragStop", function()
                local data, f = pieces.data, from
                local slot, _, side, last = Slot()
                Stop()
                if not slot or slot == f or slot == f + 1 then return end
                local before = slot <= last and data[slot].id or nil
                ns.MoveXPPiece(data[f].id, side, before)
                Redraw()
            end)
        end
        pieces:HookScript("OnHide", Stop)
    end
    local arrange
    arrange = UI.Button(page, COL_W, "", function() ns.ToggleXPArrange() end)
    local function ArrangeText()
        arrange.label:SetText(ns.xpArrange and "Stop arranging the window" or "Arrange in the window (drag pieces and rows)")
    end
    ArrangeText()
    L:Add(arrange, UI.ROW + 2)
    UI.Tooltip(arrange, "Arrange in the window", "Every switched-on piece shows in the XP window with dots: drag a piece along its row (also to the other side of the bar's start) or a row up or down to change the team order. Until you click again or /reload. Also /mmt xp arrange.")
    page.OnRefresh = function()
        Redraw()
        ArrangeText()
    end
    local function Now(set) return function(v) set(v); if ns.UpdateXPWindow then ns.UpdateXPWindow() end end end
    local gdm, sdm = Opt("xp", "durability")
    sdm = Now(sdm)
    L:Cycle("Durability", {
        { value = "LOWEST", text = "Lowest item" },
        { value = "AVERAGE", text = "Average of all items" },
    }, gdm, sdm)
    local ggf, sgf = Opt("xp", "goldFormat")
    sgf = Now(sgf)
    L:Cycle("Gold", {
        { value = "GOLD", text = "Gold only" },
        { value = "FULL", text = "Gold, silver, copper" },
    }, ggf, sgf)

    L:Header("Layer hop")
    local gn, sn = Opt("xp", "layerHopNotify")
    L:Check("Notify when layer/phase switch is pending", gn, sn,
        "Shows a pulsing red \"Layer Hop\" left of the name when the game offers to move that character to another layer. Click it to accept in 3 seconds (for a teammate, their client accepts).")
    local gau, sau = Opt("xp", "layerHopAuto")
    L:Check("Accept the layer hop automatically", gau, sau, "Counts down in chat, then accepts.")
    local gd, sd = Opt("xp", "layerHopDelay")
    L:Slider("Accept after (seconds)", 1, 30, 1, gd, sd)

    local R = UI.Column(page, COL2_X, 0, COL_W)
    R:Header("Look")
    local gf, sf = Opt("xp", "font")
    R:Cycle("Font", function()
        local l = {}
        for _, f in ipairs(ns.fonts) do l[#l + 1] = { value = f.name, text = f.name } end
        local cur = ns.db.xp.font
        local known = false
        for _, c in ipairs(l) do if c.value == cur then known = true end end
        if not known then l[#l + 1] = { value = cur, text = "Custom" } end
        return l
    end, gf, sf)
    local go, so = Opt("xp", "outline")
    R:Cycle("Outline", {
        { value = "NONE", text = "None" },
        { value = "OUTLINE", text = "Thin" },
        { value = "THICKOUTLINE", text = "Thick" },
        { value = "MONOCHROME,OUTLINE", text = "Mono" },
    }, go, so)
    local ga, sa = Opt("xp", "align")
    R:Cycle("Layout", {
        { value = "SPLIT", text = "Name left, values right" },
        { value = "LEFT", text = "Left" },
        { value = "CENTER", text = "Center" },
        { value = "RIGHT", text = "Right" },
    }, ga, sa)
    local gpa, spa = Opt("xp", "pieceAlign")
    R:Cycle("Line up pieces", {
        { value = "CENTER", text = "In columns, centred" },
        { value = "LEFT", text = "In columns, left" },
        { value = "RIGHT", text = "In columns, right" },
        { value = "OFF", text = "Off (each row on its own)" },
    }, gpa, spa)
    local gcs, scs = Opt("ftl", "crownSide")
    R:Cycle("Leader crown", {
        { value = "LEFT", text = "Left of the name" },
        { value = "RIGHT", text = "Right of the name" },
    }, gcs, scs)
    local gz, sz = Opt("xp", "size")
    R:Slider("Font size", 8, 24, 1, gz, sz)
    local gw, sw = Opt("xp", "width")
    R:Slider("Width", 100, 400, 5, gw, sw)
    local gh, sh = Opt("xp", "barHeight")
    R:Slider("Bar height", 10, 36, 1, gh, sh)
    local grg, srg = Opt("xp", "rowGap")
    R:Slider("Row spacing", 0, 10, 1, grg, srg)
    local gs, ss = Opt("xp", "scale")
    R:Slider("Scale", 0.5, 2, 0.05, gs, ss, "%.2f")
    local gal, sal = Opt("xp", "alpha")
    R:Slider("Window opacity", 0.2, 1, 0.05, gal, sal, "%.2f")
    local gb, sb = Opt("xp", "bgAlpha")
    R:Slider("Background opacity", 0, 1, 0.05, gb, sb, "%.2f")
    R:Button("Reset window position", function() ns.ResetXPPosition() end)

    R:Space(6)
    R:Note("Follow and crowd control warnings: Alerts page.")

end)

---------------------------------------------------------------------------
-- Distance window format: small side window next to the settings window
---------------------------------------------------------------------------
local distanceFormat
function ns.ToggleDistanceFormat(window)
    if distanceFormat and distanceFormat:IsShown() then distanceFormat:Hide() return end
    if not distanceFormat then
        local f = CreateFrame("Frame", "MMTDistanceFormatFrame", window)   -- scales and hides with the settings window
        f:SetFrameStrata(window:GetFrameStrata())
        f:SetFrameLevel(window:GetFrameLevel() + 50)
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        UI.Fill(f, 0.05, 0.05, 0.06, 0.96)
        UI.Border(f, 0.22, 0.22, 0.24, 1)
        f.widgets = {}
        local title = UI.Label(f, "Distance window format", "GameFontNormal")
        title:SetPoint("TOPLEFT", 16, -14)
        local close = UI.TextButton(f, "x", function() f:Hide() end, 20)
        close:SetPoint("TOPRIGHT", -8, -8)

        local C = UI.Column(f, 16, -40, COL_W)
        local gfo, sfo = Opt("distance", "font")
        C:Cycle("Font", function()
            local l = {}
            for _, font in ipairs(ns.fonts) do l[#l + 1] = { value = font.name, text = font.name } end
            return l
        end, gfo, sfo)
        local go, so = Opt("distance", "outline")
        C:Cycle("Outline", {
            { value = "NONE", text = "None" },
            { value = "OUTLINE", text = "Thin" },
            { value = "THICKOUTLINE", text = "Thick" },
        }, go, so)
        local ga, sa = Opt("distance", "align")
        C:Cycle("Alignment", {
            { value = "LEFT", text = "Left" },
            { value = "CENTER", text = "Center" },
            { value = "RIGHT", text = "Right" },
        }, ga, sa)
        local gz, sz = Opt("distance", "size")
        C:Slider("Font size", 8, 32, 1, gz, sz)
        local gw, sw = Opt("distance", "width")
        C:Slider("Width", 40, 250, 5, gw, sw)
        local gb, sb = Opt("distance", "bgAlpha")
        C:Slider("Background opacity", 0, 1, 0.05, gb, sb, "%.2f")
        f:SetSize(COL_W + 32, -C.y + 12)
        f:SetScript("OnShow", function(self) for _, w in ipairs(self.widgets) do w.Refresh() end end)
        UI.CloseOnEscape(f)
        distanceFormat = f
    end
    distanceFormat:ClearAllPoints()
    distanceFormat:SetPoint("TOPLEFT", window, "TOPRIGHT", 6, 0)
    distanceFormat:Show()
    for _, w in ipairs(distanceFormat.widgets) do w.Refresh() end
end

---------------------------------------------------------------------------
-- Alerts: follow and crowd control
---------------------------------------------------------------------------
ns.RegisterPage("alerts", "Alerts", function(page)
    local L = UI.Column(page, 0, 0, COL_W)
    L:Header("Follow")
    L:Note("Warns when a team character stops following.")
    local gfc, sfc = Opt("xp", "followCheck")
    L:Check("Check /follow of team", gfc, sfc,
        "Every client reports when its character starts or stops following. A member who stops gets a red, pulsing row in the XP window. Needs MMT on every client.")
    local gfw, sfw = Opt("xp", "followWarn")
    L:Check("Show warning when follow breaks", gfw, sfw,
        "Raid warning \"<Name> stopped following\" on the client of the character that was followed (the one you play).")
    local gfs, sfs = Opt("xp", "followSound")
    L:Check("Play sound when follow breaks", gfs, sfs, "The raid warning sound, on the same client as the warning.")
    local gfi, sfi = Opt("xp", "followIgnoreCombat")
    L:Check("Ignore follow breaks during combat", gfi, sfi,
        "Follow often breaks in a fight. A break in combat only counts if the character still isn't following when the time below has passed after its combat ended.")
    local gfd, sfd = Opt("xp", "followCombatDelay")
    L:Slider("Check after combat (seconds)", 1, 30, 1, gfd, sfd)

    L:Header("Bags and quest log")
    L:Note("Warns the leader (the FTL leader; without one online, the group leader if in the team, else the first online team member) when a character runs out of room.")
    local gwb, swb = Opt("warn", "bags")
    L:Check("Bags almost full", gwb, swb, "Once when a character gets down to the free slots below, and once more when its bags are full.")
    local gwba, swba = Opt("warn", "bagsAt")
    L:Slider("At free bag slots", 0, 10, 1, gwba, swba)
    local gwq, swq = Opt("warn", "quests")
    L:Check("Quest log almost full", gwq, swq, "Once when a character has only the free quest slots below left, and once more when its quest log is full.")
    local gwqa, swqa = Opt("warn", "questsAt")
    L:Slider("At free quest slots", 0, 10, 1, gwqa, swqa)
    local gwr, swr = Opt("warn", "raidWarning")
    L:Check("Show as raid warning", gwr, swr, "Besides the chat line.")
    L:Check("Play sound", Opt("warn", "sound"))

    local R = UI.Column(page, COL2_X, 0, COL_W)
    R:Header("Crowd control")
    R:Note("Warns when a team character can't move: stunned, feared, incapacitated or rooted. The XP window marks the row orange with the time left.")
    local ge, se = Opt("cc", "enabled")
    R:Check("Check crowd control of team", ge, se,
        "Every client reports when its character loses control and when it is free again. Needs MMT on every client.")
    local gw, sw = Opt("cc", "warn")
    R:Check("Show warning", gw, sw,
        "Raid warning \"<Name> is stunned (4 s)\" on the FTL leader's client (the character you play). With no leader known, on every client. Never for the character itself.")
    local gs, ss = Opt("cc", "sound")
    R:Check("Play sound", gs, ss, "The raid warning sound, on the same client as the warning.")
    R:Space(4)
    R:Note("Report:")
    R:Check("Stuns", Opt("cc", "stun"))
    local gf, sf = Opt("cc", "fear")
    R:Check("Fears and charms", gf, sf, "Fear, horror, charm, mind control.")
    local gi, si = Opt("cc", "incap")
    R:Check("Incapacitates", gi, si, "Polymorph, sap, sleep, gouge and similar.")
    R:Check("Roots", Opt("cc", "root"))
    local gm, sm = Opt("cc", "minDuration")
    R:Slider("Ignore shorter than (seconds)", 0, 10, 1, gm, sm)
end)

---------------------------------------------------------------------------
-- FTL
---------------------------------------------------------------------------
ns.RegisterPage("ftl", "FTL", function(page)
    local L = UI.Column(page, 0, 0, COL_W)
    L:Header("FTL")
    L:Note("FTL is short for Focusless, Targetless, Leaderless. It allows you to create macros that will always target the character you are controlling right now; like for follow or assist.")
    local warn = L:Note("Important: this feature originates from the software ISBoxer, but is inferior to it. The FTL target in MMT CANNOT be changed during combat.")
    warn:SetTextColor(1, 0.45, 0.4)

    L:Header("Settings")
    L:Check("Use FTL macros", Opt("ftl", "enabled"))
    local gd, sd = Opt("ftl", "detect")
    L:Cycle("Leader", {
        { value = "MANUAL", text = "Only by click, key, command" },
        { value = "MOVE", text = "Automatic, when you move" },
    }, gd, sd)
    local gn, sn = Opt("ftl", "nameFormat")
    L:Cycle("{FTL} becomes", {
        { value = "FULL", text = "First Last" },
        { value = "FIRST", text = "First name" },
        { value = "UNIT", text = "Group unit (party2)" },
    }, gn, sn)
    local gs, ss = Opt("ftl", "skipSelf")
    L:Check("Leave {FTL} lines out on the leader", gs, ss,
        "On the leader's own client, macro lines with {FTL} are left out (the leader can't follow or assist itself).")
    local gc, sc = Opt("ftl", "crown")
    L:Check("Crown on the leader in the XP window", gc, sc)
    local ga, sa = Opt("ftl", "announce")
    L:Check("Chat line when the leader changes", ga, sa)

    L:Header("Changing the leader")
    L:Note("- Click the character in the XP window\n- Key binding \"Make this character the leader\" (Esc > Options > Keybindings > MMT (Manage My Team))\n- /mmt leader (this character) or /mmt leader <name>\n- Automatically when you move a character on its own (setting above). Not when several team characters start moving at once (movement keys or Interact with Target broadcast to every window: the leader stays), and not while following, feared or charmed.")
    local current = L:Note("")

    -- right: the macros ---------------------------------------------------
    local R = UI.Column(page, COL2_X, 0, COL_W)
    R:Header("Macros")
    local selected = 1
    local status
    local nameBox, bodyBox, preview
    local function Macros() return ns.db.ftl.macros end

    local list = List(page, COL_W, 5, 22, function(parent, i)
        local row = CreateFrame("Button", nil, parent)
        RowBackground(row, i)
        row.text = UI.Label(row, "")
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetPoint("RIGHT", -8, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row.sel = UI.Fill(row, A[1], A[2], A[3], 0.15, "BORDER")
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.05)
        row:SetScript("OnClick", function()
            selected = row.index
            nameBox:ClearFocus(); bodyBox.edit:ClearFocus()
            page.OnRefresh()
        end)
        return row
    end, function(row, m, index)
        row.index = index
        row.text:SetText(m.name ~= "" and m.name or "(no name)")
        row.sel:SetShown(index == selected)
    end)
    R:Add(list, 5 * 22 + 6)

    nameBox = UI.EditBox(page, COL_W, "Macro name (max. 16 characters)")
    nameBox:SetMaxLetters(16)
    R:Add(nameBox, UI.ROW + 4)
    bodyBox = UI.TextArea(page, COL_W, 92)
    bodyBox.edit:SetMaxLetters(255)
    R:Add(bodyBox, 98)
    bodyBox.edit:HookScript("OnTextChanged", function(self)
        local text, cut = ns.FTLResolve(self:GetText())
        preview:SetText("Here: " .. (text ~= "" and text:gsub("\n", " | ") or "(nothing: every line has {FTL})") .. (cut and "  |cffff6666(too long)|r" or ""))
    end)
    preview = R:Note("")

    local function Save()
        local name = ns.Trim(nameBox:GetText())
        local body = bodyBox.edit:GetText()
        if name == "" then status.Show_("Give the macro a name.", true) return end
        for i, m in ipairs(Macros()) do
            if i ~= selected and m.name == name then status.Show_("There is already a macro called " .. name .. ".", true) return end
        end
        local m = Macros()[selected]
        if not m then m = {}; table.insert(Macros(), m); selected = #Macros() end
        m.name, m.body = name, body
        local r = ns.FTLUpdateMacros("edit")
        status.Show_(r == "combat" and "Saved. The WoW macro is written after combat." or ("Saved: " .. name .. "."))
        page.OnRefresh()
    end

    local save = UI.Button(page, 120, "Save", Save)
    R:Add(save, 0)
    local new = UI.Button(page, 120, "New", function()
        table.insert(Macros(), { name = "FTL " .. (#Macros() + 1), body = "/follow {FTL}" })
        selected = #Macros()
        page.OnRefresh()
        nameBox:SetFocus(); nameBox:HighlightText()
        status.Show_("New macro: change name and text, then Save.")
    end)
    new:SetPoint("LEFT", save, "RIGHT", 8, 0)
    R:Space(UI.ROW + 4)
    local delete = ConfirmButton(page, 120, "Delete", function()
        local m = Macros()[selected]
        if not m then return end
        table.remove(Macros(), selected)
        selected = math.max(1, selected - 1)
        ns.FTLUpdateMacros("delete")
        status.Show_("Deleted " .. m.name .. " (and its WoW macro).")
        page.OnRefresh()
    end)
    R:Add(delete, 0)
    local pickup = UI.Button(page, 120, "Drag to bar", function()
        local m = Macros()[selected]
        if m then ns.FTLPickup(m.name) end
    end)
    UI.Tooltip(pickup, "Drag to bar", "Puts the macro on your cursor: click an action bar slot to place it. The macro is also in the game's macro window (account macros).")
    pickup:SetPoint("LEFT", delete, "RIGHT", 8, 0)
    R:Space(UI.ROW + 4)
    status = StatusLine(page)
    status:SetWidth(COL_W)
    R:Add(status, UI.ROW)
    R:Note("Write {FTL} where the leader's name goes. Every client keeps these macros up to date.")
    R:Space(6)
    R:Header("Sending the macros to the team")
    R:Note("Same account and profile: nothing to do. Other accounts: log them in, then click "
        .. "Profiles > Sync to team (or /mmt sync) here and accept on each client. This sends all core "
        .. "settings, not only the macros. Put the macros on each character's bar once (Drag to bar).")

    page.OnRefresh = function()
        local macros = Macros()
        if selected > #macros then selected = math.max(1, #macros) end
        list:Render(macros)
        local m = macros[selected]
        if not nameBox:HasFocus() then nameBox:SetText(m and m.name or "") nameBox:UpdatePlaceholder() end
        if not bodyBox.edit:HasFocus() then bodyBox.edit:SetText(m and m.body or "") end
        local leader = ns.FTLLeader()
        current:SetText("Leader now: " .. (leader and (ns.FullDisplay(leader) .. (ns.IsSelf(leader) and " (this character)" or "")) or "nobody yet"))
    end
    ns.Listen("FTL_LEADER", function() if page:IsVisible() then page.OnRefresh() end end)
end)

---------------------------------------------------------------------------
-- Automations (formerly OMT)
---------------------------------------------------------------------------
ns.RegisterPage("automations", "Automations", function(page)
    local L = UI.Column(page, 0, 0, COL_W)

    L:Header("Gossip")
    local gv, sv = Opt("gossip", "vendor")
    L:Check("Go straight to the vendor", gv, sv,
        "Opens the vendor pane even when the NPC has other options, e.g. an innkeeper.")
    local gtx, stx = Opt("gossip", "taxi")
    L:Check("Go straight to the flight map", gtx, stx,
        "At a flight master, picks \"I need a ride\" so the flight map opens at once. With \"Take flight paths with the team\" the team members then follow you without clicking.")
    local gdl, sdl = Opt("gossip", "dialog")
    L:Check("Click through NPC dialogs", gdl, sdl,
        "When an NPC has no quests and only plain dialog lines, MMT picks them one after another to advance the conversation. Lines that could cost gold, teleport, train, bind your hearthstone or start a fight are left to you, and NPCs with any other option (vendor, trainer, flights, ...) stay manual.")
    L:Check("Hold Shift to skip automation",
        function() return ns.db.shiftBypass end,
        function(v) ns.db.shiftBypass = v end,
        "Hold Shift while an NPC window opens to keep that page manual. Pick an option without Shift and the next page is automated again.")
    L:Note("Quest automation (accept, turn in, share) is in the Quest Tracker module.")

    L:Header("Group invites")
    L:Check("Accept from team members", Opt("invites", "team"))
    L:Check("Accept from friends", Opt("invites", "friends"))
    L:Check("Accept from Battle.net friends", Opt("invites", "bnet"))
    L:Check("Accept from guild members", Opt("invites", "guild"))
    local gw, sw = Opt("invites", "whisper")
    L:Check("Invite people who whisper the keyword", gw, sw,
        "Anyone who whispers you exactly this word (not case-sensitive) gets a group invite.")
    -- keyword: saved on Enter or when the box loses focus
    local keyword = UI.EditBox(page, COL_W - 24, "keyword", function(text, box)
        local word = ns.Trim(text)
        if word ~= "" then ns.db.invites.keyword = word end
        box:SetText(ns.db.invites.keyword)
        box:ClearFocus()
    end)
    keyword:HookScript("OnEditFocusLost", function(box)
        local word = ns.Trim(box:GetText())
        if word ~= "" then ns.db.invites.keyword = word end
        box:SetText(ns.db.invites.keyword)
        box:UpdatePlaceholder()
    end)
    keyword.Refresh = function()
        if not keyword:HasFocus() then keyword:SetText(ns.db.invites.keyword or "") keyword:UpdatePlaceholder() end
    end
    table.insert(page.widgets, keyword)
    L:Add(keyword, UI.ROW + 2, 24)

    L:Header("When you die")
    local grl, srl = Opt("death", "release")
    L:Check("Release as team", grl, srl,
        "When a character dies, a \"Release as team\" button appears under the game's death dialog on every dead character. Clicking it releases every dead team member. It lists who is dead or a ghost.")
    local grv, srv = Opt("death", "revive")
    L:Check("Revive as team", grv, srv,
        "When a ghost reaches its corpse, a \"Revive as team\" button appears under the game's dialog. Clicking it revives every ghost that is at its corpse; one whose corpse still has a delay revives when it ends; one that isn't at its corpse says so. The list shows who can revive now.")

    L:Header("Accept automatically")
    -- sources x (resurrections, summons): any combination
    local gridY = L.y
    local resLabel = UI.Label(page, "Resurrections")
    resLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 110, gridY)
    resLabel:SetTextColor(0.6, 0.6, 0.6)
    local sumLabel = UI.Label(page, "Summons")
    sumLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 196, gridY)
    sumLabel:SetTextColor(0.6, 0.6, 0.6)
    L:Space(16)
    local SOURCES = { { "team", "From team" }, { "friends", "From friends" }, { "guild", "From guild" }, { "anyone", "From anyone" } }
    for _, src in ipairs(SOURCES) do
        local key, text = src[1], src[2]
        local label = UI.Label(page, text)
        label:SetPoint("TOPLEFT", page, "TOPLEFT", 0, L.y - 4)
        local res = UI.Check(page, 24, "", function() return ns.db.death.acceptRes[key] end,
            function(v) ns.db.death.acceptRes[key] = v end,
            "Accept resurrections " .. text:lower() .. ".")
        res:SetPoint("TOPLEFT", page, "TOPLEFT", 126, L.y)
        local sum = UI.Check(page, 24, "", function() return ns.db.death.acceptSummon[key] end,
            function(v) ns.db.death.acceptSummon[key] = v end,
            "Accept warlock summons " .. text:lower() .. ".")
        sum:SetPoint("TOPLEFT", page, "TOPLEFT", 204, L.y)
        L:Space(UI.ROW)
    end

    local R = UI.Column(page, COL2_X, 0, COL_W)
    R:Header("Camera")
    R:Check("Maximum camera distance", Opt("camera", "enabled"))
    local gf, sf = Opt("camera", "factor")
    R:Slider("Zoom factor", 1, 2.6, 0.1, gf, sf, "%.1f")

    R:Header("Distance window")
    local gde, sde = Opt("distance", "enabled")
    R:Check("Show window", gde, sde,
        "Shows a small window with distance information to your target. Mostly useful for hunters that want to avoid their deadzone.")
    R:Check("Lock (click-through)", Opt("distance", "locked"))
    local gh, sh = Opt("distance", "hideNoTarget")
    R:Check("Hide without target", gh, sh, "Only applies while the window is locked.")
    local gc, sc = Opt("distance", "colorize")
    R:Check("Colour by distance", gc, sc, "Green melee, yellow up to 30, orange up to 40, red beyond.")
    R:Button("Format window", function() ns.ToggleDistanceFormat(page:GetParent()) end)
    R:Button("Reset window position", function() ns.ResetDistancePosition() end)

    R:Header("Flight paths")
    local gt, st = Opt("taxi", "enabled")
    R:Check("Take flight paths with the team", gt, st,
        "When a team member picks a destination at a flight master, every team member that is talking to a flight master too (flight map open, or opened within 5 seconds) flies to the same destination. Needs MMT on every client.")
    R:Check("Print to chat", Opt("taxi", "report"))
    local gtl, stl = Opt("taxi", "tellLeader")
    R:Check("Tell the leader", gtl, stl, "The leader's chat says who took the flight too, and who couldn't (the FTL leader; without one online, the group leader if in the team, else the first online team member).")

    R:Header("Mounts")
    local gmo, smo = Opt("mount", "mount")
    R:Check("Mount up with the leader", gmo, smo,
        "When the leader (the FTL leader; without one online, the group leader if in the team, else the first online team member) mounts, every team member nearby mounts too: the same mount if it has it, else one of the same kind, else a random favourite. Hold Shift while mounting to ride alone.")
    local gdm, sdm = Opt("mount", "dismount")
    R:Check("Dismount with the leader", gdm, sdm,
        "When the leader dismounts, every team member dismounts too, never in the air. Hold Shift while dismounting to do it alone.")
end)

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Trade / Mail / Vendor
---------------------------------------------------------------------------
-- dropdown values: "none" plus every role
local function RoleChoices()
    local l = { { value = "", text = "None" } }
    local names = {}
    for name in pairs(ns.db.roles) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do l[#l + 1] = { value = name, text = name } end
    return l
end

-- after a reset or a new empty profile: modules back to their defaults too?
-- show(msg) reports the result (default: chat)
function ns.AskResetModules(done, show)
    show = show or function(msg) ns.Print("%s", msg) end
    UI.Confirm(done .. "\n\nAlso switch the modules back to their default (on or off)?", "Reset modules", function()
        local changed, reload = ns.ResetModuleStates()
        if changed == 0 then show(done .. " Modules were already at their defaults.")
        else show(("%s %d %s switched%s."):format(done, changed, changed == 1 and "module" or "modules",
            reload and "; reload the UI to load the ones switched on" or "")) end
        ns.Refresh()
    end, "Keep modules")
end

local function MemberChoices()
    local l = { { value = "", text = "Nobody" } }
    for _, key in ipairs(ns.SortedMembers()) do l[#l + 1] = { value = key, text = ns.ShownName(key) } end
    return l
end

ns.RegisterPage("trade", "Trade / Mail / Vendor", function(page)
    local L = UI.Column(page, 0, 0, COL_W)
    L:Header("Vendor")
    L:Check("Sell grey items", Opt("merchant", "sellGrey"))
    L:Check("Repair automatically", Opt("merchant", "repair"))
    local gg, sg = Opt("merchant", "guildRepair")
    L:Check("Use guild funds if allowed", gg, sg, "Falls back to your own gold.")
    L:Check("Print results to chat", Opt("merchant", "report"))
    local gml, sml = Opt("merchant", "tellLeader")
    L:Check("Tell the leader", gml, sml, "Items sold and repairs of the other characters are posted in the leader's chat (the FTL leader; without one online, the group leader if in the team, else the first online team member).")
    local gm, sm = Opt("merchant", "moneyFormat")
    L:Cycle("Money format", {
        { value = "text",  text = "1 gold 2 silver" },
        { value = "short", text = "1g 2s 3c" },
        { value = "coins", text = "Coin icons" },
    }, gm, sm)

    L:Header("Trade")
    local gtr, str = Opt("trade", "enabled")
    L:Check("Fill trades from role rules", gtr, str,
        "When you open a trade with a team member, the items their roles ask for go into the trade window. You still accept the trade yourself. /mmt trade fills it again.")
    local function ShareChoices()
        local l = {}
        for _, c in ipairs(RoleChoices()) do if c.value ~= "" then l[#l + 1] = c end end
        return l
    end
    L:Add(UI.MultiDropdown(page, COL_W, "Share among team", ShareChoices,
        function(role) ns.ShareRoles() return ns.db.trade.shareRoles[role] and true or false end,
        function(role)
            ns.ShareRoles()
            ns.db.trade.shareRoles[role] = not ns.db.trade.shareRoles[role] or nil
        end), UI.ROW + 2)
    L:Note("Pick any number of roles. The items of each are split evenly among the members that have that role. In a trade between two of them, the one above the even share gives what the other is missing.")
    local shareInfo = UI.Label(page, "")
    shareInfo:SetWidth(COL_W)
    shareInfo:SetJustifyH("LEFT")
    shareInfo:SetJustifyV("TOP")
    shareInfo:SetTextColor(0.75, 0.75, 0.75)
    L:Add(shareInfo, 80)

    L:Header("Sell list")
    local gsr, ssr = Opt("merchant", "sellRole")
    L:Cycle("Also sell items of role", RoleChoices, gsr, ssr)
    local gnr, snr = Opt("merchant", "neverRole")
    L:Cycle("Never sell items of role", RoleChoices, gnr, snr)
    L:Note("Lists are roles from the Roles page: create e.g. \"Sell\" and \"Keep\" with their items and rules (item, quality, Bind on Equip, item group). The never-sell list wins, greys included.")

    -- right: buy list, mail, guild bank ------------------------------------
    local R = UI.Column(page, COL2_X, 0, COL_W)
    R:Header("Buy list")
    local gby, sby = Opt("merchant", "buy")
    R:Check("Buy up to the count at vendors", gby, sby,
        "At a vendor that sells them, the items below are bought until you carry the count (gold only). Each character buys for itself, or only the character chosen for the item.")
    local buyFor = ""
    local function BuyerChoices()
        local l = { { value = "", text = "Every character" } }
        for _, key in ipairs(ns.SortedMembers()) do l[#l + 1] = { value = key, text = ns.ShownName(key) } end
        return l
    end
    local function BuyList() ns.db.merchant.buyList = ns.db.merchant.buyList or {} return ns.db.merchant.buyList end
    local list = List(page, COL_W, 4, 20, function(parent, i)
        local row = CreateFrame("Frame", nil, parent)
        RowBackground(row, i)
        row.name = UI.Label(row, "")
        row.name:SetPoint("LEFT", 6, 0)
        row.name:SetWidth(COL_W - 90)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.count = UI.Label(row, "")
        row.count:SetPoint("RIGHT", -30, 0)
        row.del = UI.TextButton(row, "x", function()
            table.remove(BuyList(), row.index)
            page.OnRefresh()
        end)
        row.del:SetPoint("RIGHT", -4, 0)
        return row
    end, function(row, entry, index)
        row.index = index
        local who = entry.who and entry.who ~= "" and ns.ShownName(entry.who)
        row.name:SetText((entry.name or ("item " .. tostring(entry.itemID))) .. (who and ("  |cff999999" .. who .. "|r") or ""))
        row.count:SetText(tostring(entry.count))
    end)
    R:Add(list, 4 * 20 + 4)
    R:Cycle("Buy on", BuyerChoices, function() return buyFor end, function(v) buyFor = v end)
    local buyStatus
    local countBox
    local itemBox = UI.EditBox(page, COL_W - 96, "Shift-click an item", function(text, box)
        local rule = ns.RuleFromText(text)
        local n = tonumber(countBox:GetText()) or 0
        if not (rule and rule.itemID) then buyStatus.Show_("Item not known: use an item link or its ID.", true) return end
        if n <= 0 then buyStatus.Show_("Enter how many to carry.", true) return end
        local entries = BuyList()
        for _, e in ipairs(entries) do
            if e.itemID == rule.itemID then
                e.count, e.who = n, buyFor ~= "" and buyFor or nil
                box:SetText(""); page.OnRefresh(); return
            end
        end
        entries[#entries + 1] = { itemID = rule.itemID, name = rule.name, count = n, who = buyFor ~= "" and buyFor or nil }
        box:SetText("")
        box:ClearFocus()
        page.OnRefresh()
    end)
    UI.AcceptItemLinks(itemBox)
    UI.Tooltip(itemBox, "Add to the buy list", "Click into the field, then shift-click an item (bags, vendor, chat link) or type its ID. Enter the count beside it, then Add. \"Buy on\" above picks the character that buys it. Adding an item again changes its count and character.")
    R:Add(itemBox, 0)
    countBox = UI.EditBox(page, 40, "20", function() itemBox:GetScript("OnEnterPressed")(itemBox) end)
    countBox:SetNumeric(true)
    countBox:SetPoint("LEFT", itemBox, "RIGHT", 6, 0)
    local add = UI.Button(page, 44, "Add", function() itemBox:GetScript("OnEnterPressed")(itemBox) end)
    add:SetPoint("LEFT", countBox, "RIGHT", 6, 0)
    R:Space(UI.ROW + 2)
    buyStatus = StatusLine(page)
    buyStatus:SetWidth(COL_W)
    R:Add(buyStatus, 16)

    R:Header("Mail")
    local gme, sme = Opt("mail", "enabled")
    R:Check("\"Mail to team\" button at the mailbox", gme, sme,
        "Sends every item in your bags that another team member's role wants to that member (team order; items your own role wants stay), 12 items per mail.")
    local ggt, sgt = Opt("mail", "goldTo")
    R:Cycle("Also mail gold to", MemberChoices, ggt, sgt)
    local gkg, skg = Opt("mail", "keepGold")
    R:Slider("Keep gold", 0, 1000, 10, gkg, skg)

    R:Header("Guild bank")
    local gge, sge = Opt("gbank", "enabled")
    R:Check("\"Deposit\" button at the guild bank", gge, sge,
        "Puts the items of the role below into the chosen tab, and optionally the gold above the amount to keep.")
    local ggr, sgr = Opt("gbank", "role")
    R:Cycle("Deposit items of role", RoleChoices, ggr, sgr)
    local gtb, stb = Opt("gbank", "tab")
    R:Slider("Tab", 1, 8, 1, gtb, stb)
    local ggg, sgg = Opt("gbank", "gold")
    R:Check("Also deposit gold above \"Keep gold\"", ggg, sgg)
    local gbk, sbk = Opt("gbank", "keepGold")
    R:Slider("Keep gold (guild bank)", 0, 1000, 10, gbk, sbk)

    page.OnRefresh = function()
        list:Render(BuyList())
        shareInfo:SetText(ns.ShareSummary and ns.ShareSummary() or "")
    end
end)

ns.RegisterPage("profiles", "Profiles", function(page)
    local col = UI.Column(page, 0, 0, PAGE_W)
    local copySource

    col:Header("Profile")
    col:Note("Profiles are shared by all characters on this account. Each character uses one profile; new characters start with \"Default\".")

    local function ProfileChoices()
        local l = {}
        for _, name in ipairs(ns.ProfileNames()) do l[#l + 1] = { value = name, text = name } end
        return l
    end
    local active = UI.Cycle(page, 360, "Active profile", ProfileChoices,
        function() return ns.CurrentProfileName() end,
        function(v) ns.SetProfile(v) end)
    col:Add(active, UI.ROW + 6)

    local status
    local function AskModules(done) ns.AskResetModules(done, function(msg) status.Show_(msg) end) end
    local newName = UI.EditBox(page, 230, "New profile name", nil)
    col:Add(newName, 0)
    local function Create(copy)
        local name = ns.Trim(newName:GetText())
        if ns.CreateProfile(name, copy and ns.db or nil) then
            ns.SetProfile(name)
            newName:SetText(""); newName:ClearFocus()
            status.Show_(("Created \"%s\"%s."):format(name, copy and " as a copy of the current settings" or ""))
            if not copy then AskModules(("Created \"%s\"."):format(name)) end
        else
            status.Show_("Enter a name that isn't used yet.", true)
        end
        ns.Refresh()
    end
    newName:SetScript("OnEnterPressed", function() Create(true) end)
    local copyCurrent = UI.Button(page, 130, "Copy current", function() Create(true) end)
    copyCurrent:SetPoint("LEFT", newName, "RIGHT", 8, 0)
    local empty = UI.Button(page, 130, "New (empty)", function() Create(false) end)
    empty:SetPoint("LEFT", copyCurrent, "RIGHT", 8, 0)
    col:Space(UI.ROW + 6)

    local source = UI.Cycle(page, 230, "Copy from", function()
        local l = {}
        for _, name in ipairs(ns.ProfileNames()) do
            if name ~= ns.CurrentProfileName() then l[#l + 1] = { value = name, text = name } end
        end
        if #l == 0 then l[1] = { value = nil, text = "-" } end
        return l
    end, function() return copySource end, function(v) copySource = v end)
    col:Add(source, 0)
    local copy = ConfirmButton(page, 130, "Copy into active", function()
        if copySource and ns.CopyProfileInto(copySource) then
            status.Show_(("Copied \"%s\" into \"%s\"."):format(copySource, ns.CurrentProfileName()))
        end
    end)
    copy:SetPoint("LEFT", source, "RIGHT", 8, 0)
    col:Space(UI.ROW + 6)

    local reset = ConfirmButton(page, 120, "Reset profile", function()
        ns.ResetProfile()
        status.Show_("Profile reset to defaults.")
        AskModules("Profile reset to defaults.")
    end)
    col:Add(reset, 0)
    local delete = ConfirmButton(page, 120, "Delete profile", function()
        local name = ns.CurrentProfileName()
        if ns.DeleteProfile(name) then status.Show_(("Deleted \"%s\"."):format(name)) ns.Refresh() end
    end)
    delete:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    UI.Tooltip(delete, "Delete profile", "Deletes the active profile. Default can't be deleted. Characters using it go back to Default.")
    col:Space(UI.ROW + 6)

    col:Header("Export / import")
    col:Note("Export, copy the text (Ctrl+A, Ctrl+C) and import it on the other account. Import uses the name box if filled, overwrites a profile of that name and activates it.")
    local area = UI.TextArea(page, PAGE_W, 110)
    col:Add(area, 118)

    local export = UI.Button(page, 120, "Export", function()
        area.edit:SetText(ns.ExportProfile())
        area.edit:SetFocus()
        area.edit:HighlightText()
        status.Show_(("Exported \"%s\"."):format(ns.CurrentProfileName()))
    end)
    col:Add(export, 0)
    local import = UI.Button(page, 120, "Import", function()
        local name, data = ns.ParseExport(area.edit:GetText())
        if not name then
            status.Show_("That text is not a valid MMT profile export.", true)
            return
        end
        local custom = ns.Trim(newName:GetText())
        if custom ~= "" then name = custom end
        ns.ImportProfile(name, data, true)
        area.edit:SetText("")
        newName:SetText("")
        status.Show_(("Profile \"%s\" imported and activated."):format(name))
        ns.Refresh()
    end)
    import:SetPoint("LEFT", export, "RIGHT", 8, 0)
    col:Space(UI.ROW + 8)

    status = StatusLine(page)
    status:SetWidth(PAGE_W)
    col:Add(status, UI.ROW)

    local syncButton = UI.SyncButton(page, "Sync to team", function() ns.SendProfileToTeam() end, "Sync core settings",
        "Same as /mmt sync: sends the core settings of the active profile (team, roles, XP window incl. its position, automations, distance window) and which modules are on or off to your group and online team members. With \"Use guild channel\" and every recipient in your guild, the settings of the modules go along too; otherwise every module page has its own Sync button. Each recipient gets a dialog to accept them (or accepts on its own, see the option beside this button).")
    local autoAccept = UI.Check(page, 250, "Auto-accept synced settings",
        function() return MMTDB.autoAcceptSync and true or false end,
        function(v) MMTDB.autoAcceptSync = v or nil end,
        "Settings a team member syncs to this client (core settings and module settings) are applied without the dialog. Only team members can sync. This option belongs to this account (all its characters) and is never synced itself.")
    autoAccept:SetPoint("RIGHT", syncButton, "LEFT", -16, 0)

    page.OnRefresh = function()
        if not copySource or copySource == ns.CurrentProfileName() or not MMTDB.profiles[copySource] then
            copySource = nil
            for _, name in ipairs(ns.ProfileNames()) do
                if name ~= ns.CurrentProfileName() then copySource = name break end
            end
        end
        source.Refresh()
        local canDelete = ns.CurrentProfileName() ~= "Default"
        delete:SetEnabled(canDelete)
        delete:SetAlpha(canDelete and 1 or 0.4)
    end
end)

---------------------------------------------------------------------------
-- Manage modules
---------------------------------------------------------------------------
ns.RegisterPage("modules", "Modules", function(page)
    local col = UI.Column(page, 0, 0, PAGE_W)
    local header = col:Header("Installed modules")
    col:Note("Modules add features on top of the core. Each one is its own addon (folder MMT_<Name>), so it can also be switched on and off in the game's AddOns list.")

    local status

    -- "github.com/..." link: click shows it ready to copy (the game can't open links)
    local function LinkButton(parent)
        local b = CreateFrame("Button", nil, parent)
        b:SetHeight(14)
        b.text = UI.Label(b, "")
        b.text:SetPoint("LEFT")
        b.text:SetTextColor(A[1], A[2], A[3])
        b:SetScript("OnClick", function(self) if self.url then UI.CopyText(self.label or "Repository", self.url) end end)
        b:SetScript("OnEnter", function(self)
            self.text:SetTextColor(1, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.url or "")
            GameTooltip:AddLine("Click to copy the link.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self) self.text:SetTextColor(A[1], A[2], A[3]); GameTooltip:Hide() end)
        b.Set = function(self, url, label)
            self.url, self.label = url, label
            self.text:SetText(url and url:gsub("^https?://", ""):gsub("/$", "") or "")
            self:SetWidth(self.text:GetStringWidth() + 2)
            self:SetShown(url ~= nil)
        end
        return b
    end

    -- core line
    local core = CreateFrame("Frame", nil, page)
    core:SetSize(PAGE_W, 18)
    core.text = UI.Label(core, "")
    core.text:SetPoint("LEFT", 8, 0)
    core.text:SetTextColor(0.7, 0.7, 0.7)
    core.link = LinkButton(core)
    core.link:SetPoint("LEFT", core.text, "RIGHT", 6, 0)
    col:Add(core, 24)

    -- module rows (scroll with the mouse wheel when there are more)
    local ROWS, ROW_H = 7, 58
    local function MakeRow(list, i)
        local row = CreateFrame("Frame", nil, list)
        RowBackground(row, i)
        row.check = UI.Check(row, 24, "", function() return row.entry and row.on end, function(v)
            if not row.entry then return end
            local result = ns.SetModuleEnabled(row.entry, v)
            if result == "reload" then
                status.Show_(row.entry.title .. " is enabled and loads after a UI reload.")
            elseif result == "active" then
                status.Show_(row.entry.title .. " is on.")
            else
                status.Show_(row.entry.title .. " is off and won't load at the next login.")
            end
            ns.RefreshConfig()
        end)
        row.check:SetPoint("TOPLEFT", 8, -6)
        row.title = UI.Label(row, "", "GameFontNormal")
        row.title:SetPoint("TOPLEFT", 34, -8)
        row.version = UI.Label(row, "")
        row.version:SetPoint("LEFT", row.title, "RIGHT", 6, 0)
        row.version:SetTextColor(0.5, 0.5, 0.5)
        row.state = UI.Label(row, "")
        row.state:SetPoint("TOPRIGHT", -8, -8)
        row.notes = UI.Label(row, "")
        row.notes:SetPoint("TOPLEFT", 34, -24)
        row.notes:SetPoint("RIGHT", -8, 0)
        row.notes:SetJustifyH("LEFT")
        row.notes:SetWordWrap(false)
        row.notes:SetTextColor(0.6, 0.6, 0.6)
        row.author = UI.Label(row, "")
        row.author:SetPoint("TOPLEFT", 34, -39)
        row.author:SetTextColor(0.5, 0.5, 0.5)
        row.link = LinkButton(row)
        row.link:SetPoint("LEFT", row.author, "RIGHT", 6, 0)
        -- notes are cut to one line: the full text in the tooltip
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            local e = self.entry
            if not e then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(e.title .. (e.version and ("  v" .. e.version) or ""))
            if e.notes ~= "" then GameTooltip:AddLine(e.notes, 1, 1, 1, true) end
            GameTooltip:AddLine("Addon folder: " .. e.addon, 0.6, 0.6, 0.6)
            if e.author then GameTooltip:AddLine("Author: " .. e.author, 0.6, 0.6, 0.6) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return row
    end
    local function FillRow(row, e)
        row.entry = e
        local active = e.module and e.module.enabled
        row.on = active or (not e.loaded and e.enabled)
        row.title:SetText(e.title)
        row.version:SetText(e.version and ("v" .. e.version) or "")
        row.notes:SetText(e.notes)
        row.author:SetText(e.author and ("by " .. e.author) or "author unknown")
        row.link:Set(e.repo, e.title .. " repository")
        if active then
            row.state:SetText("on"); row.state:SetTextColor(0.4, 1, 0.4)
        elseif e.loaded then
            row.state:SetText("off"); row.state:SetTextColor(0.6, 0.6, 0.6)
        elseif e.enabled then
            row.state:SetText("loads after reload"); row.state:SetTextColor(1, 0.85, 0.2)
        else
            row.state:SetText("off (not loaded)"); row.state:SetTextColor(0.6, 0.6, 0.6)
        end
        row.check.Refresh()
    end
    local list = List(page, PAGE_W, ROWS, ROW_H, MakeRow, FillRow)
    col:Add(list, ROWS * ROW_H + 4)
    local more = UI.Label(page, "")
    more:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", -4, 0)
    more:SetTextColor(0.5, 0.5, 0.5)

    local none = UI.Label(page, "No modules installed. Put module folders (e.g. MMT_ItemCompare) next to the MMT folder in Interface/AddOns.")
    none:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -8)
    none:SetWidth(PAGE_W - 16)
    none:SetJustifyH("LEFT")
    none:SetTextColor(0.5, 0.5, 0.5)

    status = StatusLine(page)
    status:SetWidth(PAGE_W)
    col:Add(status, UI.ROW)

    -- reload notice at the bottom, only while a reload is needed
    local notice = CreateFrame("Frame", nil, page)
    notice:SetPoint("BOTTOMLEFT", 0, 0)
    notice:SetSize(PAGE_W - 190, 34)   -- the sync button sits to the right
    UI.Fill(notice, 1, 0.85, 0.2, 0.08)
    UI.Border(notice, 1, 0.85, 0.2, 0.35)
    local reload = UI.Button(notice, 120, "Reload UI", function()
        UI.AskReload("Reload the UI now, so the module changes take effect?")
    end)
    reload:SetPoint("RIGHT", -7, 0)
    reload.label:SetTextColor(1, 0.85, 0.2)
    notice.text = UI.Label(notice, "")
    notice.text:SetPoint("LEFT", 10, 0)
    notice.text:SetPoint("RIGHT", reload, "LEFT", -10, 0)
    notice.text:SetJustifyH("LEFT")
    notice.text:SetTextColor(1, 0.85, 0.2)
    notice:Hide()

    UI.SyncButton(page, "Sync to team", function() ns.SendModuleStates() end, "Sync module on/off",
        "Same as /mmt sync modules: sends which modules are on or off to your group and online team members; they switch theirs the same way (after a dialog, unless they accept syncs automatically). Modules switched on there may need a UI reload. Module settings are not included: every module page has its own Sync button. /mmt sync sends this too, with the core settings.")

    page.OnRefresh = function()
        local v, author, repo = ns.AddOnInfo("MMT")
        core.text:SetText(("Core: MMT %s%s"):format(v or ns.version, author and ("  by " .. author) or ""))
        core.link:Set(repo, "MMT repository")

        -- switched-on modules first, then the others (each by name)
        local entries = ns.InstalledModules()
        local function On(e) return ((e.module and e.module.enabled) or (not e.loaded and e.enabled)) and true or false end
        table.sort(entries, function(a, b)
            if On(a) ~= On(b) then return On(a) end
            return a.title < b.title
        end)
        local on = 0
        for _, e in ipairs(entries) do if On(e) then on = on + 1 end end
        if header and header.SetText then header:SetText(("Installed modules (%d of %d)"):format(on, #entries)) end
        list:Render(entries)
        more:SetText(#entries > ROWS and ("%d modules, scroll for more"):format(#entries) or "")
        none:SetShown(#entries == 0)

        local pending = ns.PendingReload()
        if #pending > 0 then
            notice.text:SetText("Reload needed: " .. table.concat(pending, ", ") .. (#pending == 1 and " loads" or " load")
                .. " after a UI reload.")
            notice:Show()
        elseif ns.reloadNeeded then
            notice.text:SetText("Reload the UI to finish the module changes.")
            notice:Show()
        else
            notice:Hide()
        end
    end
end)
