# Design decisions

## Guided Practice — 2026-10-29

- Practice stays in the existing clubhouse scene and uses the same player, can, slipper, charge, lunge, tag, and stun scripts as the game. It starts after character selection, marks a temporary blue toe-line, checks actual actions, then changes the local actor from thrower to Taya for can recovery and tag drills. Leonardo and Kay skip the three-orb special lesson because their specials are not assigned yet.
- The tutorial is solo and changes no network rules or protocol identifiers. Restart restores the course; Free practice removes its movement/throw restriction. Godot 4.7.2 passed scripted thrower checkpoints and real can pickup/reset, Space lunge, contact tag, and stun probes; a normal-resolution guide render was reviewed. Human playthrough and input timing still need review.
- On 2026-10-29, each lesson now holds its success state until Continue, including the handoff to Taya and the final completion screen. Mouse diagrams and keycaps replace long button-name instructions. The tutorial can marker is fitted around the visible standing can, and Taya steps aside after automatic reset so the result can be seen. A Godot 4.7.2 scripted full-course check passed with a wait assertion at every step; rendered mouse-icon and can-reset views were reviewed. Human input pacing remains unverified.
- A later Practice correction restores the can's original base when Taya training starts. Thrower-phase automatic stand-up can move the can's `base` to its landing spot; without restoring it, Taya reset placed the standing can away from the fixed yellow marker. The full-course check now simulates this shifted base, asserts the original base is restored, and verifies the can resets exactly there. Godot 4.7.2 headless and rendered checks passed.

## Throw-off and can-impact sound — 2026-10-29

- Use short original synthesized cues for the opening sliding title, each of the final 3–2–1 counts, throw opening, and a hollow can impact. The five-second run to the toe-line now always finishes so early arrivals still see and hear the full countdown. Each client plays a cue once from replicated stage/deadline and can state; the host remains responsible for hit physics. The can snapshot includes impact strength for matching pitch and level on joiners.
- LAN/online identifiers advance to `canclash-lan-abilities-13` / `canclash-rules-17` because the run-to-line timing and can snapshot changed. Godot 4.7.2 `tests/match_sfx_smoke.gd` passed title, all three synchronized counts, early arrival hold, throw opening, weak/strong can hits, and impact snapshot checks. Physical cross-PC listening remains unverified.

## Can ring and tag handoff — 2026-10-27

- The latest visual correction keeps one yellow ring fixed on the can's ground base through standing, toppled, and carried states. The match disables the can-attached ring, so the marker never travels with a flung can. This supersedes the earlier temporary choice to hide both rings on impact. Taya's standing-can clearance is now 100 pixels, down from 115; toppled and carried cans remain accessible for automatic recovery.
- A valid tag transfers Taya and awards exactly one point, then enters a 2.6-second host-owned `tag_reset` phase. The five-minute match timer pauses. Players cannot move, throw, use abilities, tag, or score while the phase runs. At its midpoint, under the existing darkened tag announcement, the new Taya moves to 115 pixels left of the can and all four throwers return to their toe-line slots. Their active slippers, Rapid Fire extras, and Taya stun projectile are canceled without miss or safe-return points; each thrower has a slipper ready when play resumes. Scores, three-orb charge, and per-player cooldowns persist.
- The phase and paused match time use existing snapshots. LAN/online compatibility advances to `canclash-lan-abilities-9` / `canclash-rules-13` because older clients do not recognize the handoff. Godot 4.7.2 passed local tag-reset and guard-circle smoke checks, a two-process localhost ENet host/joiner handoff probe, and a 960×540 rendered review of standing, displaced-toppled, carried, and reset can states; the ground ring stays fixed throughout. Physical cross-PC LAN and live human input remain unverified.

## Automatic Taya can handling and directional art — 2026-10-25

- The host picks up a toppled can when Taya enters its existing pickup radius and the can is near the ground, without waiting for it to finish sliding or spinning. A carried can resets immediately when Taya reaches the base radius. Neither action needs E or waits for the old 0.68-second action animation; carrying still slows movement. This supersedes the manual can interaction described below. Thrower slipper retrieval is unchanged.
- Head Band, Glasses Thrower, and Curly Haired use the correct down-left/down-right rows from their empty-hand movement sheets for both thrower and Taya movement. Taya walking/sprinting uses those four-frame sheets instead of alternating two throw-recovery poses. Bullcap's release rows now follow the direction order in its authored eight-direction atlas. The original Hat Thrower art stays as the reference.

## Integrated customization, abilities and possession UI — 2026-10-25

- Merge the new lobby character claims, customization and five specials with the relaxed movement artwork, large possession badges, three-second tag delay, manual 15% slower carrying, private aim guides, clean podium and selection sound. Preserve both ability and possession fields in host snapshots.
- Stun and cast locks now suspend LAN prediction and reset its history on state changes. Reaction/cast animation aliases remain available, while item-bearing wind-up/carry artwork stays hidden behind possession badges. Bullcap retains the newer eight-direction release sheet.
- Combined compatibility is `canclash-lan-abilities-4` for LAN and `canclash-rules-8` for online, rejecting either pre-merge build.
- Merge verification passed: Godot import; all-five-character animation, possession, pickup, timing-meter and LAN prediction checks; all-map rules and podium checks; map-selection sound; full five-process localhost LAN character selection/ready/start/match/results/disconnect flow; and two-process special-projectile, steering and stun replication. Physical multi-PC and real internet play remain unverified.

## Map-selection spinning sound — 2026-10-25

- Reuse the user's named spinning-wheel MP3 from the soundtrack Drive folder. Keep the original file intact, skip its silent lead-in during playback and align the final cue with the existing five-second map shuffle. Selection duration, host map choice and networking stay unchanged.
- A scene-owned AudioStreamPlayer plays once on entry, mixes with the continuing lobby track, and stops on transition or early exit. No new global audio manager or network messages are needed.

## Possession icons, tag cooldown and private aiming — 2026-10-25

- Circle badges above each actor show owned slippers or a carried can. Hand props and item-bearing wind-up/carry artwork are hidden; empty-hand release and lunge drawings remain visible. Hidden pickup/place animation clocks still complete normally, and only the host places the can.
- Becoming Taya sets a host-clock deadline three seconds ahead. Tags are rejected before that deadline, while movement and lunges remain usable. The new Taya alone sees a fixed-screen countdown. Reapplying the same role does not restart the delay; the deadline is replicated unchanged to clients.
- Can return stays manual: carry at 85% of normal walking speed, with no sprint boost, and press E near the original spot to place. No automatic return, steering or placement is added.
- Timing meters, trajectory paths and spread previews are rendered only for the locally owned human actor. Other players and bots retain synchronized gameplay state without visible aiming guides on this PC.
- Podium actors disable gameplay overlays entirely so skill circles and possession badges cannot cover their place numbers.
- The new possession regression check covers every character, real pickup/place completion, carrying speed, three-second unlocking and owner-only aim state. Updated animation, pickup and five-process LAN checks retain role/retrieval coverage.

