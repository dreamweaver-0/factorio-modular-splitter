--[[
A modular-splitter entity is made of a linked_container buffer (modular-splitter-buffer) and two opposite-direction loader1x1s (modular-splitter-loaders), a combined set of modular splitters is called a modular-splitter-line
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
    [DIR.west] = "west",
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
    local position = valid and (entity.position.x .. "," .. entity.position.y) or "n/a"
    game.print("[Modular Splitter] " .. event_name
        .. " entity=" .. entity_name
        .. " unit=" .. unit_number
        .. " buffer_id=" .. buffer_id
        .. " direction=" .. direction
        .. " position=" .. position
        .. (details and (" " .. details) or ""))
end

--[[-----------------------------------------------------------------------
    BUFFER ID HANDLING
-------------------------------------------------------------------------]]

-- Creates and initializes the buffer ID storage tables
local function init_id_storage()
    storage.segments = storage.segments or {}
    storage.lines = storage.lines or {}
    storage.free_ids = storage.free_ids or {}
    storage.next_id = storage.next_id or CONST.link_id_base
    storage.inspector_targets = storage.inspector_targets or {}
end
script.on_init(function()
    init_id_storage()
    debug_event("on_init", nil, "storage=initialized")
end)
script.on_configuration_changed(function()
    init_id_storage()
    debug_event("on_configuration_changed", nil, "storage=initialized")
end)

-- Checks the list of free buffer IDs to reuse one. If none are available, give the new buffer the next ID based on storage.next_id
local function alloc_buffer_id()
    local id = table.remove(storage.free_ids)
    if not id then
        id = storage.next_id
        storage.next_id = storage.next_id + 1
    end
    storage.lines[id] = true
    return id
end

-- Removes the given ID from tracked buffer IDs, add it to the list of free IDs
local function free_buffer_id(id)
    if id and storage.lines[id] then
        storage.lines[id] = nil
        storage.free_ids[#storage.free_ids + 1] = id
    end
end

--[[-----------------------------------------------------------------------
    GEOMETRY / LOOKUP HELPERS
-------------------------------------------------------------------------]]

-- Determine the perpendicular vector for a given direction
local function perp_vector(direction)
    if direction == DIR.north or direction == DIR.south then
        return { x = 1, y = 0 }
    else
        return { x = 0, y = 1 }
    end
end

-- Checks if an entity is a modular splitter
local function is_modular_splitter(entity)
    return entity
        and entity.valid
        and entity.type == "simple-entity-with-owner"
        and entity.name:find("modular%-splitter$") ~= nil
end

-- Returns a square area around the given position with radius r.
local function small_area(position, r)
    r = r or 0.05
    return { { position.x - r, position.y - r }, { position.x + r, position.y + r } }
end

-- Appends "-loader" to the entity name if it doesn't already have it
local function loader_name(entity)
    if entity.name:find("loader$") == nil then
        return entity.name .. "-loader"
    end
end

-- Determines the end positions where loaders should be placed and oriented
local function end_positions(entity)
    local v = DIR_VECTOR[entity.direction]
    local p = entity.position
    return { x = p.x - v.x, y = p.y - v.y }, { x = p.x + v.x, y = p.y + v.y }
end

-- Finds a modular splitter at the given position
local function splitter_at(surface, position)
    for _, e in pairs(surface.find_entities_filtered({ type = "simple-entity-with-owner", area = small_area(position, 0.1) })) do
        if is_modular_splitter(e)
            and math.abs(e.position.x - position.x) < 0.1 and math.abs(e.position.y - position.y) < 0.1 then
            return e
        end
    end
end

local function adjacent_splitters(entity)
    local perp = perp_vector(entity.direction)
    local neighbors = {}
    for _, sign in ipairs({ -1, 1 }) do
        local position = {
            x = entity.position.x + perp.x * sign,
            y = entity.position.y + perp.y * sign,
        }
        local neighbor = splitter_at(entity.surface, position)
        if neighbor and neighbor ~= entity and neighbor.force == entity.force
            and neighbor.direction % 8 == entity.direction % 8 then
            neighbors[#neighbors + 1] = neighbor
        end
    end
    return neighbors
end

-- Returns the buffer associated with the given entity
local function buffer_of(entity)
    local rec = storage.segments[entity.unit_number]
    local buffer = rec and rec.buffer
    if buffer and buffer.valid then
        return buffer
    end
end

-- Returns the list of entities that are part of the same line as the given entity
local function line_members(entity)
    local buffer = buffer_of(entity)
    if not buffer or buffer.link_id == 0 then
        return { entity }
    end
    local id = buffer.link_id
    local members = { entity }
    for _, sign in ipairs({ -1, 1 }) do
        local p = entity.position
        while true do
            local perp = perp_vector(entity.direction)
            p = { x = p.x + perp.x * sign, y = p.y + perp.y * sign }
            local n = splitter_at(entity.surface, p)
            local nb = n and buffer_of(n)
            if not (n and n.force == entity.force and n.direction % 8 == entity.direction % 8
                and nb and nb.link_id == id) then
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

-- Returns a slice of the given list from index `from` to `to`
local function slice(list, from, to)
    local out = {}
    for i = from, to do
        out[#out + 1] = list[i]
    end
    return out
end

--[[-----------------------------------------------------------------------
    INVENTORY HELPERS
-------------------------------------------------------------------------]]

-- Returns the inventory associated with the given buffer
local function inv_of(buffer)
    return buffer.get_inventory(CHEST)
end

-- Drains the inventory of the given buffer and returns its contents
local function drain_inv(buffer)
    local inv = inv_of(buffer)
    local items = inv.get_contents()
    inv.clear()
    return items
end

-- Insert items; whatever doesn't fit is appended to `overflow`
local function fill_inv(buffer, items, overflow)
    local inv = inv_of(buffer)
    if not items then
        return
    end
    for _, item in pairs(items) do
        local inserted = inv.insert(item)
        if inserted < item.count then
            overflow[#overflow + 1] = { name = item.name, quality = item.quality, count = item.count - inserted }
        end
    end
end

-- Give overflow to the buffer if it still exists (not the last splitter in the line) otherwise spill to ground
local function spill_inv(overflow, entity, mined_buffer)
    for _, item in pairs(overflow) do
        local remaining = item.count
        if mined_buffer then remaining = remaining - mined_buffer.insert(item) end
        if remaining > 0 then
            entity.surface.spill_item_stack({
                position = entity.position,
                stack = { name = item.name, quality = item.quality, count = remaining },
                enable_looted = true,
                force = entity.force,
            })
        end
    end
end

-- Usable slots = 4 per splitter segment. Over the limit, bar = 1 closes every slot:
-- Items can still be taken out but nothing can be inserted
local function apply_capacity(entity)
    local members = line_members(entity)
    local n = #members
    local over = n > CONST.max_segments
    local bar = over and 1 or (n * CONST.slots_per_segment + 1)
    for _, m in ipairs(members) do
        local b = buffer_of(m)
        if b then
            inv_of(b).set_bar(bar)
        end
    end
    if over then
        entity.force.print("Modular Splitter line has \"" .. n .. "\" segments, which exceeds the limit of \"" .. CONST.max_segments .. "\". Line disabled until it is shortened.")
    end
    return n
end

--[[-----------------------------------------------------------------------
    HIDDEN COMPONENTS
-------------------------------------------------------------------------]]

-- Creates a new buffer entity associated with the given splitter
local function create_buffer(entity)
    return entity.surface.create_entity({
        name = CONST.buffer_name,
        position = entity.position,
        force = entity.force,
        create_build_effect_smoke = false
    })
end

-- Creates a single loader for the splitter segment
local function create_loader(entity, position, loader_type)
    return entity.surface.create_entity({
        name = loader_name(entity),
        position = position,
        direction = entity.direction,
        type = loader_type,
        force = entity.force,
        create_build_effect_smoke = false
    })
end

local function create_loader_pair(entity, rec)
    local back, front = end_positions(entity)
    rec[DIR_NAME[DIR_OPPOSITE[entity.direction]]] = create_loader(entity, back, "input")
    rec[DIR_NAME[entity.direction]] = create_loader(entity, front, "output")
end

local function update_loader_orientation(entity, rec)
    for _, side in ipairs(LOADER_SIDES) do
        local loader = rec[side]
        if loader and loader.valid then
            loader.loader_type = side == DIR_NAME[entity.direction] and "output" or "input"
        end
    end
end

local function synchronize_line_orientation(entity, direction)
    local members = { entity }
    local seen = { [entity.unit_number] = true }
    local index = 1
    while index <= #members do
        for _, neighbor in ipairs(adjacent_splitters(members[index])) do
            if not seen[neighbor.unit_number] then
                seen[neighbor.unit_number] = true
                members[#members + 1] = neighbor
            end
        end
        index = index + 1
    end

    for _, member in ipairs(members) do
        member.direction = direction
        local rec = storage.segments[member.unit_number]
        if rec then
            update_loader_orientation(member, rec)
        end
    end
end

local function take_loader_items(rec)
    local out = {}
    for _, side in ipairs(LOADER_SIDES) do
        local loader = rec[side]
        if loader and loader.valid then
            for i = 1, loader.get_max_transport_line_index() do
                local line = loader.get_transport_line(i)
                for _, it in pairs(line.get_contents()) do
                    out[#out + 1] = { name = it.name, quality = it.quality, count = it.count }
                end
                line.clear()
            end
        end
    end
    return out
end

local INSPECTOR_FRAME = "modular_splitter_inspector"

local function item_caption(item)
    local quality = item.quality and item.quality ~= "normal" and (" (" .. item.quality .. ")") or ""
    return item.count .. " x " .. item.name .. quality
end

local function add_item_rows(parent, items)
    local found = false
    for _, item in pairs(items or {}) do
        parent.add({ type = "label", caption = item_caption(item) })
        found = true
    end
    if not found then
        parent.add({ type = "label", caption = "Empty" })
    end
end

local function get_loader_contents(loader)
    local items = {}
    for line_index = 1, loader.get_max_transport_line_index() do
        for _, item in pairs(loader.get_transport_line(line_index).get_contents()) do
            items[#items + 1] = item
        end
    end
    return items
end

local function show_debug_inspector(player)
    local entity = storage.inspector_targets[player.index]
    if not entity or not entity.valid then
        storage.inspector_targets[player.index] = nil
        player.print("Modular Splitter inspector target is no longer valid.")
        return
    end

    local existing = player.gui.screen[INSPECTOR_FRAME]
    if existing then
        existing.destroy()
    end

    local frame = player.gui.screen.add({
        type = "frame",
        name = INSPECTOR_FRAME,
        direction = "vertical",
    })
    frame.auto_center = true

    local titlebar = frame.add({ type = "flow", direction = "horizontal" })
    titlebar.add({ type = "label", caption = "Modular Splitter Inspector", style = "frame_title" })
    local drag_space = titlebar.add({ type = "empty-widget", style = "draggable_space" })
    drag_space.style.horizontally_stretchable = true
    drag_space.drag_target = frame
    titlebar.add({
        type = "sprite-button",
        name = "modular_splitter_inspector_close",
        style = "frame_action_button",
        sprite = "utility/close",
    })

    local actions = frame.add({ type = "flow", direction = "horizontal" })
    actions.add({ type = "button", name = "modular_splitter_inspector_refresh", caption = "Refresh" })

    frame.add({
        type = "label",
        caption = entity.name .. "  |  direction=" .. (DIR_NAME[entity.direction] or tostring(entity.direction))
            .. "  |  position=" .. entity.position.x .. ", " .. entity.position.y,
    })

    local content = frame.add({ type = "scroll-pane", direction = "vertical" })
    content.style.width = 420
    content.style.maximal_height = 480

    local rec = storage.segments[entity.unit_number]
    local buffer = buffer_of(entity)
    content.add({ type = "label", caption = "Shared buffer inventory", style = "heading_2_label" })
    if buffer then
        content.add({ type = "label", caption = "Buffer ID: " .. buffer.link_id })
        add_item_rows(content, inv_of(buffer).get_contents())
    else
        content.add({ type = "label", caption = "Buffer unavailable" })
    end

    content.add({ type = "label", caption = "Loader contents", style = "heading_2_label" })
    for _, side in ipairs(LOADER_SIDES) do
        local loader = rec and rec[side]
        if loader and loader.valid then
            local direction = DIR_NAME[loader.direction] or tostring(loader.direction)
            content.add({
                type = "label",
                caption = side .. " loader (" .. loader.loader_type .. ", facing " .. direction .. ")",
            })
            add_item_rows(content, get_loader_contents(loader))
        else
            content.add({ type = "label", caption = side .. " loader: unavailable" })
        end
    end

    player.opened = frame
end

---@class ModularSplitterInspectEvent
---@field player_index uint

---@param event ModularSplitterInspectEvent
local function on_inspector_input(event)
    if not CONST.debug_inspector then
        return
    end

    local player = game.get_player(event.player_index)
    local entity = player and player.selected
    if not is_modular_splitter(entity) then
        if player then
            player.print("Point at a modular splitter before opening the inspector.")
        end
        return
    end

    storage.inspector_targets[event.player_index] = entity
    show_debug_inspector(player)
end
script.on_event("modular-splitter-inspect", on_inspector_input)

script.on_event(defines.events.on_gui_click, function(event)
    if not CONST.debug_inspector then
        return
    end

    local player = game.get_player(event.player_index)
    if not player or not event.element.valid then
        return
    end

    if event.element.name == "modular_splitter_inspector_refresh" then
        show_debug_inspector(player)
    elseif event.element.name == "modular_splitter_inspector_close" then
        storage.inspector_targets[player.index] = nil
        player.opened = nil
        local frame = player.gui.screen[INSPECTOR_FRAME]
        if frame then
            frame.destroy()
        end
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    if event.element and event.element.valid and event.element.name == INSPECTOR_FRAME then
        storage.inspector_targets[event.player_index] = nil
        event.element.destroy()
    end
end)

local function destroy_loaders(rec)
    for _, side in ipairs(LOADER_SIDES) do
        local loader = rec[side]
        if loader and loader.valid then
            loader.destroy()
        end
        rec[side] = nil
    end
end

local function purge_strays(entity)
    local back, front = end_positions(entity)
    for _, pos in ipairs({ entity.position, back, front }) do
        for _, e in pairs(entity.surface.find_entities_filtered({
            name = { CONST.buffer_name, loader_name(entity) },
            area = small_area(pos, 0.2)
        })) do
        e.destroy()
        end
    end
end

--[[-----------------------------------------------------------------------
    REMOVING SEGMENT
-------------------------------------------------------------------------]]

local function remove_splitter_segment(entity, extra)
    local overflow = {}
    for _, item in pairs(extra or {}) do
        overflow[#overflow + 1] = item
    end

    local buffer = buffer_of(entity)
    local members = line_members(entity)
    local removed_index
    for index, member in ipairs(members) do
        if member == entity then
            removed_index = index
            break
        end
    end

    local left = removed_index and slice(members, 1, removed_index - 1) or {}
    local right = removed_index and slice(members, removed_index + 1, #members) or {}
    local contents = buffer and drain_inv(buffer) or {}
    local original_id = buffer and buffer.link_id

    if #left == 0 and #right == 0 then
        for _, item in pairs(contents) do
            overflow[#overflow + 1] = item
        end
        free_buffer_id(original_id)
    elseif #left > 0 and #right > 0 then
        local new_id = alloc_buffer_id()
        for _, member in ipairs(right) do
            local member_buffer = buffer_of(member)
            if member_buffer then
                member_buffer.link_id = new_id
            end
        end
    end

    if buffer and buffer.valid then
        buffer.link_id = 0
        buffer.destroy()
    end
    storage.segments[entity.unit_number] = nil

    local survivor_count = #left + #right
    if survivor_count > 0 then
        local left_items, right_items = {}, {}
        for _, item in pairs(contents) do
            local left_count = #right == 0 and item.count
                or math.floor(item.count * #left / survivor_count)
            local right_count = item.count - left_count
            if left_count > 0 then
                left_items[#left_items + 1] = { name = item.name, quality = item.quality, count = left_count }
            end
            if right_count > 0 then
                right_items[#right_items + 1] = { name = item.name, quality = item.quality, count = right_count }
            end
        end

        if #left > 0 then
            apply_capacity(left[1])
            fill_inv(buffer_of(left[1]), left_items, overflow)
        end
        if #right > 0 then
            apply_capacity(right[1])
            fill_inv(buffer_of(right[1]), right_items, overflow)
        end
    end

    return overflow
end

--[[-----------------------------------------------------------------------
    JOINING SEGMENTS
-------------------------------------------------------------------------]]

local function destroy_parts(entity)
  local rec = storage.segments[entity.unit_number]
  if not rec then return end
  destroy_loaders(rec)
  if rec.buffer and rec.buffer.valid then rec.buffer.destroy() end
  storage.segments[entity.unit_number] = nil
end

-- Reject a placement: remove the entity and hand the item back.
local function reject(entity, player_index, reason)
  local name, force, surface, position = entity.name, entity.force, entity.surface, entity.position
  destroy_parts(entity)
  entity.destroy()
  local player = player_index and game.get_player(player_index)
  if player then
    player.print(reason)
    player.insert({ name = name, count = 1 })
  else
    force.print(reason)
    surface.spill_item_stack({ position = position, stack = { name = name, count = 1 }, force = force })
  end
  return false
end

-- Give the entity's fresh buffer a link id, merging it with neighboring lines.
local function attach(entity, player_index)
    local buffer = buffer_of(entity)
    local perp = perp_vector(entity.direction)

    local found = {}
    for _, sign in ipairs({ -1, 1 }) do
        local n = splitter_at(entity.surface, { x = entity.position.x + perp.x * sign, y = entity.position.y + perp.y * sign })
        if n and n ~= entity and n.force == entity.force and buffer_of(n) then found[#found + 1] = n end
    end
    if #found > 2 then
        return reject(entity, player_index, "Modular splitter: more than two neighboring buffers found.")
    end
    if #found == 2 and found[1].direction ~= found[2].direction then
        return reject(entity, player_index, "Modular splitters placed side by side must face the same direction.")
    end

    local mergeable = {}
    for _, n in ipairs(found) do
        if n.direction == entity.direction then mergeable[#mergeable + 1] = n end
    end

    local overflow = {}
    if #mergeable == 0 then
        buffer.link_id = alloc_buffer_id()
    elseif #mergeable == 1 then
        buffer.link_id = buffer_of(mergeable[1]).link_id
    else
        local ida, idb = buffer_of(mergeable[1]).link_id, buffer_of(mergeable[2]).link_id
    if ida == idb then
        buffer.link_id = ida
    else
        local small, large, large_entity = ida, idb, mergeable[2]
        if idb < ida then small, large, large_entity = idb, ida, mergeable[1] end
        local items = drain_inv(buffer_of(large_entity))
        for _, m in ipairs(line_members(large_entity)) do buffer_of(m).link_id = small end
        free_buffer_id(large)
        buffer.link_id = small
        apply_capacity(entity)
        fill_inv(buffer, items, overflow)
        end
    end

    apply_capacity(entity)
    spill_inv(overflow, entity, nil)
    return true
end

--[[-----------------------------------------------------------------------
    ENTITY CREATION / DESTRUCTION
-------------------------------------------------------------------------]]

local function ensure_parts(entity, player_index)
    purge_strays(entity)
    local rec = {}
    storage.segments[entity.unit_number] = rec
    rec.buffer = create_buffer(entity)
    if not rec.buffer then
        return reject(entity, player_index, "Modular Splitter: Failed to create buffer.")
    end
    create_loader_pair(entity, rec)
    if not (rec[DIR_NAME[DIR_OPPOSITE[entity.direction]]] and rec[DIR_NAME[entity.direction]]) then
        return reject(entity, player_index, "Modular Splitter: Failed to create loaders.")
    end
    return attach(entity, player_index)
end

local function remove_parts(entity, mined_buffer)
    local rec = storage.segments[entity.unit_number]
    if not rec then
        return
    end
    local items = take_loader_items(rec)
    destroy_loaders(rec)
    spill_inv(remove_splitter_segment(entity, items), entity, mined_buffer)
    storage.segments[entity.unit_number] = nil
end

--[[-----------------------------------------------------------------------
    EVENTS
-------------------------------------------------------------------------]]

local filter = { { filter = "type", type = "simple-entity-with-owner" } }

local function on_built(event)
    init_id_storage()
    local entity = event.entity or event.destination
    if is_modular_splitter(entity) then
        local neighbors = adjacent_splitters(entity)
        if #neighbors > 0 then
            synchronize_line_orientation(entity, neighbors[1].direction)
        end
        local success = ensure_parts(entity, event.player_index)
        debug_event("built", entity, "neighbors=" .. #neighbors .. " success=" .. tostring(success))
    end
end

script.on_event(defines.events.on_built_entity, on_built, filter)
script.on_event(defines.events.on_robot_built_entity, on_built, filter)
script.on_event(defines.events.on_space_platform_built_entity, on_built, filter)
script.on_event(defines.events.script_raised_built, on_built, filter)
script.on_event(defines.events.script_raised_revive, on_built, filter)
script.on_event(defines.events.on_entity_cloned, on_built)

local function on_mined(event)
    init_id_storage()
    if is_modular_splitter(event.entity) then
        debug_event("mined", event.entity, "has_mined_buffer=" .. tostring(event.buffer ~= nil))
        remove_parts(event.entity, event.buffer)
    end
end

script.on_event(defines.events.on_player_mined_entity, on_mined, filter)
script.on_event(defines.events.on_robot_mined_entity, on_mined, filter)
script.on_event(defines.events.on_space_platform_mined_entity, on_mined, filter)

local function on_destroyed(event)
    init_id_storage()
    if is_modular_splitter(event.entity) then
        debug_event("destroyed", event.entity, "cause=entity_destroyed")
        remove_parts(event.entity, nil)
    end
end

script.on_event(defines.events.on_entity_died, on_destroyed, filter)
script.on_event(defines.events.script_raised_destroy, on_destroyed, filter)

-- Placement is 4-way, but once placed only a 180 degree turn is allowed.
script.on_event(defines.events.on_player_rotated_entity, function(event)
    init_id_storage()
    local entity = event.entity
    if not is_modular_splitter(entity) then
        return
    end
    local rec = storage.segments[entity.unit_number]
    if not rec then
        debug_event("rotated", entity, "skipped=no_segment_record")
        return
    end
    local old_direction = DIR_NAME[event.previous_direction] or tostring(event.previous_direction)
    local turned = (entity.direction - event.previous_direction) % 16
    if turned ~= DIR.south then -- south == 8 == 180 degrees
        entity.direction = (event.previous_direction + DIR.south) % 16
    end

    synchronize_line_orientation(entity, entity.direction)
    local segment_count = apply_capacity(entity)
    debug_event("rotated", entity, "previous_direction=" .. old_direction .. " segments=" .. segment_count)
end)