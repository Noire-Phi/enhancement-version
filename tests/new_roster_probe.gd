extends SceneTree

const DIRECTIONS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
const ACTIONS := {"idle": 4, "walk": 16, "sprint": 16, "aim": 1, "throw": 4, "hit": 1, "stunned": 2, "recover": 1}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var problems: Array[String] = []
	var hat_frames := load("res://scenes/player_movement_neutral_frames.tres") as SpriteFrames
	print("HAT REFERENCE FRAMES: idle_down=%d walk_down=%d sprint_down=%d" % [hat_frames.get_frame_count(&"idle_down"), hat_frames.get_frame_count(&"walk_down"), hat_frames.get_frame_count(&"sprint_down")])
	for character in ["Leonardo", "Kay"]:
		for role in ["Thrower", "Taya"]:
			var path := "res://scenes/%s %s.tscn" % [role, character]
			var scene := load(path) as PackedScene
			if scene == null:
				problems.append("Missing scene " + path)
				continue
			var actor := scene.instantiate() as CharacterBody2D
			root.add_child(actor)
			var body := actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
			var attack := actor.get_node("AttackSprite") as AnimatedSprite2D
			for direction in DIRECTIONS:
				for action in ACTIONS:
					var animation := StringName(action + "_" + direction)
					var frames := attack.sprite_frames if action in ["aim", "throw"] else body.sprite_frames
					# Walks and cardinal sprints are doubled twice (16 frames); diagonal/side sprints stay at 4 drawn frames.
					var expected_count: int = 4 if (direction.contains("_") or direction in ["left", "right"]) and action == "sprint" else ACTIONS[action]
					if not frames.has_animation(animation) or frames.get_frame_count(animation) != expected_count:
						problems.append("%s: %s" % [path, animation])
						continue
					for frame in range(frames.get_frame_count(animation)):
						var texture := frames.get_frame_texture(animation, frame)
						if texture == null or texture.get_image().get_used_rect().size == Vector2i.ZERO:
							problems.append("Empty %s %s frame %d" % [path, animation, frame])
						if action in ["idle", "walk", "sprint", "hit", "stunned", "recover"]:
							body.play(animation)
							body.frame = frame
							actor._align_current_motion_frame()
							var geometry: Dictionary = actor.motion_geometry[String(animation)]
							# One steady scale per animation: its average height is 210.
							var average := 0.0
							for value in geometry["heights"]: average += float(value)
							average /= float(geometry["heights"].size())
							var visible_height: float = body.scale.y * average
							var foot_y: float = body.position.y + body.scale.y * float(geometry["canvas_height"]) * 0.5
							if absf(visible_height - 210.0) > 0.2 or absf(foot_y) > 0.2:
								problems.append("Size/ground %s %s frame %d" % [path, animation, frame])
				for action in ["idle", "walk", "sprint"]:
					var taya_animation := StringName("taya_" + action + "_" + direction)
					if not body.sprite_frames.has_animation(taya_animation):
						problems.append("%s: %s" % [path, taya_animation])
				for action in ["idle", "walk"]:
					var carry := StringName("carry_" + action + "_" + direction)
					var count := 1 if action == "idle" else 4
					if not body.sprite_frames.has_animation(carry) or body.sprite_frames.get_frame_count(carry) != count:
						problems.append("%s: %s" % [path, carry])
				for action in ["aim", "throw"]:
					var cast := StringName("taya_stun_" + action + "_" + direction)
					var count := 1 if action == "aim" else 4
					if not attack.sprite_frames.has_animation(cast) or attack.sprite_frames.get_frame_count(cast) != count:
						problems.append("%s: %s" % [path, cast])
			var visual = actor.get_node("TayaVisual")
			for can_action in [&"can_pickup", &"can_place"]:
				if not visual.body.sprite_frames.has_animation(can_action) or visual.body.sprite_frames.get_frame_count(can_action) != 4:
					problems.append("%s: %s" % [path, can_action])
			for direction in ["right", "down_right", "down", "up_right", "up"]:
				var lunge := StringName("lunge_" + direction)
				if not visual.body.sprite_frames.has_animation(lunge) or visual.body.sprite_frames.get_frame_count(lunge) != 4:
					problems.append("%s: %s" % [path, lunge])
			if actor.has_thrower_special():
				problems.append("Unexpected special: " + path)
			actor.queue_free()
			await process_frame
	if problems.is_empty():
		print("NEW ROSTER: four scenes, eight directions, movement/throw/reaction/carry/Taya cast/lunge frames OK")
	else:
		for problem in problems:
			push_error(problem)
	quit(0 if problems.is_empty() else 1)
