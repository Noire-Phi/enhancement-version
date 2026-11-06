extends Control

const FONT = preload("res://assets/fonts/TitanOne-Regular.ttf")
const CREAM := Color("fff5dc")
const GOLD := Color("ffe29a")
const INK := Color("26150f")

var map_name := ""
var rows: Array[Dictionary] = []
var developer := false
# Row flash when a score rises: name -> seconds left.
const BUMP_SECONDS := 0.55
var bumps: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(320, 374)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if bumps.is_empty():
		return
	for key in bumps.keys():
		bumps[key] = float(bumps[key]) - delta
		if bumps[key] <= 0.0: bumps.erase(key)
	queue_redraw()

func set_score_state(next_map: String, members: Array[Dictionary], points: Dictionary, taya_id: int, is_developer: bool) -> void:
	var next_rows: Array[Dictionary] = []
	for member in members:
		next_rows.append({"name": str(member.name), "color": member.color, "score": int(points.get(member.id, 0)), "taya": int(member.id) == taya_id})
	if map_name == next_map and rows == next_rows and developer == is_developer:
		return
	for row in next_rows:
		for old in rows:
			if old.name == row.name and int(row.score) > int(old.score):
				bumps[row.name] = BUMP_SECONDS
	map_name = next_map
	rows = next_rows
	developer = is_developer
	queue_redraw()

func _draw() -> void:
	var width := size.x
	draw_string_outline(FONT, Vector2(0, 32), map_name, HORIZONTAL_ALIGNMENT_LEFT, width, 27, 4, INK)
	draw_string(FONT, Vector2(0, 32), map_name, HORIZONTAL_ALIGNMENT_LEFT, width, 27, CREAM)
	draw_string(FONT, Vector2(0, 50), "MATCH SCORE", HORIZONTAL_ALIGNMENT_LEFT, width, 14, GOLD)
	# A tiny court-center mark ties the scoreboard to the arena art.
	draw_line(Vector2(0, 65), Vector2(width * 0.5 - 14, 65), GOLD, 3.0, true)
	draw_arc(Vector2(width * 0.5, 65), 10, 0, TAU, 24, GOLD, 3.0, true)
	draw_line(Vector2(width * 0.5 + 14, 65), Vector2(width, 65), GOLD, 3.0, true)
	draw_string(FONT, Vector2(8, 90), "PLAYER", HORIZONTAL_ALIGNMENT_LEFT, width - 90, 15, GOLD)
	draw_string(FONT, Vector2(width - 51, 90), "PTS", HORIZONTAL_ALIGNMENT_RIGHT, 43, 15, GOLD)
	for index in range(mini(rows.size(), 5)):
		var row: Dictionary = rows[index]
		var top := 100.0 + index * 46.0
		var background := Color("872f18") if row.taya else Color("a54610") if index % 2 == 0 else Color("98400e")
		var bump: float = float(bumps.get(row.name, 0.0)) / BUMP_SECONDS
		draw_rect(Rect2(0, top, width, 42), background.lerp(Color("f2b23a"), bump * 0.75))
		draw_circle(Vector2(15, top + 21), 9, INK)
		draw_circle(Vector2(15, top + 21), 6, row.color)
		var player_name := str(row.name)
		if player_name.length() > 13:
			player_name = player_name.left(10) + "..."
		draw_string_outline(FONT, Vector2(31, top + 29), player_name, HORIZONTAL_ALIGNMENT_LEFT, width - 145, 20, 3, INK)
		draw_string(FONT, Vector2(31, top + 29), player_name, HORIZONTAL_ALIGNMENT_LEFT, width - 145, 20, CREAM)
		if row.taya:
			var badge := Rect2(width - 111, top + 10, 55, 22)
			draw_rect(badge, Color("d73023"))
			draw_rect(badge, INK, false, 2.0)
			draw_string(FONT, Vector2(badge.position.x, top + 27), "TAYA", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 14, CREAM)
		var score_size := int(round(23.0 + 9.0 * bump))
		draw_string_outline(FONT, Vector2(width - 47, top + 29 + 3.0 * bump), str(row.score), HORIZONTAL_ALIGNMENT_RIGHT, 39, score_size, 4, INK)
		draw_string(FONT, Vector2(width - 47, top + 29 + 3.0 * bump), str(row.score), HORIZONTAL_ALIGNMENT_RIGHT, 39, score_size, CREAM.lerp(Color.WHITE, bump))
	draw_line(Vector2(width - 51, 99), Vector2(width - 51, 330), Color(GOLD, 0.58), 2.0, true)
	draw_line(Vector2(0, 342), Vector2(width, 342), GOLD, 2.0, true)
	draw_string(FONT, Vector2(0, 366), ("VS AI · " + LanSession.ai_difficulty.to_upper() if LanSession.is_vs_ai() else "DEVELOPER") if developer else "LIVE MATCH", HORIZONTAL_ALIGNMENT_LEFT, width - 100, 16, GOLD)
	draw_string(FONT, Vector2(width - 124, 366), "STATS OFF" if developer else "%d PLAYERS" % rows.size(), HORIZONTAL_ALIGNMENT_RIGHT, 124, 16, CREAM)
