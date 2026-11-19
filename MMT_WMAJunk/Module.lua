-- MMT_WMAJunk: at a vendor, sell the items this character marked Junk in WMA
-- (Alt+right-click in the bags). WMA keeps the marks per character; this module only reads
-- them through WMA:IsMarkedJunk(itemID). Grey items are left to MMT's own "Sell grey items".
-- The never-sell list (Roles page) still protects items, same as for MMT's own selling.
local MMT = MMT
local M = MMT.NewModule({
    name = "WMAJunk",
    title = "WMA Junk Seller",
    description = "Sells the items you marked Junk in WMA when you open a vendor.",
    defaults = { report = true },
})

local BATCH, INTERVAL = 10, 0.2
local merchantOpen, ticker = false, nil
local BAGS = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

local function Protected(link)
    local never = MMT.db.merchant and MMT.db.merchant.neverRole
    return never and never ~= "" and MMT.db.roles[never] and MMT.RoleWantsItem(never, link)
end

local function Collect()
    local list = {}
    for bag = 0, BAGS do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and not info.hasNoValue and not info.isLocked
                and WMA:IsMarkedJunk(info.itemID) and not Protected(info.hyperlink or info.itemID) then
                local price = select(11, MMT.ItemInfo(info.hyperlink or info.itemID)) or 0
                if price > 0 then
                    local n = info.stackCount or 1
                    list[#list + 1] = { bag = bag, slot = slot, itemID = info.itemID, count = n, value = price * n }
                end
            end
        end
    end
    return list
end

local function Sell()
    if ticker then return end
    if not (WMA and WMA.IsMarkedJunk) then return end
    local list = Collect()
    if #list == 0 then return end
    local index, count, value = 1, 0, 0
    ticker = C_Timer.NewTicker(INTERVAL, function(self)
        for _ = 1, BATCH do
            local item = list[index]
            if not item or not merchantOpen then
                self:Cancel()
                ticker = nil
                if count > 0 and M.db.report then
                    MMT.Print("%d junk %s sold, %s made.", count, count == 1 and "item" or "items", MMT.FormatMoney(value))
                end
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

M:On("MERCHANT_SHOW", function()
    merchantOpen = true
    Sell()
end)
M:On("MERCHANT_CLOSED", function() merchantOpen = false end)

M.OnDisable = function() merchantOpen = false end

M.Page = function(self, page)
    local col = MMT.UI.Column(page, 0, 0, MMT.ConfigHelpers.COL_W)
    col:Header("WMA Junk Seller")
    col:Check("Print results to chat", function() return M.db.report end, function(v) M.db.report = v end)
    col:Note((WMA and WMA.IsMarkedJunk) and "WMA found. Alt+right-click an item in your bags to mark it Junk; it sells the next time you open a vendor."
        or "WMA is not loaded, so nothing is sold. Install and enable the WMA addon.")
end
