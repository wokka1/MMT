-- MMT module: Heal (step 1: diagnostic only).
--
-- /mmtheal check   can this client read party / pet health right now? Prints and logs to MMTDB.healLog.
-- /mmtheal combat  arm: logs the same check at the start of the next fight, 1s, 3s and 6s in.
-- /mmtheal clear   empty the log
-- The log is written to SavedVariables on /reload or logout.

local MMT = MMT

local M = MMT.NewModule({
    name = "Heal",
    title = "Heal",
    description = "Heal keys for a boxed healer (diagnostic stage).",
    sync = false,
    defaults = {},
})

local UNITS = { "player", "target", "party1", "party2", "party3", "party4", "pet",
                "partypet1", "partypet2", "partypet3", "partypet4" }

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
    if C_Secrets then
        for _, fn in ipairs({ "ShouldUnitHealthBeSecret", "ShouldUnitComparisonBeSecret", "ShouldAurasBeSecret" }) do
            if C_Secrets[fn] then
                local ok, r = pcall(C_Secrets[fn], "party1")
                Log("C_Secrets.%s(party1) = %s", fn, ok and Show(r) or ("err " .. tostring(r)))
            end
        end
    else
        Log("C_Secrets not present")
    end
    for _, u in ipairs(UNITS) do
        if UnitExists(u) then
            local okH, h = pcall(UnitHealth, u)
            local okM, m = pcall(UnitHealthMax, u)
            local okF, pct = pcall(function() return UnitHealth(u) / UnitHealthMax(u) end)
            Log("%s %s hp=%s max=%s ratio=%s", u, Show(UnitName(u)), okH and Show(h) or "err",
                okM and Show(m) or "err", okF and Show(pct) or "ERR(arith)")
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
    for _, t in ipairs({ 1, 3, 6 }) do
        C_Timer.After(t, function() Check("combat +" .. t .. "s") end)
    end
end)

SLASH_MMTHEAL1 = "/mmtheal"
SlashCmdList.MMTHEAL = function(msg)
    if not M.enabled then MMT.Print("Heal is switched off (/mmt > Modules).") return end
    local cmd = (msg or ""):match("^%s*(%S*)"):lower()
    if cmd == "check" then
        Check("manual")
    elseif cmd == "combat" then
        armed = true
        MMT.Print("armed: the check runs when the next fight starts. /reload afterwards to write the log.")
    elseif cmd == "clear" then
        if MMTDB then MMTDB.healLog = {} end
        MMT.Print("log cleared.")
    else
        MMT.Print("/mmtheal check | combat | clear")
    end
end
