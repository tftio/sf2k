# sf2k -- Wormhole Universe Implementation Plan

Implementation plan for the wormhole-based FTL system, starbases, surface
content, crew, combat, threat escalation, and wormhole construction.

Derived from the Wormhole Universe Design document. Each task is scoped to a
single commit or tight group of related changes.

---

## Phase 1: Wormhole Network Generation

The network generator is the foundation -- all later phases depend on it.

### Task 1.1: Create `scripts/space/wormhole_network.gd`

New static class `WormholeNetwork` (class_name) with a single public method:

```gdscript
static func generate(galaxy_seed: int, systems: Array[StarSystemData]) -> Dictionary
```

**Algorithm:**

1. Cluster 200 systems spatially using a simple k-means variant (k=12, seeded
   RNG, ~15 iterations). Each system gets a `cluster_id`.
2. Select junction systems: for each cluster, pick the system closest to the
   cluster centroid. Bias toward larger clusters getting a junction. Target
   10-15 junctions total.
3. Build minimum spanning tree of junction systems (edge weight = Euclidean
   distance between system positions).
4. Add 2-4 extra edges: iterate non-MST edges by ascending weight, add if
   neither endpoint already has 4 connections. Stop after 2-4 additions
   (seeded random count).
5. Return dictionary:

```gdscript
{
    "junctions": Array[int],           # system indices that are junctions
    "connections": Array[Array],       # each element: [from_idx, to_idx]
    "cluster_assignments": Array[int], # cluster_id per system index
}
```

**Constraints:**
- Deterministic from `galaxy_seed` (use `RandomNumberGenerator` with derived seed)
- No system is in more than one cluster
- Every junction connects to at least 1 other junction (MST guarantees this)
- Junction count between 10 and 15 inclusive

**Verification:**
- Write a gdUnit4 test in `tests/test_wormhole_network.gd`:
  - Same seed produces same output across multiple calls
  - Junction count in [10, 15]
  - All junctions are reachable from any other junction (BFS/DFS on the graph)
  - No junction has more than 4 connections
  - Different seeds produce different networks

### Task 1.2: Add junction fields to `StarSystemData`

Add two new fields to `StarSystemData`:

```gdscript
var has_junction: bool = false
var junction_connections: Array[int] = []  # indices of connected junction systems
```

These are NOT set during `generate()` -- they are populated after
`WormholeNetwork.generate()` runs, by the caller (space_controller or
game_state).

### Task 1.3: Add wormhole state to `GameState`

Add new state variables:

```gdscript
## Set of discovered junction system indices.
var discovered_junctions: Dictionary = {}  # system_index -> true
## Collected precursor artifact IDs.
var precursor_artifacts: Array[String] = []
## Player-constructed wormhole connections: Array of [from_idx, to_idx].
var constructed_connections: Array[Array] = []
## Cached wormhole network data (generated once per game).
var wormhole_network: Dictionary = {}
```

Add new signals:

```gdscript
signal junction_discovered(system_index: int)
signal artifact_found(artifact_id: String)
signal wormhole_constructed(from_index: int, to_index: int)
```

Add methods:

```gdscript
func discover_junction(system_index: int) -> void
func add_artifact(artifact_id: String) -> void
func construct_wormhole(from_index: int, to_index: int) -> void
```

Extend `new_game()`: after setting seed, generate wormhole network:

```gdscript
var systems: Array[StarSystemData] = []
for i in range(GALAXY_SIZE):
    systems.append(StarSystemData.generate(galaxy_seed, i))
wormhole_network = WormholeNetwork.generate(galaxy_seed, systems)
# Populate junction flags on StarSystemData instances
for idx: int in wormhole_network.get("junctions", []):
    systems[idx].has_junction = true
    # ... populate junction_connections from connections array
```

Note: this means `GameState` needs to hold or regenerate the `StarSystemData`
array. Currently `space_controller.gd` generates it locally. Decide: either
move generation into `GameState` (cleaner) or pass systems into `new_game()`.
Recommendation: move generation into `GameState` so all state lives in one
place. Add `var star_systems: Array[StarSystemData] = []` to GameState, generate
in `new_game()`, and have `space_controller` read from `GameState.star_systems`.

Extend `serialize()` to include:

```gdscript
"discovered_junctions": discovered_junctions.keys(),
"precursor_artifacts": precursor_artifacts.duplicate(),
"constructed_connections": constructed_connections.duplicate(),
```

