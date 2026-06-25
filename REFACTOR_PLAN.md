# Refactor Plan: Simplicity, Extensibility, SOLID

The prototype has reached the right point for a structural pass. The current code is valuable because it proves the loop quickly, but most systems still live in `ArenaManager`: arena construction, spawn orchestration, match wiring, HUD, shot feedback, spring-trap contact rules, floor scoring, red bot behavior, and debug state.

The goal of this refactor is not to add architecture for its own sake. The goal is to preserve the fast prototype loop while making the next features easier to add: better tuning, practice/debug modes, richer bots, reusable scenes, and eventual LAN/listen-server authority.

## Design Goals

1. Keep gameplay behavior unchanged during the refactor.
2. Move one responsibility at a time out of `ArenaManager`.
3. Prefer Godot nodes, scenes, resources, groups, and signals over large inheritance hierarchies.
4. Keep APIs small and testable.
5. Make rules explicit enough that multiplayer authority can later own them cleanly.
6. Keep automated scenario tests passing after each step.

## Current Pain Points

### `ArenaManager` Has Too Many Reasons To Change

`ArenaManager` currently changes when any of these change:

- Arena geometry and visual construction.
- Spawn positions and object creation.
- Match reset behavior.
- HUD labels and crosshair layout.
- Shot feedback visuals and lifetime fading.
- Spring trap cap detection and debounce rules.
- Ground-loss detection.
- Red keeper bot behavior.
- Debug serialization.

This violates the single responsibility principle and makes later features risky because unrelated edits land in the same large script.

### Tests Depend On Internals

`scripts/test_runner.gd` directly calls several private methods and reads many internal fields. That was fine for a prototype, but it will slow refactors because tests are coupled to implementation details instead of gameplay contracts.

Examples:

- `arena._dome_normal_at(...)`
- `arena._check_ball_floor_loss()`
- `arena._check_spring_trap_cap_contact(ball)`
- `weapon._resolve_shot(...)`
- `weapon._raycast_result(...)`

The refactor should introduce small public test/debug APIs where needed, then move tests over gradually.

### Runtime Scene Construction Is Useful But Overcentralized

Generating graybox nodes in code is still a good fit for the prototype. The problem is not runtime construction itself; the problem is that one script constructs every category of object. Builders/factories can keep the speed while making ownership clearer.

### Shot Resolution And Hit Effects Are Coupled

`WeaponController` is one of the cleaner scripts, but it currently handles ammo state, raycast resolution, ricochet logic, target normalization, and hit application. This will become crowded when adding networking, assist modes, replay/debug traces, or alternate weapons.

### Rule Ownership Is Blurry

Spring trap cap contact currently lives in `ArenaManager`, while the trap owns body-entered behavior and charge/trigger state. Floor scoring lives in `ArenaManager` and `MatchManager`. This works, but multiplayer will need clearer authority boundaries.

## Target Architecture

Use a shallow composition-based structure:

```text
Main
└── ArenaRoot / ArenaManager
    ├── ArenaGeometry
    ├── SpawnRegistry
    ├── MatchManager
    ├── RoundResetService
    ├── HUDController
    ├── ShotFeedbackController
    ├── BotController / KeeperBotController
    ├── SpringTrap
    ├── PlayerController x2
    └── TeamBall x2
```

`ArenaManager` should become a coordinator. It should wire dependencies, expose high-level lookup/debug helpers, and respond to major signals. It should not build every mesh, decide every rule, or update every UI label directly.

## Proposed Responsibilities

### `ArenaManager`

Owns high-level composition only.

Keep:

- Creating or instancing the top-level arena subsystems.
- Holding references to players, balls, trap, match manager, HUD, feedback, and bot.
- Connecting signals between subsystems.
- Providing public lookup helpers like `get_player(team_id)` and `get_ball(team_id)`.
- Providing `get_debug_state()` by aggregating subsystem debug state.

Move out:

- Mesh/collision construction.
- HUD label creation and text formatting.
- Shot feedback node creation and fading.
- Red bot movement/shooting logic.
- Spring trap cap-contact detection.
- Floor scoring details.

### `ArenaGeometry`

New node responsible for the physical and visual arena.

Owns:

- Floor body.
- Cylinder/frustum/top-cap collision.
- Arena shape guide rings.
- Lighting and overview camera only if keeping the arena self-contained.
- Geometry helper methods such as normal calculation and cap/frustum containment checks.

Public API:

- `setup(config: ArenaConfig) -> void`
- `get_frustum_incline_degrees() -> float`
- `get_surface_normal_at(point: Vector3) -> Vector3`
- `is_point_on_cap(point: Vector3, tolerance: float = 0.0) -> bool`
- `is_point_on_frustum_band(point: Vector3, tolerance: float = 0.0) -> bool`
- `get_overview_camera() -> Camera3D`

SOLID gain:

- Single responsibility: arena geometry changes no longer touch match/HUD/bot code.
- Open/closed: alternate arenas can be added by swapping geometry nodes or configs.

### `ArenaConfig`

New `Resource` or `RefCounted` data object for arena dimensions and spawn positions.

Owns values currently exported on `ArenaManager`:

- Arena radius, height, cone/frustum settings, floor height, loss height.
- Player and ball spawns.
- Shot feedback timing only if feedback remains arena-specific; otherwise move those to `ShotFeedbackConfig`.
- Bot tuning only if bot remains arena-specific; otherwise move to `BotConfig`.

Recommended first pass: use `Resource` if values should be editable in the inspector later. Use `RefCounted` only if this stays fully code-driven for now.

SOLID gain:

- Dependency inversion: systems depend on a small config object instead of reaching into `ArenaManager` fields.
- Interface segregation: each subsystem can receive only the values it needs.

### `SpawnRegistry`

New lightweight node or helper that stores named/team spawn transforms.

Owns:

- Player spawn lookup.
- Ball spawn lookup.
- Marker creation if markers are still useful visually.

Public API:

- `get_player_spawn(team_id: int) -> Vector3`
- `get_ball_spawn(team_id: int) -> Vector3`
- `reset_player(player: PlayerController) -> void`
- `reset_ball(ball: TeamBall) -> void`

SOLID gain:

- Keeps reset positioning separate from match flow.
- Makes future spawn rules easier, such as side swapping, practice mode, or random variants.

### `RoundResetService`

New node responsible for resetting point state.

Owns:

- Reset players to spawn positions.
- Reset balls to spawn positions.
- Reset trap charge.
- Clear stun/weapon transient state through public methods.
- Emit a `point_reset_completed` signal if needed.

Public API:

- `setup(players: Array, balls: Array, trap: SpringTrap, spawns: SpawnRegistry) -> void`
- `reset_point() -> void`

This lets `MatchManager` request a reset without knowing how arena entities reset themselves.

SOLID gain:

- Single responsibility: match scoring no longer needs direct arena reset knowledge.
- Dependency inversion: `MatchManager` can depend on a callable/signal/service rather than a concrete arena script.

### `HUDController`

New `CanvasLayer` or `Control` scene/script responsible for HUD creation and display state.

Owns:

- Score label.
- Ammo label.
- Charged shot label.
- Bot label.
- Crosshair.
- Hit marker label text/color.

Public API:

- `set_score(team_one_score: int, team_two_score: int) -> void`
- `set_weapon_state(ammo: int, max_ammo: int, final_bonus_enabled: bool, is_reloading: bool) -> void`
- `set_bot_enabled(enabled: bool) -> void`
- `show_hit_text(text: String, color: Color, duration: float) -> void`

SOLID gain:

- Single responsibility: UI layout/text changes no longer touch gameplay code.
- Interface segregation: gameplay emits simple state; HUD decides presentation.

### `ShotFeedbackController`

New `Node3D` responsible for world shot feedback.

Owns:

- Path line meshes.
- World hit markers.
- Feedback lifetimes and fade-out.
- Counters/debug state for generated feedback.

Public API:

- `show_shot_feedback(result: ShotFeedbackData) -> void`
- `get_debug_state() -> Dictionary`

Optional data object:

- `ShotFeedbackData`: text, color, world position, path segments, is bank shot, is charged shot.

SOLID gain:

- Single responsibility: visual feedback can evolve independently.
- Open/closed: new feedback styles can be added without changing weapon or arena orchestration.

### `KeeperBotController`

New node for the red keeper bot.

Owns:

- Enabled state.
- Reaction thresholds.
- Movement under the ball.
- Fire/reload decision.

Public API:

- `setup(player: PlayerController, ball: TeamBall) -> void`
- `set_enabled(enabled: bool) -> void`
- `is_enabled() -> bool`
- `get_debug_state() -> Dictionary`

SOLID gain:

- Single responsibility: bot tuning stops changing `ArenaManager`.
- Open/closed: future bot variants can be added without changing arena/match code.