## Movement artwork follows role and slipper ownership — 2026-10-25

- All five characters select relaxed `idle`/`walk`/`sprint` while holding a slipper, separate `empty_` movement while retrieving it, and `taya_` movement only in the Taya role. Role transfers refresh immediately. Existing aim, release, pickup, carry, place and lunge actions remain distinct.
- Head Band, Glasses and Curly receive six relaxed empty-hand sheets derived from their original aiming-walk artwork. Hat and Bullcap keep their authored neutral motion. A small native slipper drawing follows the lowered hand only in free movement when the actor actually owns the slipper; the projectile uses the same silhouette. Original aiming/release artwork is preserved. Bullcap now has its own eight-direction aiming/release sheet, replacing the old walk-frame throw placeholder. Taya still uses the existing character-specific Taya action coverage described below.
- Held-slipper visibility and movement selection update on both host state and replicated snapshots, including the locally predicted LAN actor. Updated animation names require the current LAN/online compatibility versions; old builds are rejected at registration.
- `tests/role_animation_smoke.gd` exercises both starting roles for every character, eight directions, idle/walk/sprint, held/empty/Taya selection, charge interruption and can actions. Pickup and five-process LAN checks verify the live transition paths.

## Five thrower specials and Taya stun — 2026-10-25

- The existing three-orb meter is the sole thrower power system. Retire the draft concept's unimplemented two-hit powered-throw rule. The host fills one orb per confirmed can hit, caps it at three, and spends all three when an armed special slipper actually launches. RMB toggles arming without cost; becoming Taya disarms but preserves the meter. A down or carried can pauses all new thrower shots.
- Character order maps to Rapid Fire (Hat Thrower), Ricochet (Head Band), Self-Returning (Glasses Thrower), Stunning (Curly Haired), and Mind-Controlled (Bullcap Head). Rapid Fire schedules two more shots at 0.25-second intervals, cancels pending shots if the can falls, returns all three automatically, and resolves one hit or miss for the burst. Ricochet redirects within 75 degrees after its first wall bounce. Self-Returning comes home after impact, rest, or timeout; safe-return scoring still requires leaving and recrossing safety. Stunning stops Taya on direct contact. Mind-Controlled turns toward the current host-received cursor at up to 150 degrees per second for two seconds without increasing speed.
- Any Taya has a separate aimed stun slipper on held/released RMB. Its 120-second launch cooldown stays with the player through role swaps, uses no orbs, and works while carrying or when the can is down. It stuns one thrower outside the safe strip for three seconds; any recovered player has five seconds of stun immunity. Space remains the lunge.
- The host simulates special projectiles, validates the request and match state, awards points, and applies stun. Snapshots replicate armed state, cooldowns, stun timers, the main slipper, two bounded Rapid Fire extras, and the Taya projectile. LAN compatibility is `canclash-lan-abilities-3`; online compatibility is `canclash-rules-7`.
- The current animation pass creates eight-direction cast and reaction animation states from each character's existing clean art. Activation glow, colored projectile trails, stun stars, and cooldown arc distinguish them. A generated replacement sheet was rejected because it changed cell transparency and alignment. Dedicated newly drawn action and reaction poses remain an art task, especially Bullcap's throw; the existing Bullcap walk drawings are still the casting source. Do not describe the current aliases as new hand-drawn frames.
- Godot 4.7.2 loaded the match and passed `tests/ability_smoke.tscn`: all five special launches and meter spending, eight-direction state availability, one-score Rapid Fire cap, pending-burst cancellation, cursor turn without speed gain, stun immunity, Taya's carried-can case, and cooldown persistence. Two localhost ENet processes passed `tests/ability_lan_probe.tscn`: the joiner armed by reliable RMB request and saw Rapid Fire extras, Bullcap cursor steering, stun state, and Taya projectile/cooldown. Eight direction contact sheets were saved under `tests/ability_visual/` and inspected at the match's 0.576 actor scale; the repeated cast art and static reaction poses remain visible limitations. Physical five-PC play, real scoring under chained collisions, and full manual input play are still unverified.

## Player customization and lobby character claims — 2026-10-25

- The main menu's former Avatar entry opens player customization for the saved display name and one of five marker colors. Fixed character sprite art is unchanged by the color choice.
- Choose a character in the waiting room before pressing Ready. The host reserves each of the five characters for one player at a time, rejects competing claims, and clears Ready when a player switches. Start rechecks every choice for validity and uniqueness. The waiting-room roster shows each choice and developer bots use the remaining characters.
- A character change replaces that player's waiting-room practice actor while preserving its position. The match uses the host-confirmed roster choice. LAN and online compatibility identifiers advance because registration and character-claim messages changed. This pass has static review only; visual layout, live character switching, and multi-process claim races remain to be reviewed in Godot.

## Screen fit and LAN presentation — 2026-10-25

- Keep the 1920×1080 design canvas centered and scale it uniformly to the available window. On screens with a different aspect ratio, use bars in the spare space so menus, HUD, and camera framing are not cropped or stretched.
- Send host LAN snapshots at 30 Hz while keeping online at 20 Hz. Retain physics-rate client input and host-owned outcomes. Bound remote visual extrapolation to 50 ms and smooth toward the newer snapshots over 35 ms; discard acknowledged input commands in place to avoid rebuilding the prediction history each snapshot.
- Godot 4.7.2 loaded the game headlessly with this setting. The existing two-process ENet responsiveness check passed with 120 ms delayed snapshots and 10% dropped snapshots: 7.965 ms first local movement, 62/62 local moving frames, 47/62 remote moving frames, and 0 px settled drift. A rendered resolution check and physical five-PC LAN latency check are still needed. The earlier 2026-10-24 measurements below predate this tuning.

## Match scoreboard placement and layout — 2026-10-25

- Keep the existing orange panel, dark outline, and shadow, but anchor it 24 pixels from the top and right edges of the game viewport. This removes it from the left play area shown in the user's screenshot.
- Draw the map name as the header, a small court-center line motif, clear player and points columns, alternating dark-orange rows, roster-color markers, and a red Taya badge. Put developer mode information in one quiet footer line. The board updates from the same host-owned scores and role snapshot as before; this is presentation only.
- This change has had static inspection only; check the rendered panel at different window sizes and with five player names before treating the layout as final.

## Three-hit character special placeholder (superseded) — 2026-10-25

- Each participant has an individual three-orb special meter below their character. It starts empty and gains one orb only when the host confirms that player's slipper struck and toppled a standing can during active play. Each slipper can award at most one orb. The meter stays with the participant through Taya transfers and is capped at three.
- At three orbs, show `RMB SPECIAL` below the meter and accept a reliable right-click request. The host validates the active match, player identity, and full meter, then broadcasts a `SPECIAL ABILITY IS COMING SOON` notice. No effect or charge consumption occurs until the five character abilities are specified; this prevents players from losing earned charge to a nonfunctional placeholder.
- The later five-special decision above retired the two-hit powered throw and replaced this placeholder.
- LAN and online protocol identifiers advance because older builds do not carry the orb state or right-click request. This pass has static inspection only; live input, can-hit count, layout, and multi-process replication remain unverified.

