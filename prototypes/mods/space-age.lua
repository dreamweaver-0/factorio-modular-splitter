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