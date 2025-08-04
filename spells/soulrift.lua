local my_utility = require("my_utility/my_utility")

-- Menu elements definition
local menu_elements_soulrift = 
{
    tree_tab                  = tree_node:new(1),
    enable_spell              = checkbox:new(true, get_hash(my_utility.plugin_label .. "enable_spell_soulrift")),
    min_targets               = slider_int:new(1, 10, 3, get_hash(my_utility.plugin_label .. "min_enemies_to_cast_soulrift")),
    health_percentage         = slider_int:new(0, 100, 75, get_hash(my_utility.plugin_label .. "soulrift_health_percentage")),
    boss_range                = slider_float:new(5.0, 20.0, 10.0, get_hash(my_utility.plugin_label .. "soulrift_boss_range")),
    force_on_boss             = checkbox:new(true, get_hash(my_utility.plugin_label .. "soulrift_force_on_boss")),
    enable_movement           = checkbox:new(true, get_hash(my_utility.plugin_label .. "soulrift_enable_movement")),
    movement_enemy_threshold  = slider_int:new(3, 15, 5, get_hash(my_utility.plugin_label .. "soulrift_movement_threshold")),
    movement_range            = slider_float:new(5.0, 25.0, 15.0, get_hash(my_utility.plugin_label .. "soulrift_movement_range")),
}

-- Spell ID
local spell_id_soulrift = 1644584

-- Logic variables
local next_time_allowed_cast = 0.0
local last_cast_time = 0.0
local movement_target_pos = nil
local movement_start_time = 0.0
local movement_last_command_time = 0.0

-- Menu function
local function menu()
    if menu_elements_soulrift.tree_tab:push("Soulrift") then
        menu_elements_soulrift.enable_spell:render("Enable Spell", "")
        
        if menu_elements_soulrift.enable_spell:get() then
            menu_elements_soulrift.min_targets:render("Min Enemies Around", "Amount of targets to cast the spell", 0)
            menu_elements_soulrift.health_percentage:render("Max Health %", "Cast when health below this %", 0)
            menu_elements_soulrift.boss_range:render("Boss Detection Range", "Range to detect boss targets", 0)
            menu_elements_soulrift.force_on_boss:render("Force Cast on Boss", "Ignore conditions when boss is present", 0)
            
            menu_elements_soulrift.enable_movement:render("Enable Movement", "Move to enemy clusters when skill is active", 0)
            if menu_elements_soulrift.enable_movement:get() then
                menu_elements_soulrift.movement_enemy_threshold:render("Movement Enemy Threshold", "Move when detecting this many enemies", 0)
                menu_elements_soulrift.movement_range:render("Movement Detection Range", "Range to search for enemy clusters", 0)
            end
        end
        
        menu_elements_soulrift.tree_tab:pop()
    end
end

-- Check if there's a boss in range
local function has_boss_in_range(range)
    local player_pos = get_player_position()
    if not player_pos then
        return false
    end
    
    -- Use target_selector to get nearby enemies
    local enemy_list = target_selector.get_near_target_list(player_pos, range)
    
    for _, enemy in ipairs(enemy_list) do
        if enemy:is_boss() and enemy:get_current_health() > 0 then
            return true
        end
    end
    
    return false
end

-- Check if Soulrift skill is active
local function is_soulrift_active()
    local local_player = get_local_player()
    if not local_player then
        return false
    end
    
    -- Check if player has Soulrift buff/status
    local buffs = local_player:get_buffs()
    for _, buff in ipairs(buffs) do
        if buff.spell_id == spell_id_soulrift then
            return true
        end
    end
    
    return false
end

-- Find best enemy cluster position
local function find_best_enemy_cluster()
    local player_pos = get_player_position()
    if not player_pos then
        return nil, 0
    end
    
    local movement_range = menu_elements_soulrift.movement_range:get()
    local enemy_list = target_selector.get_near_target_list(player_pos, movement_range)
    
    local best_position = nil
    local max_enemies = 0
    
    -- Iterate through all enemies to find densest cluster
    for _, enemy in ipairs(enemy_list) do
        if enemy:get_current_health() > 0 then
            local enemy_pos = enemy:get_position()
            local distance_to_player = math.sqrt(enemy_pos:squared_dist_to_ignore_z(player_pos))
            
            -- Only consider enemies within movement range
            if distance_to_player <= movement_range then
                -- Count enemies within 3 meters of this enemy
                local nearby_count = 0
                for _, other_enemy in ipairs(enemy_list) do
                    if other_enemy ~= enemy and other_enemy:get_current_health() > 0 then
                        local other_pos = other_enemy:get_position()
                        local distance_to_cluster = math.sqrt(enemy_pos:squared_dist_to_ignore_z(other_pos))
                        if distance_to_cluster <= 3.0 then
                            nearby_count = nearby_count + 1
                        end
                    end
                end
                
                -- Include the current enemy in the count
                nearby_count = nearby_count + 1
                
                -- Update best position if this cluster is larger
                if nearby_count > max_enemies then
                    max_enemies = nearby_count
                    best_position = enemy_pos
                end
            end
        end
    end
    
    -- Only return position if it meets the threshold
    if max_enemies >= menu_elements_soulrift.movement_enemy_threshold:get() then
        return best_position, max_enemies
    end
    
    return nil, 0
