local component = require("component")
local ME = component.me_interface

local AE2 = {}

-- Lightweight cache for specific items only
local itemCache = {}
local cacheTimestamp = 0
local CACHE_DURATION = 600 -- 10 minutes in seconds

local function requireMethod(object, method, owner)
    if object == nil or type(object[method]) ~= "function" then
        error((owner or "ME interface") .. " is missing " .. method .. "()", 0)
    end
    return object[method]
end

-- allItems returns a stack iterator on OC; also accept a plain stack list.
-- Match the same label used by the craftable filter, without craftable metadata.
local function getStockForItem(name)
    local stacks = requireMethod(ME, "allItems")()
    local size = 0
    local function add(stack)
        if stack.label == name then
            if type(stack.size) ~= "number" then
                error("allItems() returned an item without a numeric size", 0)
            end
            size = size + stack.size
        end
    end
    local mt = getmetatable(stacks)
    if type(stacks) == "function" or (type(mt) == "table" and mt.__call) then
        for stack in stacks do
            add(stack)
        end
    elseif type(stacks) == "table" then
        for _, stack in ipairs(stacks) do
            add(stack)
        end
    else
        error("allItems() did not return a stack iterator or list", 0)
    end
    return {label = name, size = size}
end

-- Function to get or cache a specific craftable item
local function getCraftableForItem(itemName)
    local currentTime = os.time()
    
    -- Check if we have a cached version of this specific item and it's still valid
    if itemCache[itemName] and currentTime - cacheTimestamp < CACHE_DURATION then
        return itemCache[itemName]
    end
    
    -- If cache is too old, clear it completely to save memory
    if currentTime - cacheTimestamp >= CACHE_DURATION then
        itemCache = {}
        cacheTimestamp = currentTime
    end
    
    -- Look for this specific item in craftables
    local craftables = requireMethod(ME, "getCraftables")({["label"] = itemName})
    if type(craftables) ~= "table" then
        error("getCraftables() did not return a craftable list", 0)
    end
    if #craftables >= 1 then
        itemCache[itemName] = craftables[1] -- Cache only this one item
        return craftables[1]
    end
    
    itemCache[itemName] = nil -- Cache that it's not craftable
    return nil
end

local function requestItem(name, threshold, count, fluidRegistry)
    local craftable = getCraftableForItem(name)

    if craftable then
        if threshold ~= nil then
            local itemInSystem = nil

            if fluidRegistry then
                itemInSystem = requireMethod(ME, "getFluidInNetwork")(fluidRegistry)
            else
                itemInSystem = getStockForItem(name)
            end

            if itemInSystem ~= nil and itemInSystem.size >= threshold then
                return table.unpack({false, "The amount of " .. (itemInSystem.label or name) .. " (" .. itemInSystem.size .. ") meets or exceeds threshold (" .. threshold .. ")! Aborting request."})
            end
        end

        -- getCraftables was already filtered by the configured label.
        requireMethod(craftable, "request", "Craftable for " .. name)
        local craft = craftable.request(count)
        requireMethod(craft, "isComputing", "Crafting job for " .. name)
        requireMethod(craft, "hasFailed", "Crafting job for " .. name)

        while craft.isComputing() == true do
            os.sleep(1)
        end
        if craft.hasFailed() then
            return table.unpack({false, "Failed to request " .. name .. " x " .. count})
        else
            return table.unpack({true, "Requested " .. name .. " x " .. count})
        end
    end
    return table.unpack({false, name .. " is not craftable!"})
end

function AE2.requestItem(name, threshold, count, fluidRegistry)
    local ok, success, message = pcall(requestItem, name, threshold, count, fluidRegistry)
    if not ok then
        return false, "Unable to request " .. tostring(name) .. ": " .. tostring(success)
    end
    return success, message
end

function AE2.checkIfCrafting()
    local cpus = ME.getCpus()
    local items = {}
    for k, v in pairs(cpus) do
        local finaloutput = v.cpu.finalOutput()
        if finaloutput ~= nil then
            items[finaloutput.label] = true
        end
    end

    return items
end

-- Function to manually clear the cache if needed
function AE2.clearCache()
    itemCache = {}
    cacheTimestamp = 0
end

-- Returns true if none of the items from entries are crafting according to itemsCrafting.
function AE2.batchReady(entries, itemsCrafting)
    local batchReady = true
    for itemName, config in pairs(entries) do
        if itemsCrafting[itemName] then
            batchReady = false
        end
    end
    return batchReady
end

return AE2
