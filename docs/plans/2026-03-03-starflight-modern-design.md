# Starflight Modern: Full Design Document

## 1. Overview

**sf2k** is a modern update to Starflight (1986), built in Godot 4.4. It is a
persistent campaign game (20-50 hours) centered on exploration, diplomacy, and
an optional central mystery. The player commands a starship, explores a
procedurally generated galaxy, befriends or antagonizes alien factions, trades,
collects resources, and upgrades their ship and crew.

The game should be welcoming to players who want to fly around and make friends
with aliens. There is no mode toggle between "casual" and "story" -- the main
plot is available but never forced.

## 2. Core Design Pillars

1. **Exploration first** -- The galaxy is the primary content. Discovery is
   intrinsically rewarding.
2. **Diplomacy over combat** -- Combat exists as a fallback, but diplomacy is
   the primary interaction mode with alien species.
3. **Persistent world** -- Every action matters. Alliances, grudges, debts, and
   discoveries persist across the entire campaign.
4. **Organic progression** -- No artificial level gates. Fuel range naturally
   limits how far the player can go. Better fuel = bigger galaxy.
5. **Low-stress failure** -- No permadeath. Ship destruction means rescue, repair
   debt, and a trip home. The player is never stuck.

## 3. Campaign Structure

### 3.1 New Game
- Player names their ship and captain
- Galaxy is generated from a seed (shown to the player for sharing)
- Player starts at Starbase Alpha in a known-safe system
- Initial ship has basic modules, minimal fuel, small cargo hold
- Tutorial is contextual (tips appear on first encounter with new mechanics)

### 3.2 Progression Arc
1. **Early game**: Explore nearby systems, learn basic trading, meet first alien
   species, earn credits for upgrades
2. **Mid game**: Fuel upgrades open distant regions, faction relationships
   develop, central mystery clues emerge
3. **Late game**: Full galaxy access, deep faction politics, mystery resolution
   (optional)
4. **Post-game**: Continue exploring, complete faction quests, find all species

### 3.3 Victory Conditions
- **Primary**: Solve the central mystery (TBD)
- **Secondary**: Achieve maximum diplomatic standing with all factions
- **Freeform**: No explicit end -- player decides when they're done

## 4. Galaxy Generation

### 4.1 Structure
- 200 star systems (adjustable)
- Roughly disk-shaped distribution with slight vertical spread
- Star types follow astronomical classification (O, B, A, F, G, K, M)
- Each star has 0-8 planets depending on type
- ~10% of systems have starbases (higher density near center)

### 4.2 Determinism
- All generation is seeded from a single galaxy seed
- Star positions, types, names: `hash(galaxy_seed, system_index)`
- Planet properties: `hash(galaxy_seed, system_index, planet_index)`
- Surface terrain: `hash(galaxy_seed, system_index, planet_index)` fed to noise
- Same seed always produces same galaxy

### 4.3 Star System Contents
Each system contains:
- A star (type determines color, luminosity, habitability)
- 0-N planets (each with type, gravity, temperature, atmosphere, resources)
- Optional starbase (trading, refueling, repairs, crew hiring)
- Optional anomalies (derelicts, artifacts, signals -- later phases)

## 5. Space Navigation

### 5.1 Movement Model
- Player selects destination system from star map or 3D view
- Ship travels in straight line at constant speed
- Fuel consumed proportional to distance
- Travel is real-time with time acceleration option (later)

### 5.2 Fuel
- Fuel is the primary resource constraint
- Starting fuel allows ~5-8 system jumps
- Fuel can be: purchased at starbases, refined from deuterium, found as fuel cells
- Running out of fuel strands the player (distress beacon mechanic -- later)

### 5.3 Floating Origin
- Galaxy coordinates can be very large
- Ship position is rebased when it exceeds a threshold from the origin
- All visible objects shift to maintain relative positions
- Player never notices the rebasing

## 6. Planet Exploration

### 6.1 Landing
- Approach planet in star system view
- Landing screen shows planet stats (type, gravity, temperature, hazards)
- Player chooses to land or abort
- Gas giants and extreme environments may be unlandable

### 6.2 Surface
- 2D top-down tile map generated from planet seed
- Terrain types vary by planet type (ice, volcanic, temperate, etc.)
- Map size: 64x64 tiles (expandable)
- Landing zone is cleared area near map center

### 6.3 Rover
- Player controls a rover with WASD/arrow movement
- Rover has hull integrity (damaged by hazards)
- Scanner reveals nearby resources
- Interact key collects resources at rover position
- Resources added to ship cargo

### 6.4 Hazards
- Environmental hazards drain rover hull over time
- Types: radiation, cold, heat, toxic gas, acid
- Severity varies by planet type
- Hull depletion triggers emergency lift-off (no death)

