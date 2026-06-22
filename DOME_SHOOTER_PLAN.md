# Dome Shooter Prototype Plan

Build a playable graybox Godot 4.6 LAN/listen-server prototype for a 1v1 first-person dome shooter. Each team protects its own airborne ball while trying to force the enemy ball to the ground. The local gameplay loop should be validated first, with the listen host authoritative over match, ball, shot, trap, stun, and scoring rules once multiplayer is added.

## Core Concept

- The match takes place inside a dome arena.
- Each team has one ball.
- If a team's ball hits the ground, the opposing team scores a point.
- First team to 5 points wins.
- Both balls spawn above their respective teams at the start of each point.
- Players use six-shooters.
- The sixth fired shot has stronger knockback.
- Reloading early refills ammo but removes immediate access to the final-shot bonus.
- Shooting a ball applies impulse in the shot direction, allowing players to keep it up, redirect it, or drive it down.
- Shooting a player knocks them back.
- If a knocked player strikes a wall above a speed threshold, they are stunned.
- Stun disables movement and shooting for a tunable duration.
- Shots that miss players, balls, and the spring trap should ricochet once off the dome, enabling banked shots that can hit the tops of balls.
- Shots should briefly draw their path, including both pre-ricochet and post-ricochet segments, so banked shots are readable.
- The centered crosshair must line up with the camera-center shot ray.
- Shot path visuals should fade and disappear shortly after firing so the arena does not fill with old trails.
- A shootable spring trap at the top of the dome has base downward knockback.
- Shooting the spring trap increases its next downward impulse.
- When a ball contacts the charged spring trap, the trap launches it downward and then resets its charge.

## Decisions Captured

- Target: playable graybox prototype, not final art/audio.
- First mode: 1v1.
- Multiplayer: LAN/listen server.
- Camera/control: first-person shooter.
- Movement: low-gravity floaty arena movement.
- Scoring: ball drop scores a point; first to 5 wins.
- Ball start: both balls spawn above their respective teams.
- Ball shot behavior: impulse follows the shot direction.
- Missed shots ricochet once from the dome surface before expiring.
- Shot origin: shots originate from the camera-center ray represented by the crosshair.
- Shot path lifetime: shot trails are temporary and fade out quickly.
- Spring trap: shootable trap with base downward knockback; shots increase next trap impulse; charge resets after hitting a ball.
- Wall stun: impact speed threshold; stun disables movement and shooting.
- Reload: early reload refills ammo but loses immediate access to the final-shot bonus.

## Implementation Steps

### 1. Foundation And Project Structure

- Create folders for scenes, scripts, materials, UI, and autoloads.
- Set a main scene in `project.godot` once the root scene exists.
- Add input actions for movement, jump/float, fire, reload, look, scoreboard/menu, host, join, and disconnect.
- Keep art graybox-only for the prototype.

### 2. Core Scene Architecture

Depends on step 1.

- Create a `Main` scene responsible for bootstrapping menus, hosting/joining, spawning the match scene, and owning network lifecycle.
- Create an `Arena` scene containing an actual dome-shaped play space and collision surface, playable floor trigger, team spawn points, ball spawn points, wall impact collision groups, and top spring trap.
- Create reusable `Player`, `TeamBall`, and `SpringTrap` scenes.
- Use clear collision layers/groups for players, balls, walls, ground-loss trigger, shots, and trap.

### 3. Local First-Person Player Prototype

Depends on step 2. Can be developed in parallel with step 4.

- Implement low-gravity floaty first-person movement using a `CharacterBody3D` controller.
- Add mouse-look, jump/float tuning, air control, player knockback velocity, and stun state handling.
- Add temporary player meshes/colors so teams are readable in a graybox arena.
- Add a centered crosshair and first-pass hit feedback so players can tell where shots land.

### 4. Team Ball Physics Prototype

Depends on step 2. Can be developed in parallel with step 3.

