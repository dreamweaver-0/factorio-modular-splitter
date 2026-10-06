local mode = settings.startup["modular-splitter-modes"]
local cost_mult = settings.startup["modular-splitter-cost-multiplier"]
local BASE_NAME = "modular-splitter"

local function build_item(tier)
    
    data:extend {
        {
            name = tier.name,
            type = "item",
            icons = {
                {
                    icon = "graphics/icons/modular-splitter-item.jpg",
                    icon_size = 256
                }
            },
            stack_size = 64,
            default_import_location = tier.default_import_location,
            subgroup = tier.subgroup or "transport_belt",
            place_result = tier.name
        }
    }

    return data.raw.item[tier.name]
end

local function build_entity(tier)
    local entity = table.deepcopy(data.raw["transport-belt"][BASE_NAME]) --[[{
        type = "transport-belt-connectable",
        name = tier.name,
        speed = 100,
        icons = {
            {
                icon = "graphics/icons/modular-splitter-item.jpg",
                icon_size = 256
            }
        },

    }]]
    --[[ local structure = tier.structure or "modular-splitter"
    
    local entity = {
        name = tier.name,
        type = "transport-belt",
        icons = {
                {
                    icon = "graphics/icons/modular-splitter-item.jpg",
                    icon_size = 256
                }
            },
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

    return data.raw["transport-belt"][tier.name] ]]
end

local function build_recipe(tier)
    local cost_mult = settings.startup["modular-splitter-cost-multiplier"].value
    local lubed = settings.startup["modular-splitter-mode"].value
    
    local recipe = tier.recipe
    if not tier.recipe.type then
        tier.recipe.type = "recipe"
    end
    if not tier.recipe.name then
        tier.recipe.name = tier.name .. "-recipe"
    end
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
function ModularSplitters.build_tier(prototype)
    --[[if not prototype.color then
        debug_log("No color provided, using default")
        prototype.color = {r = 1.0, g = 1.0, b = 1.0}
    end
    for k, v in pairs(prototype) do --check for empty values; is this necessary?
        if not v then
            debug_log("Attempted to build tier with empty value for "..k)
            return
        end
    end
    if prototype.name == "" then --prefix belt tier
        prototype.name = "modular-splitter"
    else
        prototype.name = prototype.name .. "-modular-splitter"
    end
    --prototype.transport_belt = data.raw["transport-belt"][prototype.transport_belt]
    
    local entity = build_entity(prototype)
    local item = build_item(prototype)
    local recipe = build_recipe(prototype)
    local tech = build_tech(prototype)

    if tech and recipe then
        tech.effects = tech.effects or {}
        table.insert(tech.effects, {type = "unlock-recipe", recipe = recipe.name})
    end

    return {loader = entity, item = item, recipe = recipe, technology = tech}
    ]]
end