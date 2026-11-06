extends "res://game/network_world.gd"

const UI = preload("res://ui/game_ui.gd")
const CATALOG = preload("res://game/maps/map_catalog.gd")
const TAG_BURST = preload("res://game/match/tag_burst.gd")
const SCOREBOARD = preload("res://game/match/scoreboard.gd")
const SCORE_TOGGLE = preload("res://game/match/score_toggle.gd")
const SCORE_POPUP = preload("res://game/match/score_popup.gd")
const IMPACT_FX = preload("res://game/match/impact_fx.gd")
const AMBIENCE = preload("res://game/match/ambience.gd")
const BOUNCE_DUST = preload("res://scenes/sprint_dust.gd")
const CAST_SHADOWS = preload("res://game/match/cast_shadows.gd")
const THROWOFF_TITLE_SFX = preload("res://assets/audio/sfx/throwoff_title.wav")
const THROWOFF_TICK_SFX = preload("res://assets/audio/sfx/throwoff_tick.wav")
const THROWOFF_GO_SFX = preload("res://assets/audio/sfx/throwoff_go.wav")
const CAN_HIT_SFX = preload("res://assets/audio/sfx/can_hit.wav")
# Inner fence edges for slipper and player movement limits.
const ARENA := Rect2(153, 49, 1568, 1023)
# Camera may show the full court artwork beyond the collision fence.
const CAMERA_BOUNDS := Rect2(0, 0, 1920, 1080)
const CAMERA_NORMAL_ZOOM := 1.25
const CAMERA_AIM_ZOOM := 1.05
const CAMERA_SLIPPER_ZOOM := 1.18
# Cover the visible floor to the fence/curb, not only the inset movement bounds.
const SAFE := Rect2(140, 0, 390, 1072)
const PREPARATION_SECONDS := 7.0
const MATCH_SECONDS := 300.0
const INTRO_SECONDS := 2.8
const RUN_TO_LINE_SECONDS := 5.0
const THROW_OFF_SECONDS := 26.0
const RESULT_SECONDS := 3.5
const TAG_NOTICE_SECONDS := 2.6
const TAG_RESET_SECONDS := TAG_NOTICE_SECONDS
const CAN_START := Vector2(1450, 610)
const TAYA_START := CAN_START + Vector2(-180, 0)
const TAG_RESET_TAYA_START := CAN_START + Vector2(-115, 0)
# The last seconds of a match tick audibly and pulse the timer red.
const FINAL_COUNTDOWN_SECONDS := 10
const FINAL_COUNTDOWN_COLOR := Color("ff4a3a")
# Screen shake is presentation only; each peer shakes its own camera.
const CAN_SHAKE_MIN := 5.0
const CAN_SHAKE_MAX := 15.0
const TAG_SHAKE := 12.0
const SHAKE_DECAY := 42.0
const SCORE_POPUP_HEIGHT := 150.0

var stage := "loading"
var remaining := 7.0
var phase_deadline := 0.0
var opening_label: Label
var match_camera: Camera2D
var scores: Dictionary = {}
var taya_id := 0
var tag_immunity := 0.0
var acknowledgment_clock := 0.0
var can: CharacterBody2D
var role_status_label: Label
var phase_label: Label
var score_panel: PanelContainer
var scoreboard
var score_toggle: Button
var score_open := true
var notice_label: Label
var notice_remaining := 0.0
var tag_notice_id := 0
var tag_notice_until := 0.0
var tag_notice_serial := 0
var tag_notice_position := Vector2.ZERO
var tag_reset_repositioned := false
var tag_shade: ColorRect
var tag_panel: PanelContainer
var tag_title: Label
var throwoff_distances: Dictionary = {}
var throwoff_last_shot_at := 0.0
var intro_shade: ColorRect
var intro_title: Label
var result_panel: PanelContainer
var result_portrait: TextureRect
var result_title: Label
var result_character: Label
var camera_slipper: Node2D
var camera_landing_point := Vector2.ZERO
var camera_return_at := 0.0
var camera_following_slipper := false
var title_sfx: AudioStreamPlayer
var tick_sfx: AudioStreamPlayer
var go_sfx: AudioStreamPlayer
var can_sfx: AudioStreamPlayer
var last_sfx_stage := "loading"
var last_countdown := 4
var last_can_state := 0
# Host-only tallies of what earned each player's points, shown as awards on the results screen.
var stats: Dictionary = {}
var shown_scores: Dictionary = {}
var last_final_tick := FINAL_COUNTDOWN_SECONDS + 1
var phase_label_color := Color("fff5dc")
var shake_strength := 0.0
var ambience: Node2D
var seen_bounces: Dictionary = {}
# The host simulates every body at 60 Hz; interpolation draws them smoothly at any
# refresh rate. Joiners keep their own snapshot smoothing, so they leave this off.
var smooth_motion := false
var pause_menu: Control
var hit_stop_until := 0

func _ready() -> void:
	Music.play_music("lobby")
	if LanSession.players.is_empty():
		LanSession.begin_local("developer")
		LanSession.players[0].character = 0
		LanSession.players[0].ready = true
		LanSession.add_developer_bots()
	LanSession.phase = "match"
	var level: Node2D = load("res://level/basketball_court.tscn").instantiate()
	level.get_node("World/PlayerMovementNeutral").free()
	level.get_node("Camera2D").free()
	# Sort players and props together by their feet; keep only floor art behind them.
	level.y_sort_enabled = true
	for layer in ["Backdrop", "Ground", "Decals"]:
		level.get_node(layer).z_index = -10
	level.get_node("World/FenceLayer").y_sort_enabled = true
	level.get_node("World/World Border").collision_layer = 16
	# Keep the authored fence-aligned border at the World origin.
	level.get_node("World/World Border").position = Vector2.ZERO
	CATALOG.configure(level, LanSession.selected_map)
	CAST_SHADOWS.add_to_props(level.get_node("World"))
	add_child(level)
	ambience = AMBIENCE.new()
	ambience.setup(level, LanSession.selected_map, CAMERA_BOUNDS)
	add_child(ambience)
	smooth_motion = LanSession.is_host()
	if smooth_motion:
		# Only the bodies below opt in; effects and the camera move per frame and stay off.
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		get_tree().physics_interpolation = true
	var base := Node2D.new()
	base.name = "CanBase"
	base.position = CAN_START
	add_child(base)
	can = load("res://scenes/Taya can.tscn").instantiate()
	can.name = "Can"
	can.position = base.position
	can.starts_toppled = false
	can.auto_stand_up = false
	can.show_target_ring = false
	can.base_path = NodePath("../CanBase")
	can.collision_mask = 1 | 16
	add_child(can)
	_interpolate(can)
	setup_network_world()
	LanSession.match_event_received.connect(_match_event)
	LanSession.skill_requested.connect(_skill_requested)
	_build_hud()
	_build_sfx()
	_build_camera()
	# Automatically acknowledge scene loading; no rules dialog gates the match.
	LanSession.acknowledge_tutorial()
	queue_redraw()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if smooth_motion:
		get_tree().physics_interpolation = false

