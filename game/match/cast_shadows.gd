extends RefCounted

# 2.5D depth: every prop and player casts a soft silhouette shadow onto the floor,
# folded down from its base and slanted away from a sun at the upper left.

const COLOR := Color(0.06, 0.04, 0.12, 0.24)
const SLANT := 0.55 # Sideways lean of the shadow per unit of object height.
const SQUASH := 0.32 # Shadow length relative to object height.
const FLOOR_Z := -5 # Above the floor art (-10/-9), below every prop and player.

# Maps a point at height h above the base line (base_y) to its shadow on the floor.
static func fold(base_y: float) -> Transform2D:
	return Transform2D(Vector2(1, 0), Vector2(-SLANT, -SQUASH), Vector2(SLANT * base_y, (1.0 + SQUASH) * base_y))

static func style(shadow: CanvasItem) -> void:
	shadow.name = "CastShadow"
	shadow.self_modulate = COLOR
	shadow.z_as_relative = false
	shadow.z_index = FLOOR_Z
	# Set every frame, so it rides the (smoothed) body without its own smoothing.
	shadow.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

# Static props: copy each prop's Sprite2D once.
static func add_to_props(world: Node) -> void:
	for prop in world.get_children():
		if not prop is StaticBody2D or "Ring" in prop.name or "Border" in prop.name:
			continue
		var sprite := prop.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null or sprite.texture == null or prop.has_node("CastShadow"):
			continue
		var shadow := sprite.duplicate(0) as Sprite2D
		for child in shadow.get_children(): child.free()
		shadow.material = null
		# Anchor at the lowest visible pixel; prop images carry transparent padding.
		var used: Rect2i = sprite.texture.get_image().get_used_rect()
		var bottom: float = sprite.get_rect().position.y + used.end.y
		var base_y: float = sprite.position.y + bottom * sprite.scale.y
		shadow.transform = fold(base_y) * sprite.transform
		style(shadow)
		prop.add_child(shadow)
		prop.move_child(shadow, 0)

# Players animate, so their shadow follows the visible sprite every frame.
class PlayerShadow extends AnimatedSprite2D:
	var actor: Node2D

	func _process(_delta: float) -> void:
		if not is_instance_valid(actor):
			return
		var source: AnimatedSprite2D = actor.attack_sprite if actor.attack_sprite.visible else actor.sprite
		visible = actor.visible and source.visible
		if not visible:
			return
		if sprite_frames != source.sprite_frames: sprite_frames = source.sprite_frames
		if animation != source.animation: animation = source.animation
		frame = source.frame
		flip_h = source.flip_h
		# Shadows stay on the ground while the body bounces.
		offset = Vector2.ZERO
		centered = source.centered
		# The actor's origin is at its feet, so the base line is y = 0.
		transform = Transform2D(Vector2(1, 0), Vector2(-SLANT, -SQUASH), Vector2.ZERO) * source.transform

static func add_to_actor(actor: Node2D) -> void:
	if actor.has_node("CastShadow"):
		return
	var shadow := PlayerShadow.new()
	shadow.actor = actor
	style(shadow)
	actor.add_child(shadow)
