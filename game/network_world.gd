extends Node2D

const PLAYER_FONT = preload("res://assets/fonts/TitanOne-Regular.ttf")
const SLIPPER = preload("res://scenes/slipper_visual.gd")
const LAN_SNAPSHOT_INTERVAL := 1.0 / 30.0
const ONLINE_SNAPSHOT_INTERVAL := 1.0 / 20.0
const LAN_SMOOTHING_SECONDS := 0.025
const LAN_VISUAL_SMOOTHING_SECONDS := 0.05
@export_range(0.5, 1.0, 0.001) var player_scale := 0.52
var actors: Dictionary = {}
var world_tick := 0.0
var send_tick := 0.0
var observed_slippers: Dictionary = {}
var observed_extra_slippers: Dictionary = {}
var observed_taya_slippers: Dictionary = {}
var lan_movement: RefCounted
var lan_remote_motion: Dictionary = {}
var lan_visual_targets: Dictionary = {}
var lan_phase := ""

func setup_network_world() -> void:
	if has_node("Player"):
		get_node("Player").free()
	LanSession.roster_changed.connect(_sync_actors)
	LanSession.input_received.connect(_receive_input)
	LanSession.throw_input_received.connect(_receive_throw)
	LanSession.world_snapshot_received.connect(_apply_snapshot)
	LanSession.room_closed.connect(_room_closed)
	_sync_actors()
	if not LanSession.is_host():
		for can in get_tree().get_nodes_in_group("can_targets"):
			can.set_physics_process(false)
			if LanSession.mode != "lan": can.collision_layer = 0

func _spawn_point(slot: int) -> Vector2:
	if LanSession.players.size() == 1:
		return Vector2(1210, 820)
	return Vector2(1140 + (slot % 2) * 230, 450 + int(slot / 2) * 250)

func _sync_actors() -> void:
	var previous_positions := {}
	for id in actors.keys():
		var entry := LanSession.member(id)
		if entry.is_empty() or int(actors[id].get_meta("character_index", -2)) != int(entry.character):
			previous_positions[id] = actors[id].position
			actors[id].set_taya_role(false)
			if is_instance_valid(actors[id].active_slipper):
				actors[id].active_slipper.queue_free()
			actors[id].collision_layer = 0
			actors[id].collision_mask = 0
			actors[id].hide()
			actors[id].name = "Retiring_%s" % id
			actors[id].queue_free()
			actors.erase(id)
			observed_slippers.erase(id)
			lan_remote_motion.erase(id)
	for entry in LanSession.players:
		if actors.has(entry.id):
			continue
		var character_index: int = clampi(int(entry.character), 0, LanSession.CHARACTERS.size() - 1)
		var path := "res://scenes/Thrower %s.tscn" % LanSession.CHARACTERS[character_index]
		var scene := load(path) as PackedScene
		if scene == null:
			push_error("Could not load %s; using Head Band until the game files are repaired." % path)
			scene = load("res://scenes/Thrower Head Band.tscn") as PackedScene
		if scene == null:
			push_error("Could not load the fallback player scene.")
			continue
		var actor := scene.instantiate() as CharacterBody2D
		var body: AnimatedSprite2D
		if actor != null:
			body = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if body == null or body.sprite_frames == null:
			push_error("Missing character frames in %s; using Head Band until the game files are repaired." % path)
			if actor != null:
				actor.free()
			var fallback := load("res://scenes/Thrower Head Band.tscn") as PackedScene
			if fallback == null:
				continue
			actor = fallback.instantiate() as CharacterBody2D
			if actor == null:
				continue
			body = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if body == null or body.sprite_frames == null:
				push_error("The fallback Head Band scene also has missing frames.")
				actor.free()
				continue
		actor.name = "Player" if entry.id == 1 else "Player_%s" % entry.id
		actor.position = previous_positions.get(entry.id, _spawn_point(entry.slot))
		actor.scale = Vector2.ONE * player_scale
		actor.walk_speed = 240.0
		actor.sprint_speed = 340.0
		actor.player_color = entry.color
		actor.set_meta("peer_id", entry.id)
		actor.set_meta("character_index", entry.character)
		actor.set_meta("bot", entry.bot)
		actor.network_controlled = entry.id != LanSession.local_id() or entry.bot
		actor.accept_local_input = LanSession.is_host()
		actor.collision_mask = 1 | 2 | 16
		add_child(actor)
		var shadow := Node2D.new()
		shadow.name = "GroundShadow"
		shadow.show_behind_parent = true
		shadow.set_script(preload("res://ui/waiting_room/ground_shadow.gd"))
		actor.add_child(shadow)
		if not LanSession.is_host():
			actor.set_physics_process(false)
			actor.collision_layer = 2 if LanSession.mode == "lan" else 0
		actor.throw_status.visible = entry.id == LanSession.local_id()
		actor.throw_status.scale = Vector2.ONE / player_scale
		actor.throw_status.position.x /= player_scale
		var name_label := Label.new()
		name_label.position = Vector2(-90 / player_scale, -250)
		name_label.scale = Vector2.ONE / player_scale
		name_label.size = Vector2(180, 28)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.text = entry.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", PLAYER_FONT)
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_outline_color", Color("20130f"))
		name_label.add_theme_constant_override("outline_size", 6)
		actor.add_child(name_label)
		actor.name_label = name_label
		var role_label := Label.new()
		role_label.position = Vector2(-70 / player_scale, -455)
		role_label.scale = Vector2.ONE / player_scale
		role_label.size = Vector2(140, 30)
		role_label.text = "TAYA"
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.add_theme_font_override("font", PLAYER_FONT)
		role_label.add_theme_font_size_override("font_size", 31)
		role_label.add_theme_color_override("font_color", Color("ff3030"))
		role_label.add_theme_color_override("font_outline_color", Color("290d0b"))
		role_label.add_theme_constant_override("outline_size", 8)
		role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		actor.add_child(role_label)
		actor.role_label = role_label
		actor.update_name_color()
		actors[entry.id] = actor
		_actor_added(actor)
		if LanSession.mode == "lan" and not LanSession.is_host() and entry.id == LanSession.local_id():
			lan_movement = preload("res://game/lan_movement.gd").new(actor)

