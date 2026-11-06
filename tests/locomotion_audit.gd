extends SceneTree

const CHARACTERS := ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head", "Leonardo", "Kay"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for character in CHARACTERS:
		for role in ["Thrower", "Taya"]:
			var actor = load("res://scenes/%s %s.tscn" % [role, character]).instantiate()
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			for action in ["idle", "walk", "sprint"]:
				for direction in actor.DIRECTIONS:
					var vector: Vector2 = Vector2.RIGHT.rotated(actor.DIRECTIONS.find(direction) * PI / 4.0)
					actor._play(action, vector)
					var count: int = actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation)
					assert(count >= 1, "%s %s %s %s has no frames" % [character, role, action, direction])
					# Each animation keeps one scale; its average height is 210 and feet stay planted.
					var total_height := 0.0
					var scales := []
					for frame in range(count):
						actor.sprite.frame = frame
						if actor.has_method("_fit_polished_frame"):
							actor._fit_polished_frame()
						if actor.has_method("_align_current_motion_frame"):
							actor._align_current_motion_frame()
						var height: float
						var foot: float
						if actor.has_method("_align_current_motion_frame"):
							var name := String(actor.sprite.animation).trim_prefix("taya_").trim_prefix("empty_")
							var geometry: Dictionary = actor.motion_geometry[name]
							height = float(geometry["heights"][frame]) * actor.sprite.scale.y
							foot = actor.sprite.position.y + float(geometry["canvas_height"]) * actor.sprite.scale.y * 0.5
						else:
							var texture: Texture2D = actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation, frame)
							var bounds: Rect2i = texture.get_image().get_used_rect()
							height = bounds.size.y * actor.sprite.scale.y
							foot = actor.sprite.position.y + (bounds.end.y - texture.get_size().y * 0.5) * actor.sprite.scale.y
						total_height += height
						scales.append(actor.sprite.scale.y)
						assert(absf(foot) < 0.5, "%s %s %s %s frame %d foot %.1f" % [character, role, action, direction, frame, foot])
					assert(is_equal_approx(scales.min(), scales.max()), "%s %s %s %s changes scale mid-cycle" % [character, role, action, direction])
					assert(absf(total_height / count - 210.0) < 0.5, "%s %s %s %s average height %.1f" % [character, role, action, direction, total_height / count])
			actor.free()
		print("PASS: %s idle, walk and sprint keep one scale, a 210-pixel average height and foot origin in eight directions and both roles" % character)
	quit()
