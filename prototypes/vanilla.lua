local express_upgrade = mods["space-age"] and "turbo"

ModularSplitters.build_tier({ --base
    name = "",
    belt = "transport-belt",
    tint = {r=0.95, g=0.80, b=0.20},
    order = "d[modular-splitter]-a",
    ingredients = {
        {type = "item", name = "transport-belt", amount = 2}
    },
    technology = {
        unlock_with = "logistics"
    },
    next_upgrade = "fast"
})

ModularSplitters.build_tier({ --fast
    name = "fast",
    belt = "fast-transport-belt",
    tint = {r=0.85, g=0.20, b=0.20},
    order = "d[modular-splitter]-b",
    ingredients = {
        {type = "item", name = "modular-splitter", amount = 1}
    },
    technology = {
        unlock_with = "logistics-2"
    },
    previous = "",
    next_upgrade = "express"
})

ModularSplitters.build_tier({ --express
    name = "express",
    belt = "express-transport-belt",
    tint = {r=0.20, g=0.50, b=0.95},
    order = "d[modular-splitter]-c",
    ingredients = {
        {type = "item", name = "fast-modular-splitter", amount = 1}
    },
    technology = {
        unlock_with = "logistics-3"
    },
    previous = "fast",
    next_upgrade = express_upgrade
})