Extend `deserialize()` to restore these. The wormhole network itself does NOT
need serializing -- it is regenerated deterministically from `galaxy_seed`.
After deserialize, call `WormholeNetwork.generate()` again and repopulate
`StarSystemData` junction fields.

**Verification:**
- Save/load round-trip preserves discovered junctions, artifacts, constructed
  connections
- After deserialize, `wormhole_network` matches pre-save state

### Task 1.4: Update `space_controller.gd` to use `GameState.star_systems`

Remove `_generate_galaxy()` and `_star_systems` from `space_controller.gd`.
Replace with reads from `GameState.star_systems`.

- `_ready()`: use `GameState.star_systems` instead of generating locally
- `_spawn_system_nodes()`: iterate `GameState.star_systems`
- `get_all_systems()`: return `GameState.star_systems`
- All other methods that reference `_star_systems` -> `GameState.star_systems`

**Verification:**
- Game still starts, galaxy renders, travel works as before
- Star map still loads system data correctly

---

## Phase 2: Junction Interaction & Transit

### Task 2.1: Render junction structures in space

In `space_controller.gd`, after spawning star nodes, add visual indicators for
junction systems:

- For each system where `has_junction == true`, add a child mesh (torus or ring)
  around the star node, with a distinct material (e.g., cyan unshaded glow).
- Junction ring is only visible if the junction is discovered OR the player is
  within a discovery range (e.g., 20 units).

### Task 2.2: Junction discovery on proximity

In `space_controller.gd._process_travel()` or `_on_arrived_at_system()`:

- When player arrives at a junction system, check if junction is undiscovered
- If undiscovered: call `GameState.discover_junction(system_index)`
- Junction ring becomes permanently visible on the star
- Star map also updates (Phase 3)

### Task 2.3: Create junction menu scene

**New files:**
- `scenes/ui/junction_menu.tscn`
- `scripts/ui/junction_menu_controller.gd`

The junction menu appears when the player interacts with a discovered junction
(e.g., pressing `interact` when near the junction structure, or clicking it).

UI: panel listing connected junction system names + indices. Each is a button.
Clicking a destination initiates wormhole transit.

Signal: `destination_selected(target_system_index: int)`

### Task 2.4: Wormhole transit mechanic

In `space_controller.gd` (or `main_controller.gd`):

When the junction menu emits `destination_selected`:

1. Use `ModeSwitchController.transition_out()` (fade to black)
2. Update `GameState.current_system_index` to destination
3. Update `GameState.ship_position` to destination system position
4. Reposition ship node
5. Discover destination system and junction
6. Use `ModeSwitchController.transition_in()` (fade from black)
7. No fuel cost

**Verification:**
- Travel to a junction system, junction ring appears
- Open junction menu, see connected destinations (only discovered ones? or all
  once you find the junction?)
  - Design decision: seeing a junction reveals ALL its connections on the star
    map, even if destinations are unexplored. You know WHERE the wormhole goes
    but not WHAT is there.
- Select destination, fade transition, arrive at new system, no fuel consumed
- Discovery fires for new junction and system
- Save/load preserves discovered junctions

---

## Phase 3: Star Map Network Overlay

### Task 3.1: Draw wormhole connections on star map

Modify `star_map_controller.gd._draw()`:

After drawing star dots, draw wormhole connection lines:
- For each connection in `GameState.wormhole_network["connections"]`:
  - If BOTH endpoints are in `GameState.discovered_junctions`: draw a colored
    line (e.g., cyan, dashed or glowing) between the two systems' screen
    positions using `draw_line()`.
  - If only one endpoint is discovered: optionally draw a faded/dotted line
    extending from the discovered junction in the direction of the undiscovered
    one (showing "there's something out there").

### Task 3.2: Distinguish junction systems visually

In `star_map_controller.gd._draw()`:

- For discovered junction systems, draw an additional ring or diamond shape
  around the star dot (distinct from the "current system" highlight).
- Use a consistent junction color (cyan/teal).

### Task 3.3: Show constructed connections

Player-constructed wormholes from `GameState.constructed_connections` draw with
a different style (e.g., green dashed line) to distinguish from precursor
network.

**Verification:**
- Open star map, discovered junctions show special icon
- Connection lines drawn between discovered junction pairs
- Undiscovered junctions remain hidden
- Constructed connections (once Phase 9 is implemented) show differently
- Zoom and pan work correctly with the new overlay