func _actor_added(_actor: CharacterBody2D) -> void:
	pass

func _world_inputs_enabled() -> bool:
	return true

func _actor_inputs_enabled(_actor: CharacterBody2D) -> bool:
	return _world_inputs_enabled()

func _local_inputs_enabled() -> bool:
	return _world_inputs_enabled()

func _physics_process(delta: float) -> void:
	if LanSession.is_host():
		for id in actors:
			var actor: CharacterBody2D = actors[id]
			actor.accept_local_input = _actor_inputs_enabled(actor) and (_local_inputs_enabled() if id == LanSession.local_id() else true)
			if actor.get_meta("bot", false) and _actor_inputs_enabled(actor):
				_update_bot(actor)
			if is_instance_valid(actor.active_slipper) and observed_slippers.get(id) != actor.active_slipper.get_instance_id():
				observed_slippers[id] = actor.active_slipper.get_instance_id()
				_slipper_spawned(actor, actor.active_slipper)
			for shot in actor.rapid_slippers:
				if is_instance_valid(shot) and not observed_extra_slippers.has(shot.get_instance_id()):
					observed_extra_slippers[shot.get_instance_id()] = true
					_slipper_spawned(actor, shot)
			if is_instance_valid(actor.taya_stun_projectile) and observed_taya_slippers.get(id) != actor.taya_stun_projectile.get_instance_id():
				observed_taya_slippers[id] = actor.taya_stun_projectile.get_instance_id()
				_taya_stun_spawned(actor, actor.taya_stun_projectile)
		world_tick += delta
		var snapshot_interval := LAN_SNAPSHOT_INTERVAL if LanSession.mode == "lan" else ONLINE_SNAPSHOT_INTERVAL
		if world_tick >= snapshot_interval:
			world_tick = fmod(world_tick, snapshot_interval)
			if LanSession.mode == "lan": _publish_lan_snapshot.call_deferred()
			else: LanSession.publish_world(_snapshot())
	elif LanSession.mode == "lan":
		_update_lan_client(delta)
	else:
		send_tick += delta
		if send_tick >= 1.0 / 30.0:
			send_tick = 0.0
			var active: Node2D = actors.get(LanSession.local_id())
			if active != null:
				var enabled := _local_inputs_enabled() and _actor_inputs_enabled(active)
				LanSession.send_input({"move": Input.get_vector("left", "right", "up", "down") if enabled and not active.movement_locked else Vector2.ZERO, "aim": UserSettings.aim_position(active), "sprint": enabled and Input.is_action_pressed("sprint"), "interact": enabled and Input.is_action_pressed("interact"), "lunge": enabled and Input.is_action_pressed("lunge"), "throw": enabled and UserSettings.throw_pressed(get_viewport()), "charge_id": active.charge_id})

