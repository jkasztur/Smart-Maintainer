-- Run from the repository root: lua tests/AE2_test.lua (Lua 5.2+).
local me
package.preload.component = function() return {me_interface = me} end
local tests = 0
local function setup(stacks)
    local calls = {requests = 0, lookups = 0, scans = 0, sleeps = 0}
    local job = {isComputing = function() return false end, hasFailed = function() return false end}
    -- Deliberately no getStack: GTNH 2.8.4 craftables only need request.
    local craftable = {request = function(amount)
        calls.requests = calls.requests + 1
        calls.amount = amount
        return job
    end}
    me = {
        getCraftables = function(filter)
            assert(filter.label == "Processor Assembly")
            calls.lookups = calls.lookups + 1
            return {craftable}
        end,
        allItems = function()
            calls.scans = calls.scans + 1
            local i = 0
            return setmetatable({}, {__call = function()
                i = i + 1
                return (stacks or {})[i]
            end})
        end,
        getFluidInNetwork = function(registry)
            assert(registry == "test.fluid")
            return {size = 1000}
        end,
        getCpus = function()
            return {{cpu = {finalOutput = function() return {label = "Processor Assembly"} end}}}
        end,
    }
    os.sleep = function() calls.sleeps = calls.sleeps + 1 end
    package.loaded.component = nil
    package.loaded["src.AE2"] = nil
    return require("src.AE2"), calls, craftable, job
end
local function test(name, run)
    run()
    tests = tests + 1
    print("ok - " .. name)
end
local function fails(ae2, expected, threshold)
    local ok, message = ae2.requestItem("Processor Assembly", threshold, 1)
    assert(ok == false and message:find(expected, 1, true), tostring(message))
end

test("request without getStack or stock API when threshold is nil", function()
    local ae2, calls = setup()
    me.allItems = nil
    assert(ae2.requestItem("Processor Assembly", nil, 3))
    assert(calls.requests == 1 and calls.amount == 3)
end)
test("empty stock crafts; craftable cache does not cache stock", function()
    local stacks = {}
    local ae2, calls = setup(stacks)
    assert(ae2.requestItem("Processor Assembly", 10, 2))
    stacks[1] = {label = "Processor Assembly", size = 10}
    fails(ae2, "meets or exceeds threshold", 10)
    assert(calls.requests == 1 and calls.lookups == 1 and calls.scans == 2)
    ae2.clearCache()
    fails(ae2, "meets or exceeds threshold", 10)
    assert(calls.lookups == 2)
end)
test("stock sums matching labels and ignores other items", function()
    local ae2, calls = setup({
        {label = "Processor Assembly", size = 4},
        {label = "Other", size = 100},
        {label = "Processor Assembly", size = 6},
    })
    fails(ae2, "meets or exceeds threshold", 10)
    assert(calls.requests == 0)
    assert(ae2.requestItem("Processor Assembly", 11, 2))
end)
test("plain list and function iterator stock results", function()
    local ae2 = setup()
    me.allItems = function() return {{label = "Processor Assembly", size = 10}} end
    fails(ae2, "meets or exceeds threshold", 10)
    me.allItems = function()
        local done = false
        return function()
            if done then return nil end
            done = true
            return {label = "Processor Assembly", size = 10}
        end
    end
    fails(ae2, "meets or exceeds threshold", 10)
end)
test("not craftable", function()
    local ae2, calls = setup()
    me.getCraftables = function() return {} end
    fails(ae2, "is not craftable!")
    assert(calls.requests == 0)
end)
test("missing lookup and stock methods return useful errors", function()
    local ae2 = setup()
    me.getCraftables = nil
    fails(ae2, "missing getCraftables()")
    ae2 = setup()
    me.allItems = nil
    fails(ae2, "missing allItems()", 10)
    me.getFluidInNetwork = nil
    local ok, message = ae2.requestItem("Processor Assembly", 10, 1, "test.fluid")
    assert(ok == false and message:find("missing getFluidInNetwork()", 1, true))
end)
test("missing request and job methods return useful errors", function()
    local ae2, _, craftable, job = setup()
    craftable.request = nil
    fails(ae2, "missing request()")
    ae2, _, craftable, job = setup()
    job.isComputing = nil
    fails(ae2, "missing isComputing()")
    ae2, _, craftable, job = setup()
    job.hasFailed = nil
    fails(ae2, "missing hasFailed()")
    craftable.request = function() return nil end
    fails(ae2, "missing isComputing()")
end)
test("invalid API results and API exceptions are reported", function()
    local ae2 = setup()
    me.getCraftables = function() return nil end
    fails(ae2, "did not return a craftable list")
    ae2 = setup()
    me.allItems = function() return nil end
    fails(ae2, "did not return a stack iterator or list", 10)
    me.allItems = function() error("network unavailable") end
    fails(ae2, "network unavailable", 10)
end)
test("fluid thresholds preserve registry lookup", function()
    local ae2, calls = setup()
    local ok = ae2.requestItem("Processor Assembly", 1000, 1, "test.fluid")
    assert(ok == false and calls.requests == 0 and calls.scans == 0)
    assert(ae2.requestItem("Processor Assembly", 1001, 1, "test.fluid"))
end)
test("job computing and failure behavior", function()
    local ae2, calls, _, job = setup()
    job.isComputing = function() return calls.sleeps < 2 end
    job.hasFailed = function() return true end
    fails(ae2, "Failed to request")
    assert(calls.sleeps == 2 and calls.requests == 1)
end)
test("CPU detection and batch readiness", function()
    local ae2 = setup()
    local crafting = ae2.checkIfCrafting()
    assert(crafting["Processor Assembly"])
    assert(not ae2.batchReady({["Processor Assembly"] = {}}, crafting))
    assert(ae2.batchReady({Other = {}}, crafting))
end)
print(tests .. " tests passed")
