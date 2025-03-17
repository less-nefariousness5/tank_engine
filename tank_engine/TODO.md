# Tank Engine Framework TODO

## Status: 🟢 Completed | 🟡 In Progress | 🔴 Not Started

## Project Structure (🟢 Completed)
```
PS/scripts/tank_engine/
├── core/
│   ├── index.lua          - Main entry point that loads core modules
│   ├── api.lua            - API integration points
│   ├── humanizer.lua      - Action humanization for detection avoidance
│   ├── menu.lua           - UI menu elements and configuration
│   ├── settings.lua       - Engine settings and thresholds
│   └── variables.lua      - Global variables and state tracking
├── modules/
│   ├── threat_engine/     - Threat tracking and management
│   ├── defensive_engine/  - Defensive cooldown optimization
│   ├── mitigation_engine/ - Active mitigation tracking
│   ├── interrupt_engine/  - Interrupt and CC management
│   ├── pull_engine/       - Pull planning and execution
│   ├── survival_engine/   - Survival analytics and metrics
│   ├── resource_engine/   - Resource efficiency optimization
│   ├── wigs_engine/       - BigWigs/LittleWigs tracking
│   ├── healer_engine/     - Healer performance tracking 
│   └── ttd_engine/        - Time-to-death calculations
└── main.lua               - Main initialization file
```

## Core Components (🟢 Completed)

### 1. Threat Engine (🟢 Completed)
Tracks threat for all engaged targets, calculates threat differentials, and prioritizes targets.

```lua
FS.modules.threat_engine = {
    units = {},                    -- Currently tracked units
    threat_values = {},            -- Threat values for each unit
    threat_differentials = {},     -- Difference between your threat and others
    losing_threat_targets = {},    -- Targets where threat is dropping
    high_priority_targets = {},    -- Targets that need immediate attention
    
    -- Target selection algorithms
    get_losing_threat_target = function(threshold) end,
    get_highest_threat_target = function() end,
    get_aoe_threat_targets = function(count, radius) end,
}
```

### 2. Defensive Engine (🟢 Completed)
Optimizes defensive cooldown usage based on incoming damage patterns.

```lua
FS.modules.defensive_engine = {
    incoming_damage_history = {},  -- Historical damage intake
    damage_spikes = {},            -- Detected spike damage patterns
    cooldowns_available = {},      -- Available defensive cooldowns
    
    -- Cooldown selection algorithms
    get_physical_defense_cooldown = function(threshold) end,
    get_magical_defense_cooldown = function(threshold) end,
    get_emergency_cooldown = function() end,
    predict_damage_pattern = function(window_size) end,
}
```

### 3. Mitigation Engine (🟢 Completed)
Tracks active mitigation uptimes and optimizes their usage.

```lua
FS.modules.mitigation_engine = {
    mitigation_uptimes = {},       -- Active mitigation uptime tracking
    resource_availability = {},    -- Resource tracking for mitigation
    mitigation_gaps = {},          -- Gaps in mitigation coverage
    
    -- Mitigation algorithms
    get_optimal_mitigation_ability = function() end,
    calculate_mitigation_uptime = function(window_size) end,
    predict_mitigation_gaps = function(future_window) end,
}
```

### 4. Interrupt Engine (🟢 Completed)
Manages interrupts and crowd control priorities.

```lua
FS.modules.interrupt_engine = {
    interrupt_targets = {},        -- Current interrupt targets
    interrupt_priorities = {},     -- Priority scoring for interrupts
    cc_targets = {},               -- Crowd control targets
    
    -- Target selection algorithms
    get_high_priority_interrupt = function() end,
    get_optimal_cc_target = function() end,
    calculate_cast_danger = function(spell_id) end,
}
```

### 5. Pull Engine (🔴 Not Started)
Plans and executes optimal pulls.

```lua
FS.modules.pull_engine = {
    enemy_packs = {},              -- Nearby enemy packs
    patrol_timings = {},           -- Patrol timing tracking
    pull_history = {},             -- History of recent pulls
    
    -- Pull algorithms
    get_optimal_pull_size = function(cooldowns_available) end,
    calculate_los_pull_position = function() end,
    analyze_enemy_pack_danger = function(pack) end,
}
```

