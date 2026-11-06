extends SceneTree

const CHARACTERS := ["Head Band", "Glasses Thrower", "Curly Haired"]


func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	for character in CHARACTERS:
		for role in ["Thrower", "Taya"]:
			var actor = load("res://scenes/%s %s.tscn" % [role, character]).instantiate()
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			for direction in actor.DIRECTIONS:
				var motion: Vector2 = Vector2.RIGHT.rotated(actor.DIRECTIONS.find(direction) * PI / 4.0)
				actor._play("idle", motion)
				_check_frame(actor.sprite)
				if direction == "left":
					assert(not actor.sprite.flip_h, "The drawn left idle must not be mirrored")
				if direction not in ["left", "right"]:
					continue
				for action in ["walk", "sprint"]:
					actor._play(action, motion)
					if direction == "left":
						assert(actor.sprite.flip_h, "The right-facing side gait must mirror for left movement")
					# Enhanced sheets: the four drawn poses plus four in-betweens.
					assert(actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation) == 8)
					# One steady scale per cycle (no size pulsing); its average height stays 210.
					var scales := []
					var heights := 0.0
					for frame in range(8):
						actor.sprite.frame = frame
						actor._fit_polished_frame()
						heights += _check_frame(actor.sprite, false)
						scales.append(actor.sprite.scale.y)
					assert(is_equal_approx(scales.min(), scales.max()), "A run cycle must keep one scale")
					assert(absf(heights / 8.0 - 210.0) <= 2.0, "Run cycle average height changed")
			if role == "Taya":
				actor.taya_visual.play_action(&"lunge", 0)
				actor.taya_visual._process(1.0 / 60.0)
				_check_frame(actor.taya_visual.body)
			actor.free()
		print("PASS: %s neutral idle and alternating side gait keep foot/height in both roles" % character)
	quit(0)


func _check_frame(sprite: AnimatedSprite2D, exact_height: bool = true) -> float:
	var texture: AtlasTexture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	assert("/motion_polish/" in texture.atlas.resource_path)
	var bounds: Rect2i = texture.get_image().get_used_rect()
	assert(bounds.size.y > 0)
	var foot := sprite.position.y + (float(bounds.end.y) - texture.get_size().y * 0.5) * sprite.scale.y
	assert(absf(foot) <= 2.0, "Polished sprite feet must stay on the actor origin")
	var height := float(bounds.size.y) * sprite.scale.y
	if exact_height:
		assert(absf(height - 210.0) <= 2.0, "Polished sprite height changed")
	return height