---

## Phase 4: Surface Content Expansion

### Task 4.1: Create `data/precursor_artifacts.json`

Data file defining artifact types:

```json
{
  "artifacts": [
    {
      "id": "schematic_fragment_alpha",
      "name": "Schematic Fragment (Alpha)",
      "description": "Partial wormhole construction schematic. Shows junction field geometry.",
      "rarity": 0.3,
      "progression_weight": 1,
      "category": "schematic"
    },
    {
      "id": "material_analysis_report",
      "name": "Material Analysis Report",
      "description": "Precursor analysis of Endurium's crystalline lattice properties.",
      "rarity": 0.25,
      "progression_weight": 1,
      "category": "analysis"
    },
    {
      "id": "astronomical_record",
      "name": "Astronomical Record",
      "description": "Star chart fragment showing systems not in the current network.",
      "rarity": 0.2,
      "progression_weight": 2,
      "category": "record"
    },
    {
      "id": "junction_calibration_data",
      "name": "Junction Calibration Data",
      "description": "Technical data on how junction endpoints are stabilized.",
      "rarity": 0.15,
      "progression_weight": 2,
      "category": "schematic"
    },
    {
      "id": "precursor_log_entry",
      "name": "Precursor Log Entry",
      "description": "Fragmentary text in an unknown language. Partially translatable.",
      "rarity": 0.35,
      "progression_weight": 1,
      "category": "lore"
    },
    {
      "id": "endurium_resonance_key",
      "name": "Endurium Resonance Key",
      "description": "Device that demonstrates Endurium's role in junction stabilization.",
      "rarity": 0.1,
      "progression_weight": 3,
      "category": "schematic"
    }
  ]
}
```

Categories: `schematic` (wormhole construction knowledge), `analysis` (material
science), `record` (navigation/mapping), `lore` (narrative/worldbuilding).

`progression_weight`: how much this artifact contributes toward the construction
knowledge threshold.

### Task 4.2: Add ruin/anomaly tiles to surface generator

Add new terrain tile entries to `surface_generator.gd.TERRAIN_TILES`:

```gdscript
"ruin_floor": Vector2i(0, 6),
"ruin_wall": Vector2i(1, 6),
"ruin_debris": Vector2i(2, 6),
"anomaly_glow": Vector2i(3, 6),
```

These will need corresponding tiles in the tileset atlas (row 6). For now,
placeholders are acceptable.

### Task 4.3: Generate precursor ruins on planet surfaces

Modify `surface_generator.gd.generate_surface()`:

After resource placement, add ruin generation:

1. Check if this planet's star system is a junction system OR is within
   the same cluster as a junction system. Use
   `GameState.wormhole_network["cluster_assignments"]` to determine cluster
   membership, and `GameState.wormhole_network["junctions"]` for junction status.
2. Calculate ruin density: junction systems get 2-3 ruin sites, same-cluster
   systems get 0-1. Systems in non-junction clusters get 0.
3. Each ruin site is a small rectangle (3x5 to 5x7 tiles) of `ruin_floor` with
   `ruin_wall` borders and `ruin_debris` scattered inside.
4. Place 1-2 artifact nodes within each ruin site (same structure as
   resource_nodes but with `"type": "artifact"` and `"artifact_id": "..."`).
5. Store artifact nodes in a new array: `var artifact_nodes: Array[Dictionary]`

### Task 4.4: Generate anomalies on planet surfaces

After ruin generation:

1. Scatter anomaly tiles (`anomaly_glow`) at random positions -- 0-3 per planet
   depending on a seeded roll weighted by system properties.
2. Each anomaly tile has a chance to contain an artifact (50%) or be purely
   cosmetic/lore.
3. Anomaly artifacts use the same `artifact_nodes` array.

### Task 4.5: Artifact collection in rover controller

Modify `rover_controller.gd`:

- Add signal: `signal artifact_collected(artifact_id: String)`
- In `_try_collect_resource()`, also check `surface_generator.artifact_nodes`
  for artifact-type collectibles at the rover's position.
- When an artifact is collected:
  - Call `GameState.add_artifact(artifact_id)`
  - Emit `artifact_collected` signal
  - Mark the artifact node as collected
- Artifacts do NOT go into cargo -- they go into `GameState.precursor_artifacts`

