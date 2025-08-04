local local_player = get_local_player()
if local_player == nil then
    return
end

local character_id = local_player:get_character_class_id();
local is_necro = character_id == 6;
if not is_necro then
 return
end;

local menu = require("menu");
local spell_priority = require("spell_priority");
local spell_data = require("my_utility/spell_data");

local spells =
{
    blood_mist                  = require("spells/blood_mist"),
    bone_spear                  = require("spells/bone_spear"),           
    bone_splinters              = require("spells/bone_splinters"),               
    corpse_explosion            = require("spells/corpse_explosion"),                     
    corpse_tendrils             = require("spells/corpse_tendrils"),                  
    decrepify                   = require("spells/decrepify"), 
    hemorrhage                  = require("spells/hemorrhage"),
    reap                        = require("spells/reap"),
    blood_lance                 = require("spells/blood_lance"),
    blood_surge                 = require("spells/blood_surge"),
    blight                      = require("spells/blight"),
    sever                       = require("spells/sever"),
    bone_prison                 = require("spells/bone_prison"),
    iron_maiden                 = require("spells/iron_maiden"),
    bone_spirit                 = require("spells/bone_spirit"),
    blood_wave                  = require("spells/blood_wave"),
    army_of_the_dead            = require("spells/army_of_the_dead"),
    bone_storm                  = require("spells/bone_storm"),
    raise_skeleton              = require("spells/raise_skeleton"),
    golem_control               = require("spells/golem_control"),
    soulrift                    = require("spells/soulrift"),
    decompose                   = require("spells/decompose"),
}

on_render_menu (function ()

    if not menu.main_tree:push("Necro - Clean version") then
        return;
    end;

    menu.main_boolean:render("Enable Plugin", "");

    if menu.main_boolean:get() == false then
        menu.main_tree:pop();
        return;
    end;
    
    -- Get equipped spells
    local equipped_spells = get_equipped_spell_ids()
    table.insert(equipped_spells, spell_data.evade.spell_id)
    
    -- Create lookup table for equipped spells
    local equipped_lookup = {}
    for _, spell_id in ipairs(equipped_spells) do
        equipped_lookup[spell_id] = true
    end
    
    -- Weighted Targeting System menu
    if menu.weighted_targeting_tree:push("Weighted Targeting") then
         menu.weighted_targeting_enabled:render("Enable Weighted Targeting", "")
		 menu.scan_radius:render("Scan Radius", "Radius around character to scan for targets (1-30)")
         menu.scan_refresh_rate:render("Refresh Rate", "How often to refresh target scanning in seconds (0.1-1.0)", 1) -- Add rounding parameter for float slider
         menu.min_targets:render("Minimum Targets", "Minimum number of targets required to activate weighted targeting (1-10)")
         menu.comparison_radius:render("Comparison Radius", "Radius to check for nearby targets when calculating weights (0.1-6.0)", 1) -- Add rounding parameter for float slider
            
        menu.weighted_targeting_tree:pop()
    end
    
    -- Active spells menu (spells that are currently equipped)
    if menu.active_spells_tree:push("Active Spells") then
        for _, spell_name in ipairs(spell_priority) do
            if spells[spell_name] and spell_data[spell_name] and spell_data[spell_name].spell_id and equipped_lookup[spell_data[spell_name].spell_id] then
                spells[spell_name].menu()
            end
        end
        menu.active_spells_tree:pop()
    end
    
    -- Inactive spells menu (spells that are not currently equipped)
    if menu.inactive_spells_tree:push("Inactive Spells") then
        for _, spell_name in ipairs(spell_priority) do
            if spells[spell_name] and spell_data[spell_name] and spell_data[spell_name].spell_id and not equipped_lookup[spell_data[spell_name].spell_id] then
                spells[spell_name].menu()
            end
        end
        menu.inactive_spells_tree:pop()
    end

    menu.main_tree:pop();
end)

local can_move = 0.0;
local cast_end_time = 0.0;

local blood_mist_buff_name = "Necromancer_BloodMist";
local blood_mist_buff_name_hash = blood_mist_buff_name;
local blood_mist_buff_name_hash_c = 493422;

local mount_buff_name = "Generic_SetCannotBeAddedToAITargetList";
local mount_buff_name_hash = mount_buff_name;
local mount_buff_name_hash_c = 1923;

local my_utility = require("my_utility/my_utility");
local my_target_selector = require("my_utility/my_target_selector");

