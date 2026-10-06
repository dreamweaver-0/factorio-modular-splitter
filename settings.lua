data:extend{
    {
        type = "string-setting",
        name = "modular-splitter-mode",
        setting_type = "startup",
        order = "a",
        default_value = "normal",
        allowed_values = {"normal", "lubricated"},
    },
    {
        type = "double-setting",
        name = "modular-splitter-cost-multiplier",
        setting_type = "startup",
        order = "b",
        default_value = 1.0,
        allowed_values = {0.25, 0.5, 1.0, 2.0, 4.0}
    },
    {
        type = "string-setting",
        name = "modular-splitter-extension-modes",
        setting_type = "startup",
        order = "c",
        default_value = "Fixed",
        allowed_values = {"Fixed", "Scale with Quality"}
    },
    {
        type = "double-setting",
        name = "modular-splitter-extension-limit-multiplier",
        setting_type = "startup",
        order = "d",
        default_value = 1.0,
        allowed_values = {0.5, 1.0, 2.0, 4.0}
    }
}