**Verification:**
- Land on a planet near a junction system, ruin tiles appear on the surface
- Scan near ruins to detect artifacts
- Collect artifact with interact key, appears in `GameState.precursor_artifacts`
- Artifacts persist through save/load
- Non-junction-cluster planets have no ruins

---

## Phase 5: Starbases

### Task 5.1: Create starbase scene and controller

**New files:**
- `scenes/starbase/starbase.tscn`
- `scripts/starbase/starbase_controller.gd`

The starbase is a UI-heavy mode (like a menu). Layout:

- Top bar: starbase name, faction affiliation
- Tab buttons: Trade | Crew | Upgrades | News
- Main content area changes per tab
- "Depart" button to return to space

Start with Trade tab only. Other tabs are stubs that display "Coming soon."

### Task 5.2: Trade system

In `starbase_controller.gd`:

- Load `data/resources.json` for resource definitions
- Display player cargo on the left, starbase inventory on the right
- Buy/sell buttons with quantity controls
- Prices vary by a multiplier per starbase (seeded from system index):
  - `sell_price = base_value * sell_multiplier` (player sells to starbase)
  - `buy_price = base_value * buy_multiplier` (player buys from starbase)
  - Multipliers range [0.5, 2.0], seeded per system per resource

### Task 5.3: Fuel purchase at starbases

Add fuel purchase option to the trade tab (or a dedicated "Refuel" button):

- Fuel costs credits (e.g., 2 credits per fuel unit)
- Top-up to `GameState.max_fuel`

### Task 5.4: Starbase locations at junctions

Starbases exist at junction systems (replace or supplement the existing
`has_starbase` random flag on `StarSystemData`):

- Every junction system has a starbase
- Non-junction starbases may still exist (keep existing random generation)
- Junction starbases are labeled differently (e.g., "Junction Starbase" vs
  "Outpost")

Modify `main_controller.gd` to support switching to starbase mode:

- When player is at a system with a starbase and presses a "dock" key (or
  clicks the starbase), trigger `_switch_to_starbase(system_index)`
- Use `ModeSwitchController` fade transitions
- On depart, return to space mode

### Task 5.5: Create `data/factions.json` (stub)

Minimal faction definitions for starbase flavor:

```json
{
  "factions": [
    {
      "id": "human_federation",
      "name": "Terran Federation",
      "description": "Humanity's primary governing body in connected space.",
      "color": "#4488ff"
    },
    {
      "id": "neutral_trade",
      "name": "Free Trade Consortium",
      "description": "Independent merchants and traders operating across faction lines.",
      "color": "#88ff88"
    }
  ]
}
```

Each starbase gets a faction assignment (seeded). Full alien factions come in
Phase 6.

**Verification:**
- Dock at a junction starbase, starbase UI appears
- Trade tab shows resources, buy/sell works, credits update
- Refuel works
- Depart returns to space
- Non-junction starbases also accessible
- Save/load preserves credits/cargo after trading

---

## Phase 6: Crew System

### Task 6.1: Create crew data structures

**New file: `scripts/crew/crew_member.gd`**

```gdscript
extends RefCounted
class_name CrewMember

var crew_id: String = ""
var crew_name: String = ""
var species: String = "human"
var role: String = ""  # pilot, science, engineer, comms, security
var skills: Dictionary = {}  # skill_id -> int (1-10)
var loyalty: float = 75.0  # 0-100
var personality: String = ""  # cautious, bold, pragmatic, idealist, etc.
var motivations: Array[String] = []  # what they care about
```

Skills per role:
- Pilot: navigation, evasion, fuel_efficiency
- Science: scanning, artifact_analysis, research
- Engineer: repair, maintenance, construction
- Comms: diplomacy, trade, signal_interpretation
- Security: combat, hazard_survival, boarding_defense

### Task 6.2: Create `data/crew_templates.json`

Starting crew and recruitable crew at starbases:

```json
{
  "starting_crew": [
    {
      "crew_id": "chen_pilot",
      "crew_name": "Chen Ayumi",
      "species": "human",
      "role": "pilot",
      "skills": {"navigation": 5, "evasion": 4, "fuel_efficiency": 6},
      "loyalty": 80,
      "personality": "cautious",
      "motivations": ["survival", "exploration"]
    }
  ],
  "recruitable_crew": [...]
}
```

Provide 5 starting crew (one per role) and 8-10 recruitable crew across
different starbases.

