--[[
A modular-splitter entity is made of a linked_container buffer (modular-splitter-buffer) and two opposite-direction loader1x1s (modular-splitter-loaders), a combined set splitters in with the same ID and orientation are known as a group
    modular-splitter placed
        create the modular-splitter-buffer at center
            check adjacent tiles for other modular-splitter-buffers
                zero found
                    create new buffer id and assign to the new buffer
                one found
                    set new buffer id to existing buffer id
                two found
                    check if the two existing buffers are in the same orientation
                        if not, throw error
                    set new buffer id to the smaller of the two existing buffer ids
                    transfer all items in old buffer to new one and close it
                    set the larger buffer id to the buffer id of the new buffer, remove the unused id from tracked buffer list
                more than two found
                    throw error
    modular-splitter destroyed
        check if the buffer is part of a line (has other segments)
            if yes
                remove the buffer from the line, shrink buffer inventory by 4
            if no (last segment)
                drop all items in the buffer to player inventory or ground
                remove buffer id from tracker buffer list
]]
-- Every segment owns a hidden 1x1 linked-container at its center tile (right where
-- its loaders point). Side-by-side splitters with the same direction and force
-- share a link_id, hence one inventory. A group is found by walking adjacent
-- same-direction segments whose buffers carry the same link_id.
--
-- Removing a segment can split its group; rotating one turns the connected line
-- in place. After placement only 180 degree rotation is allowed.

local CONST = require("prototypes/modular-splitter-constants")
local DIR = defines.direction
local CHEST = defines.inventory.chest
local DIR_NAME = {
    [DIR.north] = "north",
    [DIR.east] = "east",
    [DIR.south] = "south",
    [DIR.west] = "west"
}
local DIR_OPPOSITE = {
    [DIR.north] = DIR.south,
    [DIR.east] = DIR.west,
    [DIR.south] = DIR.north,
    [DIR.west] = DIR.east,
}
local LOADER_SIDES = { "north", "east", "south", "west" }
local DIR_VECTOR = {
    [DIR.north] = { x = 0, y = -1 },
    [DIR.east] = { x = 1, y = 0 },
    [DIR.south] = { x = 0, y = 1 },
    [DIR.west] = { x = -1, y = 0 },
}

require("scripts/buffer-id-handler")

-- Prints debug messages to chat, toggled by modular-splitter-constants
local function debug_event(event_name, entity, details)
    if not CONST.debug_events then
        return
    end

    local valid = entity and entity.valid
    local rec = valid and storage.segments and storage.segments[entity.unit_number]
    local buffer = rec and rec.buffer
    if buffer and not buffer.valid then
        buffer = nil
    end

    local direction = valid and (DIR_NAME[entity.direction] or tostring(entity.direction)) or "n/a"
    local entity_name = valid and entity.name or "n/a"
    local unit_number = valid and tostring(entity.unit_number) or "n/a"
    local buffer_id = buffer and tostring(buffer.link_id) or "n/a"
    local position = valid and (entity.position.x..","..entity.position.y) or "n/a"
    game.print("[Modular Splitter] Debug Message"
                .."\n"..event_name
                .."\nentity:    "..entity_name
                .."\nunit:      "..unit_number
                .."\nbuffer_id: "..buffer_id
                .."\ndirection: "..direction
                .."\nposition:  "..position
                ..(details and ("\nDetails:   "..details) or "")
                )
end

--[[-----------------------------------------------------------------------
    GEOMETRY / LOOKUP HELPERS
-------------------------------------------------------------------------]]

-- Returns a square area around the given position with radius r.
local function small_area(position, r)
    r = r or 0.05
    return { { position.x - r, position.y - r }, { position.x + r, position.y + r } }
end

-- Checks if the given entity is a modular splitter
local function is_modular_splitter(entity)
    return entity
        and entity.valid
        and entity.type == "simple-entity-with-owner"
        and entity.name:find("modular%-splitter$") ~= nil
end

-- Returns the modular splitter located at the given position
local function splitter_at(surface, position)
    for _, e in pairs(surface.find_entities_filtered({
                type = "simple-entity-with-ower",
                area = small_area(position, 0.1)
            })) do
        if is_modular_splitter(e)
                and math.abs(e.position.x - position.x) < 0.1
                and math.abs(e.position.y - position.y) < 0.1 then
            return e
        end
    end
end

-- Returns the buffer associated with a modular spitter segment
local function buffer_of(modsplitter)
    local rec = storage.segments[modsplitter.unit_number]
    local buffer = rec and rec.buffer
    if buffer and buffer.valid then
        return buffer
    end
end

-- Returns a vector perpendicular to the given direction
local function perp_vector(direction)
    if direction == DIR.north or direction == DIR.south then
        return { x = 1, y = 0 }
    else
        return { x = 0, y = 1 }
    end
