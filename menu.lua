local my_utility = require("my_utility/my_utility")

local menu_elements_bone =
{
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean")),
    main_tree           = tree_node:new(0),

    -- Spell categorization trees
    active_spells_tree = tree_node:new(1),
    inactive_spells_tree = tree_node:new(1),

    -- Weighted Targeting System (menu-driven)
    weighted_targeting_tree = tree_node:new(1),
    weighted_targeting_enabled = checkbox:new(true, get_hash(my_utility.plugin_label .. "weighted_targeting_enabled")),
    scan_radius = slider_int:new(1, 30, 12, get_hash(my_utility.plugin_label .. "scan_radius")),
    scan_refresh_rate = slider_float:new(0.1, 1.0, 0.2, get_hash(my_utility.plugin_label .. "scan_refresh_rate")),
    min_targets = slider_int:new(1, 10, 1, get_hash(my_utility.plugin_label .. "min_targets")),
    comparison_radius = slider_float:new(0.1, 6.0, 3.0, get_hash(my_utility.plugin_label .. "comparison_radius")),
}

return menu_elements_bone
