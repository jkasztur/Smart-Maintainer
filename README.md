# Smart Maintainer

<!--toc:start-->
- [Smart Maintainer](#smart-maintainer)
  - [Requirements](#requirements)
  - [Installation](#installation)
  - [Config](#config)
    - [Items](#items)
    - [Fluids](#fluids)
  - [Example](#example)
<!--toc:end-->

Keeps stock of items up to a threshold or indefinitely. Uses randomization to prevent crafts, on average, from
repeatedly taking high priority crafting CPUs and blocking others.

Here's an example using one EBF to continuously level maintain three ingots...

#### Smart Maintainer

<img width="263" height="113" alt="image" src="https://github.com/user-attachments/assets/32601bbb-22df-4728-a140-4f47abb31761" />

Every ingot gets its chance to smelt!

#### Standard OC Maintainer

<img width="249" height="111" alt="image" src="https://github.com/user-attachments/assets/8b245823-72c6-4cda-ad97-2dcd16d31b98" />

Tungstensteel is stuck waiting to craft forever!

## Requirements

In addition to an functional OpenComputers computer,

- A full block ME interface connected to an OpenComputers adapter;
- Crafting Monitors on **all** CPUs attached to the interface's network;
- An internet card.

## Installation

Download and install in the computer:

```bash
wget https://raw.githubusercontent.com/rajsugavanam/Smart-Maintainer/master/installer.lua && installer
```

This requires an internet card.

Run the program using

```bash
Maintainer
```

## Config

Change maintained items in `config.lua`.

Items are specified within **recipe groups**:
```lua
cfg["items"] = {
    { -- Group 0
        priority = 2,
        batchMode = false,
        entries = {
            ["drop of Molten Polybenzimidazole"] = {512000, 16000, "molten.polybenzimidazole"},
        }
    },
    { -- Group 1
        -- Priority mode: every cycle, recipe groups with higher priority
        -- will be attempted first, default 0 if unspecified (priorityMode = false: recipe groups are randomized in order).
        -- randomizeFrequency = k: every k cycles, the order in which these items are attempted to craft is shuffled (k=0: disable this behavior)
        priority = 3,
        -- batchMode = true: items within the group will be crafted only if none are currently being crafted.
        -- Decreases throughput, increases fairness. Useful for very long recipes.
        batchMode = true,
        entries = {
            ["Aluminium Ingot"] = {nil, 16},
            ["Stainless Steel Ingot"] = {512, 8},
        }
    }
}
```

**priorityMode**: If group *A* has priority *i* and group *B* has priority *j*, items in *A* will attempt to craft before items in B if *i* > *j*.

**batchMode**: If enabled for a group *A*, items in *A* will only craft if no items from *A* are currently crafting.
Useful *with in-group randomization* for when all recipes in a group are too slow. Decreases crafting throughput due to lower scheduling frequency,
but can greatly increase fairness for which items get machine time.

**entries**: Configure the items and fluids in a group.

### Items

`["item_name"] = {threshold, batch_size}`.

### Fluids

`["item_name"] = {threshold, batch_size, registry_name}`.

> [!TIP]
> Find the registry name of a fluid by hovering over the fluid in NEI.

> [!NOTE]
> If you do not require a limit for an item to be stocked up to, set `threshold` to `nil`.

> [!NOTE]
> Reboot the computer and rerun `Maintainer` after changing the config values.

> [!CAUTION]
> Smart blocking can alter the effectiveness of this program.

## GTNH 2.8.4 compatibility

Craftables are selected with `getCraftables({label = configured_name})` and
submitted with `craftable.request(amount)`. Smart Maintainer does not require
`getStack()` on craftable objects. The first matching craftable is used, as before.

Item stock thresholds use a fresh `allItems()` stack iterator (or stack list),
summing `size` for stacks whose `label` matches the configured name. Labels should
uniquely identify maintained items: items with the same display label share a stock
count. No `getItemsInNetwork()` or `getItemInNetwork()` method is required.
Fluid thresholds still use `getFluidInNetwork(registry_name)`.

The remaining API requirements are job methods `isComputing()` and `hasFailed()`,
and CPU monitoring through `getCpus()` and `cpu.finalOutput()` (returning an output
with a `label`). Missing methods or API errors during requests return `false` and
an explanatory message. CPU monitoring retains its existing behavior.

Run the mocked regression tests from the repository root with Lua 5.2 or later:

```sh
lua tests/AE2_test.lua
```

These tests do not replace an in-game check of the adapter and ME network.

## Example

You want to passively smelt Stainless Steel, Aluminium, and Black Steel in your very slow EBF.
The maintainer schedules items in that priority order (based on crafting CPUs).

Stainless Steel is smelted in the EBF, but after one recipe of Aluminium is pushed in, Stainless Steel is
scheduled again and continues to hog the EBF. Black Steel almost never gets the chance to smelt.

The following group could resolve this problem,
```lua
    {
        priority = 0,
        batchMode = true,
        entries = {
            ["Aluminium Ingot"] = {nil, 16},
            ["Stainless Steel Ingot"] = {nil, 8},
            ["Black Steel Ingot"] = {nil, 8},
        }
    }
```

in addition to the following options:
```lua
cfg["randomizeFrequency"] = 2
cfg["priorityMode"] = true
```