## Taya tag announcement — 2026-10-25

- The host alone changes the Taya role after a valid tag. It sends a numbered tag announcement with the new Taya's ID, impact position, and expiry in match snapshots; clients show each red burst once and use the shared clock for the centered notice.
- Keep a bright red `TAYA` label above the current Taya's name throughout play. On a tag, show a short red impact burst and a centered `%PLAYER% IS NOW TAYA!` card with a brief red screen tint. The card does not pause movement or change tag rules.
- This pass has static inspection only; rendered layout and a multi-process tag handoff still need review.

## Opening throw-off and camera — 2026-10-25

- After all human scenes load, place the roster characters near midcourt, show a sliding THROW OFF!! banner over a dimmed screen, and have the host run them through the clear center lane to their own toe-line slots. The host then allows one charged throw per player, with movement locked until it resolves. Bots throw automatically.
- The host compares each slipper's final ground position to the standing can's base. The farthest landing becomes the first Taya. An unthrown or out-of-bounds slipper counts as a forfeit and is ranked farthest; ties use the lowest roster slot. This follows the current player request, which supersedes the draft concept note's proposed toe-line distance. The can stays standing and an accurate slipper stops on contact during the throw-off. No score is awarded for these opening throws.
- A winner card shows the selected player's name, character, and idle portrait before the existing seven-second Taya preparation. Developer-only Play As remains an explicit local override for role testing; LAN and online always use the host's landing-distance result.
- Each client frames its own character and the can in a wider view. Charging widens the view further without moving the camera in response to the cursor. Both throw-off and regular match throws move that client's camera with their own slipper, hold its landing spot for one second, then return to their character. Camera motion and zoom are presentation only; the host still owns throw outcomes.
- Bump LAN and online compatibility identifiers because older clients do not understand this opening sequence. This change has had static inspection only; rendered timing, obstacle pathing, input, and multi-process synchronization still need a playtest.

## Character throw grunts — 2026-10-25

- Use the five English child-voice grunt samples in `assets/audio/voices/`, one per character.
- Play a grunt once when the slipper actually leaves the hand, not when charging starts or the button is released. Host playback follows the release animation frame; clients play when a fresh slipper appears in the authoritative snapshot.
- Keep these as local positional audio. They do not affect host-owned throw rules.
- The 2026-10-25 energy pass keeps the original child voice performances, trims excess silence, speeds each by 10%, compresses gently, and matches their levels. Unprocessed takes remain in `../voice_line_samples/english_cartoon_kids/`.

## Distinct Eskinita and Dusty Yard — 2026-10-24

- Keep COURTYARD's floor, hoops, props and fence placement unchanged.
- Eskinita uses repaired light concrete, edge drains, colorful homes and laundry
  around the perimeter. Its asymmetric roadside cover differs from the court.
- Dusty Yard uses an ochre earth floor, worn paths, palms and an open staggered
  cover arrangement. Replace the shared asphalt rather than recoloring it.
- Retain every non-hoop obstacle, its existing collision and shadows. Perimeter
  scenery is decorative and outside the enclosure. Keep blue/spawns clear, the
  center throwing route open, the can at (1450,610), and fence movement bounds.
- Update map-selection previews/descriptions to the corresponding floor art.
  Both host and client use the same static map configuration; no new gameplay API.

## LAN client movement responsiveness — 2026-10-24

- LAN-only local movement prediction uses acknowledged-input replay and bounded
  history. Smooth remote movement between snapshots; keep host-owned outcomes.
- Send LAN input at physics rate, publish host snapshots after actor physics and
  acknowledge input actually consumed. Replays use explicit recorded timesteps.
- Reset prediction on role/action/phase changes and teleports; stop speculative
  movement after 350 ms without snapshots. Preserve real collision constraints.
- Online retains its existing input/render path and protocol. LAN uses the new
  canclash-lan-motion-1 compatibility identifier so old builds are rejected.
- With 120 ms snapshot delay and 10% loss, local response improved from 172.5 ms
  to 7.2 ms, moving on 61/61 sampled frames instead of 9/61, with zero settled
  position error. This was measured with separate ENet processes on one PC.

## Rules UI removed — 2026-10-24

- Remove the match rules popup, its text and the Rules button. Fresh profiles
  automatically enter the same seven-second Taya preparation as returning ones.
- Retain the existing network acknowledgement transport as an automatic scene-load
  handshake, including client retries. The host starts preparation after all human
  scenes load; no acknowledgement button or saved tutorial flag is required.
- Verified fresh-profile flow, five-process LAN and focused GD-Sync local match
  loading/results. The full GD-Sync check still fails its separate waiting-room
  green-release timing assertion under latency; that behavior was not changed.

## Developer map and opening-role controls — 2026-10-24

- Developer waiting rooms expose Map (Random or any arena) and Play As
  (Random, Player, Taya) beside the existing bot controls. Defaults stay random;
  choices last for this app session and apply only to developer matches.
- Player guarantees a bot is selected as opening Taya and keeps at least one bot.
  Taya selects the local player. Normal role transfers still work after tagging.
- LAN/online keep random maps and opening roles. Remove the developer-code hint
  from Join's visible copy while retaining the existing hidden test shortcut.

## Fence-aligned movement bounds — 2026-10-24

- Replace the inset court blockers with 32-pixel barriers along the visible
  enclosure: inner edges x=153/1721 and y=49/1072. Corners overlap. The bottom fence is lowered 32 pixels to meet the pavement edge,
  plus a 16-pixel artwork offset compensating for transparent tile padding.
- Match slipper bounds and camera framing use that full enclosed rectangle.
  Blue-zone permissions, prop collisions and the can base remain unchanged.

## Basketball hoops — 2026-10-24

- COURTYARD keeps the two hoops at the original authored court-end positions.
- Shared map configuration removes the entire hoop instances from ESKINITA and
  DUSTY YARD, including shadows and collision. Other props retain their layout.

## Supplied music — 2026-10-24

- Preserve the five named MP3s from the supplied Drive folder in assets/audio/music.
- Main menu/results use mainmenu; lobby/Practice/selection/preparation use lobby.
  Active matches use battle until 60 seconds remain, then intense battle.
- A persistent two-player autoload loops and crossfades tracks, without restarting
  on repeated timer snapshots. The host-owned match timer chooses the cue locally
  on every PC. Retain trailer music for trailer use; no trailer scene exists yet.


## Character size and role names — 2026-10-24

- Reduce live match/waiting-room characters by another 20%, from scale 0.72 to
  0.576. Shared root scaling keeps sprites, colliders and throw origins aligned.
- Overhead names are green for throwers and red for Taya, refreshed immediately
  by the shared role setter on hosts and replicas. Keep name text readable.


## Gameplay adjustments — 2026-10-24