- Implement each team ball as a `RigidBody3D` using Jolt Physics.
- Spawn both balls higher above their respective teams at round start so players have time to react.
- Tune ball gravity, damping, and mass so balls fall slower and stay readable in the air.
- Apply shot impulses in the direction of the shot, allowing players to keep a ball up, redirect it sideways, or drive it down by aim choice.
- Add server-owned ground trigger detection that reliably awards a point and ends/resets the round when a team ball hits the floor.
- Reset balls and players after each point.

### 5. Six-Shooter Weapon System

Depends on steps 3 and 4.

- Give each player a six-round weapon with hitscan ray shots for the prototype.
- Track ammo as six chambers where the sixth fired shot applies bonus knockback.
- Allow early reload to refill ammo but mark the next cylinder as ineligible for the final-shot bonus until the player naturally reaches the sixth shot again.
- Apply regular and final-shot impulse tuning separately for balls and players.
- Add prototype UI for ammo count, reload state, final-shot eligibility, score, and stun state.
- Add one-bounce shot ricochet when the first ray hit is dome geometry instead of a player, ball, or trap. Show the ricochet impact and continue the shot from the reflected direction.
- Add visual shot-hit feedback for direct hits and ricochet hits.
- Add a brief shot path visual that draws the direct shot segment and any ricochet segment so players can see the bank angle.
- Keep the crosshair anchored to the viewport center and verify shot rays originate from the same camera-center direction.
- Fade and remove shot path and hit-marker visuals after a short duration.

### 6. Player Knockback And Wall Stun

Depends on steps 3 and 5.

- Apply shot knockback to players in the shot direction.
- Detect wall impacts after knockback and stun only when impact speed exceeds a threshold.
- During stun, disable both movement and shooting for a short, tunable duration.
- Add minimal feedback: screen effect, sound placeholder, or UI indicator.

### 7. Shootable Top Spring Trap

Depends on steps 2, 4, and 5.

- Place a spring trap/bumper at the dome apex with a base downward knockback value.
- Let players shoot the trap to increase its next downward knockback impulse.
- When a ball contacts the trap, apply the charged downward impulse to the ball and reset the trap charge.
- Add clear graybox feedback for trap charge level, such as color intensity or a simple meter near the trap.

### 8. Match Rules And Round Flow

Depends on steps 4 through 7.

- Score one point against the team whose ball hits the ground.
- Reset the point with countdown, player respawns, ammo refill, ball respawn, trap charge reset, and stun cleanup.
- End the match when a player/team reaches 5 points.
- Add rematch/reset flow for continued testing.

### 9. LAN/Listen-Server Multiplayer

Depends on stable local gameplay from steps 3 through 8.

- Add a network manager using Godot MultiplayerAPI with host and join flows.
- Make the host authoritative for balls, trap charge/contact, score, round resets, shot validation, and wall stun outcomes.
- Clients send input/fire/reload requests; host validates and broadcasts authoritative state/events.
- Use `MultiplayerSynchronizer` or explicit RPC/state replication for player transforms, ball transforms/velocities, ammo state, stun state, score, trap charge, and round state.
- Keep client prediction minimal in the graybox; prioritize correctness and readable debugging.

### 10. Tuning And Debugging Tools

Can be added incrementally after each mechanic exists.

- Expose key values as exported variables: gravity scale, air control, shot cooldown, reload time, ball impulse, player impulse, final-shot multipliers, stun threshold, stun duration, trap base impulse, trap charge per shot, max trap charge, and score target.
- Add a debug overlay or console prints for shot hits, ball velocity, wall impact speed, trap charge, point scoring, and network authority.
- Create test arenas or debug spawn positions only if tuning the main dome becomes slow.

## Continuous Implementation Loop

Use a tight continuous loop instead of large milestone batches. Each loop should produce one playable, verifiable improvement, then immediately run automated checks and capture visual proof. The loop should stay small enough that failures are easy to diagnose.

### Loop Shape

1. Select one thin vertical task from the plan.
2. Ask a read-only exploration agent to inspect relevant files and identify existing patterns or risks.
3. Have the builder implement only that task and any required test harness support.
4. Run Godot import/script checks and automated scenario tests.
5. Run visual screenshot verification for the affected scene or mechanic.
6. Have a reviewer inspect the diff, test output, screenshots, and remaining risks.
7. Fix issues immediately, then repeat verification.
8. Update this plan with completed work, new findings, and the next task.