end

-- Handle movement logic
local function handle_movement()
    if not menu_elements_soulrift.enable_movement:get() then
        return false
    end
    
    -- Only move when Soulrift skill is active
    if not is_soulrift_active() then
        movement_target_pos = nil
        return false
    end
    
    local current_time = get_time_since_inject()
    
    -- Find new movement target
    local best_pos, enemy_count = find_best_enemy_cluster()
    if best_pos and enemy_count >= menu_elements_soulrift.movement_enemy_threshold:get() then
        local player_pos = get_player_position()
        if player_pos then
            local distance_to_cluster = math.sqrt(best_pos:squared_dist_to_ignore_z(player_pos))
            
            -- If distance to enemy cluster is more than 3 meters, move there
            if distance_to_cluster > 3.0 then
                -- Use pathfinder to move to enemy cluster
                if current_time - (movement_last_command_time or 0) > 0.3 then
                    if pathfinder.move_to_cpathfinder then
                        pathfinder.move_to_cpathfinder(best_pos)
                    elseif pathfinder.force_move then
                        pathfinder.force_move(best_pos)
                    end
                    movement_last_command_time = current_time
                    console.print("Necromancer Plugin: Moving to enemy cluster with " .. enemy_count .. " enemies (distance: " .. math.floor(distance_to_cluster) .. "m)")
                end
                
                return true
            end
        end
    end
    
    return false
end

-- Main logic function
local function logics()
    -- Check if menu is enabled
    if not menu_elements_soulrift.enable_spell:get() then
        return false
    end

    -- Handle movement logic
    local is_moving = handle_movement()
    
    -- If moving to enemy cluster, temporarily don't cast skill
    if is_moving and movement_target_pos then
        return false
    end

    -- Check if spell is allowed to cast
    local is_allowed = my_utility.is_spell_allowed(
        true,  -- Enable check
        next_time_allowed_cast,
        spell_id_soulrift
    )

    if not is_allowed then
        return false
    end

    local local_player = get_local_player()
    if not local_player then
        return false
    end

    -- BOSS detection priority logic
    if menu_elements_soulrift.force_on_boss:get() then
        local boss_range = menu_elements_soulrift.boss_range:get()
        if has_boss_in_range(boss_range) then
            -- Force cast spell (ignore other conditions)
            if cast_spell.self(spell_id_soulrift, 0.0) then
                console.print("Necromancer Plugin: Casted Soulrift on BOSS target")
                last_cast_time = get_time_since_inject()
                next_time_allowed_cast = last_cast_time + 0.5
                return true
            end
        end
    end

    -- Regular condition checks (if no BOSS detected or BOSS feature not enabled)
    
    -- Check health percentage
    local current_health = local_player:get_current_health()
    local max_health = local_player:get_max_health()
    local health_percentage = (current_health / max_health) * 100
    
    if health_percentage > menu_elements_soulrift.health_percentage:get() then
        return false
    end

    -- Get player position
    local player_pos = get_player_position()
    if not player_pos then
        return false
    end

    -- Check number of enemies around player
    local enemy_list = target_selector.get_near_target_list(player_pos, 3.0)
    local enemy_count = 0
    
    -- Count valid enemies
    for _, enemy in ipairs(enemy_list) do
        if enemy:get_current_health() > 0 then
            enemy_count = enemy_count + 1
        end
    end

    -- Check if minimum enemy count is reached
    if enemy_count < menu_elements_soulrift.min_targets:get() then
        return false
    end

    -- Cast spell
    if cast_spell.self(spell_id_soulrift, 0.0) then
        console.print("Necromancer Plugin: Casted Soulrift on " .. enemy_count .. " enemies")
        last_cast_time = get_time_since_inject()
        next_time_allowed_cast = last_cast_time + 0.5
        return true
    end

    return false
end

return {
    menu = menu,
    logics = logics
}