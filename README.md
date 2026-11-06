# Can Clash

> **Enhancement version.** This fork adds VS AI mode, smoother motion, new hit
> and arena effects, score popups and match awards. See the latest entries in
> [docs/decisions.md](docs/decisions.md). The original game lives at
> [RalphAI-suiii/Can-Clash](https://github.com/RalphAI-suiii/Can-Clash).

A Godot 4.7.2 arena game inspired by Tumbang Preso, with a playable menu,
waiting room, bots, host-authoritative matches and podium results.

## Run and play

Import `project.godot` in Godot and run the main scene.

- **Play Local:** up to five players on the same LAN, using ENet UDP 54652.
- **Play Online:** up to four players using GD-Sync Free room codes. Configure
  the developer's game keys using [the setup guide](docs/online_setup.md).
- **Practice:** choose a character, then play a guided thrower and Taya tutorial.
  Restart any time or choose Free practice; no keys or network required.
- **VS AI:** an offline match against 1–4 computer opponents on Easy, Normal
  or Hard. No network needed; results do not change saved statistics.
- Enter `developer-mode` in Play Local's Join field for a solo bot match.
  Set 0–4 bots in that waiting room before pressing Ready and Start.

LAN, Practice and developer mode work without GD-Sync credentials.

## Match rules

After everyone loads the map, a throw-off determines the first Taya: the
slipper farthest from the can loses.
Throwers remain frozen for seven seconds while Taya prepares, then a five-minute
match begins. Taya has no ordinary thrower slipper, but can aim a cooldown-based
stun slipper with right mouse; Taya cannot enter the full-height blue area.

Throw only from blue: aim with the mouse, hold left-click and release the bouncing
marker in the narrow green window for full power and accuracy. Orange gives
intermediate power; red adds substantial aim error. Retrieve your own colored
slipper by running over it, then return to blue for a safe-return point.

The can starts on the far right. When it falls, Taya runs over it to pick it up
automatically, then carries it to its marked base to reset it automatically.
Tagging works only outside blue while the can stands. Space lunges; Shift
sprints. A tag starts a short reset that returns throwers to the toe-line.

Can hits, safe returns, Taya tags and opponents' missed throws award points under
the host's authority. Highest score wins; tied leaders share victory. The top
three appear on gold, silver and bronze podiums. Developer games do not affect
saved statistics.

## Verification

Headless checks live in `tests/`, including `gameplay_rules_smoke.gd`,
`far_right_can_smoke.gd`, `lan_session_smoke.gd` and `online_session_smoke.gd`.
Set `CAN_CLASH_SAVE_PATH` to isolate test profiles from your saved statistics.

LAN has been checked with five separate processes on one PC. GD-Sync's local
transport has been checked with four players, a rejected fifth peer, simulated
latency and packet loss. Physical LAN and cross-network internet playtests remain
manual. See [networking details](docs/networking.md).
