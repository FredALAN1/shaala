class_name PauseSettingsMenu
extends Control
## Pause menu, Torn Notebook viewer, Controls Rebinding, Accessibility, Audio, and Language settings.
## Supports both in-gameplay pause mode and title-screen settings mode.

signal resume_requested
signal map_requested
signal save_and_quit_requested
signal closed_from_title

const COLOR_PALE_GOLD: Color = Color("#F6E299")
const COLOR_WARM_SAND: Color = Color("#E8C49A")
const COLOR_MUD_BRICK: Color = Color("#C68B59")

const NOTEBOOK_CATALOG: Array = [
	{
		"page_id": "page_00_camp",
		"title_key": "PAGE_CAMP_TITLE",
		"body_key": "PAGE_CAMP_BODY",
	},
	{
		"page_id": "page_01_highway",
		"title_key": "PAGE_HIGHWAY_TITLE",
		"body_key": "PAGE_HIGHWAY_BODY",
	},
	{
		"page_id": "page_02_mall",
		"title_key": "PAGE_MALL_TITLE",
		"body_key": "PAGE_MALL_BODY",
	},
]

const REBIND_ACTIONS: Array = [
	{"action": "move_left", "label_key": "UI_ACTION_MOVE_LEFT"},
	{"action": "move_right", "label_key": "UI_ACTION_MOVE_RIGHT"},
	{"action": "jump", "label_key": "UI_ACTION_JUMP"},
	{"action": "dash", "label_key": "UI_ACTION_DASH"},
	{"action": "attack", "label_key": "UI_ACTION_ATTACK"},
	{"action": "cast_spell", "label_key": "UI_ACTION_SPELL"},
	{"action": "parry", "label_key": "UI_ACTION_PARRY"},
	{"action": "interact", "label_key": "UI_ACTION_INTERACT"},
]

@onready var header_title_label: Label = $CenterContainer/MainPanel/HBox/Sidebar/HeaderTitleLabel
@onready var resume_button: Button = $CenterContainer/MainPanel/HBox/Sidebar/ResumeButton
@onready var map_button: Button = $CenterContainer/MainPanel/HBox/Sidebar/MapButton
@onready var notebook_tab_button: Button = $CenterContainer/MainPanel/HBox/Sidebar/NotebookTabButton
@onready var audio_tab_button: Button = $CenterContainer/MainPanel/HBox/Sidebar/AudioTabButton
@onready var accessibility_tab_button: Button = $CenterContainer/MainPanel/HBox/Sidebar/AccessibilityTabButton
@onready var controls_tab_button: Button = $CenterContainer/MainPanel/HBox/Sidebar/ControlsTabButton
@onready var save_quit_button: Button = $CenterContainer/MainPanel/HBox/Sidebar/SaveQuitButton
@onready var back_button: Button = $CenterContainer/MainPanel/HBox/Sidebar/BackButton

@onready var notebook_section: VBoxContainer = $CenterContainer/MainPanel/HBox/ContentArea/NotebookSection
@onready var notebook_header_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/NotebookSection/HeaderRow/NotebookHeaderLabel
@onready var notebook_count_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/NotebookSection/HeaderRow/NotebookCountLabel
@onready var notebook_list: VBoxContainer = $CenterContainer/MainPanel/HBox/ContentArea/NotebookSection/Scroll/NotebookList

@onready var audio_section: VBoxContainer = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection
@onready var language_header_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/LanguageRow/LanguageLabel
@onready var lang_ar_button: Button = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/LanguageRow/LangArButton
@onready var lang_en_button: Button = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/LanguageRow/LangEnButton
@onready var audio_header_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/AudioHeaderLabel
@onready var master_vol_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/MasterVolRow/Label
@onready var master_vol_slider: HSlider = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/MasterVolRow/Slider
@onready var master_vol_value: Label = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/MasterVolRow/ValueLabel
@onready var music_vol_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/MusicVolRow/Label
@onready var music_vol_slider: HSlider = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/MusicVolRow/Slider
@onready var music_vol_value: Label = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/MusicVolRow/ValueLabel
@onready var sfx_vol_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/SfxVolRow/Label
@onready var sfx_vol_slider: HSlider = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/SfxVolRow/Slider
@onready var sfx_vol_value: Label = $CenterContainer/MainPanel/HBox/ContentArea/AudioSection/SfxVolRow/ValueLabel

