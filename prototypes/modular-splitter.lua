local mode = settings.startup["modular-splitter-modes"]
local cost_mult = settings.startup["modular-splitter-cost-multiplier"]
local BASE_NAME = "modular-splitter"
local CONST = require("modular-splitter-constants")

ModularSplitters = ModularSplitters or {} --declaring global func?

local EMPTY_SPRITE = {
    filename = "__core__/graphics/empty.png",
    priority = "extra-high",
    width = 1,
    height = 1
}

local HIDDEN_FLAGS = {
    "placeable-neutral",
    "not-on-map",
    "not-blueprintable",
    "not-deconstructable",
    "not-repairable",
    "not-flammable",
    "not-upgradable"
}

function ModularSplitters.entity_name(prefix)
    if prefix == "" then
        return BASE_NAME
    else
        return prefix .. "-" .. BASE_NAME
    end
end

function ModularSplitters.loader_name(prefix)
    return ModularSplitters.entity_name(prefix) .. "-loader"
end

local function icons_for(tier)
    local base = data.raw["item"]["splitter"]
    return { { icon = base.icon, icon_size = base.icon_size or 64, tint = tier.tint } }
end

local function build_picture(tier) -- TEST GRAPHIC
    local chest = data.raw["container"]["steel-chest"]
    local base_layers = chest.picture.layers or {chest.picture}

    local function make(offsets)
        local layers = {}
        for _, off in ipairs(offsets) do
            for _, layer in ipairs(base_layers) do
                local l = table.deepcopy(layer)
                local sx = l.shift and (l.shift[1] or l.shift.x) or 0
                local sy = l.shift and (l.shift[2] or l.shift.y) or 0
                l.shift = { sx + off[1], sy + off[2] }
                if not l.draw_as_shadow then l.tint = tier.tint end
                layers[#layers + 1] = l
            end
        end
        return { layers = layers }
    end

    local vertical = { { 0, -1 }, { 0, 0 }, { 0, 1 } }
    local horizontal = { { -1, 0 }, { 0, 0 }, { 1, 0 } }
    return {
        north = make(vertical), south = make(vertical),
        east = make(horizontal), west = make(horizontal),
    }
end

local function has_fluid(ingredients)
    for _, ing in pairs(ingredients) do
        if ing.type == "fluid" then
            return true
        end
    end
    return false
end

local function build_item(tier)
    local name = ModularSplitters.entity_name(tier.name)
    data:extend({
        {
            type = "item",
            name = name,
            icons = icons_for(tier),
            subgroup = "belt",
            order = tier.order or ("d[modular-splitter]-" .. name),
            place_result = name,
            stack_size = 50,
        },
    })
    --[[ data:extend {
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

    return data.raw.item[tier.name] ]]
end

local function build_entity(tier)
    local name = ModularSplitters.entity_name(tier.name)
    local loader_name = ModularSplitters.loader_name(tier.name)
    local belt = data.raw["transport-belt"][tier.belt]
    assert(belt, "modular-splitter: unknown belt tier '" .. tostring(tier.belt) .. "'")

    local main = {
        type = "simple-entity-with-owner",
        name = name,
        icons = icons_for(tier),
        flags = {"placeable-neutral", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = name
        },
        max_health = 170,
        collision_box = { { -0.35, -1.35 }, { 0.35, 1.35 } },
        selection_box = { { -0.5, -1.5 }, { 0.5, 1.5 } },
        picture = build_picture(tier),
        fast_replaceable_group = "modular-splitter"
    }

    local loader = {
        type = "loader-1x1",
        name = loader_name,
        icons = icons_for(tier),
        flags = HIDDEN_FLAGS,
        hidden = true,
        selectable_in_game = false,
        max_health = 170,
        collision_box = { { -0.4, -0.45 }, { 0.4, 0.45 } },
        selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
        --collision_mask = { layers = {} },
        filter_count = 0,
        speed = belt.speed,
        container_distance = 0.75,
        belt_animation_set = belt.belt_animation_set,
        animation_speed_coefficient = belt.animation_speed_coefficient,
        structure = {
            direction_in = { north = EMPTY_SPRITE, east = EMPTY_SPRITE, south = EMPTY_SPRITE, west = EMPTY_SPRITE },
            direction_out = { north = EMPTY_SPRITE, east = EMPTY_SPRITE, south = EMPTY_SPRITE, west = EMPTY_SPRITE }
        }
    }

    data:extend({ main, loader })

    -- Chain upgrades with previous tier
    if tier.previous ~= nil then
        local prev = data.raw["simple-entity-with-owner"][ModularSplitters.entity_name(tier.previous)]
        if prev then
            prev.next_upgrade = name
        end
    end

    -- Hidden per-segment buffer (created once). Every segment owns one of these 1x1
    -- containers at its center tile; merged segments share an inventory via link_id.
    if not data.raw["linked-container"][CONST.buffer_name] then
    local chest = data.raw["item"]["steel-chest"]
    data:extend({
        {
            type = "linked-container",
            name = CONST.buffer_name,
            icon = chest.icon,
            icon_size = chest.icon_size or 64,
            flags = HIDDEN_FLAGS,
            hidden = true,
            selectable_in_game = false,
            max_health = 170,
            inventory_size = CONST.max_segments * CONST.slots_per_segment,
            inventory_type = "with_bar", -- runtime set_bar() scales capacity with group size
            quality_affects_inventory_size = false,
            gui_mode = "none",
            collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
            collision_mask = { layers = {} }
        },
    })
    end
    --[[{
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
    local name = ModularSplitters.entity_name(tier.name)
    data:extend({
        {
            type = "recipe",
            name = name,
            enabled = false,
            energy_required = tier.craft_time or 2,
            category = has_fluid(tier.ingredients) and "crafting-with-fluid" or "crafting",
            ingredients = tier.ingredients,
            results = { { type = "item", name = name, amount = 1 } }
        }
    })
    --[[ local cost_mult = settings.startup["modular-splitter-cost-multiplier"].value
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
    return data.raw.recipe[recipe.name] ]]
end

local function build_tech(tier)
    local t = tier.technology
    if not t then
        return
    end
    local name = ModularSplitters.entity_name(tier.name)
    local effect = { type = "unlock-recipe", recipe = name }

    if t.unlock_with then
        local tech = data.raw["technology"][t.unlock_with]
        assert(tech, "modular-splitter: unknown technology '" .. t.unlock_with .. "'")
        tech.effects = tech.effects or {}
        table.insert(tech.effects, effect)
        return
    end
    --[[ local name = tier.technology and tier.technology.name or tier.name

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
    return data.raw.technology[name] ]]
end

function ModularSplitters.build_tier(tier)
    assert(tier.name ~= nil, "modular-splitter: tier.name required (use \"\" for the base tier)")
    assert(tier.belt, "modular-splitter: tier.belt required")
    assert(tier.tint, "modular-splitter: tier.tint required")
    assert(tier.ingredients, "modular-splitter: tier.ingredients required")

    build_item(tier)
    build_entity(tier)
    build_recipe(tier)
    build_tech(tier)

    --[[
    prototype.transport_belt = data.raw["transport-belt"][prototype.transport_belt]
    
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