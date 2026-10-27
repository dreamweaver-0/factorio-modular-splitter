local CONST = require("prototypes/modular-splitter-constants")

---Creates and initializes the buffer ID storage tables
function init_id_storage()
    storage.groups = storage.groups or {}
    storage.free_ids = storage.free_ids or {}
    storage.inspector_targets = storage.inspector_targets or {}
end

---Checks the list of free buffer IDS to reuse one. If none are available, give the new buffer the next ID based on the list of tracked
---@return number
function alloc_buffer_id()
    local id = table.remove(storage.free_ids, 0)
    if not id then
        id = (0 < #storage.groups) and (storage.groups[#storage.groups] + 1) or CONST.link_id_base
    end
    storage.groups[#storage.groups + 1] = id
    return id
end

---Removes the given ID from tracked buffer IDs, add it to the list of free IDs
function free_buffer_id(id)
    if id and storage.groups[id] then
        storage.groups[id] = nil
        storage.free_ids[#storage.free_ids + 1] = id
        table.sort(storage.free_ids)
    end
end