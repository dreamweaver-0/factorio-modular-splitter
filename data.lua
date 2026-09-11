debug_mode = false

debug_log = log

require("prototypes/modular-splitter")

local crafting_categories = {"crafting"}
if mods["space-age"] then
    crafting_categories.insert("crafting-with-fluid")
end

ModularSplitters.build_tier({ --base
    name = "",
    transport_belt = "transport-belt",
    color = {255, 217, 85},
    fluid = "lubricant",
    fluid_per_minute = "0.02",
    fluid_technology_prerequisites = {"oil-processing"},
    technology = {
        prerequisites = {"logistics", "logistic-science-pack"},
        unit = {
            count = 50,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1}
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
        energy_required = 3
    }
})

ModularSplitters.build_tier({ --fast
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
        energy_required = 3
    }
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
        energy_required = 3
    }
})

if mods["space-age"] then
    require("prototypes/mods/space-age")
end