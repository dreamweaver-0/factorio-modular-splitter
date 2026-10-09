ModularSplitters.build_tier({ --turbo
    name = "turbo",
    belt = "turbo-transport-belt",
    tint = {r=0.55, g=0.80, b=0.20},
    order = "d[modular-splitter]-d",
    ingredients = {
        {type = "item", name = "express-modular-splitter", amount = 1}
    },
    technology = {
        unlock_with = "turbo-transport-belt"
    },
    previous = "express"
})

--[[ ModularSplitters.build_tier({ --turbo
    name = "turbo",
    transport_belt = "turbo-transport-belt",
    color = {155, 182, 0},
    fluid = "lubricant",
    fluid_per_minute = "0.05",
    default_import_location = "vulcanus",
    technology = {
        prequisites = {"turbo-transport-belt", "turbo-splitter", "processing-unit"},
        unit = {
            count = 1000,
            ingredients = data.raw.technology["turbo-transport-belt"].unit.ingredients,
            time = 15
        }
    },
    recipe = {
        categories = {"crafting-with-fluid", "metallurgy"},
        ingredients = {
            {type = "item", name = "express-modular-splitter", amount = 1},
            {type = "item", name = "tungsten-plate", amount = 30},
            {type = "item", name = "processing-unit", amount = 5},
            {type = "fluid", name = "lubricant", amount = 50}
        },
        energy_required = 8,
        icons = {
            {
                icon = "graphics/technology/modular-splitter.png",
                icon_size = 256
            }
        }
    }
}) ]]