func _interpolate(node: Node) -> void:
	if smooth_motion and is_instance_valid(node):
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		node.reset_physics_interpolation()

# Teleports (phase changes, tag resets) must not be smeared across a frame.
func _snap_bodies() -> void:
	if not smooth_motion:
		return
	for actor in actors.values():
		actor.reset_physics_interpolation()
	if is_instance_valid(can):
		can.reset_physics_interpolation()

func _spawn_point(slot: int) -> Vector2:
	return Vector2(940 + (slot % 2) * 130, 510 + slot * 50)

func _line_point(slot: int) -> Vector2:
	return Vector2(465, 330 + slot * 145)

func _sync_actors() -> void:
	super._sync_actors()
	for id in throwoff_distances.keys():
		if not actors.has(id): throwoff_distances.erase(id)
	if stage == "throw_off_result" and not actors.has(taya_id) and not actors.is_empty():
		taya_id = int(actors.keys()[0])
	if LanSession.is_host() and stage in ["preparation", "active", "tag_reset"] and taya_id != 0 and not actors.has(taya_id) and not actors.is_empty():
		taya_id = int(LanSession.players[0].id)
		var replacement: CharacterBody2D = actors[taya_id]
		if is_instance_valid(replacement.active_slipper):
			replacement.active_slipper.queue_free()
		replacement.active_slipper = null
		replacement.set_meta("returning", false)
		replacement.position = TAYA_START
		replacement.set_taya_role(true)
		if stage == "tag_reset": replacement.accept_local_input = false
		can.reset_for_preview(can.base.position)
		_snap_bodies()
		tag_immunity = 1.0
		if notice_label != null:
			_announce_new_taya(taya_id, replacement.global_position)

func _actor_added(actor: CharacterBody2D) -> void:
	actor.can_node = can
	actor.require_standing_can = true
	actor.safe_strip_rect = SAFE
	actor.allowed_throw_rect = SAFE
	actor.throw_speed_multiplier = 1.45
	actor.taya_min_x = SAFE.end.x + 1.0
	actor.arena_bounds = ARENA
	actor.tag_requested.connect(_tag_requested.bind(actor))
	scores[actor.get_meta("peer_id")] = 0
	stats[actor.get_meta("peer_id")] = {"hits": 0, "tags": 0, "returns": 0}
	_interpolate(actor)
	CAST_SHADOWS.add_to_actor(actor)

func _world_inputs_enabled() -> bool:
	return stage in ["throw_off", "preparation", "active"]

func _actor_inputs_enabled(actor: CharacterBody2D) -> bool:
	return stage == "active" or (stage == "preparation" and actor.is_taya) or (stage == "throw_off" and (remaining > 0.0 or actor.attack_state == actor.AttackState.THROWING or is_instance_valid(actor.active_slipper)))

func _update_bot(actor: CharacterBody2D) -> void:
	if stage != "throw_off":
		super._update_bot(actor)
		return
	var slot: int = int(LanSession.member(actor.get_meta("peer_id")).get("slot", 0))
	var aim := CAN_START + Vector2(0, (slot - 2) * 110.0)
	var throwing: bool = actor.attack_state != actor.AttackState.CHARGING or actor.charge_bar.value < float(actor.get_meta("bot_release_at", actor.sweet_spot))
	actor.apply_network_input({"move": Vector2.ZERO, "aim": aim, "throw": throwing, "sprint": false, "interact": false, "lunge": false})

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	notice_remaining = maxf(0.0, notice_remaining - delta)
	if notice_label != null and notice_remaining == 0.0:
		notice_label.text = ""
	if not LanSession.is_host():
		if stage == "loading":
			acknowledgment_clock += delta
			if acknowledgment_clock >= 1.0:
				acknowledgment_clock = 0.0
				LanSession.acknowledge_tutorial()
		if stage in ["intro", "run_to_line", "throw_off", "throw_off_result", "preparation", "active"]:
			remaining = maxf(0.0, phase_deadline - LanSession.clock_time())
		_update_hud()
		return
	tag_immunity = maxf(0.0, tag_immunity - delta)
	if stage == "loading" and LanSession.humans_ready_for_match():
		_start_intro()
	elif stage == "intro":
		remaining = maxf(0.0, phase_deadline - LanSession.clock_time())
		if remaining <= 0.0:
			_start_run_to_line()
	elif stage == "run_to_line":
		remaining = maxf(0.0, phase_deadline - LanSession.clock_time())
		for id in actors:
			var actor: CharacterBody2D = actors[id]
			var slot: int = int(LanSession.member(id).slot)
			var target := _line_point(slot)
			# Cross the clear middle lane, then fan out before reaching the toe-line.
			if actor.position.x > 610.0:
				target = Vector2(600.0, _spawn_point(slot).y)
			var offset: Vector2 = target - actor.position
			if offset.length() > 12.0:
				actor.velocity = actor.get_meta("intro_velocity", Vector2.ZERO)
				actor.move_from_input(delta, offset.normalized(), true, true, true)
				actor.set_meta("intro_velocity", actor.velocity)
			else:
				actor.set_meta("intro_velocity", Vector2.ZERO)
				actor._play("idle", actor.facing)
		# Keep the final three seconds for a complete, synchronized countdown.
		if remaining <= 0.0:
			_start_throw_off()
	elif stage == "throw_off":
		remaining = maxf(0.0, phase_deadline - LanSession.clock_time())
		_update_throw_off()
		if remaining <= 0.0:
			for actor in actors.values():
				if actor.attack_state == actor.AttackState.CHARGING and not is_instance_valid(actor.active_slipper):
					actor.set_taya_role(false)
		if (throwoff_distances.size() == actors.size() and LanSession.clock_time() - throwoff_last_shot_at >= 1.2) or (remaining <= 0.0 and LanSession.clock_time() >= phase_deadline + 6.0):
			_finish_throw_off()
	elif stage == "throw_off_result":
		remaining = maxf(0.0, phase_deadline - LanSession.clock_time())
		if remaining <= 0.0:
			_start_preparation()
	elif stage == "preparation":
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			_start_scoring()
	elif stage == "tag_reset":
		if not tag_reset_repositioned and LanSession.clock_time() >= phase_deadline - TAG_RESET_SECONDS * 0.5:
			_place_tag_reset_players()
		if LanSession.clock_time() >= phase_deadline:
			_resume_after_tag()
	elif stage == "active":
		remaining = maxf(0.0, remaining - delta)
		for actor in actors.values():
			if actor.get_meta("returning", false) and not SAFE.has_point(actor.global_position):
				actor.set_meta("left_safe", true)
			if actor.get_meta("rapid_complete", false):
				actor.set_meta("rapid_complete", false)
				if not actor.is_taya:
					actor.set_meta("retrieved", true)
					if not actor.get_meta("rapid_hit", false) and taya_id != 0:
						_add_point(taya_id)
			if is_instance_valid(actor.active_slipper):
				var slipper: Node2D = actor.active_slipper
				if slipper.special_kind != &"rapid" and not slipper.get_meta("outcome", false) and (slipper.is_resting() or slipper.lost_remaining > 0.0):
					slipper.set_meta("outcome", true)
					if not slipper.hit_registered and taya_id != 0:
						_add_point(taya_id)
			elif actor.get_meta("returning", false) and actor.get_meta("left_safe", false) and actor.get_meta("retrieved", false) and not actor.is_taya and SAFE.has_point(actor.global_position):
				actor.set_meta("returning", false)
				_add_point(actor.get_meta("peer_id"), "returns")
		if remaining <= 0.0:
			_finish()
	_update_hud()