### Agent Roles

- Orchestrator: owns the loop, chooses the next small task, keeps scope tight, and decides when to move on.
- Explorer: read-only agent that maps relevant files, Godot node structure, dependencies, and likely edge cases before implementation.
- Builder: edits scenes/scripts, keeps changes focused, and adds exported tuning values where useful.
- Verifier: runs command-line checks, scripted Godot scenarios, screenshot capture, and visual assertions.
- Reviewer: checks behavior, multiplayer authority assumptions, regression risk, and whether tests actually prove the mechanic.

For this project, start with the available read-only `Explore` agent for discovery, then let the main agent act as builder, verifier, and reviewer until more custom agents are worth adding. Custom agents become useful once the project has enough code for repeatable specialization.

### Headless Screenshot Verification

Use screenshot verification as a fast confidence check for scene structure, UI visibility, camera framing, and obvious rendering failures. Pair it with gameplay assertions because screenshots alone cannot prove physics correctness.

- Add deterministic test scenes that set fixed spawn positions, camera transforms, lighting, and seeded random values.
- Add a screenshot runner scene or script that loads a target scene, waits a fixed number of physics frames, captures the viewport image, and writes a PNG to `artifacts/screenshots/`.
- Add machine-readable scenario results, such as JSON in `artifacts/results/`, for scores, ball states, trap charge, ammo state, stun state, and RPC events.
- Use pixel checks for nonblank frames, expected team-color regions, visible UI elements, and stable camera framing.
- Store baseline screenshots only for stable scenes. Early in development, prefer threshold checks over exact image diffs because physics and rendering can shift while the prototype is still moving.
- On Windows, run screenshot tests through the normal Godot executable in an automated mode when rendering is needed. True headless mode may not provide reliable rendered viewport captures, so treat the goal as unattended visual verification rather than assuming every check can use a no-display driver.
- In CI on Linux, use a virtual display such as Xvfb if Godot needs a display for rendering screenshots.

### Recommended Scenario Tests

- `arena_smoke`: load the dome, confirm the camera sees the arena, both balls, floor, walls, and trap.
- `actual_dome_smoke`: confirm the arena uses dome-shaped collision/visual geometry rather than only vertical wall segments.
- `single_player_smoke`: spawn one player, simulate movement/look/fire/reload, confirm ammo and UI state change.
- `ball_impulse`: fire at a ball from controlled angles and assert the resulting velocity points in the expected direction.
- `ball_spawn_tuning`: confirm balls spawn above the current too-low manual-verification position and take longer to fall to scoring height.
- `ground_score`: drop a team ball onto the floor trigger and assert the opponent scores one point and the point resets.
- `final_shot`: fire six shots and assert the sixth applies stronger knockback than a normal shot.
- `early_reload`: reload before the sixth shot and assert the immediate final-shot bonus is unavailable.
- `shot_feedback`: fire at a ball, player, trap, wall, and empty/dome surface and assert visible shot feedback is produced.
- `ricochet_shot`: fire at the dome, reflect once, and assert the reflected ray can hit a ball from above.
- `shot_path_visual`: fire direct and ricochet shots and assert path visuals are created for each shot segment.
- `shot_origin_crosshair`: assert the HUD crosshair is viewport-centered and shot path data starts from the active camera ray.
- `shot_path_lifetime`: assert shot path and hit-marker visuals fade/remove after their configured lifetime.
- `wall_stun`: knock a player into a wall above and below the threshold and assert stun only happens above threshold.
- `spring_trap`: shoot the trap, confirm charge increases, collide a ball with it, confirm downward impulse and charge reset.
- `listen_server_smoke`: start host and client locally, join a match, fire a shot, score a point, and confirm synchronized state.

### First Five Loops

