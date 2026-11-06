extends Control

signal closed

const UI = preload("res://ui/game_ui.gd")
const LABELS := {"up": "MOVE UP", "down": "MOVE DOWN", "left": "MOVE LEFT", "right": "MOVE RIGHT", "aim_up": "AIM UP", "aim_down": "AIM DOWN", "aim_left": "AIM LEFT", "aim_right": "AIM RIGHT", "sprint": "SPRINT", "throw": "CHARGE / THROW", "special": "SPECIAL / TAYA STUN", "interact": "PICK UP SLIPPER", "lunge": "LUNGE"}

var status: Label
var mode_buttons: HBoxContainer
var rows: VBoxContainer
var capture_action := ""

func _ready() -> void:
	_build()
	_refresh()
	mode_buttons.get_child(0).grab_focus()
	Input.joy_connection_changed.connect(_connection_changed)

func _connection_changed(_device: int, _connected: bool) -> void:
	_refresh()

func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.07, 0.04, 0.02, 0.78)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.theme = UI.theme()
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(1010, 0)
	card.add_theme_stylebox_override("panel", UI.panel(Color("ad490e")))
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	card.add_child(content)
	content.add_child(UI.label("CONTROLS", 46))
	status = UI.label("", 22)
	content.add_child(status)
	mode_buttons = HBoxContainer.new()
	mode_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_buttons.add_theme_constant_override("separation", 18)
	content.add_child(mode_buttons)
	var help := UI.label("Pair a Bluetooth controller in Windows first. Choose a control, then press a button or move a stick. Esc cancels.", 19)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(930, 560)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	content.add_child(bottom)
	# Reduced-motion option for players sensitive to camera shake.
	var shake := UI.button("", func() -> void: pass)
	shake.name = "ScreenShake"
	var label_shake := func() -> void: shake.text = "SCREEN SHAKE: " + ("ON" if UserSettings.screen_shake else "OFF")
	shake.pressed.connect(func() -> void:
		UserSettings.screen_shake = not UserSettings.screen_shake
		UserSettings.save_profile()
		label_shake.call()
	)
	label_shake.call()
	bottom.add_child(shake)
	bottom.add_child(UI.button("RESET DEFAULTS", _reset))
	bottom.add_child(UI.button("BACK", _close))

func _refresh() -> void:
	if status == null:
		return
	for child in mode_buttons.get_children():
		child.queue_free()
	for mode in ["keyboard", "controller"]:
		var button := UI.button(("▶ " if UserSettings.input_mode == mode else "") + mode.to_upper(), func() -> void: _choose_mode(mode))
		mode_buttons.add_child(button)
	var pads := Input.get_connected_joypads()
	if UserSettings.input_mode == "keyboard":
		status.text = "KEYBOARD AND MOUSE ACTIVE"
	elif pads.is_empty():
		status.text = "NO CONTROLLER DETECTED - KEYBOARD FALLBACK ACTIVE"
	else:
		status.text = "CONTROLLER READY: " + Input.get_joy_name(pads[0])
	for child in rows.get_children():
		child.queue_free()
	for action in UserSettings.CONTROL_ACTIONS:
		if UserSettings.input_mode == "keyboard" and action.begins_with("aim_"):
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 18)
		rows.add_child(line)
		var name := UI.label(LABELS[action], 22)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name.custom_minimum_size = Vector2(450, 48)
		line.add_child(name)
		var button := UI.button("PRESS INPUT..." if capture_action == action else UserSettings.binding_text(action), func() -> void: _capture(action))
		button.custom_minimum_size = Vector2(410, 48)
		line.add_child(button)

func _choose_mode(mode: String) -> void:
	capture_action = ""
	UserSettings.set_input_mode(mode)
	_refresh()

func _capture(action: String) -> void:
	capture_action = action
	_refresh()

func _input(event: InputEvent) -> void:
	if capture_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		capture_action = ""
		_refresh()
		accept_event()
		return
	var token := ""
	if UserSettings.input_mode == "keyboard":
		if event is InputEventKey and event.pressed and not event.echo:
			token = "key:%d" % (event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		elif event is InputEventMouseButton and event.pressed and event.button_index <= MOUSE_BUTTON_RIGHT:
			token = "mouse:%d" % event.button_index
	else:
		if event is InputEventJoypadButton and event.pressed:
			token = "button:%d" % event.button_index
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.75:
			token = "axis:%d:%d" % [event.axis, signf(event.axis_value)]
	if token.is_empty():
		return
	UserSettings.set_binding(capture_action, token)
	capture_action = ""
	_refresh()
	accept_event()

func _reset() -> void:
	UserSettings.reset_bindings()
	capture_action = ""
	_refresh()

func _close() -> void:
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if capture_action.is_empty() and event.is_action_pressed("ui_cancel"):
		_close()
		accept_event()
