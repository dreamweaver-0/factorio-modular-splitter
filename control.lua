-- Modular splitter runtime (linked-container buffers).
--
-- Every segment owns a hidden 1x1 linked-container at its center tile (right where
-- its loaders point). Side-by-side splitters with the same direction and force
-- share a link_id, hence one inventory. A group is found by walking adjacent
-- same-direction segments whose buffers carry the same link_id.
--
-- Removing/rotating a segment splits its group in two: the left side keeps the
-- old link_id, the right side gets a new one, and the contents are divided in
-- proportion to segment counts. After placement only 180 degree rotation is allowed.

local CONST = require("prototypes/modular-splitter-constants")

local D = defines.direction
local CHEST = defines.inventory.chest

---------------------------------------------------------------------------
-- geometry helpers
---------------------------------------------------------------------------

local DIR_VECTOR = {
[D.north] = { x = 0, y = -1 },
[D.east] = { x = 1, y = 0 },
[D.south] = { x = 0, y = 1 },
[D.west] = { x = -1, y = 0 },
}

-- North/south-facing splitters sit in a row along x, east/west along y.
local function perp_vector(direction)
if direction == D.north or direction == D.south then return { x = 1, y = 0 } end
return { x = 0, y = 1 }
end

local function is_modular_splitter(entity)
return entity
    and entity.valid
    and entity.type == "simple-entity-with-owner"
    and entity.name:find("modular%-splitter$") ~= nil
end

local function small_area(position, r)
r = r or 0.05
return { { position.x - r, position.y - r }, { position.x + r, position.y + r } }
end

local function splitter_at(surface, position, direction)
for _, e in pairs(surface.find_entities_filtered({ type = "simple-entity-with-owner", area = small_area(position, 0.1) })) do
    if is_modular_splitter(e) and e.direction == direction
    and math.abs(e.position.x - position.x) < 0.1 and math.abs(e.position.y - position.y) < 0.1 then
    return e
    end
end
end

---------------------------------------------------------------------------
-- buffers
---------------------------------------------------------------------------

local function new_link_id()
storage.next_link_id = (storage.next_link_id or CONST.link_id_base) + 1
return storage.next_link_id
end

local function get_buffer(entity)
return entity.surface.find_entities_filtered({ name = CONST.buffer_name, area = small_area(entity.position) })[1]
end

local function inv_of(buffer)
return buffer.get_inventory(CHEST)
end

-- Usable slots scale with the number of segments sharing the inventory.
local function set_capacity(buffer, segment_count)
inv_of(buffer).set_bar(segment_count * CONST.slots_per_segment + 1)
end

local function create_buffer(entity)
local buffer = entity.surface.create_entity({
    name = CONST.buffer_name,
    position = entity.position,
    force = entity.force,
    create_build_effect_smoke = false,
})
buffer.link_id = new_link_id()
set_capacity(buffer, 1)
return buffer
end

local function drain(buffer)
local inv = inv_of(buffer)
local items = inv.get_contents()
inv.clear()
return items
end