1. Create folders, a main scene, an arena graybox, and an arena screenshot smoke test.
2. Address manual verification findings: raise ball spawns, slow ball fall speed, fix floor scoring/round reset, add crosshair, ammo HUD, and shot-hit feedback.
3. Replace the placeholder wall ring with an actual dome-shaped visual and collision surface.
4. Add one-bounce ricochet shots from the dome, including visible shot path segments and banked shot tests that can hit the top of a ball.
5. Add wall stun and spring trap mechanics with focused scenario tests before starting LAN/listen networking.

### Loop Exit Criteria

- The targeted mechanic works in a playable scene.
- Script checks pass.
- The relevant scenario test passes.
- Screenshot output is nonblank and shows the expected scene/UI elements.
- Any changed gameplay value is exported or documented for tuning.
- Known issues are written down before the next loop starts.

### Current Loop Status

Loop 1 is implemented and verified.

- Created a playable graybox scene at `scenes/main.tscn`.
- Added runtime-generated arena geometry, walls, floor trigger, lighting, HUD, overview camera, two players, two team balls, and a shootable spring trap.
- Added first-pass player movement, knockback/stun state, six-shooter ammo/reload logic, team ball impulses, spring trap charge/reset behavior, and point scoring.
- Added `tools/run_loop.ps1` as the local continuous-loop command.
- Added `tools/run_loop.cmd` as the Windows automation wrapper for environments where direct `.ps1` execution is blocked by policy.
- Added `scripts/test_runner.gd` with automated checks for arena smoke, screenshot content, ball impulse, ground scoring, final shot, early reload, wall stun, and spring trap behavior.
- Verification command: `./tools/run_loop.cmd -TimeoutSeconds 10` for automation, or `./tools/run_loop.ps1 -TimeoutSeconds 10` when direct PowerShell script execution is allowed.
- The loop runner launches Godot as a child process, captures stdout/stderr to `artifacts/results/`, and kills the Godot process tree with exit code `124` if the timeout is exceeded.
- Latest verified result: all scenario checks pass, no VS Code diagnostics, and `artifacts/screenshots/arena_smoke.png` shows both teams and the spring trap.
- Manual verification notes captured in `thoughts.md`: balls start too low, balls should fall slower, balls hitting the floor do not end/reset the round reliably, crosshair is missing, shot-hit feedback is missing, ammo HUD is missing, the arena should be an actual dome, and missed shots should ricochet once for banked shots off the curved ceiling.
- Additional Loop 2 note: ricochet shots should draw a brief shot path visual so the bank is readable.
- Additional Loop 2 note: the crosshair must match the shot ray origin, and shot path visuals should fade out after a short duration.
- Loop 2 implemented and verified: raised/slowed balls, reliable floor scoring, crosshair, ammo HUD, shot-hit feedback, shot path visualization, actual dome geometry, and one-bounce ricochet shots.
- Loop 2 follow-up implemented: responsive viewport-centered crosshair, camera-center shot origin verification, and fading/removal for shot path and hit-marker visuals.
- Loop 3 implemented: red player keeper bot defaults on, tracks under the red ball, shoots it when it is falling/low, reloads when empty, and can be toggled with Space. Float/jump moved to Shift so Space can serve as the bot toggle.
- Added [RICOCHET_ACCESSIBILITY_IDEAS.md](RICOCHET_ACCESSIBILITY_IDEAS.md) with options for making bank shots easier, including cylinder/cone arena shapes, larger shot hit collision, ricochet assist, preview lines, and stronger feedback.
- Loop 4 implemented: replaced the curved dome with a cylinder plus truncated cone ricochet surface, added larger invisible ball shot-hit areas, strengthened bank-shot trails/markers, skipped post-bounce cone/sphere assist as unintuitive, and added scenario checks for the new behavior.
- Loop 4 follow-up revised: the spring trap is now the flat top cap, while the sloped frustum remains a predictable ricochet surface; cap shots charge the trap and balls touching the cap get launched downward with debounce protection.
- Loop 4 tuning follow-up: frustum incline set to 30 degrees, frustum footprint reduced, duplicate coplanar roof visuals hidden to avoid clipping, and the cap spring trap made translucent.
- Loop 5 implemented: ball behavior moved to very low gravity and high damping for more predictable arcs while preserving the keep-it-up pressure.
- Loop 5 weapon follow-up: weapons now auto-reload when emptied, the HUD shows a charged-shot-ready indicator, and charged/final shots use a distinct gold shot path/marker style.
- Loop 5 ricochet follow-up: the floor is now a ricochet surface, and shot rays skip the ground-loss trigger so downward shots bounce off the physical floor.
- Next loop target: manual feel check for ball predictability; add speed clamps only if shots still create unreadable ball speeds.