### Task 6.3: Add crew state to `GameState`

```gdscript
var crew: Array[CrewMember] = []
```

Add to `serialize()` / `deserialize()`. Each `CrewMember` needs its own
`serialize()` / `deserialize()` pair.

Crew members are loaded from templates at game start via `new_game()`.

### Task 6.4: Crew effects on game systems

Wire crew skills into existing systems:

- **Pilot** `fuel_efficiency` skill modifies `FUEL_COST_PER_UNIT`:
  `effective_cost = FUEL_COST_PER_UNIT * (1.0 - pilot.skills.fuel_efficiency * 0.05)`
- **Science** `scanning` skill modifies `rover_controller.scan_radius`:
  `effective_radius = base_radius + science.skills.scanning`
- **Engineer** `repair` skill: passive hull recovery per second on planet surface
- **Comms** `trade` skill modifies starbase buy/sell multipliers in player's favor
- **Security** `hazard_survival` skill reduces hazard damage rate

### Task 6.5: Crew loyalty and departure

In `GameState`, track player actions that affect loyalty:

- Piracy (raiding ships/starbases): all crew loyalty -10, security crew -5
- Gifting resources to factions: aligned crew loyalty +5
- Running out of fuel (stranding): all crew loyalty -15
- Discovering new systems: all crew loyalty +2

When loyalty drops below 25: crew member departs at next starbase visit.
When loyalty drops below 10 AND security crew loyalty is also low: mutiny event
(crew refuses orders until resolved at starbase).

### Task 6.6: Crew recruitment at starbases

Add "Crew" tab to starbase UI:

- Show current crew roster with stats
- Show available recruits at this starbase (filtered by faction)
- Hire/fire interface
- Hiring costs credits
- Fired crew return to their home starbase's pool

**Verification:**
- New game starts with 5 crew members
- Crew skills affect scanning radius, fuel cost, trade prices
- Loyalty changes in response to player actions
- Crew departs when loyalty is low and player docks at starbase
- Recruit new crew at starbases
- Save/load preserves full crew state

---

## Phase 7: Combat / Encounter System

### Task 7.1: Create encounter data structures

**New file: `scripts/encounters/encounter.gd`**

Encounters are dialogue-first interactions with NPC ships:

```gdscript
extends RefCounted
class_name Encounter

enum Type { PATROL, TRADER, PIRATE, ALIEN_CONTACT, THREAT_SCOUT }
enum Resolution { PEACEFUL, TRADE, FLEE, COMBAT, SURRENDER }

var encounter_type: Type
var faction_id: String
var dialogue_options: Array[Dictionary]  # {text, requires_skill, outcome}
var ship_strength: int  # relative to player
```

### Task 7.2: Encounter trigger system

**New file: `scripts/encounters/encounter_controller.gd`**

- Encounters trigger on system arrival (random chance, seeded)
- Higher chance near faction borders, trade routes, and threatened junctions
- Controller presents dialogue UI with options
- Options filtered by crew skills (comms officer enables diplomacy options,
  security officer enables intimidation)

### Task 7.3: Combat resolution

When dialogue leads to combat:

- Simple stat comparison: player ship strength + crew bonuses vs. encounter
  ship strength
- Crew roles contribute:
  - Security: direct combat bonus
  - Pilot: evasion (chance to flee mid-combat)
  - Engineer: damage control (reduce damage taken)
- Outcomes: victory (loot), defeat (damage + cargo loss), flee (fuel cost +
  minor damage)
- All outcomes cost something: hull damage, fuel, crew injuries

### Task 7.4: Encounter UI

**New files:**
- `scenes/ui/encounter_dialog.tscn`
- `scripts/ui/encounter_dialog_controller.gd`

Modal dialog that appears during encounters:
- NPC ship description and faction
- Dialogue text
- Response options (2-4 buttons)
- If combat: simple progress bar / outcome display

**Verification:**
- Arrive at systems, encounters trigger sometimes
- Dialogue options appear, crew skills gate some options
- Peaceful resolution costs nothing
- Combat costs hull damage and possibly cargo
- Flee costs fuel
- Encounter outcomes affect faction standings

---

## Phase 8: Threat Escalation

### Task 8.1: Create threat controller

**New file: `scripts/space/threat_controller.gd`**

Global threat system:

```gdscript
var global_threat_level: int = 0  # 0-10, increases over game time
var junction_threat: Dictionary = {}  # junction_index -> threat_level (0-3)
```