func _start_intro() -> void:
	stage = "intro"
	remaining = INTRO_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	throwoff_distances.clear()
	taya_id = 0
	can.reset_for_preview(can.base.position)
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		if is_instance_valid(actor.active_slipper): actor.active_slipper.queue_free()
		actor.active_slipper = null
		actor.set_taya_role(false)
		actor.position = _spawn_point(int(LanSession.member(id).slot))
		actor.facing = Vector2.LEFT
		actor._play("idle", actor.facing)
		actor.network_input = {}
		actor.network_edges.clear()
		actor.accept_local_input = false
		actor.movement_locked = false
		actor.throwoff_locked = false
		actor.set_meta("intro_velocity", Vector2.ZERO)
	_snap_bodies()

func _start_run_to_line() -> void:
	stage = "run_to_line"
	remaining = RUN_TO_LINE_SECONDS
	phase_deadline = LanSession.clock_time() + remaining

func _start_throw_off() -> void:
	stage = "throw_off"
	remaining = THROW_OFF_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		actor.position = _line_point(int(LanSession.member(id).slot))
		actor.remove_meta("intro_velocity")
		actor.velocity = Vector2.ZERO
		actor.facing = Vector2.RIGHT
		actor._play("idle", actor.facing)
		actor.sprite.speed_scale = 1.0
		actor.movement_locked = true
		actor.throwoff_locked = false
		actor.accept_local_input = true
		actor.network_input = {}
		actor.network_edges.clear()
	_snap_bodies()
	_notice("AIM AT THE CAN — ONE THROW EACH!")

func _update_throw_off() -> void:
	for id in actors:
		if throwoff_distances.has(id):
			continue
		var actor: CharacterBody2D = actors[id]
		var slipper: Node2D = actor.active_slipper
		if is_instance_valid(slipper):
			actor.throwoff_locked = true
			if slipper.is_resting() or slipper.lost_remaining > 0.0:
				throwoff_distances[id] = INF if slipper.lost_remaining > 0.0 else slipper.global_position.distance_squared_to(CAN_START)
				throwoff_last_shot_at = LanSession.clock_time()

func _finish_throw_off() -> void:
	# A player who does not throw by the deadline takes the Taya role.
	var farthest := -1.0
	var selected_slot := 999
	for id in actors:
		var distance: float = float(throwoff_distances.get(id, INF))
		var slot: int = int(LanSession.member(id).slot)
		if distance > farthest or ((distance == farthest or is_equal_approx(distance, farthest)) and slot < selected_slot):
			farthest = distance
			selected_slot = slot
			taya_id = id
	# Developer Play As remains a local testing override; LAN and online use the distance result.
	if LanSession.mode == "developer":
		if LanSession.developer_role == "taya":
			taya_id = LanSession.local_id()
		elif LanSession.developer_role == "player" and taya_id == LanSession.local_id():
			for id in actors:
				if id != LanSession.local_id():
					taya_id = id
					break
	stage = "throw_off_result"
	remaining = RESULT_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	for actor in actors.values():
		actor.movement_locked = false
		actor.throwoff_locked = true
		actor.accept_local_input = false
		actor.network_input = {}
		actor.network_edges.clear()
		actor.velocity = Vector2.ZERO
	_notice("FARTHEST FROM THE CAN!")

func _start_preparation() -> void:
	stage = "preparation"
	remaining = PREPARATION_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	can.reset_for_preview(can.base.position)
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		if is_instance_valid(actor.active_slipper): actor.active_slipper.queue_free()
		actor.active_slipper = null
		actor.position = TAYA_START if id == taya_id else _line_point(int(LanSession.member(id).slot))
		actor.set_taya_role(id == taya_id)
		actor.set_meta("returning", false)
		actor.network_input = {}
		actor.network_edges.clear()
		actor.accept_local_input = id == taya_id
		actor.movement_locked = false
		actor.throwoff_locked = false
	_snap_bodies()

func _start_scoring() -> void:
	if taya_id == 0:
		return
	stage = "active"
	remaining = MATCH_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	_notice("THROW!")

