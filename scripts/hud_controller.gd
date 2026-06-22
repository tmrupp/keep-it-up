extends CanvasLayer
class_name HUDController

const GameConfig := preload("res://scripts/game_config.gd")

@export var hit_text_duration := 0.5

var score_label: Label
var ammo_label: Label
var charged_shot_label: Label
var bot_label: Label
var hit_marker_label: Label
var hit_text_timer := 0.0

func setup() -> void:
	name = "HUD"
	_build_labels()
	_build_crosshair()

func _process(delta: float) -> void:
	if hit_text_timer <= 0.0:
		return
	hit_text_timer = maxf(0.0, hit_text_timer - delta)
	if hit_text_timer == 0.0 and hit_marker_label != null:
		hit_marker_label.text = ""

func set_score(team_one_score: int, team_two_score: int) -> void:
	if score_label != null:
		score_label.text = "Blue %d  |  Red %d" % [team_one_score, team_two_score]

func set_weapon_state(ammo: int, max_ammo: int, final_bonus_enabled: bool, is_reloading: bool) -> void:
	if ammo_label != null:
		var reload_text := " RELOADING" if is_reloading else ""
		var final_text := " FINAL" if ammo == 1 and final_bonus_enabled else ""
		ammo_label.text = "Ammo %d/%d%s%s" % [ammo, max_ammo, final_text, reload_text]
	if charged_shot_label != null:
		charged_shot_label.text = "CHARGED SHOT READY" if ammo == 1 and final_bonus_enabled and is_reloading == false else ""

func set_bot_enabled(enabled: bool) -> void:
	if bot_label != null:
		bot_label.text = "Red Bot: %s (Space)" % ["ON" if enabled else "OFF"]

func show_hit_text(text: String, color: Color, duration: float = -1.0) -> void:
	if hit_marker_label == null:
		return
	hit_marker_label.text = text
	hit_marker_label.add_theme_color_override("font_color", color)
	hit_text_timer = hit_text_duration if duration < 0.0 else duration

func _build_labels() -> void:
	if score_label == null:
		score_label = Label.new()
		score_label.name = "ScoreLabel"
		score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		score_label.position = Vector2(24.0, 18.0)
		score_label.add_theme_font_size_override("font_size", 24)
		add_child(score_label)
	if ammo_label == null:
		ammo_label = Label.new()
		ammo_label.name = "AmmoLabel"
		ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ammo_label.position = Vector2(24.0, 50.0)
		ammo_label.add_theme_font_size_override("font_size", 22)
		add_child(ammo_label)
	if charged_shot_label == null:
		charged_shot_label = Label.new()
		charged_shot_label.name = "ChargedShotLabel"
		charged_shot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		charged_shot_label.position = Vector2(24.0, 78.0)
		charged_shot_label.add_theme_font_size_override("font_size", 20)
		charged_shot_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.18, 1.0))
		add_child(charged_shot_label)
	if bot_label == null:
		bot_label = Label.new()
		bot_label.name = "BotLabel"
		bot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bot_label.position = Vector2(24.0, 106.0)
		bot_label.add_theme_font_size_override("font_size", 18)
		add_child(bot_label)
	if hit_marker_label == null:
		hit_marker_label = Label.new()
		hit_marker_label.name = "HitMarkerLabel"
		hit_marker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit_marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hit_marker_label.position = Vector2(490.0, 394.0)
		hit_marker_label.size = Vector2(300.0, 40.0)
		hit_marker_label.add_theme_font_size_override("font_size", 20)
		add_child(hit_marker_label)

func _build_crosshair() -> void:
	if has_node("CrosshairRoot"):
		return
	var root := Control.new()
	root.name = "CrosshairRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	var horizontal := ColorRect.new()
	horizontal.name = "CrosshairHorizontal"
	horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal.color = Color(0.95, 0.98, 1.0, 0.82)
	horizontal.position = Vector2(-12.0, -1.0)
	horizontal.size = Vector2(24.0, 2.0)
	root.add_child(horizontal)
	var vertical := ColorRect.new()
	vertical.name = "CrosshairVertical"
	vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical.color = horizontal.color
	vertical.position = Vector2(-1.0, -12.0)
	vertical.size = Vector2(2.0, 24.0)
	root.add_child(vertical)
	add_child(root)