### `ShotResolver`

New `RefCounted` or `Node` that resolves hitscan shots.

Owns:

- Raycasts.
- Ricochet loop.
- Effective target mapping from shot-hit areas to target nodes.
- Shot path segment recording.

Does not own:

- Ammo state.
- Reload state.
- Hit application.
- HUD/feedback.

Public API:

- `resolve(origin: Vector3, direction: Vector3, owner: CollisionObject3D, config: ShotConfig) -> ShotResult`

`WeaponController` keeps ammo/reload/cooldown and calls `ShotResolver` when firing.

SOLID gain:

- Single responsibility: weapon state and geometric shot resolution separate cleanly.
- Open/closed: alternate shot resolution, assist, projectile weapons, or debug previews can be added behind the same result contract.

### `ShotResult`

New `RefCounted` data class, or keep a Dictionary initially with a stable schema.

Fields:

- `hit_node`
- `hit_direction`
- `hit_position`
- `ricochet_count`
- `path_segments`

Recommendation: start with a documented Dictionary schema to minimize churn. Convert to a typed class after the boundaries stabilize.

### `ShotEffectApplicator`

Optional later extraction. Only create this when shot effects start growing.

Owns:

- Applying ball impulse.
- Applying player knockback.
- Charging trap.
- Returning impulse/effect strength.

Public API:

- `apply(hit_node: Node, direction: Vector3, is_final_shot: bool, weapon: WeaponController) -> float`

This may be premature right now. Keep `_apply_hit` in `WeaponController` until networking or additional effects make the extraction clearly useful.

### `GroundLossMonitor`

New `Area3D` or small node responsible for floor-loss detection.

Owns:

- Ground-loss area creation.
- Filtering to team balls.
- Emitting `ball_grounded(team_id: int, ball: TeamBall)` once per active point.

`MatchManager` listens to this signal and scores the point.

SOLID gain:

- Single responsibility: floor-loss detection is separate from scoring and resets.
- Dependency inversion: match rules listen to an event instead of being called from arena polling.

### `SpringTrap` Boundary Cleanup

Keep charge and trigger behavior inside `SpringTrap`.

Move cap geometry checks out of `ArenaManager` and into one of these:

1. `SpringTrap` owns cap contact detection once it knows its cap radius/height.
2. `ArenaGeometry` exposes `is_point_on_cap`, and a `SpringTrapContactMonitor` bridges geometry contact to trap triggering.

Recommended first pass: put cap contact detection inside `SpringTrap` because it is trap behavior, but pass top-cap dimensions through `setup_cap` as it already does.

Add public API:

- `reset_charge() -> void`
- `try_trigger_for_ball(ball: TeamBall) -> bool`
- `can_trigger_for_ball(ball: TeamBall) -> bool`

SOLID gain:

- Encapsulation: arena reset code does not mutate `current_charge` directly.
- Single responsibility: trap contact rules live with the trap.

### `PlayerController` Boundary Cleanup

Mostly keep as-is for now.

Small improvements:

- Add `reset_for_point(spawn_position: Vector3) -> void` as the public reset API.
- Add `set_active_camera(active: bool) -> void`.
- Add `get_weapon() -> WeaponController` only if direct property access becomes noisy.
- Keep local input handling here until multiplayer input authority work begins.

### `TeamBall` Boundary Cleanup

Mostly keep as-is for now.

Small improvements:

- Add `reset_for_point() -> void` as a clearer public API or keep `reset_ball()` if preferred.
- Add optional `clamp_speed()` later only if manual feel check shows unreadable ball speeds.
- Keep shot-hit area ownership here because it belongs to the ball target contract.

### `MatchManager` Boundary Cleanup

Keep scoring and match state here.

Improve dependencies:

- Replace `setup(arena)` with either `setup(reset_service)` or a `point_reset_requested` signal.
- Prefer emitting `point_reset_requested` and letting `RoundResetService` respond.
- Keep `score_changed` and `match_finished` signals.

Possible API:

- `register_ball_grounded(fallen_team_id: int) -> void`
- `reset_match() -> void`
- `request_point_reset()` signal, or `point_reset_requested` signal.

SOLID gain:

- Dependency inversion: match rules do not depend on a concrete arena node.
- Single responsibility: match manager handles score state, not physical reset details.

## Migration Plan

Each phase should be small enough to run the existing loop after completion.

### Phase 0: Lock Current Behavior

Before moving code, run the current verification loop and keep the latest passing result as the baseline.