func _slipper_spawned(actor: CharacterBody2D, slipper: Node2D) -> void:
	if stage == "throw_off":
		actor.throwoff_locked = true
		slipper.throwoff_stop_at_can = true
	_interpolate(slipper)
	if stage == "active":
		if slipper == actor.active_slipper:
			actor.set_meta("returning", true)
			actor.set_meta("left_safe", not SAFE.has_point(actor.global_position))
			actor.set_meta("retrieved", false)
	slipper.can_hit.connect(_can_hit.bind(actor, slipper))
	slipper.player_hit.connect(_special_player_hit.bind(actor))
	slipper.picked_up.connect(func() -> void:
		if slipper.special_kind != &"rapid": actor.set_meta("retrieved", true)
		if slipper.special_kind == &"rapid": return
		if stage == "active" and not slipper.get_meta("outcome", false):
			slipper.set_meta("outcome", true)
			if not slipper.hit_registered and taya_id != 0:
				_add_point(taya_id)
	)
	slipper.returned_after_penalty.connect(func() -> void: actor.set_meta("returning", false))

func _can_hit(_target: Node2D, actor: CharacterBody2D, slipper: Node2D) -> void:
	if not LanSession.is_host() or stage != "active" or actor.is_taya or slipper.get_meta("skill_counted", false):
		return
	if slipper.special_kind == &"rapid":
		if actor.get_meta("rapid_hit", false): return
		actor.set_meta("rapid_hit", true)
	slipper.set_meta("skill_counted", true)
	slipper.set_meta("outcome", true)
	var id: int = actor.get_meta("peer_id")
	_add_point(id, "hits")
	if actor.has_thrower_special():
		actor.set_skill_charge(actor.skill_charge + 1)
	LanSession.publish_event({"kind": "hit", "player": id, "match_id": LanSession.match_id})
	var player_name: String = LanSession.member(id).get("name", "Player")
	if actor.skill_charge == 3:
		_notice("%s'S SPECIAL IS READY — RIGHT-CLICK!" % player_name)
	else:
		_notice("%s KNOCKED DOWN THE CAN!" % player_name)

func _special_player_hit(target: Node2D, actor: CharacterBody2D) -> void:
	if not LanSession.is_host() or stage != "active" or actor.is_taya or not target.is_taya:
		return
	if target.apply_stun():
		_notice("%s IS STUNNED!" % LanSession.member(int(target.get_meta("peer_id"))).get("name", "Player"))

func _taya_stun_spawned(_actor: CharacterBody2D, slipper: Node2D) -> void:
	slipper.player_hit.connect(func(target: Node2D) -> void:
		_notice("%s IS STUNNED!" % LanSession.member(int(target.get_meta("peer_id"))).get("name", "Player"))
	)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("special") and not event.is_action_released("special"):
		return
	if stage != "active":
		return
	if event.is_action_pressed("special") and event is InputEventMouseButton and get_viewport().gui_get_hovered_control() != null:
		return
	var pressed := event.is_action_pressed("special")
	var local_actor: Node2D = actors.get(LanSession.local_id())
	if not is_instance_valid(local_actor):
		return
	var aim := UserSettings.aim_position(local_actor)
	if LanSession.is_host():
		_skill_requested(LanSession.local_id(), pressed, aim)
	else:
		LanSession.request_skill(pressed, aim)
	get_viewport().set_input_as_handled()

func _skill_requested(id: int, pressed: bool, aim: Vector2) -> void:
	if not LanSession.is_host() or stage != "active" or not actors.has(id) or not aim.is_finite():
		return
	var actor: CharacterBody2D = actors[id]
	if actor.is_stunned(): return
	if actor.is_taya:
		if pressed: actor.begin_taya_stun_aim()
		else: actor.release_taya_stun(aim)
	elif pressed and actor.has_thrower_special() and (actor.special_armed or actor.skill_charge == 3 and actor.throw_target_ready()):
		actor.special_armed = not actor.special_armed
		actor.queue_redraw()

func _tag_requested(thrower: Node2D, guard: CharacterBody2D) -> void:
	if not LanSession.is_host() or stage != "active" or tag_immunity > 0.0 or not guard.can_tag() or thrower.is_taya or SAFE.has_point(thrower.global_position):
		return
	var guard_id: int = guard.get_meta("peer_id")
	_add_point(guard_id, "tags")
	guard.flash_hit()
	thrower.flash_hit()
	# Separate bodies along the court before transferring roles; neither player is stunned.
	var away: Vector2 = thrower.global_position - guard.global_position
	if away.is_zero_approx(): away = guard.facing
	var gap: float = guard.PLAYER_CLEARANCE * maxf(guard.scale.x, thrower.scale.x) + 8.0
	if away.length() < gap:
		# Ignore only the tagging partner while separating; scenery still blocks movement.
		thrower.add_collision_exception_with(guard)
		guard.add_collision_exception_with(thrower)
		var direction := away.normalized()
		thrower.move_and_collide(direction * (gap - away.length()))
		var remaining_gap := gap - thrower.global_position.distance_to(guard.global_position)
		if remaining_gap > 0.0:
			guard.move_and_collide(-direction * remaining_gap)
		thrower.remove_collision_exception_with(guard)
		guard.remove_collision_exception_with(thrower)
	var tag_position: Vector2 = thrower.global_position
	taya_id = thrower.get_meta("peer_id")
	stage = "tag_reset"
	phase_deadline = LanSession.clock_time() + TAG_RESET_SECONDS
	tag_reset_repositioned = false
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		_clear_for_tag_reset(actor)
		actor.set_taya_role(id == taya_id)
		actor.accept_local_input = false
		actor.movement_locked = true
	tag_immunity = 1.0
	_announce_new_taya(taya_id, tag_position)

func _clear_for_tag_reset(actor: CharacterBody2D) -> void:
	if is_instance_valid(actor.active_slipper):
		actor.active_slipper.set_physics_process(false)
		actor.active_slipper.queue_free()
	actor.active_slipper = null
	for shot in actor.rapid_slippers:
		if is_instance_valid(shot):
			shot.set_physics_process(false)
			shot.queue_free()
	actor.rapid_slippers.clear()
	if is_instance_valid(actor.taya_stun_projectile):
		actor.taya_stun_projectile.set_physics_process(false)
		actor.taya_stun_projectile.queue_free()
	actor.taya_stun_projectile = null
	actor.rapid_remaining = 0
	actor.set_meta("returning", false)
	actor.set_meta("left_safe", false)
	actor.set_meta("retrieved", false)
	actor.set_meta("rapid_complete", false)
	actor.set_meta("rapid_hit", false)
	actor.network_input = {}
	actor.network_edges.clear()
	actor.velocity = Vector2.ZERO