@onready var accessibility_section: VBoxContainer = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection
@onready var access_header_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/AccessHeaderLabel
@onready var shake_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/ShakeRow/Label
@onready var shake_slider: HSlider = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/ShakeRow/Slider
@onready var shake_value: Label = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/ShakeRow/ValueLabel
@onready var flash_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/FlashRow/Label
@onready var flash_check: CheckButton = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/FlashRow/CheckButton
@onready var assist_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/AssistRow/Label
@onready var assist_slider: HSlider = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/AssistRow/Slider
@onready var assist_value: Label = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/AssistRow/ValueLabel
@onready var deadzone_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/DeadzoneRow/Label
@onready var deadzone_slider: HSlider = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/DeadzoneRow/Slider
@onready var deadzone_value: Label = $CenterContainer/MainPanel/HBox/ContentArea/AccessibilitySection/DeadzoneRow/ValueLabel

@onready var controls_section: VBoxContainer = $CenterContainer/MainPanel/HBox/ContentArea/ControlsSection
@onready var controls_header_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/ControlsSection/ControlsHeaderLabel
@onready var rebind_status_label: Label = $CenterContainer/MainPanel/HBox/ContentArea/ControlsSection/RebindStatusLabel
@onready var rebind_list: VBoxContainer = $CenterContainer/MainPanel/HBox/ContentArea/ControlsSection/Scroll/RebindList

var _opened_from_title: bool = false
var _active_section: String = "audio"
var _rebinding_action: String = ""
var _syncing_controls: bool = false
var _rebind_row_labels: Dictionary = {}
var _rebind_row_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_connect_ui_signals()
	_build_rebind_rows()
	_sync_from_settings()
	refresh_texts()


func _connect_ui_signals() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	map_button.pressed.connect(_on_map_pressed)
	notebook_tab_button.pressed.connect(_on_select_section.bind("notebook"))
	audio_tab_button.pressed.connect(_on_select_section.bind("audio"))
	accessibility_tab_button.pressed.connect(_on_select_section.bind("accessibility"))
	controls_tab_button.pressed.connect(_on_select_section.bind("controls"))
	save_quit_button.pressed.connect(_on_save_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)

	lang_ar_button.pressed.connect(_on_set_locale.bind("ar"))
	lang_en_button.pressed.connect(_on_set_locale.bind("en"))

	master_vol_slider.value_changed.connect(_on_master_vol_changed)
	music_vol_slider.value_changed.connect(_on_music_vol_changed)
	sfx_vol_slider.value_changed.connect(_on_sfx_vol_changed)

	shake_slider.value_changed.connect(_on_shake_changed)
	flash_check.toggled.connect(_on_flash_toggled)
	assist_slider.value_changed.connect(_on_assist_changed)
	deadzone_slider.value_changed.connect(_on_deadzone_changed)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _rebinding_action.is_empty():
		if event is InputEventKey:
			var key_ev := event as InputEventKey
			if key_ev.pressed and not key_ev.echo:
				get_viewport().set_input_as_handled()
				var code: Key = key_ev.physical_keycode if key_ev.physical_keycode != KEY_NONE else key_ev.keycode
				if code == KEY_ESCAPE:
					_cancel_rebind()
				elif code != KEY_NONE:
					_apply_rebind(_rebinding_action, code)
		return

	if _opened_from_title and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func is_rebinding() -> bool:
	return not _rebinding_action.is_empty()