These decisions supersede earlier grace-period, initial-Taya, can recovery and
throw-meter tuning below, following Gameplay adjustments.docx and user corrections.

- The protected blue area covers the visible left floor to the fence and curb,
  ending at x=530. Only throwers inside it can begin/release a throw. Taya cannot
  cross that boundary, including lunges. Validation is host-owned.
- After rules acknowledgments, choose Taya randomly from all participants,
  including the human in developer mode. Freeze throwers for seven seconds while
  Taya can move, show the selected name and countdown, then start 600 seconds of
  scoring. A solo developer player is Taya and also resets the can manually.
- The can's original and reset position is (1450,610), near the far-right end.
  Taya starts 180 pixels to its left. Match cans stay toppled until Taya uses E
  to pick up, carries to the original circle, and uses E to place. Practice keeps
  automatic recovery. Existing power-dependent tumbling remains.
- Green covers 4% of the meter, orange 23% on either side, red the remaining 50%.
  Sweep timing, randomized targets and power/error ranges remain. Base horizontal
  launch speeds increase 20%; match-specific 1.45 speed scaling keeps the far-right
  can reachable from blue. Actual physics and preview use the same values.
- A bottom foreground fence reuses the upper fence tiles and joins the lower
  curb on every map. The existing bottom world border remains the collider.
- Keep all 17 original prop nodes and their collisions. Arrange benches, hoops,
  barrels, crates, tires and cones with clear spacing and an open throwing lane;
  do not interpret cleanup as deleting the scenery. Account for the authored
  level root offset when positioning props.
- Keep characters at 0.72 scale and use the existing shared Taya/thrower artwork
  and role actions. Each bot gets its own throwing position inside blue.
- A local Camera2D follows the player/can midpoint with 0.9 baseline zoom and
  widens when needed to keep both visible. HUD uses its existing CanvasLayer.
- Results retain character identity and show silver/gold/bronze left/center/right,
  remaining ranks below, empty unused places, stable tie ordering and shared wins.
- Network compatibility is canclash-rules-3. Match phase deadlines use synchronized
  host time with bounds to avoid displaying more than 7 seconds or 10 minutes.

Acceptance: all-map geometry, throw eligibility, Taya boundary/lunge, seven-second
preparation, manual E recovery, power-dependent tumbling, far-right throw reach,
0–4 bots, movement/pickup/waiting-room checks, five-process LAN, and GD-Sync local
transport under latency/loss. Viewports inspected at 1920×1080 and 1280×720.
Headless tests still emit the existing tree-shader dummy-renderer diagnostic;
real OpenGL captures do not. Real cloud connectivity remains unverified.


The original concept note is the current design reference.

## Open decisions

- Confirm Godot 4 and the exact engine version.
- Ranking tie-break rule.
- Opening throw-off ties and the precise distance measurement.
- Arena setting, visual style, layout, and camera implementation.
- Input bindings, charge times, throw speeds, and power-up balance.
- Lunge distance, wind-up, and recovery.
- Disconnect behavior and interrupted matches.
- Ownership and recovery of slippers when roles change.
- Miss scoring when the can is already toppled.

Record each resolved decision here with its date and rationale.

## Match timer — 2026-10-26

- The user set active match scoring to five minutes (300 seconds). The separate
  opening throw-off and seven-second Taya preparation remain outside this timer.
  This supersedes the earlier three-minute and ten-minute durations below.

## Adjustments implementation — 2026-10-21

- The requested match duration is three minutes, after a separate 30-second
  grace period. First-time rules acknowledgments precede the grace timer; all
  human members must finish reading. The rules remain available during play.
- The roster contains actual members rather than five placeholders. LAN starts
  with a host, accepts four clients, and requires at least two ready humans to
  start. The `developer-mode` Join shortcut starts with one human and fills the
  match with four computer-controlled opponents. Practice is a separate solo mode.
- Seven-character room codes encode the host's IPv4 address on UDP port 54652.
  They remain valid while the address is unchanged. Direct-IP joining is also
  supported, without a discovery server or internet matchmaking dependency.
- Slippers collect automatically at first landing when the owner runs within
  72 pixels. Each member's stable color marks their name, ring, roster badge,
  and slipper outline. This supersedes E-based retrieval below. Leaving the
  arena hides the slipper for three seconds, then returns it to the owner's hand.
- The map roulette chooses one of three variants of the existing 2D level:
  Courtyard, Eskinita, or Dusty Yard. Their prop layouts and palettes differ;
  the existing art remains the source. Selection is host-owned and shared.
- Initial Taya is chosen from the host's match seed; developer mode starts a bot
  as Taya. This is the provisional match entry for the adjustments, rather than
  claiming the concept's opening throw-off is implemented.
- Local statistics persist in `user://profile.cfg`. A successful throw is a
  projectile's first standing-can hit, which also records one knockdown. Normal
  LAN results count wins/losses once per match ID; tied leaders share victory.
  Practice and developer games never change lifetime totals. `CAN_CLASH_SAVE_PATH`
  isolates automated test profiles from the user's data.
- The match host owns simulation and scoring. First landing prediction includes
  existing World/divider ricochets and standing-can deflection. Prediction is a
  preview rather than a guarantee if another player changes the can mid-flight.
- Safe-return points require leaving the strip, physically collecting the owned
  slipper, and re-entering the strip. Out-of-bounds respawns do not earn that point.

## Slipper pickup responsiveness — 2026-10-19

- Throwers can press or hold E while walking or sprinting into their own slipper's
  existing 72-pixel pickup radius. After its first landing, the slipper can be
  retrieved during its small floor bounce (up to 12 pixels of simulated height),
  sliding, or spin. Collection preserves movement and clears ownership immediately
  so another throw can begin; there is no pickup animation or cooldown.
- This supersedes the older settle-before-retrieval rule below. Initial flight
  remains ineligible, as do slippers owned by another player or outside reach.
  Taya's can pickup and placement timing stays unchanged.
- Check with `godot --headless --path . --script res://tests/slipper_pickup_smoke.gd`.

## Provisional prototype choices — 2026-10-18

- The local 2D Taya prototype displays the lunge in eight directional sectors so the body and feet face the target while steering. Five right/front/back source views and horizontal mirroring cover all eight sectors. This only resolves the prototype's animation coverage; the concept note's 2.5D camera and four-direction movement remain a team design decision.
- The lunge uses four full-body key poses and begins recovery when gameplay movement lands. Its initial 210-pixel travel, 0.13-second wind-up, 0.30-second travel, and 0.20-second visual recovery were provisional tuning values for playtesting.
- The local 2D player prototypes initially used a 27-pixel circular feet collider on the Player physics layer with World and Player masks. Taya requests a tag on body contact as well as by proximity. Match authority still has to validate and award tags.

## Local collision tuning — 2026-10-19

