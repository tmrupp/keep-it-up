# Multiplayer And Web Export Plan

This plan extends the local prototype toward two targets:

1. Desktop LAN/listen-server multiplayer for the first playable networked version.
2. Web export for browser play, with a realistic networking path that respects browser limitations.

The short version: build the authoritative gameplay model once, then support desktop LAN first. Treat web multiplayer as join-only or relay/server-backed unless a WebRTC signaling flow is added.

## Goals

- Keep the local prototype playable throughout networking work.
- Make the host/server authoritative for scoring, ball physics, trap charge/contact, shot validation, stun, ammo, and point reset.
- Keep clients responsive enough for aiming and movement, but prefer correctness over prediction complexity in the graybox.
- Support a desktop LAN/listen-server MVP before tackling browser multiplayer.
- Support web export for local/practice play early, then add web multiplayer through WebSocket or WebRTC constraints deliberately.
- Preserve automated scenario testing and add network smoke tests once the first network loop exists.

## Key Constraints

### Desktop LAN

- Desktop builds can use Godot `ENetMultiplayerPeer` for LAN/listen-server play.
- A listen host can create the match, own authoritative physics, and accept one client for the first 1v1 version.
- LAN discovery can be deferred; manual IP join is enough for the MVP.

### Browser/Web Export

- Browsers cannot host arbitrary UDP listen servers like a desktop ENet host.
- Browser multiplayer should use `WebSocketMultiplayerPeer` or `WebRTCMultiplayerPeer`.
- WebRTC requires a signaling server and usually STUN/TURN configuration.
- WebSocket multiplayer usually requires a reachable server process, not a browser-hosted LAN listen server.
- Web exports must be tested from an HTTP server, not by opening the HTML file directly.
- Keep renderer and asset choices compatible with the current `gl_compatibility` web/mobile path.

## Networking Strategy

### Phase 1: Authority Boundaries In Local Code

Before adding real peers, make local gameplay flow through server-shaped APIs.

Responsibilities:

- `MatchManager`: authoritative score, match over state, and point reset requests.
- `TeamBall`: authoritative transform, linear velocity, angular velocity, and applied impulses.
- `SpringTrap`: authoritative charge, charge reset, and trap impulse.
- `WeaponController` or future `ShotResolver`: authoritative shot validation and hit result.
- `PlayerController`: local input collection; authoritative position/stun once networked.
- `ArenaManager`: match composition and signal wiring only.
- Presentation controllers: local-only visual output from replicated events.

Tasks:

- Add signals for major gameplay events: `shot_resolved`, `trap_charged`, `trap_triggered`, `player_stunned`, `point_reset_completed`.
- Avoid having UI or shot feedback own gameplay state.
- Keep all reset and scoring code callable by a future host/server path.

Exit criteria:

- Local scenario tests still pass.
- Debug state exposes enough data for a future network smoke test.

### Phase 2: Network Manager Skeleton

Create `scripts/network_manager.gd` as the single owner of peer lifecycle.

Initial API:

- `start_local() -> void`
- `host_lan(port: int = 7000) -> Error`
- `join_lan(address: String, port: int = 7000) -> Error`
- `disconnect_from_match() -> void`
- `is_host() -> bool`
- `get_debug_state() -> Dictionary`

Signals:

- `host_started`
- `join_started`
- `peer_connected(peer_id)`
- `peer_disconnected(peer_id)`
- `network_failed(reason)`

Implementation notes:

- Use `ENetMultiplayerPeer` for desktop LAN first.
- Limit first network match to host plus one client.
- Keep the current bot path available when no client is connected.
- Keep manual host/join input actions for debug, but move real lifecycle out of `Main` and `ArenaManager`.

Exit criteria:

- Host and join commands can create/connect peers without gameplay replication yet.
- Local mode still works with no peer.

### Phase 3: Spawn And Player Ownership

Add deterministic network spawning for two players.

Tasks:

- Assign team 1 to host and team 2 to the first client.
- Keep balls and trap server-owned.
- Set local camera active only for the locally controlled player.
- Disable local input on remote player instances.
- Add player identity to debug state: peer id, team id, local/remote flag.

Possible implementation:

- Use explicit RPC spawning for clarity in the prototype.
- Defer `MultiplayerSpawner` until scene composition is more settled.

Exit criteria:

- Host sees blue as local and red as remote.
- Client sees red as local and blue as remote.
- Local single-player/bot mode still works.

### Phase 4: Input And Player State Replication

Start with conservative authority.

Tasks:

- Clients send input snapshots or commands to host: move vector, jump/float pressed, look delta/yaw/pitch, fire request, reload request.
- Host simulates authoritative player movement initially.
- Replicate player transforms, velocity, stun timer, weapon state, and local camera orientation needed for visual correctness.
- Allow client-side camera look locally if it improves feel, but host remains authoritative for hit validation.

Exit criteria:

- Two desktop instances can move and see each other in the arena.
- Host and client agree on ammo/reload state after reload requests.

### Phase 5: Authoritative Shots

Shots are hitscan, so validate on host.

Tasks:

- Client sends `request_fire(origin, direction, client_fire_sequence)` to host.
- Host checks weapon cooldown/ammo/reload/stun state.
- Host resolves shot using the same shot resolver/weapon logic.
- Host applies impulses/charge/stun outcomes.
- Host broadcasts a compact shot feedback event: path segments, hit position, hit kind, final shot flag, ricochet count.
- Clients render shot feedback locally through `ShotFeedbackController`.

Anti-cheat is not the prototype goal, but basic validation should reject impossible fire states.

Exit criteria:

- Client firing changes authoritative ammo and can hit balls/players/trap.
- Shot path feedback appears on host and client from the same event payload.

### Phase 6: Ball, Trap, Score, And Round State

Host owns the core match state.

Tasks:

- Replicate ball transform, linear velocity, angular velocity, sleeping state if relevant, and team id.
- Replicate trap charge and trigger events.
- Replicate score and match-over state.
- Replicate point reset start/completion.
- During reset, snap players and balls from authoritative state rather than letting clients infer it.

Exit criteria:

- A full point can be scored from either side and both peers see the same score/reset state.
- Trap charge and trigger stay consistent.

### Phase 7: Desktop LAN Smoke Test

Add an automated or semi-automated network smoke path.

Minimum test:

- Launch host instance in automation mode.
- Launch client instance pointed at `127.0.0.1`.
- Wait for connected state.
- Client requests fire/reload or sends deterministic input.
- Host writes authoritative result JSON.
- Client writes observed replicated result JSON.
- Test asserts peer connection, team assignment, shot event replication, score replication, and clean disconnect.

Exit criteria:

- `listen_server_smoke` becomes part of the loop or a separate longer network loop.

## Web Export Strategy

### Phase W1: Web Local/Practice Export

Get the game running in a browser without multiplayer first.

Tasks:

- Add `export_presets.cfg` with a Web export preset.
- Export a web build to `artifacts/web/` or another generated-output folder.
- Serve the output through a local HTTP server for testing.
- Verify canvas renders, input capture works after click/focus, HUD scales correctly, and screenshot/smoke checks have a browser equivalent if practical.
- Add a web note for controls: browser pointer lock requires user interaction.

Exit criteria:

- Browser local/practice mode loads and is playable.
- No missing resource or shader errors in browser console.

### Phase W2: Web Networking Decision

Pick one web multiplayer path after desktop LAN works.

Option A: Native Host Plus Browser Client Over WebSocket

- Run a desktop/headless host that exposes WebSocket multiplayer.
- Browser clients join the host/server by URL.
- Good for quick web-client testing.
- Not a true browser listen server.

Option B: Dedicated WebSocket Server

- Host authoritative game in a native server process.
- Browser and desktop clients connect to the same server.
- Better long-term path for public web play.

Option C: WebRTC Peer-To-Peer

- Browser-to-browser can work with WebRTC data channels.
- Requires signaling and STUN/TURN.
- More moving parts, but closer to peer-hosted browser play.

Recommendation:

- Use desktop ENet for LAN MVP.
- Use WebSocket server/client for first browser multiplayer.
- Consider WebRTC only after the game loop is proven and there is a real need for browser peer hosting.

### Phase W3: Browser-Compatible Network Abstraction

Hide peer type behind `NetworkManager`.

Tasks:

- Add a `network_transport` mode: `local`, `enet_lan`, `websocket`, `webrtc`.
- Keep game code independent of transport choice.
- Ensure RPC names and payloads are transport-neutral.
- Avoid relying on desktop-only socket behavior in gameplay code.

Exit criteria:

- The same match replication code works with ENet and WebSocket/WebRTC peer setup.

## Web Export Verification Checklist

- Export preset exists and can build without editor-only resources.
- Main scene loads from an HTTP server.
- First click enables pointer lock/camera capture.
- Keyboard and mouse inputs work in browser.
- HUD text and crosshair scale at common browser viewport sizes.
- Arena, balls, spring trap, shot paths, and translucent materials render correctly.
- Audio policy issues are documented if audio is added later.
- Browser console has no fatal errors.
- Web build size is tracked before adding final art/audio.

## Multiplayer Verification Checklist

- Local mode still works with no peer.
- Desktop host starts and assigns itself team 1.
- Desktop client joins and receives team 2.
- Local player camera/input attach to the correct player on both peers.
- Host owns balls, trap, score, shot validation, stun, and reset.
- Client fire/reload requests are validated by host.
- Ball impulse, trap charge, score, and point reset replicate to both peers.
- Disconnect returns both instances to a stable menu/local state.
- Network debug state is written to JSON for smoke tests.

## Suggested Next Implementation Order

1. Finish extracting arena geometry and ground/trap detectors from `ArenaManager`.
2. Extract shot resolution into `ShotResolver`, because networked firing will need host-side preview/validation.
3. Create `NetworkManager` with local/desktop LAN lifecycle only.
4. Add deterministic player ownership and local/remote camera/input behavior.
5. Replicate player state, then weapon state, then shot events.
6. Replicate balls/trap/score/reset.
7. Add desktop `listen_server_smoke`.
8. Add web export preset and local browser smoke.
9. Add WebSocket transport for browser clients.