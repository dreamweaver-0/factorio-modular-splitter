data:extend{
    {
        name = "manifold-splitter-mode",
        type = "string-setting",
        setting_type = "startup",
        order = "a",
        default_value = "normal",
        allowed_values = {"normal", "lubricated"},
    },
    {
        name = "manifold-splitter-cost-multiplier",
        type = "double-setting",
        setting_type = "startup",
        order = "b",
        default_value = 1.0,
        allowed_values = {0.25, 0.5, 1.0, 2.0, 4.0}
    },
    {
        name = "manifold-splitter-extension-modes",
        type = "string-setting",
        setting_type = "startup",
        order = "c",
        default_value = "Fixed",
        allowed_values = {"Fixed", "Scale with Quality"}
    },
    {
        name = "manifold-splitter-extension-limit-multiplier",
        type = "double-setting",
        setting_type = "startup",
        order = "d",
        default_value = 1.0,
        allowed_values = {0.5, 1.0, 2.0, 4.0}
    }
}