Tasks:

- Run `./tools/run_loop.cmd -TimeoutSeconds 10`.
- Confirm `artifacts/results/latest.json` passes.
- Do not change gameplay values in this phase.

Exit criteria:

- Existing tests pass before refactor starts.

### Phase 1: Extract HUD

This is low-risk because it has minimal physics coupling.

Tasks:

- Create `scripts/hud_controller.gd`.
- Move `_add_hud`, `_add_crosshair`, hit marker text, score/ammo/bot label formatting into `HUDController`.
- Keep node names stable so existing tests still pass.
- Update `ArenaManager` to call HUD methods instead of editing labels directly.

Expected `ArenaManager` reduction:

- Removes UI node fields except `hud`.
- Removes text formatting and crosshair construction.

Tests to watch:

- `hud_has_crosshair_root`
- `hud_has_ammo`
- `charged_shot_ready_indicator_visible`
- `shot_feedback_hit_label`

### Phase 2: Extract Shot Feedback

Tasks:

- Create `scripts/shot_feedback_controller.gd`.
- Move shot path, world marker, fade lifetime, and counters into it.
- `ArenaManager._on_local_shot_fired` should translate weapon shot data into one feedback request.
- Keep feedback group names and metadata stable for tests.

Expected `ArenaManager` reduction:

- Removes shot feedback counters and lifetime processing.
- `_process` no longer scans feedback nodes.

Tests to watch:

- `shot_feedback_created`
- `shot_path_visual_created`
- `ricochet_feedback_marked_bank`
- `shot_path_fades_and_disappears`

### Phase 3: Extract Keeper Bot

Tasks:

- Create `scripts/keeper_bot_controller.gd`.
- Move red bot exported tuning and `_update_red_bot` / `_move_red_bot_under_ball` into it.
- Arena input toggles bot through `keeper_bot.set_enabled(...)`.
- HUD reads enabled state from bot.

Expected `ArenaManager` reduction:

- Removes red bot tuning fields and bot update logic.

Tests to watch:

- `red_bot_default_on`
- `red_bot_space_toggles_off`
- `red_bot_fires_to_save_ball`

### Phase 4: Extract Arena Geometry

Tasks:

- Create `scripts/arena_geometry.gd`.
- Move lighting, overview camera, floor body, dome/frustum/top-cap mesh creation, rings, and geometry helper methods.
- Keep generated node names stable: `Floor`, `Dome`, `CylinderWallVisual`, `FrustumRoofVisual`, `CylinderFrustumSeam`, `TopCapRing`.
- Update tests to call public geometry APIs through `arena.geometry` where appropriate.

Expected `ArenaManager` reduction:

- Removes the largest construction block.
- Arena still owns object spawning and match wiring.

Tests to watch:

- `actual_dome_exists`
- `arena_has_cylinder_visual`
- `arena_uses_cylinder_wall_normal`
- `arena_frustum_incline_30_degrees`
- `floor_is_ricochet_surface`

### Phase 5: Extract Spawn And Reset Flow

Tasks:

- Create `scripts/spawn_registry.gd`.
- Create `scripts/round_reset_service.gd`.
- Move spawn marker creation into `SpawnRegistry`.
- Move `reset_point` logic into `RoundResetService`.
- Add `SpringTrap.reset_charge()` so reset code does not mutate `current_charge` directly.
- Change `MatchManager` to signal reset requests instead of calling `arena.reset_point()` directly, or give it a reset service dependency.

Expected `ArenaManager` reduction:

- `ArenaManager.reset_point()` becomes a compatibility wrapper or disappears.
- Match flow is less coupled to arena implementation.

Tests to watch:

- `ground_score_resets_point`
- `floor_threshold_resets_ball_high`
- `cap_spring_trap_resets_charge`

### Phase 6: Extract Ground Loss And Trap Contact Monitors

Tasks:

- Create `scripts/ground_loss_monitor.gd` or make the existing `GroundLossArea` scene/scripted.
- Move floor-loss area creation and `body_entered` scoring signal out of `ArenaManager`.
- Move spring trap cap contact/debounce into `SpringTrap` if possible.
- If physics contact detection for the cap remains unreliable, use a small `SpringTrapContactMonitor` node that calls public `SpringTrap.try_trigger_for_ball(ball)`.

Expected `ArenaManager` reduction:

- `_physics_process` no longer checks floor loss or trap cap contact.

Tests to watch:

- `floor_threshold_scores`
- `spring_trap_pushes_down`
- `cap_spring_trap_pushes_down`

### Phase 7: Extract Shot Resolution

Tasks:

- Create `scripts/shot_resolver.gd`.
- Move `_resolve_shot`, `_raycast_result`, `_reflect_direction`, and target normalization into it.
- Keep `WeaponController` responsible for ammo, cooldown, reload, final-shot state, and hit application.
- Add a stable public method for tests: `weapon.preview_shot(origin, direction, owner_player) -> Dictionary` or expose `shot_resolver.resolve(...)`.

Expected `WeaponController` reduction:

- Weapon becomes easier to adapt for RPC validation later.

Tests to watch:

- `near_miss_hits_enlarged_ball_target`
- `ricochet_count_one`
- `floor_ricochet_count_one`
- `shot_origin_matches_camera_crosshair`

### Phase 8: Introduce Config Resources

Do this after the code is split so it is clear which subsystem owns which values.

Tasks:

- Create `scripts/arena_config.gd` as a `Resource`.
- Optionally create `scripts/shot_config.gd`, `scripts/bot_config.gd`, and `scripts/feedback_config.gd` only if value groups are clearly independent.
- Move exported values from `ArenaManager` to the subsystem that owns them or to config resources.

Expected gain:

- Easier tuning and future scene variants.
- Cleaner path to practice mode and alternate arena modes.

### Phase 9: Scene-First Conversion

Only after the scripted boundaries are clean.

Tasks:

- Convert reusable runtime-created objects into `.tscn` scenes where it helps authoring.
- Prioritize `HUD`, `Player`, `TeamBall`, `SpringTrap`, and `ArenaGeometry`.
- Keep procedural geometry generation inside `ArenaGeometry` unless hand-authored meshes become useful.

Expected gain:

- Better editor inspection and iteration without sacrificing procedural arena shape tuning.

## SOLID Checklist For Each New Class

Use this as a quick review gate during each phase.

### Single Responsibility

Can this script be described in one sentence without using "and" repeatedly?

Good:

- `HUDController` displays current HUD state.
- `ShotResolver` resolves shot geometry.
- `MatchManager` owns score and match state.

Too broad:

- A node that builds geometry, tracks score, updates UI, and moves bots.

### Open/Closed

Can a new arena shape, bot, or feedback style be added by introducing a new component or config rather than editing unrelated systems?

Prefer:

- `ArenaGeometry` variants.
- `KeeperBotController` variants.
- Feedback data passed into a display controller.

Avoid:

- More conditionals in `ArenaManager` for every new mode.

### Liskov Substitution

Godot scripts do not need deep inheritance here. If inheritance appears, derived scripts should be usable anywhere the base is expected.

Prefer composition first. Use inheritance only for clear variants, such as future bot strategies or arena geometry variants.

### Interface Segregation

Do not pass all of `ArenaManager` when a system needs one method or one value.

Prefer:

- `HUDController.set_score(...)`
- `RoundResetService.reset_point()`
- `ArenaGeometry.is_point_on_cap(...)`

Avoid:

- `some_system.setup(arena)` followed by reaching into many arena fields.

### Dependency Inversion

High-level rules should depend on signals, small APIs, or data objects, not concrete mega-nodes.

Prefer:

- `GroundLossMonitor.ball_grounded` -> `MatchManager.register_ball_grounded`.
- `MatchManager.point_reset_requested` -> `RoundResetService.reset_point`.
- `WeaponController` -> `ShotResolver.resolve` result.

Avoid:

- `MatchManager` calling arbitrary methods on `ArenaManager`.

## Testing Strategy During Refactor

Keep the current tests as a safety net, but migrate them toward public contracts as boundaries appear.

Recommended approach:

1. Before each phase, run the loop and confirm green.
2. Move code without changing behavior.
3. Keep existing node names/groups/metadata stable.
4. Add public methods only where tests or other systems need a real contract.
5. Update tests away from private methods as each new contract exists.
6. Run the loop after every phase.

Useful test migrations:

- `arena._dome_normal_at(...)` -> `arena.geometry.get_surface_normal_at(...)`
- `arena._is_point_on_cap(...)` -> `arena.geometry.is_point_on_cap(...)` or `spring_trap.is_point_in_cap(...)`
- `weapon._resolve_shot(...)` -> `weapon.preview_shot(...)` or `shot_resolver.resolve(...)`
- `arena._check_ball_floor_loss()` -> `ground_loss_monitor.force_check_for_tests()` only if event simulation is not enough.