-- Insert items; whatever doesn't fit is appended to `overflow`.
local function fill(buffer, items, overflow)
local inv = inv_of(buffer)
for _, item in pairs(items) do
    local inserted = inv.insert(item)
    if inserted < item.count then
    overflow[#overflow + 1] = { name = item.name, quality = item.quality, count = item.count - inserted }
    end
end
end

-- Hand overflow to a mined-buffer inventory if there is one, else spill it.
local function dispose(overflow, entity, mined_buffer)
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

---------------------------------------------------------------------------
-- groups
---------------------------------------------------------------------------

-- Segments sharing `entity`'s inventory, ordered along the row axis, plus its buffer.
-- `direction` is the direction neighbors must have (differs from entity.direction
-- only while handling a rotation).
local function group_of(entity, direction)
local buffer = get_buffer(entity)
if not buffer then return { entity }, nil end

local id = buffer.link_id
local perp = perp_vector(direction)
local segs = { entity }
for _, sign in ipairs({ -1, 1 }) do
    local p = entity.position
    while true do
    p = { x = p.x + perp.x * sign, y = p.y + perp.y * sign }
    local n = splitter_at(entity.surface, p, direction)
    local nb = n and get_buffer(n)
    if not (nb and nb.link_id == id and n.force == entity.force) then break end
    if sign == -1 then table.insert(segs, 1, n) else segs[#segs + 1] = n end
    end
end
return segs, buffer
end

local function slice(list, from, to)
local out = {}
for i = from, to do out[#out + 1] = list[i] end
return out
end

-- Detach `entity` from its group, splitting contents proportionally between the
-- segments on either side. The entity's own buffer is destroyed (it is left with
-- none). Returns the overflow that no longer fits.
local function leave_group(entity, direction)
local overflow = {}
local segs, buffer = group_of(entity, direction)
if not buffer then return overflow end

local k
for i, s in ipairs(segs) do
    if s == entity then k = i break end
end
local left, right = slice(segs, 1, k - 1), slice(segs, k + 1, #segs)
local L, R = #left, #right

local items = drain(buffer)
buffer.destroy()

if L + R == 0 then
    for _, item in pairs(items) do overflow[#overflow + 1] = item end
    return overflow
end

-- Left keeps the old link_id (and its inventory); right gets a fresh one.
-- If there is no left side, right simply keeps the old id.
local lbuf = L > 0 and get_buffer(left[1]) or nil
if L > 0 and R > 0 then
    local id = new_link_id()
    for _, s in ipairs(right) do get_buffer(s).link_id = id end
end
local rbuf = R > 0 and get_buffer(right[1]) or nil
if lbuf then set_capacity(lbuf, L) end
if rbuf then set_capacity(rbuf, R) end

local to_left, to_right = {}, {}
for _, item in pairs(items) do
    local l
    if L == 0 then l = 0
    elseif R == 0 then l = item.count
    else l = math.floor(item.count * L / (L + R) + 0.5) end
    if l > 0 then to_left[#to_left + 1] = { name = item.name, quality = item.quality, count = l } end
    if item.count - l > 0 then to_right[#to_right + 1] = { name = item.name, quality = item.quality, count = item.count - l } end
end
if lbuf then fill(lbuf, to_left, overflow) end
if rbuf then fill(rbuf, to_right, overflow) end
return overflow
end

-- Merge with side-by-side neighbors (same direction + force) by sharing a link_id.
local function try_merge(entity)
local perp = perp_vector(entity.direction)
for _, sign in ipairs({ -1, 1 }) do
    local n = splitter_at(entity.surface,
    { x = entity.position.x + perp.x * sign, y = entity.position.y + perp.y * sign },
    entity.direction)
    if n and n.force == entity.force then
    -- re-fetch each iteration: an earlier merge changed the group
    local a, b = get_buffer(entity), get_buffer(n)
    if a and b and a.link_id ~= b.link_id then
        local segs_a = group_of(entity, entity.direction)
        local segs_b = group_of(n, n.direction)
        local total = #segs_a + #segs_b
        if total <= CONST.max_segments then
        local items_a, items_b = drain(a), drain(b)
        for _, s in ipairs(segs_b) do get_buffer(s).link_id = a.link_id end
        set_capacity(a, total)
        local overflow = {}
        fill(a, items_a, overflow)
        fill(a, items_b, overflow)
        dispose(overflow, entity, nil) -- shouldn't happen: capacity is the sum
        end
    end
    end
end
end

---------------------------------------------------------------------------
-- loaders
---------------------------------------------------------------------------

local function loader_name(entity)
return entity.name .. "-loader"
end

-- Items flow in entity.direction: input loader at the back, output at the front.
local function end_positions(entity)
local v = DIR_VECTOR[entity.direction]
local p = entity.position
return { x = p.x - v.x, y = p.y - v.y }, { x = p.x + v.x, y = p.y + v.y }
end

local function find_loaders(entity, position)
return entity.surface.find_entities_filtered({ name = loader_name(entity), area = small_area(position, 0.2) })
end

local function create_loader(entity, position, loader_type)
entity.surface.create_entity({
    name = loader_name(entity),
    position = position,
    direction = entity.direction,
    type = loader_type,
    force = entity.force,
    create_build_effect_smoke = false,
})
end

local function destroy_loaders(entity)
local back, front = end_positions(entity)
for _, pos in pairs({ back, front }) do
    for _, loader in pairs(find_loaders(entity, pos)) do loader.destroy() end
end
end

---------------------------------------------------------------------------
-- entity lifecycle
---------------------------------------------------------------------------

-- Create whatever is missing, then merge with side-by-side neighbors.
local function ensure_parts(entity, rebuild_loaders)
if not get_buffer(entity) then create_buffer(entity) end

local back, front = end_positions(entity)
if rebuild_loaders then destroy_loaders(entity) end
if #find_loaders(entity, back) == 0 then create_loader(entity, back, "input") end
if #find_loaders(entity, front) == 0 then create_loader(entity, front, "output") end

try_merge(entity)
end

local function remove_parts(entity, mined_buffer)
destroy_loaders(entity)
dispose(leave_group(entity, entity.direction), entity, mined_buffer)
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------

local filter = { { filter = "type", type = "simple-entity-with-owner" } }

local function on_built(event)
local entity = event.entity or event.destination
if is_modular_splitter(entity) then ensure_parts(entity, false) end
end

script.on_event(defines.events.on_built_entity, on_built, filter)
script.on_event(defines.events.on_robot_built_entity, on_built, filter)
script.on_event(defines.events.on_space_platform_built_entity, on_built, filter)
script.on_event(defines.events.script_raised_built, on_built, filter)
script.on_event(defines.events.script_raised_revive, on_built, filter)

-- A cloned linked-container keeps the source's link_id and would share its
-- inventory with the original, so drop the clone's buffer and start fresh.
script.on_event(defines.events.on_entity_cloned, function(event)
local entity = event.destination
if not is_modular_splitter(entity) then return end
local stale = get_buffer(entity)
if stale then stale.destroy() end
ensure_parts(entity, false)
end)

local function on_mined(event)
if is_modular_splitter(event.entity) then remove_parts(event.entity, event.buffer) end
end

script.on_event(defines.events.on_player_mined_entity, on_mined, filter)
script.on_event(defines.events.on_robot_mined_entity, on_mined, filter)
script.on_event(defines.events.on_space_platform_mined_entity, on_mined, filter)

local function on_destroyed(event)
if is_modular_splitter(event.entity) then remove_parts(event.entity, nil) end
end

script.on_event(defines.events.on_entity_died, on_destroyed, filter)
script.on_event(defines.events.script_raised_destroy, on_destroyed, filter)

-- Placement is 4-way, but once placed only a 180 degree turn is allowed.
script.on_event(defines.events.on_player_rotated_entity, function(event)
local entity = event.entity
if not is_modular_splitter(entity) then return end

local turned = (entity.direction - event.previous_direction) % 16
if turned ~= D.south then -- south == 8 == 180 degrees
    entity.direction = (event.previous_direction + D.south) % 16
end

-- Neighbors still face previous_direction, so use it to find the old group.
dispose(leave_group(entity, event.previous_direction), entity, nil)
ensure_parts(entity, true)
end)