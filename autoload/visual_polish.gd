extends Node

# Game-wide presentation polish, applied without touching each screen:
# - every scene change fades in from a warm dark tint instead of popping in;
# - every Button grows slightly on hover/focus and squashes when pressed.
# Purely visual; nothing here affects input handling or networking.

const FADE_COLOR := Color(0.09, 0.05, 0.03)
const FADE_SECONDS := 0.32
const HOVER_SCALE := 1.05
const PRESS_SCALE := 0.94

var fade_layer: CanvasLayer
var fade_rect: ColorRect
var fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(FADE_COLOR, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)
	get_tree().scene_changed.connect(fade_in)
	get_tree().node_added.connect(_node_added)

func fade_in() -> void:
	if fade_tween != null and fade_tween.is_valid(): fade_tween.kill()
	fade_rect.color.a = 1.0
	fade_tween = create_tween().set_ignore_time_scale(true)
	fade_tween.tween_property(fade_rect, "color:a", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _node_added(node: Node) -> void:
	if node is Button and not node.has_meta("polished"):
		node.set_meta("polished", true)
		var button: Button = node
		button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
		button.pivot_offset = button.size * 0.5
		button.mouse_entered.connect(_settle.bind(button))
		button.mouse_exited.connect(_settle.bind(button))
		button.focus_entered.connect(_settle.bind(button))
		button.focus_exited.connect(_settle.bind(button))
		button.button_down.connect(_scale_to.bind(button, PRESS_SCALE, 0.06))
		button.button_up.connect(_settle.bind(button))

func _settle(button: Button) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	var lifted := not button.disabled and (button.is_hovered() or button.has_focus())
	_scale_to(button, HOVER_SCALE if lifted else 1.0, 0.12)

func _scale_to(button: Button, value: float, seconds: float) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	var tween := button.create_tween().set_ignore_time_scale(true)
	tween.tween_property(button, "scale", Vector2.ONE * value, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
