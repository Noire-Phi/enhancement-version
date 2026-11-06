extends SceneTree

# Checks the enhancement-version additions: per-player stats in the rankings,
# floating score popups, the final-seconds countdown, camera shake and results awards.
# Run: godot --headless --path . --script res://tests/enhancements_smoke.gd

const RESULTS_PATH := "res://ui/results/results.gd"
const SCORE_POPUP = preload("res://game/match/score_popup.gd")
var failures := 0

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("FAIL: enhancements check timed out")
		quit(1)
	)
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _popups(game: Node) -> Array:
	return game.get_children().filter(func(node: Node) -> bool: return node.get_script() == SCORE_POPUP)

func _run() -> void:
	var session: Node = root.get_node("LanSession")
	var settings: Node = root.get_node("UserSettings")
	settings.tutorial_seen = true
	settings.screen_shake = true

	# VS AI: difficulty profiles, CPU names and labels; developer bots keep full strength.
	session.begin_local("developer")
	_check(not session.is_vs_ai() and session.bot_profile().release == 0.025, "developer bots keep their original accuracy")
	session.begin_vs_ai("easy", 2)
	_check(session.is_vs_ai() and session.developer_bot_count == 2 and session.room_code == "VS AI", "vs AI room starts")
	session.add_developer_bots()
	_check(session.players.size() == 3 and str(session.players[1].name).begins_with("CPU"), "vs AI opponents are CPUs")
	_check(session.bot_profile().release > session.AI_PROFILES.hard.release and not session.bot_profile().taya_sprint, "easy bots are weaker")
	session.close_room()
	_check(not session.is_vs_ai(), "closing the room clears vs AI")
	session.begin_vs_ai("impossible", 0)
	_check(session.ai_difficulty == "normal" and session.developer_bot_count == 1, "bad input falls back safely")
	session.close_room()

	session.developer_bot_count = 4
	session.begin_local("developer")
	session.add_developer_bots()
	var game: Node2D = load("res://game/match/match.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	for actor in game.actors.values():
		actor.set_meta("bot", false)
		actor.accept_local_input = false
	var ids: Array = game.actors.keys()
	_check(ids.size() >= 3, "developer match should have bots")

	# Ambience and smooth motion.
	_check(game.ambience != null and game.ambience.get_node_or_null("CloudShadows") != null, "cloud shadows exist")
	_check(game.ambience.particles != null and game.ambience.particles.amount > 0, "map particles exist")
	_check(game.ambience.vignette != null, "vignette exists")
	_check(physics_interpolation and game.smooth_motion, "host turns on smooth motion")
	_check(game.actors[ids[0]].physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON, "players are interpolated")
	_check(game.match_camera.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_ON and not game.match_camera.is_physics_interpolated(), "camera is not interpolated")

	# 2.5D: props and players cast floor shadows anchored at their visible base.
	var crate: Node = null
	for node in game.get_children():
		if node.has_node("World/Crate"): crate = node.get_node("World/Crate")
	_check(crate != null and crate.has_node("CastShadow"), "props cast shadows")
	if crate != null and crate.has_node("CastShadow"):
		var art: Sprite2D = crate.get_node("Sprite2D")
		var shade: Sprite2D = crate.get_node("CastShadow")
		var art_rect: Rect2 = art.get_global_transform() * art.get_rect()
		var shade_rect: Rect2 = shade.get_global_transform() * shade.get_rect()
		_check(shade_rect.position.y < art_rect.end.y and shade_rect.end.y > art_rect.end.y - 40.0, "prop shadow touches the prop's base")
	_check(game.actors[ids[0]].has_node("CastShadow"), "players cast shadows")
	# Seamless running: a blend frame appears while running and hides at rest.
	var runner: CharacterBody2D = game.actors[ids[1]]
	runner.facing = Vector2.RIGHT
	runner._play("sprint", Vector2.RIGHT)
	runner.sprite.play()
	runner._update_run_polish()
	_check(runner.step_blend != null and runner.step_blend.visible and runner.sprite.skew != 0.0, "running adds a blend frame and lean")
	runner._play("idle", Vector2.RIGHT)
	runner._update_run_polish()
	_check(runner.step_blend != null and not runner.step_blend.visible and runner.sprite.offset == Vector2.ZERO, "blend and bounce clear at rest")

	# Can impact burst and the screen-shake toggle.
	game._spawn_can_impact(0.8)
	_check(game.get_children().any(func(node: Node) -> bool: return node.get_script() == game.IMPACT_FX), "can impact burst spawns")
	settings.screen_shake = false
	game._shake(12.0)
	_check(game.shake_strength == 0.0, "screen shake setting turns shake off")
	settings.screen_shake = true

	# Hit-stop (offline only) always returns to normal speed.
	game._hit_stop(40)
	_check(Engine.time_scale < 0.5, "hit-stop slows time offline")
	await create_timer(0.08, true, false, true).timeout
	await process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "hit-stop restores normal speed")

	# Pause menu: offline it freezes the match and resumes cleanly.
	game.pause_menu.open()
	_check(paused and game.pause_menu.visible, "pause menu pauses an offline match")
	game.pause_menu.close()
	_check(not paused, "resume unpauses")

	# Game-wide polish: buttons get hover/press animation, scenes fade in.
	_check(root.has_node("VisualPolish"), "visual polish autoload runs")
	var probe := Button.new()
	root.add_child(probe)
	_check(probe.has_meta("polished"), "buttons are animated game-wide")
	probe.queue_free()
	game.stage = "active"
	game.remaining = 120.0
	game.phase_deadline = session.clock_time() + game.remaining
	game.taya_id = ids[0]
	await _frames(2)

	# Stats: each kind of point is tallied separately; Taya's miss points are not.
	game._add_point(ids[1], "hits")
	game._add_point(ids[1], "hits")
	game._add_point(ids[2], "returns")
	game._add_point(ids[0], "tags")
	game._add_point(ids[0])
	_check(game.scores[ids[1]] == 2 and game.stats[ids[1]].hits == 2, "can hits are counted")
	_check(game.stats[ids[2]].returns == 1, "safe returns are counted")
	_check(game.scores[ids[0]] == 2 and game.stats[ids[0]].tags == 1, "tags count, miss points only score")

	# Popups: one per player whose score rose, showing the size of the rise.
	await _frames(1)
	var popups := _popups(game)
	_check(popups.size() == 3, "expected 3 score popups, got %d" % popups.size())
	var texts := popups.map(func(popup: Node) -> String: return popup.text)
	_check(texts.count("+2") == 2 and texts.count("+1") == 1, "popup amounts match score gains: %s" % str(texts))
	await create_timer(SCORE_POPUP.LIFETIME + 0.2).timeout
	_check(_popups(game).is_empty(), "popups free themselves")
	# No popups for score changes outside play (e.g. a fresh snapshot).
	game.stage = "preparation"
	game._add_point(ids[1])
	await _frames(1)
	_check(_popups(game).is_empty(), "no popups outside active play")
	game.stage = "active"

	# Final countdown: ticks once per second in the last ten and pulses the timer.
	game.remaining = 10.5
	game._update_match_sfx()
	_check(game.last_final_tick == 11, "no tick above ten seconds")
	game.remaining = 9.6
	game._update_match_sfx()
	_check(game.last_final_tick == 10, "tick at ten seconds")
	game._update_match_sfx()
	_check(game.last_final_tick == 10, "one tick per second")
	game._update_hud()
	var timer_color: Color = game.phase_label.get_theme_color("font_color")
	_check(timer_color.r > 0.9 and timer_color.g < 0.75, "timer turns red in the final seconds: %s" % timer_color)
	game.remaining = 60.0
	game._update_match_sfx()
	game._update_hud()
	_check(game.phase_label.get_theme_color("font_color") == game.phase_label_color, "timer color restores")

	# Camera shake decays back to a still camera.
	game._shake(12.0)
	game._update_camera(1.0 / 60.0)
	_check(game.shake_strength > 0.0, "shake starts")
	for i in range(40): game._update_camera(1.0 / 60.0)
	_check(game.shake_strength == 0.0 and game.match_camera.offset == Vector2.ZERO, "shake settles")

	# Rankings carry the stats; awards pick the leaders and share ties.
	game.remaining = 0.0
	game._finish()
	var rankings: Array = session.results
	_check(rankings.size() == ids.size(), "rankings include every player")
	var by_id := {}
	for row in rankings: by_id[row.id] = row
	_check(by_id[ids[1]].hits == 2 and by_id[ids[2]].returns == 1 and by_id[ids[0]].tags == 1, "rankings include stats")
	var RESULTS: GDScript = load(RESULTS_PATH)
	var sharp: Dictionary = RESULTS.award_winners(rankings, "hits")
	_check(sharp.value == 2 and sharp.names.size() == 1, "sharpshooter has one winner")
	var tie := [{"name": "A", "tags": 3}, {"name": "B", "tags": 3}, {"name": "C", "tags": 1}]
	_check(RESULTS.award_winners(tie, "tags").names == ["A", "B"], "tied awards are shared")
	_check(RESULTS.award_winners([{"name": "A"}], "hits").names.is_empty(), "no award without a stat")

	# The results scene builds award cards from those rankings.
	await process_frame
	await process_frame
	var screen: Node = current_scene
	var awards: Node = screen.get_node_or_null("Awards") if screen != null else null
	_check(awards != null and awards.get_child_count() == 3, "results show three award cards")
	_check(not physics_interpolation, "smooth motion turns off after the match")

	if failures == 0:
		print("PASS: enhancements smoke")
		quit(0)
	else:
		quit(1)