func _publish_lan_snapshot() -> void:
	if LanSession.mode == "lan" and LanSession.is_host(): LanSession.publish_world(_snapshot())

func _update_lan_client(delta: float) -> void:
	var actor: CharacterBody2D = actors.get(LanSession.local_id())
	if actor == null or lan_movement == null: return
	var enabled: bool = _local_inputs_enabled() and _actor_inputs_enabled(actor) and lan_movement.fresh()
	var packet := {"move": Input.get_vector("left", "right", "up", "down") if enabled and not actor.movement_locked else Vector2.ZERO, "aim": UserSettings.aim_position(actor), "sprint": enabled and Input.is_action_pressed("sprint"), "interact": enabled and Input.is_action_pressed("interact"), "lunge": enabled and Input.is_action_pressed("lunge"), "throw": enabled and UserSettings.throw_pressed(get_viewport()), "charge_id": actor.charge_id}
	LanSession.send_input(packet)
	var movable: bool = enabled and not actor.is_stunned() and not actor.taya_stun_aiming and LanSession.clock_time() >= actor.taya_stun_cast_until and actor.attack_state == actor.AttackState.FREE and actor.taya_action == &""
	if not actor.is_taya and packet["throw"] and actor.throw_target_ready() and not is_instance_valid(actor.active_slipper): movable = false
	lan_movement.step(delta, LanSession.send_sequence, packet, movable)

func _process(delta: float) -> void:
	if LanSession.mode != "lan" or LanSession.is_host(): return
	var blend := 1.0 - exp(-delta / LAN_SMOOTHING_SECONDS)
	var visual_blend := 1.0 - exp(-delta / LAN_VISUAL_SMOOTHING_SECONDS)
	for id in lan_remote_motion.keys():
		if not actors.has(id):
			lan_remote_motion.erase(id)
			continue
		var motion: Dictionary = lan_remote_motion[id]
		motion.age += delta
		# Ease out a remote actor's velocity if packets pause, instead of freezing
		# exactly at the extrapolation cap and jumping on the next packet.
		var lead: float = minf(motion.age, 0.06)
		if motion.age > 0.06:
			lead += 0.06 * (1.0 - exp(-(motion.age - 0.06) / 0.06))
		var target: Vector2 = motion.position + motion.velocity * lead
		actors[id].position = actors[id].position.lerp(target, blend)
	for visual in lan_visual_targets.keys():
		if not is_instance_valid(visual):
			lan_visual_targets.erase(visual)
			continue
		var target: Dictionary = lan_visual_targets[visual]
		if target.get("global", false):
			visual.global_position = visual.global_position.lerp(target.position, visual_blend)
			visual.rotation = lerp_angle(visual.rotation, target.rotation, visual_blend)
			visual.scale = visual.scale.lerp(target.scale, visual_blend)
		else:
			if target.has("height") and (visual.position.distance_to(target.position) > 0.05 or absf(visual.height - target.height) > 0.05 or absf(angle_difference(visual.spin_angle, target.spin)) > 0.005):
				visual.position = visual.position.lerp(target.position, visual_blend)
				visual.height = lerpf(visual.height, target.height, visual_blend)
				visual.spin_angle = lerp_angle(visual.spin_angle, target.spin, visual_blend)
				visual.queue_redraw()

func _receive_input(id: int, packet: Dictionary) -> void:
	if LanSession.is_host() and actors.has(id):
		if _actor_inputs_enabled(actors[id]):
			actors[id].apply_network_input(packet)
		else:
			actors[id].network_input = {}
			actors[id].network_edges.clear()

func _receive_throw(id: int, pressed: bool, charge: int, at_time: float, aim: Vector2) -> void:
	if not LanSession.is_host() or not actors.has(id) or not _world_inputs_enabled(): return
	var actor: CharacterBody2D = actors[id]
	if not _actor_inputs_enabled(actor): return
	actor.network_input["aim"] = aim
	actor.network_input["throw"] = pressed
	if pressed:
		if not actor.is_taya and actor.attack_state == actor.AttackState.FREE and not is_instance_valid(actor.active_slipper):
			actor._start_charge()
	else:
		if not actor.release_network_throw(charge, at_time, aim) and actor.attack_state == actor.AttackState.CHARGING:
			# Quick clicks can release before the start snapshot arrives; cancel, never award a perfect throw.
			actor.set_taya_role(actor.is_taya)

