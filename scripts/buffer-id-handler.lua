local CONST = require("prototypes/modular-splitter-constants")

---Creates and initializes the buffer ID storage tables
function init_id_storage()
    storage.groups = storage.groups or {}
    storage.free_ids = storage.free_ids or {}
    storage.next_id = storage.next_id or CONST.link_id_base
    storage.inspector_targets = storage.inspector_targets or {}
end

---Checks the list of free buffer IDS to reuse one. If none are available, give the new buffer the next ID based on storage.next_id
function alloc_buffer_id()
    local id = table.remove(storage.free_ids)
    if not id then
        id = storage.next_id
        storage.next_id = storage.next_id + 1
    end
    storage.groups[id] = true
    return id
end

---Removes the given ID from tracked buffer IDs, add it to the list of free IDs
function free_buffer_id(id)
    if id and storage.groups[id] then
        storage.groups[id] = nil
        storage.free_ids[#storage.free_ids + 1] = id
    end
end