func open_pause() -> void:
	_opened_from_title = false
	_cancel_rebind()
	resume_button.visible = true
	map_button.visible = true
	notebook_tab_button.visible = true
	save_quit_button.visible = true
	back_button.visible = false
	visible = true
	_sync_from_settings()
	_show_section("notebook")
	refresh_texts()
	AudioManager.play_sfx("ui_click")
	resume_button.grab_focus()


func open_from_title() -> void:
	_opened_from_title = true
	_cancel_rebind()
	resume_button.visible = false
	map_button.visible = false
	notebook_tab_button.visible = false
	save_quit_button.visible = false
	back_button.visible = true
	visible = true
	_sync_from_settings()
	_show_section("audio")
	refresh_texts()
	AudioManager.play_sfx("ui_click")
	back_button.grab_focus()


func refresh_texts() -> void:
	header_title_label.text = tr("UI_SETTINGS") if _opened_from_title else tr("UI_PAUSED")
	resume_button.text = tr("UI_RESUME")
	map_button.text = tr("UI_MAP")
	notebook_tab_button.text = tr("UI_NOTEBOOK")
	audio_tab_button.text = "%s / %s" % [tr("UI_LANGUAGE"), tr("UI_AUDIO")]
	accessibility_tab_button.text = tr("UI_ACCESSIBILITY")
	controls_tab_button.text = tr("UI_CONTROLS")
	save_quit_button.text = tr("UI_SAVE_AND_QUIT")
	back_button.text = tr("UI_BACK")

	notebook_header_label.text = tr("UI_NOTEBOOK")
	language_header_label.text = tr("UI_LANGUAGE")
	lang_ar_button.text = tr("UI_LANG_AR")
	lang_en_button.text = tr("UI_LANG_EN")
	audio_header_label.text = tr("UI_AUDIO")
	master_vol_label.text = tr("UI_MASTER_VOL")
	music_vol_label.text = tr("UI_MUSIC_VOL")
	sfx_vol_label.text = tr("UI_SFX_VOL")

	access_header_label.text = tr("UI_ACCESSIBILITY")
	shake_label.text = tr("UI_SCREEN_SHAKE")
	flash_label.text = tr("UI_REDUCE_FLASH")
	flash_check.text = tr("UI_ON") if flash_check.button_pressed else tr("UI_OFF")
	assist_label.text = tr("UI_ASSIST_SPEED")
	deadzone_label.text = tr("UI_GAMEPAD_DEADZONE")

	controls_header_label.text = tr("UI_CONTROLS")
	rebind_status_label.text = tr("UI_REBIND_PROMPT") if not _rebinding_action.is_empty() else ""
	rebind_status_label.visible = not _rebinding_action.is_empty()

	_update_value_labels()
	_update_language_highlights()
	_refresh_rebind_rows()
	refresh_notebook()


func refresh_notebook() -> void:
	for child: Node in notebook_list.get_children():
		child.queue_free()

	var collected_ids: Array[String] = GameState.collected_pages
	notebook_count_label.text = ArabicFontSetup.format_bidi_pair(
		tr("UI_PAGES_COUNT"),
		"%d / %d" % [collected_ids.size(), NOTEBOOK_CATALOG.size()]
	)

	if collected_ids.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = tr("UI_NO_PAGES_YET")
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.set_meta("align_reading_edge", true)
		empty_lbl.add_theme_color_override("font_color", Color(COLOR_WARM_SAND, 0.72))
		notebook_list.add_child(empty_lbl)
		ArabicFontSetup.apply_to_control(notebook_section, TranslationServer.get_locale())
		return

	for page_entry: Dictionary in NOTEBOOK_CATALOG:
		var pid: String = str(page_entry["page_id"])
		if not (pid in collected_ids):
			continue
		var card := PanelContainer.new()
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)

		var badge := Label.new()
		badge.text = tr("UI_TORN_PAGE")
		badge.set_meta("align_reading_edge", true)
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", COLOR_MUD_BRICK)
		box.add_child(badge)

		var title := Label.new()
		title.text = tr(str(page_entry["title_key"]))
		title.set_meta("align_reading_edge", true)
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", COLOR_PALE_GOLD)
		box.add_child(title)

		var body := RichTextLabel.new()
		body.fit_content = true
		body.scroll_active = false
		body.bbcode_enabled = false
		body.text = tr(str(page_entry["body_key"]))
		body.add_theme_font_size_override("normal_font_size", 20)
		box.add_child(body)

		notebook_list.add_child(card)

	ArabicFontSetup.apply_to_control(notebook_section, TranslationServer.get_locale())


