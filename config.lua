local cfg = {}

cfg["items"] = {
    { -- Group 1
        priority = 3,
        batchMode = true,
        entries = {
            ["Aluminium Ingot"] = {256, 16},
            ["Stainless Steel Ingot"] = {256, 8},
        }
    },    
    { -- Group 2
        priority = 3,
        batchMode = true,
        entries = {
            ["Integrated Processor"] = {32,4},
            ["Processor Assembly"] = {16, 2},
            ["Workstation"] = {8, 2},
        }
    }

}

-- Higher values reduce lag, but decrease throughput.
cfg["sleep"] = 10

-- Randomizes the order recipes are scheduled within their group
-- Higher values reduce lag, but lower values increase fairness.
-- 0 to disable.
-- If priorityMode is false, recipe groups are additionally scheduled in random order.
cfg["randomizeFrequency"] = 2

-- false: disable randomization of the order recipe groups are attemped
-- to be scheduled.
-- true: higher priority recipe groups are scheduled first.
cfg["priorityMode"] = true

return cfg