func _place_tag_reset_players() -> void:
	tag_reset_repositioned = true
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		actor.position = TAG_RESET_TAYA_START if id == taya_id else _line_point(int(LanSession.member(id).get("slot", 0)))
		actor.velocity = Vector2.ZERO
		actor._keep_out_of_can_circle()
	_snap_bodies()

func _resume_after_tag() -> void:
	if not tag_reset_repositioned: _place_tag_reset_players()
	stage = "active"
	phase_deadline = LanSession.clock_time() + remaining
	for actor in actors.values():
		actor.movement_locked = false
		actor.network_input = {}
		actor.network_edges.clear()
	_notice("THROW!")

func _announce_new_taya(id: int, position: Vector2) -> void:
	tag_notice_id = id
	tag_notice_until = LanSession.clock_time() + TAG_NOTICE_SECONDS
	tag_notice_serial += 1
	tag_notice_position = position
	_spawn_tag_burst(position)

func _spawn_tag_burst(position: Vector2) -> void:
	var burst := TAG_BURST.new()
	burst.position = position + Vector2(0, -55)
	burst.z_index = 30
	add_child(burst)
	_shake(TAG_SHAKE)
	_hit_stop(90)

func _add_point(id: int, kind := "") -> void:
	scores[id] = int(scores.get(id, 0)) + 1
	if kind == "":
		return
	var entry: Dictionary = stats.get(id, {"hits": 0, "tags": 0, "returns": 0})
	entry[kind] = int(entry.get(kind, 0)) + 1
	stats[id] = entry

func _shake(strength: float) -> void:
	if UserSettings.screen_shake:
		shake_strength = maxf(shake_strength, strength)

# A brief near-freeze sells big impacts. Offline only: networked matches keep
# every peer on the host's clock, so time is never bent there.
func _hit_stop(milliseconds: int) -> void:
	if LanSession.is_networked() or not UserSettings.screen_shake:
		return
	Engine.time_scale = 0.05
	hit_stop_until = Time.get_ticks_msec() + milliseconds

func _update_hit_stop() -> void:
	if hit_stop_until > 0 and Time.get_ticks_msec() >= hit_stop_until:
		hit_stop_until = 0
		Engine.time_scale = 1.0

func _spawn_can_impact(strength: float) -> void:
	var burst := IMPACT_FX.new()
	burst.strength = strength
	burst.position = can.global_position + Vector2(0, -27)
	burst.z_index = 35
	add_child(burst)

# A small dust puff each time a thrown slipper smacks the floor.
func _update_bounce_dust() -> void:
	var live := {}
	for actor in actors.values():
		var slipper: Node2D = actor.active_slipper
		if not is_instance_valid(slipper) or not slipper.visible:
			continue
		var key := slipper.get_instance_id()
		live[key] = true
		var bounces: int = slipper.floor_bounces
		if bounces > int(seen_bounces.get(key, 0)):
			var dust := BOUNCE_DUST.new()
			dust.position = slipper.global_position
			dust.scale = Vector2.ONE * 0.42
			dust.lifetime = 0.4
			dust.drift_direction = Vector2(signf(slipper.velocity.x), 0.0)
			dust.z_index = 5
			add_child(dust)
		seen_bounces[key] = bounces
	for key in seen_bounces.keys():
		if not live.has(key): seen_bounces.erase(key)

func _update_score_popups() -> void:
	for id in scores:
		var now := int(scores[id])
		var before := int(shown_scores.get(id, now))
		shown_scores[id] = now
		if now <= before or not actors.has(id) or stage not in ["active", "tag_reset"]:
			continue
		var actor: Node2D = actors[id]
		var popup := SCORE_POPUP.new()
		popup.text = "+%d" % (now - before)
		popup.color = LanSession.member(id).get("color", Color("ffe29a"))
		popup.position = actor.global_position + Vector2(0, -SCORE_POPUP_HEIGHT)
		popup.z_index = 40
		add_child(popup)

func _match_event(event: Dictionary) -> void:
	if event.get("kind") == "hit" and event.get("player") == LanSession.local_id() and event.get("match_id") == LanSession.match_id and LanSession.mode in ["lan", "online"]:
		UserSettings.record_hit()