local is_blood_mist = false
on_update(function ()

    local local_player = get_local_player();
    if not local_player then
        return;
    end
    
    if menu.main_boolean:get() == false then
        return;
    end;

    local current_time = get_time_since_inject()
    if current_time < cast_end_time then
        return;
    end;

    is_blood_mist = false;
    local local_player_buffs = local_player:get_buffs();
    for _, buff in ipairs(local_player_buffs) do
        if buff.name_hash == blood_mist_buff_name_hash_c then
            is_blood_mist = true;
            break;
        end
    end

    if not my_utility.is_action_allowed() then
        return;
    end  

    local screen_range = 16.0;
    local player_position = get_player_position();

    local collision_table = { true, 2.0 };
    local floor_table = { true, 5.0 };
    local angle_table = { false, 90.0 };

    local entity_list = my_target_selector.get_target_list(
        player_position,
        screen_range, 
        collision_table, 
        floor_table, 
        angle_table);

    local target_selector_data = my_target_selector.get_target_selector_data(
        player_position, 
        entity_list);

    if not target_selector_data.is_valid then
        return;
    end

    local is_auto_play_active = auto_play.is_active();
    local max_range = 10.0;
    if is_auto_play_active then
        max_range = 12.0;
    end

    -- Default target selection
    local best_target = target_selector_data.closest_unit;

    -- Apply weighted targeting if enabled
    if menu.weighted_targeting_enabled:get() then
    local min_targets = menu.min_targets:get()
    local scan_radius = menu.scan_radius:get()
    local refresh_rate = menu.scan_refresh_rate:get()
    local comparison_radius = menu.comparison_radius:get()
    local weighted_target = my_target_selector.get_weighted_target(
        player_position,
        min_targets,
        scan_radius,
        refresh_rate,
        comparison_radius
    )
    if weighted_target then
        best_target = weighted_target
    else
            -- No valid weighted target found
            return
        end
    else
        -- Traditional targeting (if weighted targeting is disabled)
        if target_selector_data.has_elite then
            local unit = target_selector_data.closest_elite;
            local unit_position = unit:get_position();
            local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
            if distance_sqr < (max_range * max_range) then
                best_target = unit;
            end        
        end

        if target_selector_data.has_boss then
            local unit = target_selector_data.closest_boss;
            local unit_position = unit:get_position();
            local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
            if distance_sqr < (max_range * max_range) then
                best_target = unit;
            end
        end

        if target_selector_data.has_champion then
            local unit = target_selector_data.closest_champion;
            local unit_position = unit:get_position();
            local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
            if distance_sqr < (max_range * max_range) then
                best_target = unit;
            end
        end
    end

    if not best_target then
        return;
    end

    local best_target_position = best_target:get_position();
    local distance_sqr = best_target_position:squared_dist_to_ignore_z(player_position);

    if distance_sqr > (max_range * max_range) then            
        best_target = target_selector_data.closest_unit;
        local closer_pos = best_target:get_position();
        local distance_sqr_2 = closer_pos:squared_dist_to_ignore_z(player_position);
        if distance_sqr_2 > (max_range * max_range) then
            return;
        end
    end

    -- Get equipped spells for spell casting logic
    local equipped_spells = get_equipped_spell_ids()
    table.insert(equipped_spells, spell_data.evade.spell_id)
    
    -- Create lookup table for equipped spells
    local equipped_lookup = {}
    for _, spell_id in ipairs(equipped_spells) do
        equipped_lookup[spell_id] = true
    end

    -- Define spell parameters
    local spell_params = {
        -- No parameters (self-cast spells)
        blood_mist = { args = {} },
        raise_skeleton = { args = {} },
        golem_control = { args = {} },
        decrepify = { args = {} },
        army_of_the_dead = { args = {} },
        corpse_tendrils = { args = {} },
        corpse_explosion = { args = {} },
        blood_surge = { args = {} },
        iron_maiden = { args = {} },
        bone_storm = { args = {} },
        soulrift = { args = {} },
        
        -- Single target parameter
        blood_wave = { args = {best_target} },
        bone_splinters = { args = {best_target} },
        reap = { args = {best_target} },
        blood_lance = { args = {best_target} },
        blight = { args = {best_target} },
        sever = { args = {best_target} },
        bone_prison = { args = {best_target} },
        bone_spirit = { args = {best_target} },
        hemorrhage = { args = {best_target} },
        decompose = { args = {best_target} },
        
        -- Multiple parameters
        bone_spear = { args = {best_target, entity_list} },
    }

    -- Loop through spells in priority order
    for _, spell_name in ipairs(spell_priority) do
        local spell = spells[spell_name]
        -- Only process spells that are equipped
        if spell and spell_data[spell_name] and spell_data[spell_name].spell_id and equipped_lookup[spell_data[spell_name].spell_id] then
            local params = spell_params[spell_name]
            
            if params then
                local cast_successful = spell.logics(unpack(params.args))
                if cast_successful then
                    cast_end_time = current_time + 0.4 -- Default cooldown
                    return
                end
            end
        end
    end

    -- Auto play movement logic (unchanged)
    local move_timer = get_time_since_inject()
    if move_timer < can_move then
        return;
    end;

    local is_auto_play = my_utility.is_auto_play_enabled();
    if is_auto_play then
        local player_position = local_player:get_position();
        local is_dangerous_evade_position = evade.is_dangerous_position(player_position);
        if not is_dangerous_evade_position then
            local closer_target = target_selector.get_target_closer(player_position, 15.0);
            if closer_target then
                if is_blood_mist then
                    local closer_target_position = closer_target:get_position();
                    local move_pos = closer_target_position:get_extended(player_position, -5.0);
                    if pathfinder.move_to_cpathfinder(move_pos) then
                        cast_end_time = current_time + 0.40;
                        can_move = move_timer + 1.5;
                    end
                else
                    local closer_target_position = closer_target:get_position();
                    local move_pos = closer_target_position:get_extended(player_position, 4.0);
                    if pathfinder.move_to_cpathfinder(move_pos) then
                        can_move = move_timer + 1.5;
                    end
                end
            end
        end
    end
end);

-- Render functions remain the same
local draw_player_circle = false;
local draw_enemy_circles = false;

on_render(function ()
    -- ... existing render code remains unchanged ...
end);

console.print("Lua Plugin - Necromancer Clean version");