- Players stay solid to one another during ordinary movement. A Taya lunge temporarily ignores only its locked thrower's body when the remaining lunge reach can carry Taya past that body. The lunge can tag while passing through, then restores collision at a clear landing position. Short lunges still stop at contact. World obstacles and other players continue to block the dash. This is a local prototype rule; the host still needs to validate tags and role changes in a match.
- After a rendered preview showed shoes still overlapping, the prototype player bodies use a 65-pixel circular footprint and a 132-pixel tag distance. Lunge travel is 300 pixels so a close target can still be crossed and the Taya can land beyond the larger body. These are visual and gameplay tuning values for the local 2D prototype, not a final meters-to-pixels decision.
- The Taya demo now instances the existing Head Band `CharacterBody2D` player scene as its stationary second actor. Local input is disabled on that instance because this preview has only one keyboard. Its separate Head Band art and movement script remain available when controlled independently later.
- The Taya demo sorts actors by their feet position: a player lower on the screen draws in front of a player behind them. Player collisions remain 65-pixel circles around the feet, so normal movement cannot merge the bodies while the upper sprites may overlap naturally. The lunge still uses its targeted, temporary collision exception and restores a clear landing.

## Local slipper and can motion — 2026-10-19

- A Player Neutral thrower has one owned slipper in play. Charge increases launch speed from 260 to 540 pixels per second and gives it a longer arc. The slipper follows the exact cursor direction, sweeps its path against standing cans, ricochets off World-layer obstacles, bounces on the floor, and remains where it stops. Only its owner can retrieve it with E after it settles; another throw is blocked until retrieval.
- A standing can accepts one moving-slipper impact, tips, and receives linear and angular motion based on the incoming direction, speed, and charge. It bounces off the floor and World-layer obstacles, loses momentum, and settles on its side. Taya can pick it up only after it settles. These are provisional screen-pixel tuning values for the local 2D prototype, not final match balance.
- The existing Hat Thrower and silver can art stay intact. The left diagonal aim and release rows require different mirroring; up-left needs mirroring in both. A separate `scenes/Slipper can demo.tscn` lets one keyboard exercise charge, impact, E retrieval, and a demo-only R can reset. Host validation, scoring, slipper ownership on role transfer, and network replication remain match integration work.

## Character role scenes — 2026-10-19

- Each of the five characters has a separate `Thrower <Character>` and `Taya <Character>` scene for choosing a starting role. They share one local mechanic controller, collider size, and feet origin. The controller's `set_taya_role()` remains available for a later authoritative role swap.
- On 2026-10-25, Head Band, Glasses Thrower, and Curly Haired use the existing empty-hand release recovery frame for their normal idle. Their supplied `idle_throw` sheets are aiming poses, so those remain exclusive to charging. Bullcap and Hat Thrower keep their existing neutral idle art. This reuses current full-body drawings; dedicated multi-frame neutral idles for the other three are still an art task.
- The older character animation atlases were preserved as reusable SpriteFrames resources. Head Band, Glasses, and Curly use existing empty-hand release poses for Taya so no character visibly carries a slipper in that role. These are temporary visual coverage until dedicated Taya motion sheets exist; Bullcap's existing directional walk art likewise times its throw release until authored throw frames exist.
- The old prototype scenes were removed after the level, character selection, and compatibility Player scene were updated to use named role scenes. The combined local preview is for visual and mechanic review only; its R can shortcut is outside match rules.

## Player customization — 2026-10-25

- Main-menu Customize now opens a full-screen live preview. Players can set their name and marker color, and equip a duck hat plus either a bow or scarf (or neither). The five character models in the preview are visual samples; character claims remain exclusive in the lobby.
- Cosmetic choices are saved locally for the customization demo only. They are absent from registration, roster replication, and all lobby/match actors. Name and marker color retain their existing gameplay behavior. The LAN/online protocol remains at the character-claim version.
- The preview holds one fixed pose per character: neutral art for Hat Thrower and Bullcap Head, a menu pose for Head Band and Glasses Thrower, and an existing idle pose for Curly Haired. Hat Thrower and Bullcap Head use a preview-only masked frame when the duck hat is chosen so their baked-in hats do not stack with it. The duck, bow, and scarf fit to alpha-thresholded painted bounds and character-specific size ratios. Match animation atlases and gameplay sprites remain untouched.

## Can-down throw pause — 2026-10-25

- In a match, throwers may start or release a slipper throw only while the can is standing. Toppled and carried states block new throws until Taya resets the can at its base. A charge in progress cancels if the can falls; slippers already in flight continue normally. The opening throw-off remains one throw per player, and standalone movement demos keep their prior behavior. The host applies the rule; clients use the replicated can state for the local status label and movement prediction.

## Leonardo and Kay roster — 2026-10-26

- Leonardo and Kay are selectable in the lobby, with both Thrower and Taya scenes. The match remains capped at five PCs; seven characters are choices, not seven players. Repeated choices remain allowed under the current lobby rule.
- Their thrower roles use ordinary charged slippers. They do not show or fill three-orb meters and cannot arm a character special until their abilities are designed. Their Taya roles retain the common stun slipper, cooldown, lunge, can and tag rules.
- All eight directions have character-specific idle, walk, sprint, aim and throw poses; Taya uses the same movement bank plus dedicated can pickup/place and lunge poses. The common stun/reaction effects remain shared. The game protocol identifiers advance for the new roster.

## Character selection before the lobby — 2026-10-27

- Local Host, Local Join, Online Host/Join, and Practice now open the full-screen seven-character selection scene before entering or creating a room. The character choice is saved locally on confirmation and sent with room registration; the host validates the index. The waiting-room Choose Character button is removed. Duplicate choices remain allowed.
- LAN and online compatibility identifiers advance because registration now carries the character index. A joining player must use the same updated build as the host. The existing room Ready gate still requires a valid character.
- The selection screen crops empty margins from each portrait at runtime, keeping the existing sprite art while showing the seven characters at readable sizes. Godot rendered the screen at 960×540; a headless smoke check passed Practice and LAN Host entry with the chosen roster character. A two-process localhost ENet probe passed host and joiner registration with the same Kay choice on both. A physical joining PC and online service were not tested in this pass.
- The screen now follows a roster-and-preview layout: a compact grid of seven portrait buttons on the left and a large selected-character preview, full name, and thrower special on the right. The small tiles use short names to stay legible at 960×540; the full names remain in the preview. The existing Titan One lettering and warm Can Clash palette frame the blue showcase. This changes only selection presentation, not character rules or room registration.

## Character selection inside the lobby — later 2026-10-27

- The pre-lobby ordering above was superseded by the user's correction. Host/Join connection now completes first; the waiting-room scene opens, then the roster-and-preview character screen appears as a blocking popup over it. Confirming a character sends the normal host-validated claim, saves the local preference, closes the popup, and returns control to the same lobby. Leaving from the popup exits the room.
- Players register without a character (`-1`) and cannot Ready until they confirm a choice. The LAN/online registration packet returns to three arguments, with identifiers `canclash-lan-abilities-8` / `canclash-rules-12` so mismatched builds reject clearly. Repeated character choices remain allowed.
- A Godot smoke check passed popup creation, blocked lobby controls, host claim, and return to lobby. A two-process localhost ENet probe passed host and joiner claims after both entered unselected. The existing waiting-room interaction smoke check passed after selecting a character. The popup was rendered at 960×540. Physical cross-PC LAN and the online service remain unverified.

