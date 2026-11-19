-- MMT: at a vendor: repair, sell grey items and the items of the sell list,
-- never the items of the never-sell list, and buy the items of the buy list
-- up to their count (Trade / Mail / Vendor page).
--
-- The sell and never-sell lists are roles (Roles page): all their items and
-- rules (item, quality, Bind on Equip, item group) count.

local _, ns = ...

local POOR = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0
local BATCH, INTERVAL = 10, 0.2

local merchantOpen = false
local ticker

local function SellPrice(info)
    local price = select(11, ns.ItemInfo(info.hyperlink or info.itemID))
    return price or 0
end

-- role of the list, or nil when none is chosen / the role was deleted
local function ListRole(name)
    if name and name ~= "" and ns.db.roles[name] then return name end
end

-- should this bag item be sold?
local function ToSell(info)
    local m = ns.db.merchant
    local link = info.hyperlink or info.itemID
    local never = ListRole(m.neverRole)
    if never and ns.RoleWantsItem(never, link) then return false end
    if m.sellGrey and info.quality == POOR then return true end
    local sell = ListRole(m.sellRole)
    return sell ~= nil and ns.RoleWantsItem(sell, link)
end

local function CollectJunk()
    local list = {}
    for bag = 0, ns.BAGS do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and not info.hasNoValue and not info.isLocked and ToSell(info) then
                local price = SellPrice(info)
                if price > 0 then
                    list[#list + 1] = {
                        bag = bag, slot = slot, itemID = info.itemID,
                        count = info.stackCount or 1,
                        value = price * (info.stackCount or 1),
                    }
                end
            end
        end
    end
    return list
end

-- tell the leader's chat (another character's client)
local function Tell(msg)
    if ns.db.merchant.tellLeader and ns.TellLeader then ns.TellLeader(msg) end
end

local function Report(count, value)
    if count == 0 then return end
    if ns.db.merchant.report then
        ns.Print("%d %s sold, %s made.", count, count == 1 and "item" or "items", ns.FormatMoney(value))
    end
    Tell(("NOTE:SELL:%d:%d"):format(count, value))
end

local function SellGrey()
    if ticker then return end
    local list = CollectJunk()
    if #list == 0 then return end

    local index, count, value = 1, 0, 0
    ticker = C_Timer.NewTicker(INTERVAL, function(self)
        for _ = 1, BATCH do
            local item = list[index]
            if not item or not merchantOpen then
                self:Cancel()
                ticker = nil
                Report(count, value)
                return
            end
            index = index + 1
            if C_Container.GetContainerItemID(item.bag, item.slot) == item.itemID then
                C_Container.UseContainerItem(item.bag, item.slot)
                count = count + item.count
                value = value + item.value
            end
        end
    end)
end

local function Repair()
    if not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    local m = ns.db.merchant
    if m.guildRepair and CanGuildBankRepair and CanGuildBankRepair() then
        local limit = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
        if limit == -1 or limit >= cost then
            RepairAllItems(true)
            if m.report then ns.Print("Repaired for %s (guild bank).", ns.FormatMoney(cost)) end
            Tell(("NOTE:REPAIR:%d:g"):format(cost))
            return
        end
    end

    if GetMoney() < cost then
        ns.Print("Not enough money to repair (%s needed).", ns.FormatMoney(cost))
        Tell(("NOTE:REPAIR:%d:x"):format(cost))
        return
    end
    RepairAllItems()
    if m.report then ns.Print("Repaired for %s.", ns.FormatMoney(cost)) end
    Tell(("NOTE:REPAIR:%d:o"):format(cost))
end

---------------------------------------------------------------------------
-- Buy list: { itemID, name, count, who } bought up to count (who: only that
-- character, nil = every character)
---------------------------------------------------------------------------
local function MerchantItem(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(i)
        if info then return info.name, info.price, info.stackCount, info.numAvailable, info.hasExtendedCost end
    end
    if GetMerchantItemInfo then
        local name, _, price, stack, available, _, _, extended = GetMerchantItemInfo(i)
        return name, price, stack, available, extended
    end
end

local function ItemCount(id)
    local count = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id)) or (GetItemCount and GetItemCount(id)) or 0
    return count
end

local function BuyList()
    local m = ns.db.merchant
    if not m.buy then return end
    local bought = {}
    for _, entry in ipairs(m.buyList or {}) do
        local id, want = entry.itemID, entry.count or 0
        -- an item for one character is bought only there
        if entry.who and entry.who ~= "" and not ns.IsSelf(entry.who) then id = nil end
        local need = id and (want - ItemCount(id)) or 0
        if need > 0 then
            for i = 1, (GetMerchantNumItems and GetMerchantNumItems() or 0) do
                if GetMerchantItemID and GetMerchantItemID(i) == id then
                    local name, price, stack, available, extended = MerchantItem(i)
                    stack = (stack and stack > 0) and stack or 1
                    if extended then break end   -- costs something other than gold
                    if available and available >= 0 then need = math.min(need, available * stack) end
                    local cost = math.ceil(need / stack) * (price or 0)
                    if cost > GetMoney() then
                        ns.Print("Not enough money to buy %d x %s.", need, name or ("item " .. id))
                        break
                    end
                    -- the game sells at most one max stack per call
                    local max = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(i)) or need
                    local left = need
                    while left > 0 do
                        local n = math.min(left, max)
                        pcall(BuyMerchantItem, i, n)
                        left = left - n
                    end
                    bought[#bought + 1] = ("%d x %s"):format(need, name or ("item " .. id))
                    break
                end
            end
        end
    end
    if #bought > 0 and m.report then ns.Print("Bought %s.", table.concat(bought, ", ")) end
end

ns.On("MERCHANT_SHOW", function()
    merchantOpen = true
    local m = ns.db.merchant
    if m.repair then Repair() end
    if m.sellGrey or ListRole(m.sellRole) then SellGrey() end
    if m.buy then C_Timer.After(0.5, function() if merchantOpen then BuyList() end end) end
end)

ns.On("MERCHANT_CLOSED", function()
    merchantOpen = false
end)

-- the leader's client: notes from the team
ns.Listen("TEAM_MESSAGE", function(key, sender, text, _, channel)
    local kind, a, b = text:match("^NOTE:(%u+):(%d+):?(%w*)")
    if not kind or not ns.AcceptNotice(channel) then return end
    local who = ns.ShownName(key)
    if kind == "SELL" then
        local count = tonumber(a)
        ns.Print("%s sold %d grey %s for %s.", who, count, count == 1 and "item" or "items", ns.FormatMoney(tonumber(b) or 0))
    elseif kind == "REPAIR" then
        local cost = ns.FormatMoney(tonumber(a))
        if b == "x" then ns.Print("|cffff6666%s doesn't have enough money to repair (%s needed).|r", who, cost)
        else ns.Print("%s repaired for %s%s.", who, cost, b == "g" and " (guild bank)" or "") end
    end
end)
