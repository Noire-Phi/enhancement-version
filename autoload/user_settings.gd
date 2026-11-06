extends Node

var selected_character_scene := "res://scenes/Thrower Hat Thrower.tscn"
var display_name := "Player"
var player_color_index := 0
var headwear_index := 0
var accessory_index := 0
var tutorial_seen := false
# Reduced-motion option: turns off camera shake in matches.
var screen_shake := true
var statistics := {"wins": 0, "losses": 0, "successful_throws": 0, "can_knockdowns": 0}
var completed_matches: Array = []
const CONTROL_ACTIONS := ["up", "down", "left", "right", "aim_up", "aim_down", "aim_left", "aim_right", "sprint", "throw", "special", "interact", "lunge"]
const DEFAULT_BINDINGS := {
	"keyboard": {"up": ["key:87", "key:4194320"], "down": ["key:83", "key:4194322"], "left": ["key:65", "key:4194319"], "right": ["key:68", "key:4194321"], "sprint": ["key:4194325"], "throw": ["mouse:1"], "special": ["mouse:2"], "interact": ["key:69"], "lunge": ["key:32"]},
	"controller": {"up": ["axis:1:-1"], "down": ["axis:1:1"], "left": ["axis:0:-1"], "right": ["axis:0:1"], "aim_up": ["axis:3:-1"], "aim_down": ["axis:3:1"], "aim_left": ["axis:2:-1"], "aim_right": ["axis:2:1"], "sprint": ["axis:4:1"], "throw": ["axis:5:1"], "special": ["button:10"], "interact": ["button:0"], "lunge": ["button:1"]}
}
var input_mode := "keyboard"
var bindings: Dictionary = DEFAULT_BINDINGS.duplicate(true)

func _ready() -> void:
	load_profile()
	Input.joy_connection_changed.connect(_controller_changed)
	apply_controls()

func _controller_changed(_device: int, _connected: bool) -> void:
	apply_controls()

func active_mode() -> String:
	return "controller" if input_mode == "controller" and not Input.get_connected_joypads().is_empty() else "keyboard"

func set_input_mode(mode: String) -> void:
	input_mode = mode if DEFAULT_BINDINGS.has(mode) else "keyboard"
	apply_controls()
	save_profile()

func set_binding(action: String, token: String) -> void:
	if not CONTROL_ACTIONS.has(action) or token_to_event(token) == null:
		return
	var mode := input_mode
	var scheme: Dictionary = bindings[mode]
	var previous: Array = scheme.get(action, []).duplicate()
	for other in scheme:
		if other != action:
			var values: Array = scheme[other]
			if values.has(token):
				scheme[other] = previous
	scheme[action] = [token]
	apply_controls()
	save_profile()

func reset_bindings() -> void:
	bindings[input_mode] = DEFAULT_BINDINGS[input_mode].duplicate(true)
	apply_controls()
	save_profile()

func token_to_event(token: String) -> InputEvent:
	var parts := token.split(":")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return null
	var number := int(parts[1])
	match parts[0]:
		"key":
			var event := InputEventKey.new()
			event.physical_keycode = number
			return event
		"mouse":
			var event := InputEventMouseButton.new()
			event.button_index = number
			return event
		"button":
			var event := InputEventJoypadButton.new()
			event.button_index = number
			event.device = int(Input.get_connected_joypads()[0]) if not Input.get_connected_joypads().is_empty() else -1
			return event
		"axis":
			if parts.size() != 3 or not parts[2].is_valid_int():
				return null
			var event := InputEventJoypadMotion.new()
			event.axis = number
			event.axis_value = float(int(parts[2]))
			event.device = int(Input.get_connected_joypads()[0]) if not Input.get_connected_joypads().is_empty() else -1
			return event
	return null

func binding_text(action: String) -> String:
	var scheme: Dictionary = bindings[input_mode]
	var values: Array = scheme.get(action, [])
	if values.is_empty():
		return "UNBOUND"
	var token: String = values[0]
	var parts := token.split(":")
	if parts[0] == "axis":
		if parts[1] == "4": return "LEFT TRIGGER"
		if parts[1] == "5": return "RIGHT TRIGGER"
		var stick := "LEFT STICK" if int(parts[1]) < 2 else "RIGHT STICK"
		var direction := "RIGHT" if int(parts[1]) % 2 == 0 and parts[2] == "1" else "LEFT" if int(parts[1]) % 2 == 0 else "DOWN" if parts[2] == "1" else "UP"
		return "%s %s" % [stick, direction]
	if parts[0] == "button":
		return {"0": "A / CROSS", "1": "B / CIRCLE", "2": "X / SQUARE", "3": "Y / TRIANGLE", "4": "VIEW", "6": "MENU", "7": "LEFT STICK CLICK", "8": "RIGHT STICK CLICK", "9": "LEFT BUMPER", "10": "RIGHT BUMPER", "11": "D-PAD UP", "12": "D-PAD DOWN", "13": "D-PAD LEFT", "14": "D-PAD RIGHT"}.get(parts[1], "BUTTON " + parts[1])
	if parts[0] == "mouse":
		return "LEFT MOUSE" if parts[1] == "1" else "RIGHT MOUSE"
	return OS.get_keycode_string(int(parts[1]))