### 6.5 Resources
- 15 resource types across categories: mineral, volatile, fuel, precious, exotic, biological
- Each has base value, weight, and rarity
- Resources spawn based on planet type's common_resources list
- Endurium is the rarest and most valuable (nod to original Starflight)

## 7. Economy

### 7.1 Trading
- Starbases buy and sell resources
- Prices vary by system type (buy low at source, sell high elsewhere)
- Credits used for: fuel, repairs, ship modules, crew hiring

### 7.2 Ship Modules (Phase 2)
- Engine (fuel efficiency + speed)
- Cargo hold (capacity)
- Scanner (range + detail)
- Shields (combat + hazard resistance)
- Weapons (combat -- fallback only)
- Comms (diplomacy bonuses)

### 7.3 Debt
- Ship destruction incurs rescue debt
- Debt accrues interest (gentle)
- Can be paid off at any starbase
- High debt locks some services (no new modules until debt < threshold)

## 8. Factions (Phase 2+)

### 8.1 Species
- 8+ alien species, each with unique:
  - Appearance and culture
  - Communication style
  - Preferred trade goods
  - Diplomatic priorities
  - Territory in the galaxy

### 8.2 Language Learning
- Initial contact: alien speech is garbled/symbolic
- Repeated interaction gradually reveals meaning
- Crew linguistics skill accelerates learning
- Full communication unlocks deeper dialogue options

### 8.3 Diplomacy
- Standing with each faction: hostile -> neutral -> friendly -> allied
- Actions affect standing: trading, gifts, completing requests, combat
- Piracy (stealing cargo) severely damages standing
- Some factions are allied/opposed to each other (political web)

## 9. Crew (Phase 2+)

### 9.1 Structure
- Ship has crew slots (captain + specialists)
- Each crew member has: name, species, skills, personality
- Skills: piloting, engineering, science, linguistics, combat, medicine
- Crew can be hired at starbases

### 9.2 Emotional Investment
- Crew members comment on events
- Relationships develop over time
- Crew members have personal quests (later)
- Losing a crew member to hazards is impactful (but recoverable)

## 10. Combat (Phase 2+)

### 10.1 Philosophy
- Combat is a failure of diplomacy, not the primary interaction
- Player should always have a non-combat path
- Piracy is viable but closes diplomatic doors

### 10.2 Mechanics (TBD)
- Ship-to-ship in space
- Simple tactical model (position, shields, weapons)
- Crew skills affect combat performance
- Retreat is always an option

## 11. Save System

### 11.1 Slots
- 10 named save slots
- Auto-save slot (triggered at starbases and on system arrival)
- Save stores complete game state

### 11.2 Serialization
- JSON format for readability and debuggability
- Version field for future migration
- Stores: galaxy seed, all player state, all galaxy mutations
  (discovered systems, depleted resources, faction standings, etc.)

## 12. Technical Architecture

### 12.1 Scene Structure
- Main scene manages mode switching (space / planet / starbase / menu)
- Each mode is a separate scene, instantiated/freed on transition
- Transitions use fade-to-black animation
- HUD persists across modes via CanvasLayer

### 12.2 Autoload Singletons
- **GameState**: All persistent game data
- **SaveManager**: Save/load operations

### 12.3 Data-Driven Design
- Game content defined in JSON (star types, planet types, resources)
- Easy to add new content without code changes
- All procedural generation reads from data files

### 12.4 Coordinate Systems
- Galaxy: 3D Vector3 (floating origin, units ~ light-years)
- Planet surface: 2D Vector2i tiles (16px per tile)
- Screen: handled by Godot's viewport system

## 13. Milestone Plan

### Milestone 1: Fly + Land (Current)
- Fly between stars in 3D space
- Land on procedurally generated 2D planet
- Explore with rover, collect resources
- Return to ship
- Save/load

### Milestone 2: Economy + Starbases
- Starbases with trading
- Fuel purchasing
- Ship module upgrades
- Debt system

### Milestone 3: Factions + Diplomacy
- First 3 alien species
- Basic dialogue system
- Faction standing
- Language learning mechanic

### Milestone 4: Full Galaxy
- All 8+ species
- Faction politics
- Central mystery introduction
- Combat system

### Milestone 5: Polish + Content
- Sound design
- Music
- Final pixel art
- Balance tuning
- QA + bug fixing

## 14. Platform Targets

- **Primary**: macOS (development platform)
- **Secondary**: Linux, Windows
- **Stretch**: Web export (Godot supports it)

## 15. Open Questions

- Central mystery theme and structure
- Exact combat mechanics
- Crew personality system depth
- Music style and approach
- Multiplayer considerations (probably not, but worth documenting)