## Can guard, aim, and impact tuning — 2026-10-27

- While the can stands in a match, Taya's feet stay at least 115 screen pixels from the can's visual center, beyond the yellow ring and the player's foot collider. This applies to walking, sprinting, predicted movement, lunges, role transfers, and can reset. The restriction lifts when the can topples so Taya can recover it. The match host remains authoritative; clients use the same movement rule for prediction.
- The standing can's slipper-hit radius is 24 pixels, close to its painted width instead of the former 35-pixel target. The aiming guide shows only its first eight path points and no exact landing crosshair, so players still see release direction without a full solution.
- A perfect green release launches 20% faster than the normal charge-speed formula. Can knockback, hop, and spin now scale with the slipper's actual impact speed and charge; wall and floor bounces and friction still determine where it settles. These are provisional match-balance values.
- Godot 4.7.2 headless checks passed `tests/guard_circle_impact_smoke.gd`, `tests/can_tumble_smoke.gd`, and `tests/skill_throw_smoke.gd`. The new check covers all eight approach directions, toppled-can access, reset clearance, green speed, and a fast hit that carries the can over 150 pixels from its base. Rendered match play and physical LAN are not yet verified. The older `tests/gameplay_rules_smoke.gd` currently stops at its stale 600-second timer assertion; the match duration has since changed.

## Close-contact tags and player spacing — 2026-10-27

- Player blocking uses a fixed eight-corner convex footprint around the lower body and shoes rather than the whole sprite silhouette. Hair, hats, and arms can visually overlap as players pass behind one another; feet remain blocked. The footprint is derived from each neutral sprite, with Leonardo and Kay's wider source art tuned separately.
- Taya's automatic contact-tag distance is 54 world pixels in the integrated match, down from 132. Ordinary movement collision still triggers a tag on actual body contact. Lunge recovery and post-tag separation use a 90-pixel scene clearance multiplied by actor scale, avoiding the former oversized gap.
- LAN/online compatibility identifiers advance to `canclash-lan-abilities-10` / `canclash-rules-14` because older clients would predict a different collider and tag range.
- Godot 4.7.2 measured player contact at 40–54 pixels in all eight directions at match scale; the host emits no tag at 90 pixels and emits one at 50. Tag reset, can guard, Leonardo/Kay match, and two-process localhost LAN handoff checks passed. A physical cross-PC match remains unverified.

## Taya's facing-direction dash — 2026-10-27

- Space commits Taya to a straight dash in the character's visible eight-way facing direction. The dash no longer picks a nearby thrower, curves toward a moving target, or uses the cursor as a fallback. The existing ray check only permits a pass-through of a thrower directly in that path when Taya can land beyond them; it does not change the dash direction. Actual contact still uses the close-range tag rule.
- LAN/online identifiers advance to `canclash-lan-abilities-11` / `canclash-rules-15` so mismatched dash behavior cannot join the same match. Godot 4.7.2's facing-dash smoke check passed cursor-away, off-path thrower, straight-path tag, and collision restoration scenarios. Physical cross-PC play remains unverified.

## Wider personal match camera — 2026-10-27

- Keep the existing local Camera2D in each player's match process. Its normal maximum zoom is 1.25 instead of 1.5, so more of the court is visible while the player and can remain in frame. Thrower charging or Taya stun aiming widens further to 1.05; following an airborne slipper uses 1.18. These values only affect presentation.
- Clamp camera framing to the full 1920×1080 court artwork rather than the smaller collision arena, so the wider view can still pan with the local player. Godot 4.7.2's `tests/match_camera_smoke.gd` checked normal/charging zoom, visible player and can, player-dependent panning, and a 960×540 window resize. Rendered normal and aiming views were reviewed in `tests/match_camera_{normal,aim}.png`. The LAN protocol remains at `canclash-lan-abilities-11` because camera framing is local.

## Smaller match players — 2026-10-27

- Set the shared match and waiting-room actor root scale to 0.52, about 10% below the prior 0.576. Court art, obstacles, can, movement speeds, and camera zoom stay at their existing world sizes. Root scaling keeps every role's sprite, foot collider, shadow, and throw origin aligned; overhead text still counter-scales for readability.
- Reduce the host's contact-tag reach from 54 to 49 world pixels to follow the smaller bodies. Lunge landing and tag separation already multiply their clearance by actor scale. Keep the can guard boundary at its world position, preserving can-gameplay distances.
- Correct AtlasTexture padding when fitting Leonardo and Kay's lower-body colliders, placing their collision shapes at their visible feet. LAN/online identifiers advance to `canclash-lan-abilities-12` / `canclash-rules-16` so old clients with larger or misaligned colliders cannot join. Godot 4.7.2 measured player contact at 36–49 pixels in all eight directions; a tag at 45 pixels and no tag at 90 passed. All seven characters were checked against fences and corners across the three maps. The facing dash, can guard, tag reset, Leonardo/Kay match, player/can camera framing, and a two-process localhost LAN handoff passed. Normal-match and collider renders were reviewed. Physical cross-PC play remains unverified.

## Idle and side movement art — 2026-10-28

- Give Head Band, Glasses Thrower, and Curly Haired a truly neutral eight-direction idle rather than holding the first walking stride. Use a separate four-phase side walk and faster, leaning side sprint for each; mirror the right-side cycle for left movement. Preserve each authored left-facing idle drawing without mirroring it.
- Normalize the newly drawn poses by visible alpha height and anchor their shoes to the actor origin. This is visual-only, so it does not change the host's movement or collision rules or the LAN compatibility identifier. The older six-direction walk/sprint art stays in place until a replacement passes pose consistency review.

## LAN joiner visual smoothing — 2026-10-28

- Preserve the existing 30 Hz host snapshot rate and host-owned physics. Smooth only the joiner's can sprite and slipper presentation between snapshots, and keep remote locomotion frames' locally fitted size and foot anchor. Snap on new projectiles, can state changes, and large position corrections. This avoids changing hit/collision decisions or adding bandwidth for a visual fix. LAN/online compatibility identifiers remain unchanged.

# Controls settings — 2026-10-29

- The main-menu gear opens a Controls screen. Keyboard/mouse and controller layouts are stored separately in the existing profile file, and each gameplay action can be rebound. Duplicate bindings swap the old assignment. A chosen controller falls back to keyboard/mouse while disconnected and resumes after reconnection.
- Controller defaults: left stick movement, right stick aim, left trigger sprint, right trigger hold/release throw, right bumper special or Taya stun, A slipper pickup, and B lunge. Controller aim holds its last stick direction when released. Windows handles Bluetooth pairing; the game binds to the first connected controller on each PC. Gameplay and LAN packet formats are unchanged.
- Godot 4.7.2 passed `tests/controller_controls_smoke.gd` and a rendered Settings review at `tests/settings_preview.png`. Physical controller feel and cross-PC LAN play remain to be checked.