func _slipper_spawned(_actor: CharacterBody2D, _slipper: Node2D) -> void:
	pass

func _taya_stun_spawned(_actor: CharacterBody2D, _slipper: Node2D) -> void:
	pass

func _update_bot(actor: CharacterBody2D) -> void:
	var can: CharacterBody2D = actor.can_node
	if can == null:
		return
	var destination := can.global_position
	var interact := false
	var lunge := false
	var throwing := false
	if actor.is_taya:
		if actor.carrying_can:
			destination = can.base.global_position
			interact = actor.global_position.distance_to(destination) <= 60.0
		elif can.is_toppled():
			interact = can.can_pick_up(actor)
		else:
			var nearest := INF
			for candidate in actors.values():
				if candidate == actor or actor.safe_strip_rect.has_point(candidate.global_position):
					continue
				var distance: float = actor.global_position.distance_to(candidate.global_position)
				if distance < nearest:
					nearest = distance
					destination = candidate.global_position
			lunge = actor.can_lunge() and nearest < float(LanSession.bot_profile().lunge)
	elif is_instance_valid(actor.active_slipper):
		if actor.active_slipper.lost_remaining > 0.0:
			destination = actor.global_position
		else:
			destination = actor.active_slipper.global_position
	elif actor.get_meta("returning", false):
		destination = Vector2(actor.safe_strip_rect.get_center().x, actor.global_position.y)
	else:
		if actor.allowed_throw_rect.has_area():
			var slot := int(LanSession.member(int(actor.get_meta("peer_id"))).get("slot", 0))
			var throwing_y: float = can.global_position.y + (slot - 2) * 125.0
			destination = Vector2(actor.allowed_throw_rect.end.x - 35.0, clampf(throwing_y, actor.allowed_throw_rect.position.y + 90.0, actor.allowed_throw_rect.end.y - 90.0))
		var aim_distance: float = (destination - actor.global_position).length()
		if (actor.allowed_throw_rect.has_area() and aim_distance < 35.0) or (not actor.allowed_throw_rect.has_area() and aim_distance < 300.0):
			destination = actor.global_position
			throwing = actor.attack_state != actor.AttackState.CHARGING or actor.charge_bar.value < float(actor.get_meta("bot_release_at", actor.sweet_spot))
	var toward := destination - actor.global_position
	var move: Vector2 = toward.normalized() if toward.length() > 18.0 else Vector2.ZERO
	# Easier bots react late: they keep their last heading until their next decision.
	var profile: Dictionary = LanSession.bot_profile()
	var now := LanSession.clock_time()
	# Arriving (no move) applies at once so bots never drift out of the throwing spot.
	if float(profile.think) > 0.0 and move != Vector2.ZERO:
		if now < float(actor.get_meta("bot_next_think", 0.0)):
			move = actor.get_meta("bot_move", move)
		else:
			actor.set_meta("bot_next_think", now + float(profile.think) * randf_range(0.7, 1.3))
			actor.set_meta("bot_move", move)
	var aim: Vector2 = can.get_hit_center() + actor.get_meta("bot_aim_offset", Vector2.ZERO) if not actor.is_taya else destination
	var sprint: bool = bool(profile.taya_sprint) or not actor.is_taya
	actor.apply_network_input({"move": move, "aim": aim, "throw": throwing, "sprint": sprint, "interact": interact, "lunge": lunge})

