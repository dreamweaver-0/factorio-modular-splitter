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

--[[ModularSplitters.build_tier({ --fast
    name = "fast",
    transport_belt = "fast-transport-belt",
    color = {255, 24, 38},
    fluid = "lubricant",
    fluid_per_minute = "0.03",
    fluid_technology_prerequisites = {"lubricant"},
    technology = {
        prerequisites = {"logistics-2", "modular-splitter", "advanced-circuit", "chemical-science-pack"},
        unit = {
            count = 250,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1}
            },
            time = 30
        }
    },
    recipe = {
        categories = crafting_categories,
        ingredients = {
            {type = "item", name = "modular-splitter", amount = 1},
            {type = "item", name = "iron-gear-wheel", amount = 12},
            {type = "item", name = "iron-plate", amount = 8},
            {type = "item", name = "electronic-circuit", amount = 6}
        },
        energy_required = 8,
        icons = {
            {
                icon = "graphics/technology/modular-splitter.png",
                icon_size = 256
            }
        }
    },
    next_upgrade = "express-transport-belt"
})

ModularSplitters.build_tier({ --express
    name = "express",
    transport_belt = "express-transport-belt",
    color = {0, 255, 255},
    fluid = "lubricant",
    fluid_per_minute = "0.04",
    fluid_technology_prerequisites = {"lubricant"},
    technology = {
        prerequisites = {"logistics-3", "modular-splitter", "processing-unit"},
        unit = {
            count = 350,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1}
            },
            time = 15
        }
    },
    recipe = {
        categories = crafting_categories,
        ingredients = {
            {type = "item", name = "modular-splitter", amount = 1},
            {type = "item", name = "iron-gear-wheel", amount = 12},
            {type = "item", name = "iron-plate", amount = 8},
            {type = "item", name = "electronic-circuit", amount = 6}
        },
        energy_required = 8,
        icons = {
            {
                icon = "graphics/technology/modular-splitter.png",
                icon_size = 256
            }
        }
    },
    next_upgrade = express_upgrade
})
]]