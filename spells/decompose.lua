local my_utility = require("my_utility/my_utility")

-- Menu elements definition
local menu_elements_decompose = 
{
    tree_tab                    = tree_node:new(1),
    enable_spell                = checkbox:new(true, get_hash(my_utility.plugin_label .. "enable_spell_decompose")),
    max_range                   = slider_float:new(3.0, 12.0, 8.0, get_hash(my_utility.plugin_label .. "decompose_max_range")),
    channel_duration            = slider_float:new(1.0, 8.0, 3.0, get_hash(my_utility.plugin_label .. "decompose_channel_duration")),
    priority_elite              = checkbox:new(true, get_hash(my_utility.plugin_label .. "decompose_priority_elite")),
    priority_champion           = checkbox:new(true, get_hash(my_utility.plugin_label .. "decompose_priority_champion")),
    priority_boss               = checkbox:new(true, get_hash(my_utility.plugin_label .. "decompose_priority_boss")),
    low_health_threshold        = slider_int:new(0, 100, 50, get_hash(my_utility.plugin_label .. "decompose_health_threshold")),
    essence_threshold           = slider_int:new(0, 100, 50, get_hash(my_utility.plugin_label .. "decompose_essence_threshold")),
    avoid_when_surrounded       = checkbox:new(true, get_hash(my_utility.plugin_label .. "decompose_avoid_surrounded")),
    surrounding_enemy_count     = slider_int:new(2, 10, 4, get_hash(my_utility.plugin_label .. "decompose_surrounding_count")),
    force_corpse_generation     = checkbox:new(false, get_hash(my_utility.plugin_label .. "decompose_force_corpse")),
    min_corpses_needed          = slider_int:new(0, 5, 2, get_hash(my_utility.plugin_label .. "decompose_min_corpses")),
}

-- Spell ID
local spell_id_decompose = 463175

-- Logic variables  
local next_time_allowed_cast = 0.0
local last_cast_time = 0.0
local current_decompose_target = nil
local decompose_start_time = 0.0
local is_channeling_decompose = false

-- Menu function
local function menu()
    if menu_elements_decompose.tree_tab:push("Decompose") then
        menu_elements_decompose.enable_spell:render("Enable Spell", "Enable/Disable Decompose channeling skill")
        
        if menu_elements_decompose.enable_spell:get() then
            -- Basic settings
            menu_elements_decompose.max_range:render("Max Range", "Maximum range to start channeling", 1)
            menu_elements_decompose.channel_duration:render("Max Channel Duration", "Maximum time to channel in seconds", 1)
            
            -- Target Priority
            menu_elements_decompose.priority_boss:render("Prioritize Boss", "Always channel on boss targets", 0)
            menu_elements_decompose.priority_elite:render("Prioritize Elite", "Prioritize elite enemies", 0)
            menu_elements_decompose.priority_champion:render("Prioritize Champion", "Prioritize champion enemies", 0)
            menu_elements_decompose.low_health_threshold:render("Low Health Threshold %", "Prefer targets below this health %", 0)
            
            -- Essence Management
            menu_elements_decompose.essence_threshold:render("Min Essence to Channel %", "Only channel when essence is below this %", 0)
            
            -- Safety Settings
            menu_elements_decompose.avoid_when_surrounded:render("Avoid When Surrounded", "Don't channel when surrounded by many enemies", 0)
            if menu_elements_decompose.avoid_when_surrounded:get() then
                menu_elements_decompose.surrounding_enemy_count:render("Surrounding Enemy Limit", "Max nearby enemies to allow channeling", 0)
            end
            
            -- Corpse Generation
            menu_elements_decompose.force_corpse_generation:render("Force for Corpse Generation", "Channel when low on corpses", 0)
            if menu_elements_decompose.force_corpse_generation:get() then
                menu_elements_decompose.min_corpses_needed:render("Min Corpses Threshold", "Channel when corpses below this number", 0)
            end
        end
        
        menu_elements_decompose.tree_tab:pop()
    end
end

-- Check if target meets health threshold
local function meets_health_threshold(target)
    if not target then
        return false
    end
    
    local threshold = menu_elements_decompose.low_health_threshold:get()
    if threshold >= 100 then
        return true -- No health restriction
    end
    
    local current_health = target:get_current_health()
    local max_health = target:get_max_health()
    if max_health <= 0 then
        return false
    end
    
    local health_percentage = (current_health / max_health) * 100
    return health_percentage <= threshold
end

-- Get priority score for target
local function get_target_priority_score(target)
    if not target then
        return 0
    end
    
    local score = 1 -- Base score
    
    -- Priority bonuses
    if target:is_boss() and menu_elements_decompose.priority_boss:get() then
        score = score + 100
    elseif target:is_elite() and menu_elements_decompose.priority_elite:get() then
        score = score + 20
    elseif target:is_champion() and menu_elements_decompose.priority_champion:get() then
        score = score + 15
    end
    
    -- Health threshold bonus (prefer low health enemies)
    if meets_health_threshold(target) then
        score = score + 10
    end
    
    return score
end

