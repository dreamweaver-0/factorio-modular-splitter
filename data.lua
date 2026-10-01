debug_mode = false

debug_log = log

require("prototypes/modular-splitter")

local crafting_categories = {"crafting"}
local express_upgrade = mods["space-age"] and "turbo-modular-splitter"

if mods["space-age"] then
    --crafting_categories.insert("crafting-with-fluid")
end

if mods["space-age"] then
    require("prototypes/mods/space-age")
end