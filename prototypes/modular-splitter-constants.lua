return {
    base_name = "modular-splitter",
    buffer_name = "modular-splitter-buffer",
    slots_per_segment = 4,
    max_segments = 16,          -- inventory is sized for this many; the bar limits smaller groups
    link_id_base = 626000000,   -- high start so we don't collide with other mods' link_ids (uint32)
    debug_events = true,
    debug_inspector = true,
}