-- Check if we have enough essence to warrant channeling
local function needs_essence_generation()
    local local_player = get_local_player()
    if not local_player then
        return false
    end
    
    local current_essence = local_player:get_current_resource()
    local max_essence = local_player:get_max_resource()
    if max_essence <= 0 then
        return false
    end
    
    local essence_percentage = (current_essence / max_essence) * 100
    return essence_percentage <= menu_elements_decompose.essence_threshold:get()
end

-- Count nearby corpses
local function count_nearby_corpses()
    local player_pos = get_player_position()
    if not player_pos then
        return 0
    end
    
    -- This would need to be implemented based on the game's corpse detection API
    -- For now, return a placeholder value
    return 3 -- Placeholder - would need actual corpse counting implementation
end

-- Check if we need corpses
local function needs_corpse_generation()
    if not menu_elements_decompose.force_corpse_generation:get() then
        return false
    end
    
    local nearby_corpses = count_nearby_corpses()
    return nearby_corpses < menu_elements_decompose.min_corpses_needed:get()
end

-- Check if we're surrounded by too many enemies
local function is_surrounded_by_enemies()
    if not menu_elements_decompose.avoid_when_surrounded:get() then
        return false
    end
    
    local player_pos = get_player_position()
    if not player_pos then
        return false
    end
    
    local nearby_enemies = target_selector.get_near_target_list(player_pos, 5.0)
    local enemy_count = 0
    
    for _, enemy in ipairs(nearby_enemies) do
        if enemy:get_current_health() > 0 then
            enemy_count = enemy_count + 1
        end
    end
    
    return enemy_count >= menu_elements_decompose.surrounding_enemy_count:get()
end

-- Find best target for decompose channeling
local function find_best_decompose_target(player_pos)
    local max_range = menu_elements_decompose.max_range:get()
    local target_list = target_selector.get_near_target_list(player_pos, max_range)
    
    local best_target = nil
    local best_score = 0
    
    for _, target in ipairs(target_list) do
        if target:get_current_health() > 0 then
            local target_pos = target:get_position()
            local distance = math.sqrt(target_pos:squared_dist_to_ignore_z(player_pos))
            
            if distance <= max_range then
                local score = get_target_priority_score(target)
                
                -- Distance penalty (closer is better for channeling)
                score = score - (distance * 0.8)
                
                if score > best_score then
                    best_score = score
                    best_target = target
                end
            end
        end
    end
    
    return best_target
end

-- Check if we should stop channeling
local function should_stop_channeling()
    local current_time = get_time_since_inject()
    local max_duration = menu_elements_decompose.channel_duration:get()
    
    -- Stop if we've been channeling too long
    if current_time - decompose_start_time >= max_duration then
        return true
    end
    
    -- Stop if target is dead or invalid
    if not current_decompose_target or current_decompose_target:get_current_health() <= 0 then
        return true
    end
    
    -- Stop if we're in danger
    local player_pos = get_player_position()
    if player_pos and evade.is_dangerous_position(player_pos) then
        return true
    end
    
    -- Stop if we're now surrounded by too many enemies
    if is_surrounded_by_enemies() then
        return true
    end
    
    return false
end

-- Main logic function
local function logics(best_target)
    -- Check if menu is enabled
    if not menu_elements_decompose.enable_spell:get() then
        return false
    end

    -- Check if we're currently channeling
    if is_channeling_decompose then
        if should_stop_channeling() then
            is_channeling_decompose = false
            current_decompose_target = nil
            console.print("Necromancer Plugin: Stopped channeling Decompose")
        end
        return false -- Don't start new spells while channeling
    end

    -- Check if spell is allowed to cast
    local is_allowed = my_utility.is_spell_allowed(
        true,  -- Enable check
        next_time_allowed_cast,
        spell_id_decompose
    )

    if not is_allowed then
        return false
    end

    local local_player = get_local_player()
    if not local_player then
        return false
    end

    local player_pos = get_player_position()
    if not player_pos then
        return false
    end

    -- Safety check - don't channel if surrounded
    if is_surrounded_by_enemies() then
        return false
    end

    -- Check if we need essence or corpses
    local needs_essence = needs_essence_generation()
    local needs_corpses = needs_corpse_generation()
    
    if not needs_essence and not needs_corpses then
        -- Only continue if we have high priority targets
        local target = best_target or find_best_decompose_target(player_pos)
        if not target then
            return false
        end
        
        -- Only channel on high priority targets if we don't need resources
        if not (target:is_boss() or target:is_elite() or target:is_champion()) then
            return false
        end
    end

    -- Find target to decompose
    local target_to_decompose = best_target or find_best_decompose_target(player_pos)
    if not target_to_decompose then
        return false
    end

    -- Start channeling decompose
    if cast_spell.target(spell_id_decompose, target_to_decompose, 0.0) then
        is_channeling_decompose = true
        current_decompose_target = target_to_decompose
        decompose_start_time = get_time_since_inject()
        last_cast_time = decompose_start_time
        next_time_allowed_cast = last_cast_time + 0.3
        
        local target_type = "enemy"
        if target_to_decompose:is_boss() then
            target_type = "BOSS"
        elseif target_to_decompose:is_elite() then
            target_type = "ELITE"
        elseif target_to_decompose:is_champion() then
            target_type = "CHAMPION"
        end
        
        console.print("Necromancer Plugin: Started channeling Decompose on " .. target_type)
        return true
    end

    return false
end

return {
    menu = menu,
    logics = logics
}