func _finish() -> void:
	if stage != "active":
		return
	stage = "finished"
	var rankings: Array = []
	for member in LanSession.players:
		var tally: Dictionary = stats.get(member.id, {})
		rankings.append({"id": member.id, "name": member.name, "score": scores.get(member.id, 0), "color": member.color, "character": member.character, "hits": int(tally.get("hits", 0)), "tags": int(tally.get("tags", 0)), "returns": int(tally.get("returns", 0))})
	rankings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score if a.score != b.score else a.id < b.id)
	LanSession.finish_match(rankings)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 4
	add_child(hud)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.theme = UI.theme()
	hud.add_child(screen)
	intro_shade = ColorRect.new()
	intro_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_shade.color = Color(0.07, 0.08, 0.13, 0.0)
	intro_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_shade.visible = false
	screen.add_child(intro_shade)
	intro_title = UI.label("THROW OFF!!", 92)
	intro_title.size = Vector2(900, 160)
	intro_title.position = Vector2(-900, -80)
	intro_title.add_theme_color_override("font_color", Color("ffb52a"))
	intro_title.add_theme_color_override("font_outline_color", Color("2a160e"))
	intro_title.add_theme_constant_override("outline_size", 10)
	intro_title.visible = false
	screen.add_child(intro_title)
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -390
	result_panel.offset_top = -135
	result_panel.offset_right = 390
	result_panel.offset_bottom = 135
	result_panel.add_theme_stylebox_override("panel", UI.panel(Color("b95519"), 7))
	result_panel.visible = false
	screen.add_child(result_panel)
	var result_row := HBoxContainer.new()
	result_row.add_theme_constant_override("separation", 18)
	result_panel.add_child(result_row)
	result_portrait = TextureRect.new()
	result_portrait.custom_minimum_size = Vector2(160, 180)
	result_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_row.add_child(result_portrait)
	var result_copy := VBoxContainer.new()
	result_copy.add_theme_constant_override("separation", 8)
	result_row.add_child(result_copy)
	result_title = UI.label("", 43)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	result_title.custom_minimum_size.x = 520
	result_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_title.add_theme_color_override("font_color", Color("fff5dc"))
	result_copy.add_child(result_title)
	result_character = UI.label("", 24)
	result_character.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	result_character.add_theme_color_override("font_color", Color("ffe49a"))
	result_copy.add_child(result_character)
	phase_label = UI.label("WAITING FOR PLAYERS TO LOAD", 30)
	phase_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	phase_label.position = Vector2(-650, 35)
	phase_label.size = Vector2(1300, 60)
	# The timer sits on a dark pill so it reads over any arena art.
	var pill := UI.panel(Color(0.12, 0.07, 0.04, 0.78), 3)
	pill.set_corner_radius_all(30)
	pill.content_margin_left = 30
	pill.content_margin_right = 30
	pill.content_margin_top = 6
	pill.content_margin_bottom = 8
	pill.shadow_size = 8
	phase_label.add_theme_stylebox_override("normal", pill)
	screen.add_child(phase_label)
	phase_label_color = screen.theme.get_color("font_color", "Label")
	role_status_label = UI.label("", 32)
	role_status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	role_status_label.position = Vector2(-430, 98)
	role_status_label.size = Vector2(860, 52)
	role_status_label.add_theme_color_override("font_color", Color("ffe071"))
	role_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(role_status_label)
	score_panel = PanelContainer.new()
	score_panel.anchor_left = 1.0
	score_panel.anchor_right = 1.0
	score_panel.offset_left = -392
	score_panel.offset_right = -24
	score_panel.offset_top = 24
	score_panel.offset_bottom = 446
	score_panel.add_theme_stylebox_override("panel", UI.panel())
	score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(score_panel)
	scoreboard = SCOREBOARD.new()
	score_panel.add_child(scoreboard)
	score_toggle = SCORE_TOGGLE.new()
	score_toggle.name = "ScoreToggle"
	score_toggle.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	score_toggle.offset_left = -80
	score_toggle.offset_right = -28
	score_toggle.offset_top = 30
	score_toggle.offset_bottom = 82
	score_toggle.focus_mode = Control.FOCUS_ALL
	score_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	score_toggle.add_theme_stylebox_override("normal", UI.panel(Color("ba500d"), 4))
	score_toggle.add_theme_stylebox_override("hover", UI.panel(Color("d46a18"), 4))
	score_toggle.add_theme_stylebox_override("pressed", UI.panel(Color("93400e"), 4))
	var score_focus := UI.panel(Color.TRANSPARENT, 3)
	score_focus.border_color = Color("fff0a8")
	score_toggle.add_theme_stylebox_override("focus", score_focus)
	score_toggle.pressed.connect(_toggle_scoreboard)
	score_toggle.hide()
	screen.add_child(score_toggle)
	notice_label = UI.label("", 30)
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	notice_label.position = Vector2(-700, -65)
	notice_label.size = Vector2(1400, 50)
	screen.add_child(notice_label)
	opening_label = UI.label("", 48)
	opening_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	opening_label.position = Vector2(-700, -100)
	opening_label.size = Vector2(1400, 200)
	screen.add_child(opening_label)
	var leave := UI.button("Leave", _leave_match)
	leave.position = Vector2(25, 28)
	screen.add_child(leave)
	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 15
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	pause_menu = preload("res://ui/pause_menu/pause_menu.tscn").instantiate()
	pause_menu.leave_requested.connect(_leave_match)
	pause_layer.add_child(pause_menu)
	tag_shade = ColorRect.new()
	tag_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tag_shade.color = Color(0.18, 0.015, 0.01, 0.0)
	tag_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_shade.hide()
	screen.add_child(tag_shade)
	tag_panel = PanelContainer.new()
	tag_panel.set_anchors_preset(Control.PRESET_CENTER)
	tag_panel.offset_left = -455
	tag_panel.offset_top = -103
	tag_panel.offset_right = 455
	tag_panel.offset_bottom = 103
	tag_panel.pivot_offset = Vector2(455, 103)
	tag_panel.add_theme_stylebox_override("panel", UI.panel(Color("c5271d"), 8))
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_panel.hide()
	screen.add_child(tag_panel)
	tag_title = UI.label("", 47)
	tag_title.custom_minimum_size = Vector2(790, 110)
	tag_title.add_theme_color_override("font_color", Color("fff3d8"))
	tag_title.add_theme_color_override("font_outline_color", Color("50150e"))
	tag_title.add_theme_constant_override("outline_size", 7)
	tag_panel.add_child(tag_title)

func _update_hud() -> void:
	Music.update_match(stage, remaining)
	if phase_label == null:
		return
	var time_text := "%d:%02d" % [int(ceil(remaining)) / 60, int(ceil(remaining)) % 60]
	phase_label.text = "WAITING FOR PLAYERS TO LOAD" if stage == "loading" else "THROW OFF INCOMING" if stage in ["intro", "run_to_line"] else "WAITING FOR SLIPPERS" if stage == "throw_off" and remaining <= 0.0 else "THROW OFF  " + time_text if stage == "throw_off" else "INITIAL TAYA" if stage == "throw_off_result" else "TAYA PREPARATION  " + time_text if stage == "preparation" else "RETURN TO THE LINE" if stage == "tag_reset" else "MATCH  " + time_text
	phase_label.visible = stage != "intro" and stage != "throw_off_result"
	# Shrink the pill to the text and keep it centred.
	phase_label.reset_size()
	phase_label.position = Vector2((phase_label.get_parent().size.x - phase_label.size.x) * 0.5, 28)
	var final_seconds := stage == "active" and remaining > 0.0 and remaining <= FINAL_COUNTDOWN_SECONDS
	var pulse := 0.5 + 0.5 * sin(LanSession.clock_time() * TAU * 2.0) if final_seconds else 0.0
	phase_label.add_theme_color_override("font_color", phase_label_color.lerp(FINAL_COUNTDOWN_COLOR, 0.55 + 0.45 * pulse) if final_seconds else phase_label_color)
	_refresh_scoreboard_visibility()
	var own: Node2D = actors.get(LanSession.local_id())
	var tag_wait: float = own.tag_delay_remaining() if own != null else 0.0
	role_status_label.visible = stage == "active" and own != null and own.is_taya and tag_wait > 0.0
	role_status_label.text = "YOU CAN TAG IN %d" % ceili(tag_wait)
	if opening_label != null:
		opening_label.text = str(ceili(remaining)) if stage == "run_to_line" and remaining > 0.0 and remaining <= 3.0 else "%s IS TAYA\n%d" % [LanSession.member(taya_id).get("name", "Player"), ceili(remaining)] if stage == "preparation" else "THROW!" if stage == "active" and remaining > MATCH_SECONDS - 2.0 else ""
		var label_size := 96 if stage == "run_to_line" else 48
		if opening_label.get_theme_font_size("font_size") != label_size:
			opening_label.add_theme_font_size_override("font_size", label_size)
	_update_intro_visual()
	scoreboard.set_score_state(CATALOG.MAPS[LanSession.selected_map].name, LanSession.players, scores, taya_id, LanSession.mode == "developer")

