extends Control

# In-match pause menu: Esc or a controller's Start opens it over a blurred view.
# Offline games (VS AI, developer) truly pause; LAN/online matches keep running
# for everyone else, so there it is an overlay only.

signal leave_requested

const UI = preload("res://ui/game_ui.gd")
const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float radius = 2.5;
uniform vec4 tint : source_color = vec4(0.09, 0.05, 0.03, 0.5);
uniform float amount = 1.0;
void fragment() {
	vec2 step_size = SCREEN_PIXEL_SIZE * radius * amount;
	vec4 sum = vec4(0.0);
	float total = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float weight = exp(-float(x * x + y * y) / 8.0);
			sum += texture(screen, SCREEN_UV + vec2(float(x), float(y)) * step_size) * weight;
			total += weight;
		}
	}
	vec3 blurred = sum.rgb / total;
	COLOR = vec4(mix(blurred, tint.rgb, tint.a * amount), 1.0);
}
"""

var backdrop: ColorRect
var card: PanelContainer
var resume_button: Button
var tween: Tween
var opened := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = BLUR_SHADER
	backdrop.material = ShaderMaterial.new()
	backdrop.material.shader = shader
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.add_theme_stylebox_override("panel", UI.panel())
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	card.add_child(content)
	content.add_child(UI.label("PAUSED", 52))
	var note := UI.label("The match keeps running for other players.", 19)
	note.visible = LanSession.is_networked()
	content.add_child(note)
	resume_button = UI.button("Resume", close)
	resume_button.name = "Resume"
	content.add_child(resume_button)
	var settings := UI.button("Settings", _open_settings)
	settings.name = "PauseSettings"
	content.add_child(settings)
	var leave := UI.button("Leave Match", func() -> void:
		close()
		leave_requested.emit()
	)
	leave.name = "LeaveMatch"
	content.add_child(leave)
	hide()

func _unhandled_input(event: InputEvent) -> void:
	var toggle: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)
	if toggle:
		if opened: close()
		else: open()
		get_viewport().set_input_as_handled()

func open() -> void:
	if opened: return
	opened = true
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not LanSession.is_networked():
		get_tree().paused = true
	_animate(true)
	resume_button.grab_focus()

func close() -> void:
	if not opened: return
	opened = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false
	_animate(false)

func _animate(showing: bool) -> void:
	if tween != null and tween.is_valid(): tween.kill()
	card.pivot_offset = card.size * 0.5
	tween = create_tween().set_parallel().set_ignore_time_scale(true)
	var blur: ShaderMaterial = backdrop.material
	if showing:
		card.scale = Vector2.ONE * 0.9
		card.modulate.a = 0.0
		tween.tween_method(func(value: float) -> void: blur.set_shader_parameter("amount", value), 0.0, 1.0, 0.2)
		tween.tween_property(card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 1.0, 0.18)
	else:
		# Exits run quicker than entrances.
		tween.tween_method(func(value: float) -> void: blur.set_shader_parameter("amount", value), 1.0, 0.0, 0.14)
		tween.tween_property(card, "modulate:a", 0.0, 0.12)
		tween.chain().tween_callback(hide)

func _open_settings() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var screen := preload("res://ui/settings/settings.tscn").instantiate()
	screen.closed.connect(func() -> void:
		layer.queue_free()
		resume_button.grab_focus()
	)
	layer.add_child(screen)

func _exit_tree() -> void:
	if opened:
		get_tree().paused = false