### 6. Survival Engine (🔴 Not Started)
Tracks survival metrics and emergency actions.

```lua
FS.modules.survival_engine = {
    health_history = {},           -- Historical health values
    damage_taken_rates = {},       -- Damage intake rates
    self_healing_rates = {},       -- Self-healing rates
    
    -- Survival algorithms
    calculate_time_to_live = function() end,
    get_emergency_action = function(threshold) end,
    predict_health_threshold_breach = function(threshold, window) end,
}
```

### 7. Resource Engine (🔴 Not Started)
Optimizes resource generation and spending.

```lua
FS.modules.resource_engine = {
    resource_history = {},         -- Historical resource values
    ability_resource_costs = {},   -- Resource costs of abilities
    resource_generators = {},      -- Resource generating abilities
    
    -- Resource algorithms
    get_optimal_spending_pattern = function() end,
    predict_resource_availability = function(window) end,
    calculate_resource_efficiency = function(ability_id) end,
}
```

### 8. Wigs Engine (🟢 Completed)
Tracks and reacts to BigWigs/LittleWigs timers.

```lua
FS.modules.wigs_engine = {
    active_bars = {},              -- Currently active bars
    important_abilities = {},      -- Important boss abilities
    cooldown_timings = {},         -- Cooldown timings relative to bars
    
    -- Wigs tracking algorithms
    get_important_bar = function(time_threshold) end,
    predict_ability_timing = function(ability_name) end,
    recommend_cooldown_timing = function(cooldown_id) end,
}
```

### 9. Healer Engine (🟢 Completed)
Tracks healer performance and incoming heals.

```lua
FS.modules.healer_engine = {
    healers = {},                  -- Healers in group
    healing_received = {},         -- Healing received from each healer
    healing_efficiency = {},       -- Healer efficiency scores
    
    -- Healer scoring algorithms
    calculate_healer_score = function(healer) end,
    predict_incoming_healing = function(window) end,
    is_healing_sufficient = function(incoming_damage) end,
}
```

### 10. TTD Engine (🟢 Completed)
Calculates time-to-death for enemies.

```lua
FS.modules.ttd_engine = {
    health_regression = {},        -- Health regression data for enemies
    damage_output = {},            -- Group damage output
    ttd_values = {},               -- Calculated TTD values
    
    -- TTD algorithms
    calculate_enemy_ttd = function(unit) end,
    calculate_group_ttd = function(units) end,
    get_priority_target_by_ttd = function(min_ttd, max_ttd) end,
}
```

## Implementation Steps

### Current Progress:

### Phase 1: Core Framework (🟢 Completed)
1. Create basic directory structure
2. Implement core modules
3. Create centralized state management

### Phase 2: Data Collection (🟡 In Progress)
1. Implement threat tracking
2. Implement damage intake monitoring
3. Implement resource tracking
4. Implement BigWigs/LittleWigs bar detection

### Phase 3: Analysis Engines (🟡 In Progress)
1. Implement TTD engine with health regression models
2. Implement healer performance analysis
3. Implement active mitigation gap analysis
4. Implement incoming damage pattern recognition

### Phase 4: Decision Systems (🔴 Not Started)
1. Implement defensive cooldown selection
2. Implement interrupt priority system
3. Implement resource optimization
4. Implement pull planning logic

### Phase 5: Integration and Testing (🔴 Not Started)
1. Integrate all modules with the core framework
2. Implement UI and configuration
3. Create testing framework
4. Class-specific implementations

## API Integration Points (🟢 Completed)

- `buff_manager` - Track debuffs, mitigation effects, etc.
- `health_prediction` - Anticipate health changes and damage intake
- `wigs_tracker` - Integration with BigWigs/LittleWigs
- `combat_forecast` - Enhanced with custom TTD module 
- `unit_helper` - Identify unit roles and states
- `spell_helper` - Check spell castability and range
- `movement_handler` - Optimize positioning
- `geometry` components - Spatial calculations for positioning