## Enhancement version: match feedback and awards — 2026-11-06

- This repository is a separate enhancement copy of Can Clash; the main repository is unchanged.
- A rising "+N" in the scorer's color appears over a player whenever their match score goes up. Every peer draws it from the score changes it already receives in snapshots, so nothing new is sent.
- In the last ten seconds of a match the timer pulses red and a tick plays each second, rising in pitch.
- The local camera shakes briefly when the can is knocked down (stronger for harder hits) and when a tag hands over the Taya role. This is presentation only.
- The host now counts each player's can hits, tags and safe returns and adds them to the final rankings. The results screen shows Sharpshooter, Tag Master and Safe Hands award cards; ties are shared and an award with no count is hidden. Results also say "1 point" instead of "1 points".
- LAN/online protocol identifiers are unchanged: rankings gain extra dictionary keys, and snapshots are untouched.
- Godot 4.7.2 passed `tests/enhancements_smoke.gd`. Tag reset, match camera, match sounds, gameplay rules, guard circle and new-roster match checks pass as before. `adjustments_smoke`, `possession_rules_smoke` and `skill_throw_smoke` fail identically on the original code, so those failures predate this change. Physical LAN play is unverified.

## Enhancement version: VS AI, smoother motion, effects and arena ambience — 2026-11-06

- **VS AI mode.** A main-menu VS AI button opens a picker for Easy, Normal or Hard and 1–4 opponents, then the usual waiting room and character choice. It reuses the offline developer room, so no network code is involved and statistics are not saved. Opponents are named CPU 1–4, and the waiting room, scoreboard and results name the difficulty. Difficulty sets each bot's throw-release spread around the sweet spot (Easy ±0.30, Normal ±0.12, Hard ±0.03), aim error at the can (70/30/6 px), decision delay (0.45/0.2/0 s), Taya's dash range (170/230/290 px) and whether an Easy Taya sprints. Developer-mode bots keep their original full-strength behavior.
- **Smoother motion.** The match host (which includes every offline game) turns on Godot's physics interpolation for players, the can and slippers, so 60 Hz simulation draws smoothly on 120/144 Hz screens. Phase changes and tag resets snap without smearing. The camera and effects move per frame and stay uninterpolated. Joiners keep their existing snapshot smoothing, so LAN/online behavior and protocol are unchanged. Interpolation is switched off again when the match scene exits.
- **Effects.** A can knockdown spawns a flash, ring, sparks and tin shards scaled by impact strength. Thrown slippers puff dust on each floor bounce.
- **Arena ambience.** Drifting cloud shadows (noise shader) cross every map, a warm vignette frames the screen under the HUD, and courtyard trees and yard palms sway. Each map has its own particles: leaves on the Courtyard, warm dust motes in the Eskinita and blowing sand on the Dusty Yard. These are local visuals only.
- **Screen shake setting.** Settings has a saved SCREEN SHAKE ON/OFF toggle as a reduced-motion option.
- Godot 4.7.2 passed `tests/enhancements_smoke.gd` with the new checks. The menu, VS AI picker and all three arenas were rendered and reviewed. Bot balance per difficulty and the feel on a high-refresh monitor need human play.

## Enhancement version: seamless running and 2.5D depth — 2026-11-06

- **Seamless running.** Five of the seven characters run on four drawn frames at 6–11 fps. Instead of new art, each walk/sprint frame now cross-fades into the next (up to 55%), the body rises between footfalls (3 px walking, 6 px sprinting) and leans into sideways runs. Hat Thrower and Bullcap, which already have 8–16 frames, get the same polish. It is computed locally from the sprite each peer already shows, so snapshots and the protocol are unchanged.
- **2.5D depth.** Every prop and player casts a soft silhouette shadow folded onto the floor and slanted down-right from an upper-left sun. Prop shadows anchor at the lowest visible pixel, because the prop images carry transparent padding. Player shadows follow the current animation frame and stay on the ground while the body bounces. A warm additive sunlight from the upper left and deeper shade to the lower right reinforce the light direction. Gameplay, collisions and the camera are unchanged, so the game stays top-down 2.5D.
- Godot 4.7.2 passed `tests/enhancements_smoke.gd` (shadow anchoring, blend frame on and off) plus the role animation, motion polish, roster, collision, waiting room, practice, tag, camera, rules, pickup, lunge and fence suites. Rendered courtyard and close-up running views were reviewed. Motion feel in live play still needs a human look.

## Enhancement version: generated running in-betweens — 2026-11-06

- New in-between frames were generated with open-source RIFE (`rife-ncnn-vulkan`, `rife-v4.6`, run locally on the GPU) from the existing drawings. Each frame goes on a flat green key, is interpolated in one pass so colour and outline move together, is keyed back to transparency, and is snapped to that sheet's own palette for clean cel colours. The original drawings stay at the even frame positions, so no hand-drawn art was replaced.
- Head Band, Glasses and Curly: every walk and sprint direction now has 8 frames (the `motion_polish` side sheets and `relaxed` cardinal/diagonal grids). The loaders count columns from each sheet's size and scale the frame rate, so the stride timing is unchanged. The game sizes these frames by their full alpha bounds, and the source art carries a faint haze above each drawing. Generated frames therefore get a 1/255-alpha marker at the neighbours' interpolated top and bottom so they are not drawn about 15% larger.
- Leonardo and Kay: diagonal and side **walks** gained generated `*_inbetween.png` sheets, registered through `tests/build_new_roster_atlas_regions.py`; existing regions are unchanged. Their diagonal and side **sprints** were reviewed and rejected, because black trousers over large leg swings smeared, so they keep 4 drawn frames plus the code blend. Hat Thrower (8) and Bullcap (16) already had enough frames.
- The code cross-fade now runs at 40% strength on cycles with 8 or more frames. Godot 4.7.2 passed `motion_polish_smoke` and `new_roster_probe` (updated to the new frame counts, with every frame on the foot line at the fixed height), plus the role animation, roster match, enhancement, collision, waiting room, practice, tag, lunge, pickup and rules suites. Side and diagonal walk strips for all seven characters were rendered and reviewed. The generator scripts are in `tools/sprites/`.

## Enhancement version: game-wide visual polish — 2026-11-06