- `global_threat_level` increases by 1 each time the player uses a wormhole
  junction N times (e.g., every 5th transit increases by 1)
- Also increases based on game progression (artifact count milestones)

### Task 8.2: Threat escalation events

Per-junction threat escalation:

- **Level 0**: Normal
- **Level 1**: Anomalous readings at junction (cosmetic -- strange visual
  effects on the junction ring, warning text)
- **Level 2**: Hostile encounters at junction (encounter_controller triggers
  threat-type encounters when transiting)
- **Level 3**: Junction lost -- junction becomes non-functional, starbase
  destroyed. Must be reclaimed (late game mechanic) or routed around.

Threat level increases at specific junctions based on global_threat_level and
seeded randomness. Farthest junctions from the player's start get threatened
first.

### Task 8.3: Visual and audio cues

- Junction rings change color based on threat level (cyan -> yellow -> red ->
  dark/destroyed)
- Star map shows threat level on junction icons
- Warning messages in starbase news tabs

### Task 8.4: Add threat state to GameState

```gdscript
var global_threat_level: int = 0
var junction_threat: Dictionary = {}
var threat_transit_count: int = 0  # counts junction uses
```

Add to serialize/deserialize.

**Verification:**
- Threat level increases with junction usage
- Junction visuals change with threat level
- Threat encounters trigger at threatened junctions
- Level 3 junctions become non-functional
- Star map reflects threat state
- Save/load preserves threat state

---

## Phase 9: Wormhole Construction (Late Game)

### Task 9.1: Knowledge threshold system

In `GameState`:

```gdscript
func get_construction_knowledge() -> int:
    var total: int = 0
    # Load artifact data, sum progression_weight for collected artifacts
    for artifact_id: String in precursor_artifacts:
        total += _get_artifact_progression_weight(artifact_id)
    return total

const CONSTRUCTION_KNOWLEDGE_THRESHOLD: int = 15  # tunable

func can_construct_wormhole() -> bool:
    return get_construction_knowledge() >= CONSTRUCTION_KNOWLEDGE_THRESHOLD
```

### Task 9.2: Endurium cost for construction

Each wormhole construction costs Endurium from cargo:

```gdscript
const WORMHOLE_ENDURIUM_COST: int = 10  # units of Endurium per construction
const MAX_CONSTRUCTED_WORMHOLES: int = 5
```

### Task 9.3: Construction UI

Add construction option to star map (when knowledge threshold met):

1. Player opens star map
2. If `can_construct_wormhole()` and has enough Endurium in cargo:
   - "Construct Wormhole" button appears
   - Click enables a "select target system" mode
   - Player clicks a target system (must not already be a junction)
   - Confirmation dialog: "Construct wormhole from [current] to [target]?
     Cost: 10 Endurium"
   - On confirm: deduct Endurium, add to `constructed_connections`, new
     junction appears at both systems

### Task 9.4: Constructed wormhole functionality

Constructed wormholes work identically to precursor junctions:
- Both endpoints become junction systems
- Both get junction rings in 3D view
- Both appear on star map with green connection line
- Transit is free
- They are NOT affected by the threat system (this is the strategic value)

**Verification:**
- Collect enough artifacts to meet threshold
- Have Endurium in cargo
- Construction option appears on star map
- Build wormhole, Endurium deducted
- New junction appears, traversable
- Connection shown on star map in distinct style
- Maximum 5 constructions enforced
- Save/load preserves constructed wormholes

---

## Implementation Order

Execute phases sequentially. Within each phase, execute tasks in order.

```
Phase 1 (foundation)  -- wormhole_network.gd, GameState changes, space_controller refactor
Phase 2 (interaction) -- junction rendering, discovery, menu, transit
Phase 3 (map)         -- star map overlay, junction visuals
Phase 4 (surface)     -- artifacts data, ruin generation, collection
Phase 5 (starbases)   -- starbase scene, trade, fuel, factions stub
Phase 6 (crew)        -- crew data, effects, loyalty, recruitment
Phase 7 (combat)      -- encounters, dialogue, combat resolution
Phase 8 (threat)      -- threat controller, escalation, visuals
Phase 9 (endgame)     -- knowledge system, construction UI, new junctions
```

After each phase, run all existing tests + new tests for that phase. Commit
per-task or per-phase depending on change size.
