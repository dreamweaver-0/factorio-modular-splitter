require("prototypes/modular-splitter")
require("prototypes/vanilla")

if mods["space-age"] then
    require("prototypes/mods/space-age")
end

data:extend({
    {
        type = "custom-input",
        name = "modular-splitter-inspect",
        key_sequence = "CONTROL + SHIFT + I",
        consuming = "none",
    },
})