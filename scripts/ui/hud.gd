class_name HUDController
extends Control
## Painterly minimal gameplay HUD for SHAALA (شعلة).
## Shows Vitality flame pips, Flame resource bar, Dagger Tier, Era badge,
## Area Name poetic banner, Interaction Prompt pill, Boss Health Bar, and Toasts.

## Colours come from UITokens ("Notebook & Ember"); HUD behaviour follows docs/UI_DESIGN_PLAN.md §6.2:
## no panels, numbers only when SettingsManager.show_numbers, tier name as a short whisper on change,
## era mark only once Time Shift is unlocked, idle fade with a 30% floor while wounded.

@onready var hp_label: Label = $TopRow/StatusPanel/VBox/HpHeaderLabel
@onready var health_pips_box: HBoxContainer = $TopRow/StatusPanel/VBox/HealthPipsBox
@onready var flame_label: Label = $TopRow/StatusPanel/VBox/FlameHeaderLabel
@onready var flame_bar: ProgressBar = $TopRow/StatusPanel/VBox/FlameBar
@onready var dagger_tier_label: Label = $TopRow/StatusPanel/VBox/DaggerTierLabel

@onready var era_badge: PanelContainer = $TopRow/EraBadge
@onready var era_label: Label = $TopRow/EraBadge/EraLabel

@onready var area_banner: VBoxContainer = $AreaBanner
@onready var area_title_label: Label = $AreaBanner/AreaTitleLabel

@onready var toast_panel: PanelContainer = $ToastPanel
@onready var toast_label: Label = $ToastPanel/ToastLabel

@onready var prompt_pill: PanelContainer = $PromptPill
@onready var prompt_label: Label = $PromptPill/PromptLabel

@onready var boss_panel: PanelContainer = $BossPanel
@onready var boss_name_label: Label = $BossPanel/VBox/HeaderRow/BossNameLabel
@onready var boss_hp_numbers_label: Label = $BossPanel/VBox/HeaderRow/BossHpNumbersLabel
@onready var boss_subtitle_label: Label = $BossPanel/VBox/BossSubtitleLabel
@onready var boss_hp_bar: ProgressBar = $BossPanel/VBox/BossHpBar

var _current_hp: int = 5
var _max_hp: int = 5
var _current_resource: float = 0.0
var _max_resource: float = 100.0
var _dagger_tier: int = 0
var _current_era: String = "2054"

var _active_prompt_key: String = ""
var _prompt_visible: bool = false
var _last_area_title_key: String = ""
var _active_toast_key: String = ""

var _boss_active: bool = false
var _boss_id: String = ""
var _boss_name_key: String = ""
var _boss_hp: int = 0
var _boss_max_hp: int = 1
var _boss_phase: int = 1

var _idle_time: float = 0.0
var _last_tier_shown: int = -1
var _tier_tween: Tween = null

var _area_tween: Tween = null
var _toast_tween: Tween = null
var _boss_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	area_banner.modulate.a = 0.0
	toast_panel.modulate.a = 0.0
	toast_panel.visible = false
	prompt_pill.visible = false
	boss_panel.visible = false

	hp_label.set_meta("align_reading_edge", true)
	flame_label.set_meta("align_reading_edge", true)
	dagger_tier_label.set_meta("align_reading_edge", true)
	dagger_tier_label.set_meta("font_role", ArabicFontSetup.ROLE_DISPLAY)
	area_title_label.set_meta("font_role", ArabicFontSetup.ROLE_DISPLAY)
	boss_name_label.set_meta("font_role", ArabicFontSetup.ROLE_DISPLAY)
	dagger_tier_label.modulate.a = 0.0
	_strip_panel_boxes()

	_connect_event_bus()
	refresh_all()