## Recommended First Refactor Loop

Start with `HUDController` and `ShotFeedbackController`.

Why:

- They reduce `ArenaManager` size quickly.
- They have low gameplay physics risk.
- Existing tests already cover them well.
- They create a pattern for extracting other systems.

Suggested loop:

1. Run `./tools/run_loop.cmd -TimeoutSeconds 10`.
2. Extract `HUDController`.
3. Run loop again.
4. Extract `ShotFeedbackController`.
5. Run loop again.
6. Update this plan with what changed and any surprises.

## Implementation Progress

Completed first implementation slice:

- Added public test/debug contracts: `ArenaManager.get_arena_normal_at`, `ArenaManager.is_point_on_cap`, `ArenaManager.is_point_on_frustum_band`, `ArenaManager.check_ball_loss_for_tests`, `ArenaManager.check_spring_trap_cap_contact_for_tests`, `WeaponController.preview_shot`, and `WeaponController.preview_raycast`.
- Updated the scenario runner to use the new public helpers where practical instead of private methods.
- Extracted HUD creation and display state into `scripts/hud_controller.gd` while preserving existing HUD node names.
- Extracted shot path and world hit marker visuals into `scripts/shot_feedback_controller.gd` while preserving feedback group metadata and arena debug counters.
- Extracted red keeper bot decisions and movement into `scripts/keeper_bot_controller.gd` while keeping `ArenaManager.set_red_bot_enabled` and `_update_red_bot` as compatibility shims.
- Added point-reset contracts: `PlayerController.reset_for_point`, `TeamBall.reset_for_point`, and `SpringTrap.reset_charge`.
- Updated `ArenaManager.reset_point` to call public reset methods rather than mutating trap charge directly.
- Extracted arena geometry construction and geometry queries into `scripts/arena_geometry.gd` while preserving generated child node names such as `Floor`, `Dome`, `CylinderFrustumSeam`, and `TopCapRing`.
- Extracted spawn lookup and spawn marker ownership into `scripts/spawn_registry.gd`.
- Extracted point reset orchestration into `scripts/round_reset_service.gd`, and gave `MatchManager` a reset target so it no longer needs to call the concrete arena for normal point resets.
- Extracted floor-loss detection into `scripts/ground_loss_monitor.gd`.
- Extracted top-cap spring-trap contact/debounce behavior into `scripts/cap_trap_contact_monitor.gd`.
- Extracted hitscan raycast, ricochet, effective target, and path-segment resolution into `scripts/shot_resolver.gd`.
- Updated the scenario runner to use public helper APIs except for direct `_input` calls that intentionally test Godot input handling.
- Completed Phase 9 scene-first conversion for reusable roots: `ArenaManager` now instantiates `ArenaGeometry`, `HUD`, `Player`, `TeamBall`, and `SpringTrap` from exported `PackedScene` references with script fallbacks.
- Added `scenes/hud.tscn` and `scenes/arena_geometry.tscn`; existing `scenes/player.tscn`, `scenes/team_ball.tscn`, and `scenes/spring_trap.tscn` are now used by default.
- Added scenario checks that verify the arena is using the reusable scene files instead of silently falling back to script-only construction.
- Added `MULTIPLAYER_WEB_EXPORT_PLAN.md` to capture LAN/listen-server authority, browser networking constraints, and web export verification.

Latest verified command:

- `./tools/run_loop.cmd -TimeoutSeconds 10`

Current refactor status:

- The planned architecture extraction and Phase 9 scene-first conversion are complete enough for the next feature pass.
- The remaining optional refactor work is config resources: introduce them only when multiple presets or modes need them.
- The next functional implementation slice should start multiplayer scaffolding from `MULTIPLAYER_WEB_EXPORT_PLAN.md`, beginning with `NetworkManager` local/desktop LAN lifecycle.

## Definition Of Done For The Refactor

The refactor is complete enough when:

- `ArenaManager` mainly wires subsystems and exposes lookup/debug helpers.
- Arena geometry, HUD, shot feedback, bot behavior, reset flow, and ground-loss monitoring are separate scripts.
- `MatchManager` no longer depends on a concrete arena implementation for point reset.
- `WeaponController` has shot resolution behind a separate boundary or public preview API.
- Scenario tests pass without relying on most private methods.
- No gameplay tuning values changed accidentally.
- The next feature can be added by touching the relevant subsystem instead of editing a central script.
