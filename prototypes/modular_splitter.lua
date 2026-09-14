local mode = settings.startup["modular-splitter-modes"]
local cost_mult = settings.startup["modular-splitter-cost-multiplier"]

local function build_entity(tier)
    local structure = tier.structure or "modular-splitter"
    
    local entity = {
        name = tier.name,
        type = "modular-splitter",
        icons = {

        },
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = tier.name
        },
        max_health = 500,
        filter_count = 10,
        corpse = "small_remnants",
        dying_explosion = tier.transport_belt.dying_explosion,
        resistances = {
            {
                type = "fire",
                percent = 80
            }
        },
        speed = tier.speed,
        collision_box = { {-0.6 , -1.2} , {0.6 , 1.2} },
        selection_box = { {-0.5 , -1.5} , {0.5 , 1.5} },
        drawing_box = { {-0.5 , -1.5} , {0.5 , 1.5} },
        animation_speed_coefficient = 32,
    }

    if feature_flags["space_travel"] then
        entity.adjustable_belt_stack_size = true
    end

    data:extend {entity}

    return data.raw["modular_splitter"][tier.name]
end

local function build_item(tier)
    
    data:extend {
        {
            name = tier.name,
            type = "item",
            icons = {

            },
            stack_size = 64,
            default_import_location = tier.default_import_location,
            subgroup = tier.subgroup or "transport_belt",
            place_result = tier.name
        }
    }

    return data.raw.item[tier.name]
end

local function build_recipe(tier)
    local cost_mult = settings.startup["modular-splitter-cost-multiplier"].value
    local lubed = settings.startup["modular-splitter-lubricated"].value
    
    local recipe = tier.recipe
    if cost_mult ~= 1 then
        for _, item in pairs(recipe.ingredients) do
            item.amount = item.amount * cost_mult
        end
    end
    data:extend{recipe}
    return data.raw.recipe[recipe.name]
end

local function build_tech(tier)
    local name = tier.technology and tier.technology.name or tier.name

    if not data.raw.technology[tier.name] then
        local tech = {
        name = name,
        type = "technology",
        icons = {
                {
                    icon = "graphics/technology/modular-splitter.png",
                    icon_size = 256
                }
            }
        }

        tech.unit = tier.technology.unit
        tech.upgrade = false
        tech.prerequisites = tier.technology.prerequisites or {}

        data:extend{tech}
    end
    return data.raw.technology[name]
end

ModularSplitters = ModularSplitters or {} --declaring global func?

function ModularSplitters.build_tier(data)
    if not data.color then
        debug_log("No color provided, using default")
        data.color = {r = 1.0, g = 1.0, b = 1.0}
    end
    for k, v in pairs(data) do --check for empty values; is this necessary?
        if not v then
            debug_log("Attempted to build tier with empty value for "..k)
            return
        end
    end
    if data.name == "" then --prefix belt tier
        data.name = "modular-splitter"
    else
        data.name = data.name .. "-modular-splitter"
    end
    data.transport_belt = data.raw["transport-belt"][data.transport_belt]
    
    local entity = build_entity(data)
    local item = build_item(data)
    local recipe = build_recipe(data)
    local tech = build_tech(data)

    if tech and recipe then
        tech.effects = tech.effects or {}
        table.insert(tech.effects, {type = "unlock-recipe", recipe = recipe.name})
    end

    return {loader = entity, item = item, recipe = recipe, technology = tech}
end