func _snapshot() -> Dictionary:
	var state := {"actors": [], "cans": [], "extra": _extra_snapshot()}
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		var data := {"id": id, "position": actor.position, "velocity": actor.velocity, "taya": actor.is_taya, "skill_charge": actor.skill_charge, "special_armed": actor.special_armed, "stunned_until": actor.stunned_until, "stun_started_at": actor.stun_started_at, "stun_immune_until": actor.stun_immune_until, "taya_stun_ready_at": actor.taya_stun_ready_at, "taya_stun_aiming": actor.taya_stun_aiming, "taya_stun_cast_until": actor.taya_stun_cast_until, "glow_until": actor.ability_glow_until, "carrying": actor.carrying_can, "tag_ready_at": actor.tag_ready_at, "released": actor.slipper_spawned, "taya_action": String(actor.taya_action), "facing": actor.facing, "attack": actor.attack_state, "aim": actor.attack_direction, "distance": actor.aim_distance, "charge": actor.charge_bar.value, "charge_id": actor.charge_id, "charge_started": actor.charge_started, "sweet_spot": actor.sweet_spot, "feedback": actor.throw_feedback, "feedback_until": actor.feedback_until, "sprite": actor.sprite.animation, "frame": actor.sprite.frame, "sprite_speed": actor.sprite.speed_scale, "flip": actor.sprite.flip_h, "sprite_pos": actor.sprite.position, "sprite_scale": actor.sprite.scale, "rotation": actor.sprite.rotation, "attack_sprite": actor.attack_sprite.animation, "attack_frame": actor.attack_sprite.frame, "attack_pos": actor.attack_sprite.position, "attack_scale": actor.attack_sprite.scale, "attack_flip": actor.attack_sprite.flip_h, "flash": actor.hit_flash_remaining, "slipper": {}, "rapid": [], "taya_stun": {}}
		if is_instance_valid(actor.active_slipper):
			data.slipper = _slipper_snapshot(actor.active_slipper)
		for shot in actor.rapid_slippers:
			if is_instance_valid(shot): data.rapid.append(_slipper_snapshot(shot))
		if is_instance_valid(actor.taya_stun_projectile): data.taya_stun = _slipper_snapshot(actor.taya_stun_projectile)
		if LanSession.mode == "lan": data["lan_ack"] = actor.lan_processed_input_sequence
		state.actors.append(data)
	for can in get_tree().get_nodes_in_group("can_targets"):
		state.cans.append({"name": String(can.name), "position": can.position, "state": can.state, "height": can.height, "tilt": can.tilt_angle, "settled": can.settled, "flash": can.hit_flash_remaining, "impact": can.impact_audio_strength, "squash": can.squash, "auto_stand": can.auto_stand_pending, "base": can.base.global_position if can.base != null else can.global_position})
	return state

func _slipper_snapshot(slipper: Node2D) -> Dictionary:
	return {"position": slipper.position, "velocity": slipper.velocity, "height": slipper.height, "spin": slipper.spin_angle, "charge": slipper.charge_ratio, "resting": slipper.resting, "bounces": slipper.floor_bounces, "lost": slipper.lost_remaining, "age": slipper.age, "kind": String(slipper.special_kind), "returning": slipper.returning, "visible": slipper.visible}