func _toggle_scoreboard() -> void:
	score_open = not score_open
	_refresh_scoreboard_visibility()

func _refresh_scoreboard_visibility() -> void:
	var score_available := stage in ["preparation", "active", "tag_reset"]
	score_panel.visible = score_available and score_open
	score_toggle.visible = score_available
	score_toggle.set("expanded", score_open)
	score_toggle.tooltip_text = "Hide match score" if score_open else "Show match score"

func _notice(message: String) -> void:
	notice_label.text = message
	notice_remaining = 2.0

func _extra_snapshot() -> Dictionary:
	return {"stage": stage, "remaining": remaining, "deadline": phase_deadline, "scores": scores, "taya": taya_id, "notice": notice_label.text if notice_label != null else "", "tag_notice_id": tag_notice_id, "tag_notice_until": tag_notice_until, "tag_notice_serial": tag_notice_serial, "tag_notice_position": tag_notice_position}

func _apply_extra_snapshot(data: Dictionary) -> void:
	stage = data.get("stage", stage)
	phase_deadline = float(data.get("deadline", phase_deadline))
	remaining = maxf(0.0, phase_deadline - LanSession.clock_time()) if stage in ["intro", "run_to_line", "throw_off", "throw_off_result", "preparation", "active"] else float(data.get("remaining", remaining))
	scores = data.get("scores", scores)
	taya_id = data.get("taya", taya_id)
	var incoming_tag_serial := int(data.get("tag_notice_serial", tag_notice_serial))
	if incoming_tag_serial >= tag_notice_serial:
		tag_notice_id = int(data.get("tag_notice_id", tag_notice_id))
		tag_notice_until = float(data.get("tag_notice_until", tag_notice_until))
		if incoming_tag_serial > tag_notice_serial:
			tag_notice_serial = incoming_tag_serial
			tag_notice_position = data.get("tag_notice_position", tag_notice_position)
			if tag_notice_until > LanSession.clock_time():
				_spawn_tag_burst(tag_notice_position)
	for actor in actors.values():
		actor.movement_locked = stage in ["throw_off", "tag_reset"]
	if notice_label != null:
		notice_label.text = data.get("notice", "")

func _leave_match() -> void:
	LanSession.close_room()
	get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")

func _draw() -> void:
	if is_instance_valid(can) and can.base != null:
		draw_arc(can.base.position + Vector2(0, -27), 48.0, 0, TAU, 48, Color("ffdb77"), 4.0, true)
	draw_rect(SAFE, Color(0.1, 0.48, 0.9, 0.14))
	draw_line(Vector2(SAFE.end.x, SAFE.position.y), Vector2(SAFE.end.x, SAFE.end.y), Color("80c9ff"), 5.0)


func _build_sfx() -> void:
	for cue in [["ThrowoffTitle", THROWOFF_TITLE_SFX, -8.0], ["ThrowoffTick", THROWOFF_TICK_SFX, -7.0], ["ThrowoffGo", THROWOFF_GO_SFX, -7.0], ["CanHit", CAN_HIT_SFX, -5.0]]:
		var sound := AudioStreamPlayer.new()
		sound.name = cue[0]
		sound.stream = cue[1]
		sound.volume_db = cue[2]
		add_child(sound)
		match sound.name:
			"ThrowoffTitle": title_sfx = sound
			"ThrowoffTick": tick_sfx = sound
			"ThrowoffGo": go_sfx = sound
			"CanHit": can_sfx = sound
	last_can_state = can.state


func _update_match_sfx() -> void:
	if title_sfx == null or can == null:
		return
	if stage != last_sfx_stage:
		match stage:
			"intro": title_sfx.play()
			"run_to_line": last_countdown = 4
			"throw_off": go_sfx.play()
		last_sfx_stage = stage
	if stage == "run_to_line" and remaining > 0.0 and remaining <= 3.0:
		var count := ceili(remaining)
		if count < last_countdown:
			tick_sfx.pitch_scale = 1.0 + float(3 - count) * 0.14
			tick_sfx.play()
			last_countdown = count
	if stage == "active" and remaining > 0.0 and remaining <= FINAL_COUNTDOWN_SECONDS:
		var second := ceili(remaining)
		if second < last_final_tick:
			# Rise in pitch toward the buzzer.
			tick_sfx.pitch_scale = 1.0 + float(FINAL_COUNTDOWN_SECONDS - second) * 0.05
			tick_sfx.play()
			last_final_tick = second
	elif stage == "active":
		last_final_tick = FINAL_COUNTDOWN_SECONDS + 1
	if can.state != last_can_state:
		if last_can_state == can.State.STANDING and can.state == can.State.TOPPLED and can.hit_flash_remaining > 0.0:
			var strength: float = clampf(can.impact_audio_strength, 0.0, 1.0)
			can_sfx.volume_db = lerpf(-7.0, -2.0, strength)
			can_sfx.pitch_scale = lerpf(0.9, 1.08, strength)
			can_sfx.play()
			_shake(lerpf(CAN_SHAKE_MIN, CAN_SHAKE_MAX, strength))
			_spawn_can_impact(strength)
			_hit_stop(70)
		last_can_state = can.state


