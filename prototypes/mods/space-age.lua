local turbo_tier = {
    name = "turbo",
    transport_belt = "turbo-transport-belt",
    color = {155, 182, 0},
    fluid = "lubricant",
    fluid_per_minute = "0.05",
    default_import_location = "vulcanus",
    technology = {
        prequisites = {"turbo-transport-belt"},
        unit = {
            count = 500,
            ingredients = data.raw.technology["turbo-transport-belt"].unit.ingredients,
            time = 15
        }
    }
}