func short_binding_text(action: String) -> String:
	var text_value := binding_text(action)
	return {"RIGHT MOUSE": "RMB", "LEFT MOUSE": "LMB", "RIGHT BUMPER": "RB", "A / CROSS": "A", "B / CIRCLE": "B", "LEFT TRIGGER": "LT", "RIGHT TRIGGER": "RT"}.get(text_value, text_value)

func apply_controls() -> void:
	var scheme: Dictionary = bindings[active_mode()]
	for action in CONTROL_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.22)
		InputMap.action_erase_events(action)
		for token in scheme.get(action, []):
			var event := token_to_event(str(token))
			if event != null:
				InputMap.action_add_event(action, event)

func aim_position(actor: Node2D) -> Vector2:
	if active_mode() != "controller":
		return actor.get_global_mouse_position()
	var direction := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if direction.length() > 0.25:
		actor.set_meta("controller_aim", direction.normalized())
	else:
		direction = actor.get_meta("controller_aim", actor.get("facing"))
	return actor.global_position + direction.normalized() * 500.0

func throw_pressed(viewport: Viewport) -> bool:
	if not Input.is_action_pressed("throw"):
		return false
	var keyboard_mouse: bool = active_mode() == "keyboard" and str(bindings["keyboard"]["throw"][0]).begins_with("mouse:")
	return not keyboard_mouse or viewport.gui_get_hovered_control() == null

func profile_path() -> String:
	var override := OS.get_environment("CAN_CLASH_SAVE_PATH")
	return override if not override.is_empty() else "user://profile.cfg"

func clean_name(value: String) -> String:
	return value.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(20)

func set_display_name(value: String) -> void:
	display_name = clean_name(value)
	if display_name.is_empty():
		display_name = "Player"
	save_profile()

func set_player_color_index(value: int) -> void:
	player_color_index = clampi(value, 0, 4)
	save_profile()

func set_cosmetics(new_headwear: int, new_accessory: int) -> void:
	headwear_index = clampi(new_headwear, 0, 1)
	accessory_index = clampi(new_accessory, 0, 2)
	save_profile()

func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(profile_path()) != OK:
		return
	display_name = clean_name(str(config.get_value("player", "name", "Player")))
	if display_name.is_empty():
		display_name = "Player"
	selected_character_scene = str(config.get_value("player", "character", selected_character_scene))
	player_color_index = clampi(int(config.get_value("player", "color_index", 0)), 0, 4)
	headwear_index = clampi(int(config.get_value("player", "headwear", 0)), 0, 1)
	accessory_index = clampi(int(config.get_value("player", "accessory", 0)), 0, 2)
	tutorial_seen = bool(config.get_value("player", "tutorial_seen", false))
	screen_shake = bool(config.get_value("display", "screen_shake", true))
	for key in statistics:
		statistics[key] = maxi(0, int(config.get_value("statistics", key, 0)))
	completed_matches = config.get_value("statistics", "completed_matches", [])
	input_mode = str(config.get_value("controls", "mode", "keyboard"))
	if not DEFAULT_BINDINGS.has(input_mode):
		input_mode = "keyboard"
	for mode in DEFAULT_BINDINGS:
		for action in DEFAULT_BINDINGS[mode]:
			var saved: Array = config.get_value("controls_" + mode, action, DEFAULT_BINDINGS[mode][action])
			if not saved.is_empty() and saved.all(func(token: Variant) -> bool: return token is String and token_to_event(token) != null):
				bindings[mode][action] = saved
	apply_controls()

func save_profile() -> Error:
	var config := ConfigFile.new()
	config.set_value("player", "name", display_name)
	config.set_value("player", "character", selected_character_scene)
	config.set_value("player", "color_index", player_color_index)
	config.set_value("player", "headwear", headwear_index)
	config.set_value("player", "accessory", accessory_index)
	config.set_value("player", "tutorial_seen", tutorial_seen)
	config.set_value("display", "screen_shake", screen_shake)
	for key in statistics:
		config.set_value("statistics", key, statistics[key])
	config.set_value("statistics", "completed_matches", completed_matches)
	config.set_value("controls", "mode", input_mode)
	for mode in bindings:
		for action in bindings[mode]:
			config.set_value("controls_" + mode, action, bindings[mode][action])
	return config.save(profile_path())

func record_hit() -> void:
	statistics.successful_throws += 1
	statistics.can_knockdowns += 1
	save_profile()

func record_result(match_id: String, won: bool) -> void:
	if match_id.is_empty() or completed_matches.has(match_id):
		return
	completed_matches.append(match_id)
	if completed_matches.size() > 40:
		completed_matches.pop_front()
	statistics["wins" if won else "losses"] += 1
	save_profile()