func _apply_snapshot(snapshot: Dictionary) -> void:
	if LanSession.is_host():
		return
	var phase: String = snapshot.get("extra", {}).get("stage", "waiting")
	var phase_changed := phase != lan_phase
	lan_phase = phase
	_apply_extra_snapshot(snapshot.get("extra", {}))
	for data in snapshot.get("actors", []):
		if not actors.has(data.id):
			continue
		var actor: CharacterBody2D = actors[data.id]
		var lan_client := LanSession.mode == "lan"
		var own: bool = lan_client and data.id == LanSession.local_id() and lan_movement != null
		var ability_changed: bool = actor.is_stunned() != (float(data.get("stunned_until", 0.0)) > LanSession.clock_time()) or actor.taya_stun_aiming != bool(data.get("taya_stun_aiming", false)) or (LanSession.clock_time() < actor.taya_stun_cast_until) != (LanSession.clock_time() < float(data.get("taya_stun_cast_until", 0.0)))
		var reset: bool = phase_changed or ability_changed or actor.is_taya != data.taya or actor.attack_state != data.attack or actor.carrying_can != data.carrying or String(actor.taya_action) != data.taya_action
		if not lan_client:
			actor.position = data.position
		elif not own:
			if reset or actor.position.distance_to(data.position) > 128.0: actor.position = data.position
			lan_remote_motion[data.id] = {"position": data.position, "velocity": data.velocity, "age": 0.0}
		actor.velocity = data.velocity
		if actor.is_taya != data.taya:
			actor.set_taya_role(data.taya)
		actor.set_skill_charge(int(data.get("skill_charge", 0)))
		actor.special_armed = bool(data.get("special_armed", false))
		actor.stunned_until = float(data.get("stunned_until", 0.0))
		actor.stun_started_at = float(data.get("stun_started_at", 0.0))
		actor.stun_immune_until = float(data.get("stun_immune_until", 0.0))
		actor.taya_stun_ready_at = float(data.get("taya_stun_ready_at", 0.0))
		actor.taya_stun_aiming = bool(data.get("taya_stun_aiming", false))
		actor.taya_stun_cast_until = float(data.get("taya_stun_cast_until", 0.0))
		actor.ability_glow_until = float(data.get("glow_until", 0.0))
		actor.carrying_can = data.carrying
		actor.tag_ready_at = float(data.get("tag_ready_at", 0.0))
		actor.facing = data.facing
		actor.attack_state = data.attack
		actor.attack_direction = data.aim
		actor.aim_distance = data.distance
		actor.slipper_spawned = bool(data.get("released", true))
		actor.charge_id = int(data.get("charge_id", 0))
		actor.charge_started = float(data.get("charge_started", 0.0))
		actor.sweet_spot = float(data.get("sweet_spot", 0.5))
		actor.throw_feedback = str(data.get("feedback", ""))
		actor.feedback_until = float(data.get("feedback_until", 0.0))
		actor.charge_bar.target_center = actor.sweet_spot
		actor.charge_bar.value = data.charge
		actor.charge_bar.visible = data.attack == actor.AttackState.CHARGING and actor.is_local_view()
		if not own or actor.is_stunned() or actor.taya_stun_aiming or LanSession.clock_time() < actor.taya_stun_cast_until or data.attack != actor.AttackState.FREE or data.carrying or data.taya_action != "":
			var changed_animation: bool = actor.sprite.animation != data.sprite
			if changed_animation:
				actor.sprite.play(data.sprite)
			# Remote locomotion runs locally between packets. Replacing its frame on
			# every snapshot made walking visibly stutter when packets arrived unevenly.
			var animation_name := String(data.sprite)
			var locomotion_loop := animation_name.contains("idle_") or animation_name.contains("walk_") or animation_name.contains("sprint_")
			if own or reset or changed_animation or not locomotion_loop:
				actor.sprite.frame = data.frame
			actor.sprite.speed_scale = float(data.get("sprite_speed", 1.0))
			actor.sprite.flip_h = data.flip
			# A remote walk cycle advances between packets. Keep its own frame's
			# fitted size and foot anchor instead of copying another frame's fit.
			if own or reset or changed_animation or not locomotion_loop:
				actor.sprite.position = data.sprite_pos
				actor.sprite.scale = data.sprite_scale
			actor.sprite.rotation = data.rotation
		var stun_cast: bool = data.taya_stun_aiming or LanSession.clock_time() < actor.taya_stun_cast_until
		actor.sprite.visible = data.attack == actor.AttackState.FREE and not data.carrying and data.taya_action == "" and not stun_cast
		actor.attack_sprite.visible = data.attack != actor.AttackState.FREE or stun_cast and not data.carrying
		actor.attack_sprite.animation = data.attack_sprite
		actor.attack_sprite.frame = data.attack_frame
		actor.attack_sprite.position = data.attack_pos
		actor.attack_sprite.scale = data.attack_scale
		actor.attack_sprite.flip_h = data.attack_flip
		actor.modulate = Color(1.8, 1.35, 0.9) if data.flash > 0.0 else Color(1.35, 1.15, 1.8) if actor.is_stunned() else Color.WHITE
		if stun_cast and not data.carrying:
			actor.taya_visual.hide()
		elif data.carrying and data.taya_action == "":
			actor.taya_visual.show_carry(actor._facing_sector(), data.velocity.length() > 10.0)
		elif not data.taya_action.is_empty():
			if String(actor.taya_action) != data.taya_action:
				actor.taya_visual.play_action(StringName(data.taya_action), actor._facing_sector())
		else:
			actor.taya_visual.hide()
		actor.taya_action = StringName(data.taya_action)
		if data.slipper.is_empty():
			if is_instance_valid(actor.active_slipper):
				actor.active_slipper.queue_free()
			actor.active_slipper = null
		else:
			if not is_instance_valid(actor.active_slipper):
				actor.active_slipper = SLIPPER.new()
				add_child(actor.active_slipper)
				actor.active_slipper.set_physics_process(false)
				if data.slipper.age < 0.5 and not data.slipper.resting:
					actor.play_throw_grunt()
			var slipper: Node2D = actor.active_slipper
			_apply_slipper_snapshot(slipper, actor, data.slipper)
		while actor.rapid_slippers.size() > data.rapid.size():
			var old: Node2D = actor.rapid_slippers.pop_back()
			if is_instance_valid(old): old.queue_free()
		while actor.rapid_slippers.size() < data.rapid.size():
			var extra := SLIPPER.new()
			add_child(extra)
			extra.set_physics_process(false)
			actor.rapid_slippers.append(extra)
		for index in range(data.rapid.size()):
			_apply_slipper_snapshot(actor.rapid_slippers[index], actor, data.rapid[index])
		if data.taya_stun.is_empty():
			if is_instance_valid(actor.taya_stun_projectile): actor.taya_stun_projectile.queue_free()
			actor.taya_stun_projectile = null
		else:
			if not is_instance_valid(actor.taya_stun_projectile):
				actor.taya_stun_projectile = SLIPPER.new()
				add_child(actor.taya_stun_projectile)
				actor.taya_stun_projectile.set_physics_process(false)
			_apply_slipper_snapshot(actor.taya_stun_projectile, actor, data.taya_stun)
		if own: lan_movement.receive(data, reset)
		actor._refresh_possession_visual()
		if actor.throw_status.visible: actor._update_throw_status()
		if not lan_client and data.id == LanSession.local_id() and actor.attack_state == actor.AttackState.CHARGING:
			actor._update_trajectory()
		actor.queue_redraw()
	for data in snapshot.get("cans", []):
		var can := get_node_or_null(NodePath(data.name))
		if can != null:
			var visual: Sprite2D = can.can_sprite
			var previous_position: Vector2 = visual.global_position
			var previous_rotation: float = visual.rotation
			var previous_scale: Vector2 = visual.scale
			var previous_state: int = can.state
			var seen: bool = lan_visual_targets.has(visual)
			can.position = data.position
			can.state = data.state
			can.height = data.height
			can.tilt_angle = data.tilt
			can.settled = data.settled
			can.squash = data.squash
			can.hit_flash_remaining = float(data.get("flash", 0.0))
			can.impact_audio_strength = float(data.get("impact", 0.0))
			can.auto_stand_pending = data.auto_stand
			if can.base != null and not can.base.global_position.is_equal_approx(data.base):
				can.base.global_position = data.base
				queue_redraw()
			can.can_sprite.modulate = Color(2.0, 1.8, 1.1) if data.flash > 0.0 else Color.WHITE
			can._refresh_visual()
			if LanSession.mode == "lan":
				var target := {"position": visual.global_position, "rotation": visual.rotation, "scale": visual.scale, "global": true}
				if seen and not phase_changed and previous_state == can.state and can.state != can.State.CARRIED and previous_position.distance_to(visual.global_position) < 160.0:
					visual.global_position = previous_position
					visual.rotation = previous_rotation
					visual.scale = previous_scale
				lan_visual_targets[visual] = target

