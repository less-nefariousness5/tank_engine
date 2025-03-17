# Tank Engine

A comprehensive framework for optimal tank performance in World of Warcraft.

## Features

- **Threat Management**: Real-time threat tracking and targeting optimization
- **Defensive Optimization**: Smart cooldown usage based on incoming damage patterns
- **Active Mitigation Tracking**: Gap analysis and resource management for mitigation abilities
- **Interrupt Management**: Priority-based interrupt and crowd control handling
- **Pull Planning**: Optimization for dungeon routes and pull sizes
- **Survival Analytics**: Health tracking and emergency action planning
- **Resource Optimization**: Efficient resource generation and spending
- **BigWigs/LittleWigs Integration**: React to boss ability timers
- **Healer Performance Tracking**: Make informed decisions based on healer performance
- **Time-To-Death Calculation**: Accurate enemy TTD predictions

## Getting Started

1. Ensure the framework is installed in `PS/scripts/tank_engine`
2. Load the main script through your addon loader
3. Configure settings in the Tank Engine menu

## Module Structure

The Tank Engine is built with a modular architecture:

```
tank_engine/
├── core/               - Core framework components
├── modules/            - Individual engine modules
└── main.lua            - Main entry point
```

## Configuration

Each module has its own configuration section accessible through the Tank Engine menu. Important settings include:

- **Threat thresholds**: Warning and taunt thresholds for threat management
- **Defensive thresholds**: Health-based triggers for defensive cooldowns
- **Mitigation gaps**: Tolerance for gaps in active mitigation
- **TTD calculation**: Regression window and smoothing for accurate predictions

## API Integration

Tank Engine leverages multiple game APIs:

- Health prediction for incoming damage forecasting
- BigWigs/LittleWigs tracking for boss ability timing
- Combat forecast for encounter planning
- Spell and movement handling for optimal positioning

## Customization

The framework is designed to be extensible:

1. Edit module settings through the menu
2. Modify threshold values for your playstyle
3. Add class-specific implementations to the framework

## Technical Information

- Tank Engine uses linear regression for TTD calculations
- Healer performance tracking includes heal rate and type analysis
- Threat management includes multi-target optimization

## Requirements

- World of Warcraft (Current Version)
- Access to core API functions
- BigWigs/LittleWigs installed (for timer integration)