func _build_camera() -> void:
	match_camera = Camera2D.new()
	match_camera.zoom = Vector2.ONE * CAMERA_NORMAL_ZOOM
	match_camera.position = _spawn_point(int(LanSession.member(LanSession.local_id()).get("slot", 0)))
	add_child(match_camera)
	_update_camera(1.0)
	match_camera.reset_smoothing()

func _process(delta: float) -> void:
	super._process(delta)
	_update_match_sfx()
	_update_intro_visual()
	_update_tag_announcement()
	_update_hit_stop()
	_update_score_popups()
	_update_bounce_dust()
	_update_camera(delta)

func _update_tag_announcement() -> void:
	if tag_panel == null:
		return
	var time_left := tag_notice_until - LanSession.clock_time()
	var visible := stage in ["active", "tag_reset"] and tag_notice_id != 0 and time_left > 0.0
	tag_panel.visible = visible
	tag_shade.visible = visible
	if not visible:
		return
	var progress := clampf(1.0 - time_left / TAG_NOTICE_SECONDS, 0.0, 1.0)
	var opacity := minf(1.0, minf(progress / 0.15, time_left / 0.35))
	tag_panel.modulate.a = opacity
	tag_panel.scale = Vector2.ONE * lerpf(0.9, 1.0, smoothstep(0.0, 0.28, progress))
	tag_shade.color.a = (0.24 + 0.7 * sin(PI * progress) if stage == "tag_reset" else 0.24) * opacity
	tag_title.text = "%s\nIS NOW TAYA!" % str(LanSession.member(tag_notice_id).get("name", "Player")).to_upper()

func _update_camera(delta: float) -> void:
	if match_camera == null or can == null: return
	var actor = actors.get(LanSession.local_id())
	if actor == null: return
	var viewport_size := get_viewport_rect().size
	var subject: Vector2 = actor.global_position
	var max_zoom := CAMERA_NORMAL_ZOOM
	var following_throw := false
	if stage in ["throw_off", "active"]:
		var own_slipper: Node2D = actor.active_slipper
		if is_instance_valid(own_slipper) and not own_slipper.resting and own_slipper.lost_remaining <= 0.0:
			camera_slipper = own_slipper
			camera_landing_point = own_slipper.global_position
			camera_return_at = 0.0
			camera_following_slipper = true
		elif camera_following_slipper and camera_return_at == 0.0:
			if is_instance_valid(camera_slipper):
				camera_landing_point = camera_slipper.global_position
			camera_landing_point = camera_landing_point.clamp(ARENA.position, ARENA.end)
			camera_return_at = LanSession.clock_time() + 1.0
		if camera_return_at > 0.0 and LanSession.clock_time() >= camera_return_at:
			camera_slipper = null
			camera_return_at = 0.0
			camera_following_slipper = false
		if camera_following_slipper and is_instance_valid(camera_slipper) and camera_return_at == 0.0:
			subject = camera_slipper.global_position
			following_throw = true
		elif camera_return_at > 0.0:
			subject = camera_landing_point
			following_throw = true
	else:
		camera_slipper = null
		camera_return_at = 0.0
		camera_following_slipper = false
	if following_throw:
		max_zoom = CAMERA_SLIPPER_ZOOM
	elif actor.attack_state == actor.AttackState.CHARGING or actor.taya_stun_aiming:
		max_zoom = CAMERA_AIM_ZOOM
	# Frame the can along with the local player or their slipper, including a little space around both.
	var can_position: Vector2 = can.global_position
	var focus: Vector2 = (subject + can_position) * 0.5 + Vector2(0, -55)
	var span: Vector2 = (subject - can_position).abs() + Vector2(320, 340)
	var target_zoom := minf(max_zoom, minf(viewport_size.x / span.x, viewport_size.y / span.y))
	target_zoom = clampf(target_zoom, 0.9, CAMERA_NORMAL_ZOOM)
	var visible_half := viewport_size / (target_zoom * 2.0)
	if visible_half.x * 2.0 < CAMERA_BOUNDS.size.x:
		focus.x = clampf(focus.x, CAMERA_BOUNDS.position.x + visible_half.x, CAMERA_BOUNDS.end.x - visible_half.x)
	else:
		focus.x = CAMERA_BOUNDS.get_center().x
	if visible_half.y * 2.0 < CAMERA_BOUNDS.size.y:
		focus.y = clampf(focus.y, CAMERA_BOUNDS.position.y + visible_half.y, CAMERA_BOUNDS.end.y - visible_half.y)
	else:
		focus.y = CAMERA_BOUNDS.get_center().y
	var weight := 1.0 - exp(-delta / (0.16 if following_throw else 0.26))
	match_camera.position = match_camera.position.lerp(focus, weight)
	match_camera.zoom = match_camera.zoom.lerp(Vector2.ONE * target_zoom, weight)
	shake_strength = move_toward(shake_strength, 0.0, SHAKE_DECAY * delta)
	match_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength if shake_strength > 0.0 else Vector2.ZERO

func _update_intro_visual() -> void:
	if intro_shade == null:
		return
	intro_shade.visible = stage in ["intro", "throw_off_result"]
	intro_title.visible = stage == "intro"
	result_panel.visible = stage == "throw_off_result" and taya_id != 0
	if stage == "intro":
		var progress := clampf((INTRO_SECONDS - remaining) / INTRO_SECONDS, 0.0, 1.0)
		var slide_in := smoothstep(0.0, 0.34, progress)
		var slide_out := smoothstep(0.76, 1.0, progress)
		var width := get_viewport_rect().size.x
		intro_title.position.x = lerpf(-900.0, (width - intro_title.size.x) * 0.5, slide_in) + width * slide_out
		intro_title.position.y = (get_viewport_rect().size.y - intro_title.size.y) * 0.5
		intro_shade.color.a = 0.48 * minf(slide_in, 1.0 - slide_out)
	elif stage == "throw_off_result":
		intro_shade.color.a = 0.36
		var member: Dictionary = LanSession.member(taya_id)
		result_title.text = "%s IS TAYA!" % str(member.get("name", "Player")).to_upper()
		result_character.text = str(LanSession.CHARACTERS[int(member.get("character", 0))]).to_upper()
		var winner: CharacterBody2D = actors.get(taya_id)
		if winner != null:
			var frames: SpriteFrames = winner.sprite.sprite_frames
			if frames.has_animation("idle_down"):
				result_portrait.texture = frames.get_frame_texture("idle_down", 0)
