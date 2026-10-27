local CONST = require("prototypes/modular-splitter-constants")

---Creates and initializes the buffer ID storage tables
function init_id_storage()
    -- Stores a list of active IDs in the world
    storage.active_ids = storage.active_ids or {}
    -- Stores a list of tables that reference all active groups in the world
    storage.groups = storage.groups or {}
    -- Stores a list of freed IDs that are no longer used by any buffer groups
    storage.free_ids = storage.free_ids or {}
    -- Yeah I don't know what this one is
    storage.inspector_targets = storage.inspector_targets or {}
end

---Checks the list of free buffer IDS to reuse one. If none are available, give the new buffer the next ID based on the list of tracked
---@return number
function alloc_buffer_id()
    local id = table.remove(storage.free_ids, 0)
    if not id then
        id = (0 < #storage.active_ids) and (storage.active_ids[#storage.active_ids] + 1) or CONST.link_id_base
    end
    storage.active_ids[#storage.active_ids + 1] = id
    return id
end

---Removes the given ID from tracked buffer IDs, add it to the list of free IDs
function free_buffer_id(id)
    if id and storage.active_ids[id] then
        storage.active_ids[id] = nil
        storage.free_ids[#storage.free_ids + 1] = id
        table.sort(storage.free_ids)
    end
end