- **Screen fades and button motion.** A new `VisualPolish` autoload fades every scene in from a warm dark tint (0.32 s) using the engine's `scene_changed` signal, and gives every Button a small hover/focus lift (1.05×) and press squash (0.94×) through `node_added`. No screen had to be edited, and input handling is unchanged.
- **Main menu entrance.** The logo pops in, then the left and right button columns slide in from their screen edges in a short stagger, each with its shadow plate.
- **Pause menu.** The placeholder is replaced: Esc or a controller's Start opens Resume / Settings / Leave Match over a blurred, tinted view of the match. VS AI and other offline games truly pause; LAN and online matches keep running for everyone, and the menu says so. Controller B is not used because it is Taya's dash.
- **Match HUD.** The timer sits on a dark pill that shrinks to its text. A player's scoreboard row flashes gold and their score pops larger when it rises.
- **Hit-stop.** Offline matches briefly slow time (70 ms on a can knockdown, 90 ms on a tag) for impact. Networked matches never bend time, and the Screen Shake toggle also turns hit-stop off.
- **Results.** Podium blocks rise third → second → first, players and names drop onto them, award cards slide in and confetti in the winner's colour falls for a moment.
- Godot 4.7.2 passed `tests/enhancements_smoke.gd` (pause/resume, hit-stop restore, game-wide button hookup) plus the waiting room, practice, character select, controls, bots, music, camera, match sound, tag, rules, motion, roster and map suites. The menu, HUD, pause and results screens were rendered mid-animation and settled, and reviewed.

## Enhancement version: steady-scale run cycles — 2026-11-06

- **This reverses the earlier "every frame is 210 px tall" rule for idle, walk and sprint.** That rule scaled each frame by its own visible height, so the body grew and shrank as the legs opened and closed: up to 14% within one stride (Hat Thrower's side sprint), 12% for Curly's side and Kay's down sprints, and 7–10% elsewhere. Only Bullcap was steady. It also flattened the bob drawn into the poses.
- Each animation now has **one scale**, taken from its average visible height, so the average stays 210 px and characters keep their overall size. Feet are still anchored per frame. This covers all three loaders: the shared base (Hat Thrower), the polished/relaxed loader (Head Band, Glasses, Curly) and the new-roster aligner (Leonardo, Kay). The Taya-only lunge/carry poses keep their own fitting. Measured scale variation is now 0.0% in every walk and sprint, in all directions, for all seven characters.
- The procedural stride bounce dropped from 3/6 px to 2/4 px (walk/sprint), because the drawn poses now show their own bob. The bounce stays phase-locked low on foot contact and high mid-stride.
- The motion principles (a constant body size, contact-low/passing-high bob, forward lean) follow a user-supplied 8-direction run-cycle reference (Slynyrd's top-down run tutorial). Only principles were used; no design or pixels were copied.
- `motion_polish_smoke`, `new_roster_probe` and `locomotion_audit` now assert one scale per cycle, a 210 px average height and planted feet. Those plus the role animation, enhancement, roster, collision, waiting room, practice, tag, lunge, pickup, rules and camera suites pass on Godot 4.7.2. Side and diagonal sprint strips for all seven characters were rendered and reviewed.

## Enhancement version: second in-between pass (16-frame runs) — 2026-11-06

- To remove the remaining "skipping" look, every walk/sprint cycle is doubled again with RIFE. Neighbouring poses are now close together, which is where interpolation is cleanest. Rather than one importer per sheet format, `tools/sprites/export_locomotion_frames.gd` exports every frame as the game builds it. `tools/sprites/locomotion_inbetweens.py` generates one in-between per neighbouring pair (544 pairs) and packs them into one atlas per character under `assets/characters/sprites/inbetween/`. `scenes/locomotion_inbetweens.gd` then installs them in `_prepare_movement_banks`.
- Pairs are keyed by their two source images, so Taya, empty-hand and mirrored animations share frames. An animation is rebuilt only if every pair is present; it then has twice the frames at twice the rate, so the stride timing is unchanged.
- Result: Hat Thrower, Head Band, Glasses and Curly run on **16 frames** in every direction. Leonardo and Kay have 16-frame walks and front/back sprints. Rejected after review at game scale: Leonardo's and Kay's side/diagonal sprints (4 drawn frames; black trousers over large swings smear) and Bullcap (already 16 drawn frames; doubling produced faint cross-faded frames).
- Fixes found during review: (1) the key colour is now chosen per character, because green-wearing characters (Bullcap, Hat Thrower, Curly) were keyed on green and lost colour; they now use cyan. (2) `_visible_bounds` adds an AtlasTexture's margin. Tightly packed frames (and the 12 px-margin relaxed sheets, by about 2 screen px) had their feet anchored in the wrong place.
- Texture memory for a 5-player VS AI match rose from about 705 MB to 900 MB. The generated atlases stay lossless so alternating frames look identical; VRAM compression of `inbetween/*.png` is the lever if low-memory PCs need it. Godot 4.7.2 passed `locomotion_audit`, `motion_polish_smoke`, `new_roster_probe` and `role_animation_smoke` (updated to 16 frames and to accept the generated atlas), plus the enhancement, roster match, collision, waiting room, practice, tag, lunge, pickup, rules and camera suites. 16-frame strips for all characters were rendered and reviewed.

## Enhancement version: drawn in-betweens for Leonardo's and Kay's sprints — 2026-11-06

- Leonardo's and Kay's side and diagonal sprints were the last cycles still on 4 drawn frames, because RIFE smeared their black trousers over the large leg swings. Each now has **8 frames**: the 4 original drawings plus 4 new in-between poses (down and up for each leg), made with SpriteCook (Nano Banana 2.1, detailed mode) from the character's own sheet as the reference. No other game's art was used. Every original drawing is unchanged and stays at the even frame positions.
- New sheets: `side_sprint_cycle_inbetween.png` (1 row) and `sprint_diagonal_v2_inbetween.png` (down-right and up-right rows) for both characters. Each pose is scaled so its body matches the drawn frames (Kay's side by skin area, the rest by opaque area per row). Kay's back-view diagonal row was drawn facing up-left, so it is mirrored. The existing `*_inbetween` loader in `new_roster_player.gd` interleaves them and doubles the frame rate, so the stride timing is unchanged; no loader code changed.
- `tests/build_new_roster_atlas_regions.py` registers the sheets. Each sprint pair shares its own canvas: the new up poses stand taller than the shared motion canvas, and the RIFE frame index is keyed by each cell's padding, so growing the shared canvas would have dropped Leonardo's and Kay's 16-frame walks. Only the two sprint pairs' canvases changed; every existing cell rectangle is unchanged. `tools/sprites/new_roster_inbetween.py` no longer touches the sprint sheets, so a RIFE rerun cannot overwrite them.
- Known weak spots: Kay's side up poses have slightly longer legs, so her head rises about 10% on those frames; Kay's diagonal down poses are a deep two-foot crouch; one Kay down-right frame has a small stray hair blob by the hand; Leonardo's new poses are close to his contact/passing poses. A second RIFE pass on these 8-frame cycles (16 frames) is possible by dropping the Kay/Leonardo sprint entries from the `locomotion_inbetweens.py` skip list.
- Godot 4.7.2 passed `new_roster_probe` (diagonal/side sprints now expect 8 frames), `locomotion_audit` and `role_animation_smoke`. `tests/sprint_strip_review.tscn` renders every frame of both characters' side and diagonal sprints through the game; the strips (`tests/sprint_strip_review_*.png`) show a steady body size and feet on the ground line.