func _apply_slipper_snapshot(slipper: Node2D, actor: CharacterBody2D, data: Dictionary) -> void:
	slipper.throw_owner = actor
	slipper.outline_color = actor.player_color
	var previous_height: float = slipper.height
	var previous_spin: float = slipper.spin_angle
	var snap := true
	if LanSession.mode == "lan":
		var seen: bool = lan_visual_targets.has(slipper)
		snap = not seen or slipper.position.distance_to(data.position) > 160.0
		if snap:
			slipper.position = data.position
		lan_visual_targets[slipper] = {"position": data.position, "height": data.height, "spin": data.spin}
	else:
		slipper.position = data.position
	slipper.velocity = data.velocity
	slipper.height = data.height
	slipper.spin_angle = data.spin
	if LanSession.mode == "lan" and not snap:
		slipper.height = previous_height
		slipper.spin_angle = previous_spin
	slipper.charge_ratio = data.charge
	slipper.resting = data.resting
	slipper.floor_bounces = data.bounces
	slipper.lost_remaining = data.lost
	slipper.visible = data.visible
	slipper.age = data.age
	slipper.special_kind = StringName(data.kind)
	slipper.returning = data.returning
	slipper.queue_redraw()

func _extra_snapshot() -> Dictionary:
	return {}

func _apply_extra_snapshot(_data: Dictionary) -> void:
	pass

func _room_closed(reason: String) -> void:
	get_tree().change_scene_to_file.call_deferred("res://ui/main_menu/main_menuu.tscn")
	LanSession.set_meta("notice", reason)
