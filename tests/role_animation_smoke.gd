extends SceneTree

func _initialize() -> void:
	create_timer(25).timeout.connect(func() -> void: printerr("FAIL: role animation timeout"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	for character in ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head"]:
		for starting_role in ["Thrower", "Taya"]:
			var player: CharacterBody2D = load("res://scenes/%s %s.tscn" % [starting_role, character]).instantiate()
			arena.add_child(player)
			player.set_physics_process(false)
			player.set_process(false)
			player.position = Vector2(600, 600)
			assert(player.is_taya == (starting_role == "Taya"))
			for state in ["held", "empty", "taya"]:
				player.set_taya_role(state == "taya")
				var slipper := Node2D.new()
				if state == "empty":
					arena.add_child(slipper)
					player.active_slipper = slipper
				for sector in range(8):
					player.facing = Vector2.RIGHT.rotated(sector * PI / 4)
					for action in ["idle", "walk", "sprint"]:
						player._play(action, player.facing)
						player._refresh_possession_visual()
						var name := String(player.sprite.animation)
						assert(name.begins_with("taya_") if state == "taya" else name.begins_with("empty_") if state == "empty" else not name.begins_with("taya_") and not name.begins_with("empty_"), "%s %s %s: %s" % [character, state, action, name])
						assert(player.possession_icon.visible == (state == "held"), "Only a thrower holding a slipper shows one")
						assert(player.sprite.sprite_frames.get_frame_count(name) > 0)
						if character in ["Head Band", "Glasses Thrower", "Curly Haired"] and state != "taya":
							for frame in range(player.sprite.sprite_frames.get_frame_count(name)):
								var texture: AtlasTexture = player.sprite.sprite_frames.get_frame_texture(name, frame)
								# "/inbetween/" frames are generated only from these relaxed/polished walk poses.
								assert("/relaxed/" in texture.atlas.resource_path or "/motion_polish/" in texture.atlas.resource_path or "/inbetween/" in texture.atlas.resource_path, "Throwers must not use aiming or throw-recovery movement")
								if action == "idle" or (action in ["walk", "sprint"] and sector in [0, 4]):
									# Side gait: drawn corrected poses, plus in-betweens generated from them.
									var generated: bool = action != "idle" and "/inbetween/" in texture.atlas.resource_path
									assert("/motion_polish/" in texture.atlas.resource_path or generated, "Neutral idle and side gait must use the corrected poses")
				if state == "empty":
					slipper.free()
					player.active_slipper = null
				else: slipper.free()
			# Role transfer updates the visible bank before another physics tick.
			player.set_taya_role(false)
			player._refresh_possession_visual()
			assert(player.possession_icon.visible and not String(player.sprite.animation).begins_with("taya_"))
			player._start_charge()
			player._refresh_possession_visual()
			assert(not player.attack_sprite.visible and player.sprite.visible and player.possession_icon.item == &"slipper")
			assert(String(player.attack_sprite.animation).begins_with("aim_"))
			if character == "Bullcap Head":
				for direction in player.DIRECTIONS:
					var frames: SpriteFrames = player.attack_sprite.sprite_frames
					assert(frames.get_frame_count("throw_" + direction) == 4)
					var aim: AtlasTexture = frames.get_frame_texture("aim_" + direction, 0)
					var release: AtlasTexture = frames.get_frame_texture("throw_" + direction, 2)
					assert(aim.atlas.resource_path.ends_with("bullcap_release.png"))
					assert(aim.region.position.x < release.region.position.x, "Held wind-up precedes empty release")
			player.set_taya_role(true)
			assert(not player.possession_icon.visible and not player.attack_sprite.visible)
			assert(String(player.sprite.animation).begins_with("taya_idle_"))
			for action in [&"pickup", &"place", &"lunge"]:
				player._start_taya_action(action)
				player._refresh_possession_visual()
				assert((player.taya_visual.visible and not player.sprite.visible) if action == &"lunge" else (not player.taya_visual.visible and player.sprite.visible))
				assert(not player.possession_icon.visible)
				player.set_taya_role(true)
			player.carrying_can = true
			player.sprite.hide()
			player.taya_visual.show_carry(2, true)
			player._refresh_possession_visual()
			assert(not player.taya_visual.visible and player.sprite.visible and player.possession_icon.item == &"can")
			player.free()
		print("PASS: %s both starting roles, eight directions, idle/walk/sprint, held/empty/Taya, charge and can actions" % character)
	arena.free()
	quit(0)
