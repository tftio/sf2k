# sf2k - CLAUDE.md

## Project Overview

sf2k is a modern update to Starflight (1986) built in Godot 4.4. Persistent
campaign game (20-50 hours) focused on exploration, diplomacy, and a central
cosmic mystery. The player explores a seeded galaxy, befriends or antagonizes
alien factions, trades, and collects resources.

## Engine & Language

- **Engine**: Godot 4.4
- **Language**: GDScript (static typing required)
- **Scene format**: .tscn (text-based)

## Architecture

### Autoload Singletons
- `GameState` (scripts/autoload/game_state.gd) - Global state: galaxy seed, fuel,
  location, mode, discoveries, cargo, credits, debt
- `SaveManager` (scripts/autoload/save_manager.gd) - Save/load with multiple slots

### Scene Modes
The game has distinct modes managed by the main scene:
- **Space**: 3D scene with starfield, ship navigation between star systems
- **Planet**: 2D tile-based surface exploration with rover
- **Starbase**: (future) Docking, trading, crew management
- **Menu**: Title screen, save/load

### Data-Driven Design
Game content is defined in JSON files under `data/`:
- `star_types.json` - Star classifications and properties
- `planet_types.json` - Planet biome/type definitions
- `resources.json` - Mineable resource definitions

All procedural generation is seeded from the galaxy seed. A planet's terrain is
deterministic from the tuple (galaxy_seed, star_index, planet_index).

## Coding Conventions

### GDScript Style
- Use static typing on all variables and function signatures
- Use snake_case for variables and functions
- Use PascalCase for class names and node names
- Prefix private members with underscore: `var _internal_state: int`
- Prefer signals over direct node references for decoupling
- Use `@export` for editor-configurable properties
- Use `@onready` for node references obtained at ready time

### Scene Organization
- Each scene has a corresponding script in `scripts/`
- Scene files (.tscn) live under `scenes/` mirroring the script structure
- Placeholder assets live under `assets/`

### Comments
- Comment the "why", not the "what"
- Add section headers for long scripts: `## Section Name`
- Document signal purposes and exported variable intent

## File Structure

```
scenes/          - Godot scene files (.tscn)
scripts/         - GDScript files (.gd)
  autoload/      - Singleton scripts
  space/         - 3D space navigation
  planet/        - 2D planet surface
  ui/            - HUD and menus
data/            - JSON game data
assets/          - Sprites, fonts, audio
  sprites/       - Pixel art
  fonts/         - Bitmap/pixel fonts
  audio/         - Sound effects
tests/           - gdUnit4 test files
docs/plans/      - Design documents
```

## Key Design Decisions

- **No permadeath**: Ship rescue + debt on destruction
- **Fuel gates progression**: No artificial barriers, fuel range limits exploration
- **Diplomacy first**: Combat exists but diplomacy is primary interaction
- **Seeded galaxy**: Entire galaxy generated deterministically from one seed
- **Pixel art in 3D**: Ship and objects are billboard sprites in 3D starfield

## Testing

Uses gdUnit4 for unit tests. Test files go in `tests/` directory.

## Platform

Primary target: macOS. Linux/Windows planned for later.
