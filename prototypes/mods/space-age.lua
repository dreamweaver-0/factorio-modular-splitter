local turbo_tier = {
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
    },

}