end

---Gets the pair of modular splitters next to the given
---@param modsplitter LuaEntity
---@returns table
local function get_adjacent_splitters(modsplitter)
    local perp = perp_vector(modsplitter.direction)
    local neighbors = {}
    for _, sign in ipairs({ -1, 1, }) do
        local position = {
            x = modsplitter.position.x + perp.x * sign,
            y = modsplitter.position.y + perp.y * sign
        }
        local neighbor = splitter_at(modsplitter.surface, position)
        if neighbor and neighbor ~= modsplitter
                    and neighbor.force == modsplitter.force
                    and neighbor.direction % 8 == modsplitter.direction % 8 then
            neighbors[#neighbors + 1] = neighbor
        end
    end
    return neighbors
end

---Returns a collection of all adjacent modular splitters that share a linked-container id
---@param modsplitter LuaEntity
---@returns table
local function get_splitter_group(modsplitter)
    local buffer = buffer_of(modsplitter)
    if not buffer or buffer.link_id == 0 then
        return { modsplitter }
    end
    local id = buffer.link_id
    local members = { modsplitter }
    for _, sign in ipairs({ -1, 1 }) do
        local p = modsplitter.position
        while true do
            local perp = perp_vector(modsplitter.direction)
            p = {
                x = p.x + perp.x * sign,
                y = p.y + perp.y * sign
            }
            local n = splitter_at(modsplitter.surface, p)
            local nb = n and buffer_of(n)
            if not (n
                    and n.force == modsplitter.force
                    and n.direction % 8 == modsplitter.direction % 8
                    and nb
                    and nb.name == buffer.name
                    and nb.link_id == id) then
                break
            end
            if sign == -1 then
                table.insert(members, 1, n)
            else
                members[#members + 1] = n
            end
        end
    end
    return members
end

--[[-----------------------------------------------------------------------
    M.S. INVENTORY HELPERS
-------------------------------------------------------------------------]]

---Gets the inventory interface of the given container
---@param container LuaEntity
---@returns LuaInventory
local function inv_of(container)
    return container.get_inventory(CHEST)
end

---Removes the items from the given inventory and returns them
---@param container LuaEntity
---@returns ItemsWithQualityCount[]
local function drain_inv(container)
    local inv = inv_of(container)
    local items = inv.get_contents()
    inv.clear()
    return items
end

---Insert items, whatever doesn't fit is appended to the "overflow_items" table
---@param container LuaEntity
---@param items LuaItemStack[]
---@param overflow_items LuaItemStack[]
local function fill_inv(container, items, overflow_items)
    local inv = inv_of(container)
    if not items then
        return
    end
    for _, item in pairs(items) do
        local inserted = inv.insert(item)
        if inserted < item.count then
            overflow_items[#overflow_items + 1] = {
                name = item.name,
                quality = item.quality,
                count = item.count - inserted
            }
        end
    end
end

-- Give overflow_items to the buffer if it still exists (not the last splitter in the group) otherwise spill to ground
local function spill_inv(overflow_items, entity, remaining_buffer)
    for _, item in pairs(overflow_items) do
        local remaining = item.count
        if remaining_buffer then
            remaining = remaining - remaining_buffer.insert(item)
        end
        if 0 < remaining then
            entity.surface.spill_item_stack({
                position = entity.position,
                stack = {
                    name = item.name,
                    quality = item.quality,
                    count = remaining
                },
                enabled_looted = true,
                force = entity.force
            })
        end
    end
end

-- Artificially limits the buffer size of one group of modular splitters based on the number of segments
local function apply_capacity(modsplitter)
    local segments = get_splitter_group(modsplitter)
    local n = #segments
    local over = CONST.max_segments < n
    local bar = over and 1 or (n * CONST.slots_per_segment + 1)
    for _, m in ipairs(segments) do
        local b = buffer_of(m)
        if b then
            inv_of(b).set_bar(bar)
        end
    end
    return n
end

local function loader_positions_of(modsplitter)

end

--[[-----------------------------------------------------------------------
    M.S. PART HELPERS
-------------------------------------------------------------------------]]

-- Forces the attached group of modular splitters to align with the interacted splitter
local function sync_group_orientation(entity, new_direction)
    local segments = get_splitter_group(entity)
    for _, seg in pairs(segments) do
        
    end
end

-- Appends "buffer" to the name of the given entity if it doesn't already have it
local function buffer_name(entity)
    if entity.name:find("buffer$") == nil then
        return entity.name.."-buffer"    
    end
end

-- Appends "loader" to the name of the given entity if it doesn't already have it
local function loader_name(entity)
    if entity.name:find("loader$") == nil then
        return entity.name.."-loader"
    end
end

--[[-----------------------------------------------------------------------
    M.S. PART BUILD / DESTROY HANDLING
-------------------------------------------------------------------------]]

local function remove_parts(modsplitter)

end

-- Reject an attempt at placing a modular splitter entity, remove the entity and hand the item back
local function reject_placement(modsplitter, player_index, reason)
    local name, force, surface, position = modsplitter.name, modsplitter.force, modsplitter.surface, modsplitter.position
    remove_parts(modsplitter)
    modsplitter.destroy()
    local player = player_index and game.get_player(player_index)
    if player then
        player.print(reason)
        player.insert({ name = name, count = 1 })
    else
        force.print(reason)
        surface.spill_item_stack({
            position = position,
            stack = {
                name = name,
                count = 1
            },
            force = force })
    end
    return false
end

-- Creates a new buffer entity associated with the given splitter
local function create_buffer(modsplitter)
    local buffer = modsplitter.surface.create_entity({
        name = buffer_name(modsplitter),
        position = modsplitter.position,
        force = modsplitter.force,
        create_build_effect_smoke = false
    })
    debug_event()
    if not buffer then
        return nil
    end
end

-- Creates a single loader for a splitter segment
local function create_loader(entity, position, loader_type)
    local loader = entity.surface.create_entity({
        name = loader_name(entity),
        position = position,
        direction = entity.direction,
        type = loader_type,
        force = entity.force,
        create_build_effect_smoke = false
    })
end

-- Creates a pair of loaders on each end of the modular splitter
local function create_loader_pair(entity, rec)
    local back, front = loader_positions_of(entity)
    rec[DIR_NAME[DIR_OPPOSITE[entity.direction]]] = create_loader(entity, back, "input")
    rec[DIR_NAME[entity.direction]] = create_loader(entity, front, "output")
end

local function build_parts(modsplitter, player_index)
    local rec = {}
    storage.segments[modsplitter.unit_number] = rec
    rec.buffer = create_buffer(modsplitter)
    if not rec.buffer or not inv_of(modsplitter) then
        return reject_placement(modsplitter, player_index, "[Modular Splitter]: Failed to create buffer inventory.")
    end
end

--[[-----------------------------------------------------------------------
    EVENTS
-------------------------------------------------------------------------]]

local filter = {
    {
        filter = "type",
        type = "simple-entity-with-owner"
    }
}

local function on_built(event)
    init_id_storage()
    local entity = event.entity or event.destination
    if is_modular_splitter(entity) then
        local neighbors = get_adjacent_splitters(entity)
        if 0 < #neighbors then
            sync_group_orientation(entity, event.player_index)
        end
    end
end

script.on_event(defines.events.on_built_entity, on_built, filter)
script.on_event(defines.events.on_robot_built_entity, on_built, filter)
--if mods["space-age"] then 
script.on_event(defines.events.on_space_platform_built_entity, on_built, filter)
--end
script.on_event(defines.events.script_raised_built, on_built, filter)
script.on_event(defines.events.script_raised_revive, on_built, filter)
script.on_event(defines.events.on_entity_cloned, on_built)

local function on_mined(event)
    init_id_storage()
    if is_modular_splitter(event.entity) then
        debug_event("mined", event.entity, "has_mined_buffer="..tostring(event.buffer ~= nil))
        remove_parts(event.entity)
    end
end

script.on_event(defines.events.on_player_mined_entity, on_mined, filter)
script.on_event(defines.events.on_robot_mined_entity, on_mined, filter)
script.on_event(defines.events.on_space_platform_mined_entity, on_mined, filter)

local function on_destroyed(event)
    init_id_storage()
    if is_modular_splitter(event.entity) then
        debug_event("destroyed", event.entity, "cause= entity_destroyed")
        remove_parts(event.entity)
    end
end

script.on_event(defines.events.on_entity_died, on_destroyed, filter)
script.on_event(defines.events.script_raised_destroy, on_destroyed, filter)

local function on_rotate(event)
    init_id_storage()
    local entity = event.entity
    if not is_modular_splitter(entity) then
        return
    end
    local rec = storage.segments[entity.unit_number]
    if not rec then
        debug_event("rotated", entity, "skipped= no_segment_record")
        return
    end
    local old_direction = DIR_NAME[event.previous_direction] or tostring(event.previous_direction)
    local turned = (entity.direction - event.previous_direction) % 16
    if turned ~= DIR.south then -- south == 8 == 180 degrees
        entity.direction = (event.previous_direction + DIR.south) % 16
    end

    sync_group_orientation(entity, entity.direction)
    local segment_count = apply_capacity(entity)
    debug_event("rotated", entity, "previous_direction= "..old_direction.."\nsegments"..segment_count)
end
script.on_event(defines.events.on_player_rotated_entity, on_rotate)