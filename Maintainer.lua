local ae2 = require("src.AE2")
local cfg = require("config")
local util = require("src.Utility") 

local groups = cfg.items
local sleepInterval = cfg.sleep
local randomizeFrequency = cfg.randomizeFrequency
local priorityMode = cfg.priorityMode

local shuffleCounter = 0
local shuffleLists = false
local recipeGroupsRandomized = randomizeFrequency ~= 0


function batchReady(groupTbl, itemsCrafting, groupNumber)
    if groupTbl.batchMode == true then
        local batchReady = ae2.batchReady(groupTbl.entries, itemsCrafting)
        if (not batchReady) then
            logInfo("Group " .. groupNumber .. ": busy")
            return false
        end
    end
    return true
end


logInfo("Loading groups...")
local groupCache = setupGroupCache(groups)
logInfo("Groups ready.")

logInfo("Checking recipes...")
local checkedRecipes = {}
for _, group in ipairs(groups) do
    for name in pairs(group.entries) do
        if not checkedRecipes[name] then
            local craftable, message = ae2.isCraftable(name)
            if craftable == false then
                logInfo("No recipe: " .. name)
            elseif craftable == nil then
                logInfo(message)
            end
            checkedRecipes[name] = true
        end
    end
end
logInfo("Recipes checked.")

local idxTable = {}
for i=1, #groups do
    idxTable[i] = i
end

-- Clean up potential unspecified priorities and batch mode specifiers
for _, group in ipairs(groups) do
    if group.priority == nil then
        group.priority = 0
    end
    if group.batchMode == nil then
        group.batchMode = false
    end
end

if priorityMode then
    -- Sort based on priority.
    table.sort(groups, function (groupA, groupB)
        return groupA.priority > groupB.priority
    end)
end

while true do
    local itemsCrafting = ae2.checkIfCrafting()

    -- randomize recipe groups
    if (not priorityMode) and recipeGroupsRandomized and shuffleLists then
        logInfo("Groups shuffled.")
        randomizeTable(idxTable)
    end

    for _, randGroupIdx in ipairs(idxTable) do
        local groupTbl = groups[randGroupIdx]

        logInfo("-- Group " .. randGroupIdx .. " --")

        -- Step 1: Randomize if necessary.
        local itemKeys = groupCache[randGroupIdx]
        -- shuffle in-group items if necessary.
        if shuffleLists then -- stays false if randomization is disabled.
            logInfo("Group " .. randGroupIdx .. ": shuffled")
            randomizeTable(itemKeys)
            groupCache[randGroupIdx] = itemKeys
        end

        -- Step 2: Skip group if batch isn't ready.
        if (not batchReady(groupTbl, itemsCrafting, randGroupIdx)) then
            goto skipGroup
        end

        -- Step 3: Craft items in group.
        for _, item in ipairs(itemKeys) do
            local config = groupTbl.entries[item]
            if itemsCrafting[item] == true then
                logInfo("Crafting: " .. item)
            else
                local success, answer = ae2.requestItem(item, config[1], config[2], config[3])
                logInfo(answer)
            end
        end

        ::skipGroup::
    end

    -- Update flag that indicates groups should be randomized.
    if recipeGroupsRandomized then
        shuffleLists = (shuffleCounter == 0)
        shuffleCounter = (shuffleCounter + 1) % randomizeFrequency
    end

    os.sleep(sleepInterval)
end
