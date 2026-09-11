local mode = settings.startup["modular-splitter-modes"]
local cost_mult = settings.startup["modular-splitter-cost-multiplier"]

local function build_entity(inupt)
    
end

local function build_item(input)
    
end

local function build_recipe(input)
    local cost_mult = settings.startup["modular-splitter-cost-multiplier"].value
    local lubed = settings.startup["modular-splitter-lubricated"].value
    local recipe_normal = {
        
    }
    local recipe_lubed = {

    }
end

local function build_tech(tier)
    local tech = {
        name = tier.technology and tier.technology.name or tier.name,
        type = "technology",
        icons = {
            {
                icon = "graphics/technology/modular-splitter.png",
                icon_size = 256
            }
        },
        
    }
end

function ModularSplitters.build_tier(tier)
    if not tier.color then
        debug_log("No color provided, using default")
        tier.color = {r = 1.0, g = 1.0, b = 1.0}
    end
    for k, v in pairs(tier) do --check for empty values; is this necessary?
        if not v then
            debug_log("Attempted to build tier with empty value for "..k)
            return
        end
    end
    if tier.name == "" then --prefix belt tier
        tier.name = "modular-splitter"
    else
        tier.name = tier.name .. "-modular-splitter"
    end
    tier.transport_belt = data.raw["transport-belt"][tier.transport_belt]
    
    local entity = build_entity(tier)
    local item = build_item(tier)
    local recipe = build_recipe(tier)
    local tech = build_tech(tier)

    if tech and recipe then
        tech.effects = tech.effects or {}
        table.insert(tech.effects, {type = "unlock-recipe", recipe = recipe.name})
    end

    return {loader = entity, item = item, recipe = recipe, technology = tech}
end