func _build_rebind_rows() -> void:
	for child: Node in rebind_list.get_children():
		child.queue_free()
	_rebind_row_labels.clear()
	_rebind_row_buttons.clear()

	for entry: Dictionary in REBIND_ACTIONS:
		var action_name: String = str(entry["action"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.set_meta("align_reading_edge", true)
		row.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(210.0, 44.0)
		btn.pressed.connect(_on_start_rebind.bind(action_name))
		row.add_child(btn)

		rebind_list.add_child(row)
		_rebind_row_labels[action_name] = lbl
		_rebind_row_buttons[action_name] = btn


func _refresh_rebind_rows() -> void:
	for entry: Dictionary in REBIND_ACTIONS:
		var action_name: String = str(entry["action"])
		var label_key: String = str(entry["label_key"])
		if _rebind_row_labels.has(action_name):
			(_rebind_row_labels[action_name] as Label).text = tr(label_key)
		if _rebind_row_buttons.has(action_name):
			var btn := _rebind_row_buttons[action_name] as Button
			if _rebinding_action == action_name:
				btn.text = ArabicFontSetup.isolate_ltr("...")
				btn.modulate = COLOR_PALE_GOLD
			else:
				var key_str: String = ArabicFontSetup.get_action_key_label(action_name)
				btn.text = ArabicFontSetup.isolate_ltr("[%s]" % key_str) if key_str != "?" else tr("UI_KEY_UNBOUND")
				btn.modulate = Color.WHITE


func _show_section(section_name: String) -> void:
	_active_section = section_name
	notebook_section.visible = section_name == "notebook"
	audio_section.visible = section_name == "audio"
	accessibility_section.visible = section_name == "accessibility"
	controls_section.visible = section_name == "controls"

	notebook_tab_button.modulate = COLOR_PALE_GOLD if section_name == "notebook" else Color.WHITE
	audio_tab_button.modulate = COLOR_PALE_GOLD if section_name == "audio" else Color.WHITE
	accessibility_tab_button.modulate = COLOR_PALE_GOLD if section_name == "accessibility" else Color.WHITE
	controls_tab_button.modulate = COLOR_PALE_GOLD if section_name == "controls" else Color.WHITE

	if section_name == "notebook":
		refresh_notebook()
	elif section_name == "controls":
		_refresh_rebind_rows()


func _sync_from_settings() -> void:
	_syncing_controls = true
	master_vol_slider.value = clampf(SettingsManager.master_volume, 0.0, 1.0)
	music_vol_slider.value = clampf(SettingsManager.music_volume, 0.0, 1.0)
	sfx_vol_slider.value = clampf(SettingsManager.sfx_volume, 0.0, 1.0)
	shake_slider.value = clampf(SettingsManager.screen_shake_scale, 0.0, 1.0)
	flash_check.button_pressed = SettingsManager.reduce_flash
	assist_slider.value = clampf(SettingsManager.assist_game_speed, 0.7, 1.0)
	deadzone_slider.value = clampf(SettingsManager.gamepad_deadzone, 0.1, 0.5)
	_syncing_controls = false
	_update_value_labels()


func _update_value_labels() -> void:
	master_vol_value.text = ArabicFontSetup.isolate_ltr("%d%%" % int(round(master_vol_slider.value * 100.0)))
	music_vol_value.text = ArabicFontSetup.isolate_ltr("%d%%" % int(round(music_vol_slider.value * 100.0)))
	sfx_vol_value.text = ArabicFontSetup.isolate_ltr("%d%%" % int(round(sfx_vol_slider.value * 100.0)))
	shake_value.text = ArabicFontSetup.isolate_ltr("%d%%" % int(round(shake_slider.value * 100.0)))
	assist_value.text = ArabicFontSetup.isolate_ltr("%d%%" % int(round(assist_slider.value * 100.0)))
	deadzone_value.text = ArabicFontSetup.isolate_ltr("%d%%" % int(round(deadzone_slider.value * 100.0)))


func _update_language_highlights() -> void:
	var is_ar: bool = ArabicFontSetup.is_rtl_locale()
	lang_ar_button.modulate = COLOR_PALE_GOLD if is_ar else COLOR_WARM_SAND
	lang_en_button.modulate = COLOR_PALE_GOLD if not is_ar else COLOR_WARM_SAND


func _on_select_section(section_name: String) -> void:
	_cancel_rebind()
	AudioManager.play_sfx("ui_hover")
	_show_section(section_name)


func _on_resume_pressed() -> void:
	_cancel_rebind()
	AudioManager.play_sfx("ui_click")
	resume_requested.emit()


func _on_map_pressed() -> void:
	_cancel_rebind()
	AudioManager.play_sfx("ui_click")
	map_requested.emit()


func _on_save_quit_pressed() -> void:
	_cancel_rebind()
	AudioManager.play_sfx("ui_click")
	save_and_quit_requested.emit()


func _on_back_pressed() -> void:
	_cancel_rebind()
	AudioManager.play_sfx("ui_click")
	closed_from_title.emit()


func _on_set_locale(locale: String) -> void:
	AudioManager.play_sfx("ui_hover")
	SettingsManager.set_locale(locale)


func _on_master_vol_changed(val: float) -> void:
	_update_value_labels()
	if _syncing_controls:
		return
	SettingsManager.set_master_volume(val)


func _on_music_vol_changed(val: float) -> void:
	_update_value_labels()
	if _syncing_controls:
		return
	SettingsManager.set_music_volume(val)


func _on_sfx_vol_changed(val: float) -> void:
	_update_value_labels()
	if _syncing_controls:
		return
	SettingsManager.set_sfx_volume(val)


func _on_shake_changed(val: float) -> void:
	_update_value_labels()
	if _syncing_controls:
		return
	SettingsManager.set_screen_shake_scale(val)


func _on_flash_toggled(pressed: bool) -> void:
	flash_check.text = tr("UI_ON") if pressed else tr("UI_OFF")
	if _syncing_controls:
		return
	SettingsManager.set_reduce_flash(pressed)


func _on_assist_changed(val: float) -> void:
	_update_value_labels()
	if _syncing_controls:
		return
	SettingsManager.set_assist_game_speed(val)


func _on_deadzone_changed(val: float) -> void:
	_update_value_labels()
	if _syncing_controls:
		return
	SettingsManager.set_gamepad_deadzone(val)


func _on_start_rebind(action_name: String) -> void:
	_rebinding_action = action_name
	rebind_status_label.text = tr("UI_REBIND_PROMPT")
	rebind_status_label.visible = true
	AudioManager.play_sfx("ui_hover")
	_refresh_rebind_rows()


func _cancel_rebind() -> void:
	_rebinding_action = ""
	if rebind_status_label != null:
		rebind_status_label.text = ""
		rebind_status_label.visible = false
	_refresh_rebind_rows()


func _apply_rebind(action_name: String, keycode: Key) -> void:
	SettingsManager.rebind_action_key(action_name, int(keycode))
	_rebinding_action = ""
	rebind_status_label.text = ""
	rebind_status_label.visible = false
	AudioManager.play_sfx("ui_click")
	_refresh_rebind_rows()