func _process(delta: float) -> void:
	if not visible:
		return
	_idle_time += delta
	var target_alpha: float = 1.0
	if not SettingsManager.hud_always_visible and not _boss_active and _idle_time > UITokens.HUD_IDLE_FADE_DELAY:
		target_alpha = UITokens.HUD_WOUNDED_FLOOR_ALPHA if _current_hp < _max_hp else 0.0
	var top_row: Control = $TopRow as Control
	if not is_equal_approx(top_row.modulate.a, target_alpha):
		var rate: float = delta / UITokens.FADE_IN if target_alpha > top_row.modulate.a else delta / UITokens.FADE_OUT
		top_row.modulate.a = move_toward(top_row.modulate.a, target_alpha, rate)


## Marks gameplay activity so the HUD wakes from its idle fade.
func wake_hud() -> void:
	_idle_time = 0.0


func _strip_panel_boxes() -> void:
	var empty := StyleBoxEmpty.new()
	($TopRow/StatusPanel as PanelContainer).add_theme_stylebox_override("panel", empty)
	era_badge.add_theme_stylebox_override("panel", empty)


func _connect_event_bus() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_resource_changed.connect(_on_player_resource_changed)
	EventBus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	EventBus.room_loaded.connect(_on_room_loaded)
	EventBus.boss_encounter_started.connect(_on_boss_encounter_started)
	EventBus.boss_health_changed.connect(_on_boss_health_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.era_changed.connect(_on_era_changed)
	EventBus.ability_unlocked.connect(_on_ability_unlocked)
	EventBus.settings_changed.connect(refresh_texts)


func refresh_all() -> void:
	_current_hp = GameState.player_hp
	_max_hp = GameState.player_max_hp
	_current_resource = GameState.player_resource
	_max_resource = 100.0
	_dagger_tier = GameState.get_dagger_tier()
	_current_era = GameState.current_era
	_rebuild_health_pips()
	_update_resource_display()
	refresh_texts()


func refresh_texts() -> void:
	_update_number_labels()
	_update_dagger_tier_label()
	_update_era_label()
	_update_prompt_label()
	if not _last_area_title_key.is_empty():
		area_title_label.text = tr(_last_area_title_key)
	if not _active_toast_key.is_empty() and toast_panel.visible:
		toast_label.text = tr(_active_toast_key)
	if _boss_active:
		_update_boss_labels()


func show_toast(message_key: String, hold_seconds: float = 2.8) -> void:
	_active_toast_key = message_key
	toast_label.text = tr(message_key)
	toast_panel.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(hold_seconds)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(_hide_toast_panel)


func _hide_toast_panel() -> void:
	toast_panel.visible = false


func _update_number_labels() -> void:
	var show_nums: bool = SettingsManager.show_numbers
	hp_label.visible = show_nums
	flame_label.visible = show_nums
	if not show_nums:
		return
	hp_label.text = ArabicFontSetup.format_bidi_pair(tr("UI_HP"), "%d/%d" % [_current_hp, _max_hp])
	flame_label.text = ArabicFontSetup.format_bidi_pair(
		tr("UI_FLAME_METER"),
		"%d/%d" % [int(round(_current_resource)), int(round(_max_resource))]
	)


func _rebuild_health_pips() -> void:
	for child: Node in health_pips_box.get_children():
		child.queue_free()

	for i: int in range(_max_hp):
		var is_lit: bool = i < _current_hp
		# Lit ember = filled teardrop; ash ember = smaller hollow shape (shape differs, not only colour).
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(28.0, 34.0) if is_lit else Vector2(22.0, 26.0)
		pip.size_flags_vertical = Control.SIZE_SHRINK_END
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = UITokens.EMBER if is_lit else Color(UITokens.HP_ASH_FILL, 0.55)
		style.set_border_width_all(2)
		style.border_color = UITokens.PALE_GOLD if is_lit else UITokens.HP_ASH_STROKE
		style.corner_radius_top_left = 14 if is_lit else 4
		style.corner_radius_top_right = 2 if is_lit else 4
		style.corner_radius_bottom_right = 14 if is_lit else 11
		style.corner_radius_bottom_left = 14 if is_lit else 11
		pip.add_theme_stylebox_override("panel", style)
		health_pips_box.add_child(pip)


func _update_resource_display() -> void:
	flame_bar.max_value = maxf(1.0, _max_resource)
	flame_bar.value = clampf(_current_resource, 0.0, _max_resource)

	var fill_style := StyleBoxFlat.new()
	match _dagger_tier:
		2:
			fill_style.bg_color = UITokens.PALE_GOLD
		1:
			fill_style.bg_color = UITokens.EMBER
		_:
			fill_style.bg_color = UITokens.MUD_BRICK
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_right = 3
	fill_style.corner_radius_bottom_left = 3
	flame_bar.add_theme_stylebox_override("fill", fill_style)
	# Fill from the reading start edge (DROP-002 §6.4 #5): FILL_BEGIN_TO_END already follows
	# the RTL layout direction, so the strip fills right-to-left in Arabic and left-to-right in English.
	flame_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	flame_bar.show_percentage = false


func _update_dagger_tier_label() -> void:
	var key: String = "UI_DAGGER_TIER_%d" % clampi(_dagger_tier, 0, 2)
	dagger_tier_label.text = tr(key)
	match _dagger_tier:
		2:
			dagger_tier_label.add_theme_color_override("font_color", UITokens.PALE_GOLD)
		1:
			dagger_tier_label.add_theme_color_override("font_color", UITokens.EMBER)
		_:
			dagger_tier_label.add_theme_color_override("font_color", UITokens.MUD_BRICK)
	if _last_tier_shown == -1:
		_last_tier_shown = _dagger_tier
		return
	if _dagger_tier != _last_tier_shown:
		_last_tier_shown = _dagger_tier
		_whisper_tier_name()


## The tier name appears briefly beside the flame strip when the tier changes, then fades.
func _whisper_tier_name() -> void:
	if _tier_tween != null and _tier_tween.is_valid():
		_tier_tween.kill()
	dagger_tier_label.modulate.a = 0.0
	_tier_tween = create_tween()
	_tier_tween.tween_property(dagger_tier_label, "modulate:a", 1.0, UITokens.FADE_IN)
	_tier_tween.tween_interval(UITokens.TIER_WHISPER_HOLD)
	_tier_tween.tween_property(dagger_tier_label, "modulate:a", 0.0, UITokens.FADE_OUT)


func _update_era_label() -> void:
	var is_2034: bool = _current_era == "2034"
	# The era mark only exists once Time Shift is unlocked (M2); M1 shows nothing.
	era_badge.visible = GameState.has_ability("time_shift")
	era_label.text = tr("UI_ERA_2034") if is_2034 else tr("UI_ERA_2054")
	era_label.add_theme_color_override("font_color", UITokens.PALE_GOLD if is_2034 else UITokens.WARM_SAND)
	era_badge.modulate = Color(1.0, 0.96, 0.86, 1.0) if is_2034 else Color(0.92, 0.94, 1.0, 0.92)


func _update_prompt_label() -> void:
	prompt_pill.visible = _prompt_visible and not _active_prompt_key.is_empty()
	if not prompt_pill.visible:
		return
	var translated: String = tr(_active_prompt_key)
	if _active_prompt_key.begins_with("TUT_"):
		prompt_label.text = translated
	else:
		var interact_key: String = ArabicFontSetup.get_action_key_label("interact")
		prompt_label.text = ArabicFontSetup.format_key_prompt(interact_key, translated)


func _update_boss_labels() -> void:
	boss_name_label.text = tr(_boss_name_key)
	if _boss_id == "boss_spire_warden":
		boss_subtitle_label.text = tr("BOSS_SPIRE_WARDEN_SUBTITLE")
		boss_subtitle_label.visible = true
	else:
		boss_subtitle_label.text = ""
		boss_subtitle_label.visible = false
	boss_hp_numbers_label.visible = SettingsManager.show_numbers
	boss_hp_numbers_label.text = ArabicFontSetup.isolate_ltr(
		ArabicFontSetup.localize_digits("%d / %d" % [maxi(0, _boss_hp), maxi(1, _boss_max_hp)])
	)
	boss_hp_bar.max_value = float(maxi(1, _boss_max_hp))
	boss_hp_bar.value = float(clampi(_boss_hp, 0, _boss_max_hp))

	var fill := StyleBoxFlat.new()
	fill.bg_color = UITokens.EMBER if _boss_phase >= 2 else UITokens.DESERT_RED
	fill.border_width_right = 2
	fill.border_color = UITokens.PALE_GOLD
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_right = 3
	fill.corner_radius_bottom_left = 3
	boss_hp_bar.add_theme_stylebox_override("fill", fill)


func _play_area_banner(title_key: String) -> void:
	if title_key.is_empty():
		return
	area_title_label.text = tr(title_key)
	if _area_tween != null and _area_tween.is_valid():
		_area_tween.kill()
	area_banner.modulate.a = 0.0
	_area_tween = create_tween()
	_area_tween.tween_property(area_banner, "modulate:a", 1.0, 0.45)
	_area_tween.tween_interval(2.4)
	_area_tween.tween_property(area_banner, "modulate:a", 0.0, 0.9)


func _on_player_health_changed(current: int, maximum: int) -> void:
	_current_hp = current
	_max_hp = maximum
	_rebuild_health_pips()
	_update_number_labels()
	wake_hud()


func _on_player_resource_changed(current: float, maximum: float, dagger_tier: int) -> void:
	_current_resource = current
	_max_resource = maximum
	_dagger_tier = dagger_tier
	_update_resource_display()
	_update_number_labels()
	_update_dagger_tier_label()
	wake_hud()


func _on_interaction_prompt_changed(is_visible: bool, prompt_key: String) -> void:
	_prompt_visible = is_visible
	_active_prompt_key = prompt_key
	_update_prompt_label()


func _on_room_loaded(_room_id: String, _area_id: String, room_title_key: String) -> void:
	wake_hud()
	_boss_active = false
	boss_panel.visible = false
	if room_title_key != _last_area_title_key:
		_last_area_title_key = room_title_key
		_play_area_banner(room_title_key)


func _on_boss_encounter_started(boss_id: String, name_key: String, max_hp: int) -> void:
	_boss_active = true
	_boss_id = boss_id
	_boss_name_key = name_key
	_boss_hp = max_hp
	_boss_max_hp = maxi(1, max_hp)
	_boss_phase = 1
	_update_boss_labels()
	boss_panel.visible = true
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	boss_panel.modulate.a = 0.0
	_boss_tween = create_tween()
	_boss_tween.tween_property(boss_panel, "modulate:a", 1.0, 0.4)


func _on_boss_health_changed(boss_id: String, current_hp: int, max_hp: int, phase: int) -> void:
	if not _boss_active or boss_id != _boss_id:
		return
	_boss_hp = current_hp
	_boss_max_hp = maxi(1, max_hp)
	_boss_phase = phase
	_update_boss_labels()


func _on_boss_defeated(boss_id: String) -> void:
	if boss_id != _boss_id and not _boss_active:
		return
	_boss_active = false
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.tween_property(boss_panel, "modulate:a", 0.0, 0.6)
	_boss_tween.tween_callback(_hide_boss_panel)


func _hide_boss_panel() -> void:
	boss_panel.visible = false


func _on_era_changed(era: String) -> void:
	_current_era = era
	_update_era_label()


func _on_ability_unlocked(_ability_id: String) -> void:
	_update_era_label()
	show_toast("UI_ABILITY_UNLOCKED", 3.0)