## Planned Files

- `project.godot` - existing Godot 4.6 project config; later update main scene and input map.
- `scenes/main.tscn` - future root scene for app state, menus, and match loading.
- `scenes/arena.tscn` - future dome, floor trigger, walls, spawn points, and spring trap layout.
- `scenes/player.tscn` - future reusable first-person player scene.
- `scenes/team_ball.tscn` - future reusable team ball physics scene.
- `scripts/network_manager.gd` - future host/join flow and authoritative state/event replication.
- `scripts/match_manager.gd` - future scoring, point reset, countdown, match end, and rematch flow.
- `scripts/player_controller.gd` - future movement, camera, knockback, and stun state.
- `scripts/weapon_controller.gd` - future six-shooter, reload, shot RPC, hit resolution, and final-shot bonus logic.
- `scripts/team_ball.gd` - future ball impulse handling, spawn/reset state, and network sync support.
- `scripts/spring_trap.gd` - future shoot-to-charge trap and ball contact impulse logic.
- `scripts/arena_manager.gd` - future arena collision groups, ground detection, and spawn references.
- `scenes/test_runner.tscn` - future automated scenario and screenshot runner scene.
- `scripts/test_runner.gd` - future command-line test harness for deterministic scenarios.
- `tests/scenarios/` - future scenario scripts for mechanics and networking checks.
- `tools/run_loop.ps1` - future local command for checks, screenshots, and result summaries.
- `tools/run_loop.cmd` - Windows wrapper that runs the PowerShell loop with execution-policy bypass for automation.
- `artifacts/screenshots/` - generated screenshot outputs, likely ignored by git.
- `artifacts/results/` - generated JSON/text test results, likely ignored by git.

## Verification Checklist

- Run the game locally and confirm a single test player can move, float, aim, fire, reload, and see ammo/final-shot state.
- Confirm shooting a ball applies impulse in shot direction and can both save it from falling and drive it toward the floor.
- Confirm each ball touching the floor awards one point to the opponent, visibly ends/resets the round, and ends the match at 5 points.
- Confirm the sixth shot has noticeably stronger knockback, and early reload removes access to that immediate final-shot bonus.
- Confirm crosshair, ammo HUD, and shot-hit feedback are visible during manual first-person play.
- Confirm the shot ray appears to originate from the centered crosshair at different window sizes.
- Confirm the arena reads and collides as a dome, not a ring of straight wall panels.
- Confirm missed shots ricochet once off the dome, can bank into the top of a ball, visibly draw both shot path segments, then fade those paths away.
- Confirm shooting a player knocks them back, and only high-speed wall impacts trigger stun that disables movement and shooting.
- Confirm shooting the spring trap increases its next downward impulse, ball contact triggers it, and charge resets afterward.
- Start two instances on LAN/listen server, connect a client, and verify host-authoritative score, ball physics, shots, reloads, stun, and trap state stay consistent.
- Stress-test latency by adding artificial delay or testing on two machines if available; record any correction jitter or perceived unfair shots.
- Inspect Godot debugger output for physics or RPC warnings after several full matches.

## Further Considerations

1. Start with hitscan shots for readability and networking simplicity; projectile bullets can be revisited after the core loop feels good.
2. Keep host-authoritative physics for fairness, accepting some early jitter in exchange for fewer scoring disputes.
3. Defer bots, matchmaking, final art, progression, and ranked systems until the 1v1 LAN prototype proves the central ball-control loop is fun.
