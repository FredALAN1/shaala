class_name PauseSettingsMenu
extends Control
## Pause = the Notebook (docs/UI_DESIGN_PLAN.md §6.5–§6.9): an open notebook spread whose start page
## holds the menu and whose end page holds the selected section; sections are Sadu bookmark ribbons.
## Journal pages are pasted paper scraps, missing pages are torn stubs along the spine, and
## Save & Quit asks on a paper slip. Supports in-gameplay pause and title-screen settings mode.

signal resume_requested
signal map_requested
signal save_and_quit_requested
signal closed_from_title


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
@onready var map_button: Button = $CenterContainer/MainPanel/HBox/PageEnd/RibbonBar/MapButton
@onready var notebook_tab_button: Button = $CenterContainer/MainPanel/HBox/PageEnd/RibbonBar/NotebookTabButton
@onready var audio_tab_button: Button = $CenterContainer/MainPanel/HBox/PageEnd/RibbonBar/AudioTabButton
@onready var accessibility_tab_button: Button = $CenterContainer/MainPanel/HBox/PageEnd/RibbonBar/AccessibilityTabButton
@onready var controls_tab_button: Button = $CenterContainer/MainPanel/HBox/PageEnd/RibbonBar/ControlsTabButton
@onready var save_quit_button: Button = $CenterContainer/MainPanel/HBox/Sidebar/SaveQuitButton
@onready var back_button: Button = $CenterContainer/MainPanel/HBox/Sidebar/BackButton

@onready var notebook_section: VBoxContainer = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/NotebookSection
@onready var notebook_header_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/NotebookSection/HeaderRow/NotebookHeaderLabel
@onready var notebook_count_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/NotebookSection/HeaderRow/NotebookCountLabel
@onready var notebook_list: VBoxContainer = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/NotebookSection/Scroll/NotebookList

@onready var audio_section: VBoxContainer = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection
@onready var language_header_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/LanguageRow/LanguageLabel
@onready var lang_ar_button: Button = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/LanguageRow/LangArButton
@onready var lang_en_button: Button = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/LanguageRow/LangEnButton
@onready var audio_header_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/AudioHeaderLabel
@onready var master_vol_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/MasterVolRow/Label
@onready var master_vol_slider: HSlider = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/MasterVolRow/Slider
@onready var master_vol_value: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/MasterVolRow/ValueLabel
@onready var music_vol_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/MusicVolRow/Label
@onready var music_vol_slider: HSlider = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/MusicVolRow/Slider
@onready var music_vol_value: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/MusicVolRow/ValueLabel
@onready var sfx_vol_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/SfxVolRow/Label
@onready var sfx_vol_slider: HSlider = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/SfxVolRow/Slider
@onready var sfx_vol_value: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AudioSection/SfxVolRow/ValueLabel

@onready var accessibility_section: VBoxContainer = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection
@onready var access_header_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/AccessHeaderLabel
@onready var shake_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/ShakeRow/Label
@onready var shake_slider: HSlider = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/ShakeRow/Slider
@onready var shake_value: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/ShakeRow/ValueLabel
@onready var flash_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/FlashRow/Label
@onready var flash_check: CheckButton = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/FlashRow/CheckButton
@onready var assist_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/AssistRow/Label
@onready var assist_slider: HSlider = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/AssistRow/Slider
@onready var assist_value: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/AssistRow/ValueLabel
@onready var deadzone_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/DeadzoneRow/Label
@onready var deadzone_slider: HSlider = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/DeadzoneRow/Slider
@onready var deadzone_value: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/AccessibilitySection/DeadzoneRow/ValueLabel

@onready var controls_section: VBoxContainer = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/ControlsSection
@onready var controls_header_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/ControlsSection/ControlsHeaderLabel
@onready var rebind_status_label: Label = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/ControlsSection/RebindStatusLabel
@onready var rebind_list: VBoxContainer = $CenterContainer/MainPanel/HBox/PageEnd/ContentArea/ControlsSection/Scroll/RebindList

@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var spine: Control = $CenterContainer/MainPanel/HBox/Spine
@onready var confirm_layer: CenterContainer = $ConfirmLayer
@onready var confirm_slip: PanelContainer = $ConfirmLayer/ConfirmSlip
@onready var confirm_label: Label = $ConfirmLayer/ConfirmSlip/VBox/ConfirmLabel
@onready var confirm_yes_button: Button = $ConfirmLayer/ConfirmSlip/VBox/Row/ConfirmYesButton
@onready var confirm_no_button: Button = $ConfirmLayer/ConfirmSlip/VBox/Row/ConfirmNoButton

const UI_ART_DIR: String = "res://assets/final/ui/"
const PAPER_SCRAPS: Array = ["paper_scrap_a.png", "paper_scrap_b.png", "paper_scrap_c.png"]
const RIBBON_WIDTH: float = 116.0
const RIBBON_HEIGHT: float = 116.0
const RIBBON_ACTIVE_HEIGHT: float = 168.0
const STUB_TOP: float = 150.0
const STUB_STEP: float = 150.0

var _opened_from_title: bool = false
var _active_section: String = ""
var _rebinding_action: String = ""
var _syncing_controls: bool = false
var _rebind_row_labels: Dictionary = {}
var _rebind_row_buttons: Dictionary = {}

# "Notebook & Ember" accessibility rows built at runtime from the existing row templates.
var motion_label: Label = null
var motion_check: CheckButton = null
var hud_label: Label = null
var hud_check: CheckButton = null
var numbers_label: Label = null
var numbers_check: CheckButton = null
var text_scale_label: Label = null
var text_scale_slider: HSlider = null
var text_scale_value: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_build_accessibility_rows()
	_apply_notebook_skin()
	_connect_ui_signals()
	_build_rebind_rows()
	_sync_from_settings()
	refresh_texts()


func _build_accessibility_rows() -> void:
	var flash_row: HBoxContainer = flash_check.get_parent() as HBoxContainer
	var assist_row: HBoxContainer = assist_slider.get_parent() as HBoxContainer

	var motion_row := flash_row.duplicate() as HBoxContainer
	motion_row.name = "MotionRow"
	accessibility_section.add_child(motion_row)
	motion_label = motion_row.get_node("Label") as Label
	motion_check = motion_row.get_node("CheckButton") as CheckButton

	var hud_row := flash_row.duplicate() as HBoxContainer
	hud_row.name = "HudAlwaysRow"
	accessibility_section.add_child(hud_row)
	hud_label = hud_row.get_node("Label") as Label
	hud_check = hud_row.get_node("CheckButton") as CheckButton

	var numbers_row := flash_row.duplicate() as HBoxContainer
	numbers_row.name = "ShowNumbersRow"
	accessibility_section.add_child(numbers_row)
	numbers_label = numbers_row.get_node("Label") as Label
	numbers_check = numbers_row.get_node("CheckButton") as CheckButton

	var scale_row := assist_row.duplicate() as HBoxContainer
	scale_row.name = "TextScaleRow"
	accessibility_section.add_child(scale_row)
	text_scale_label = scale_row.get_node("Label") as Label
	text_scale_slider = scale_row.get_node("Slider") as HSlider
	text_scale_value = scale_row.get_node("ValueLabel") as Label
	text_scale_slider.min_value = 1.0
	text_scale_slider.max_value = 1.5
	text_scale_slider.step = 0.25


func _connect_ui_signals() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	map_button.pressed.connect(_on_map_pressed)
	notebook_tab_button.pressed.connect(_on_select_section.bind("notebook"))
	audio_tab_button.pressed.connect(_on_select_section.bind("audio"))
	accessibility_tab_button.pressed.connect(_on_select_section.bind("accessibility"))
	controls_tab_button.pressed.connect(_on_select_section.bind("controls"))
	save_quit_button.pressed.connect(_on_save_quit_pressed)
	confirm_yes_button.pressed.connect(_on_confirm_yes)
	confirm_no_button.pressed.connect(_close_confirm)
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
	motion_check.toggled.connect(_on_motion_toggled)
	hud_check.toggled.connect(_on_hud_always_toggled)
	numbers_check.toggled.connect(_on_show_numbers_toggled)
	text_scale_slider.value_changed.connect(_on_text_scale_changed)


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

	if confirm_layer.visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_close_confirm()
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
	confirm_layer.visible = false
	# Default section: last used, otherwise the Journal (plan §6.5).
	_show_section(_active_section if _active_section in ["notebook", "audio", "accessibility", "controls"] else "notebook")
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
	confirm_layer.visible = false
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
	notebook_tab_button.text = tr("UI_RIBBON_JOURNAL")
	audio_tab_button.text = tr("UI_SETTINGS")
	accessibility_tab_button.text = tr("UI_RIBBON_ACCESS")
	controls_tab_button.text = tr("UI_CONTROLS")
	confirm_label.text = tr("UI_CONFIRM_SAVE_QUIT")
	confirm_yes_button.text = tr("UI_CONFIRM_YES")
	confirm_no_button.text = tr("UI_CONFIRM_NO")
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
	motion_label.text = tr("UI_REDUCE_MOTION")
	motion_check.text = tr("UI_ON") if motion_check.button_pressed else tr("UI_OFF")
	hud_label.text = tr("UI_HUD_ALWAYS_VISIBLE")
	hud_check.text = tr("UI_ON") if hud_check.button_pressed else tr("UI_OFF")
	numbers_label.text = tr("UI_SHOW_NUMBERS")
	numbers_check.text = tr("UI_ON") if numbers_check.button_pressed else tr("UI_OFF")
	text_scale_label.text = tr("UI_TEXT_SCALE")

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
	# No "0 / 3" counter: missing pages show as torn stubs along the spine (plan §6.6).
	notebook_count_label.visible = false
	_refresh_torn_stubs(NOTEBOOK_CATALOG.size() - _count_collected(collected_ids))

	if collected_ids.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = tr("UI_NO_PAGES_YET")
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.set_meta("align_reading_edge", true)
		empty_lbl.set_meta("font_role", ArabicFontSetup.ROLE_HAND)
		empty_lbl.add_theme_font_size_override("font_size", UITokens.SIZE_HAND_M)
		empty_lbl.add_theme_color_override("font_color", UITokens.INK_MUTED)
		notebook_list.add_child(empty_lbl)
		ArabicFontSetup.apply_typography_tree(notebook_section, TranslationServer.get_locale())
		return

	# Aref Ruqaa for page text, Readex Pro once text is scaled to 125% or more (DROP-002 §6.4 #4).
	var body_role: String = ArabicFontSetup.ROLE_HAND if ArabicFontSetup.get_text_scale() < 1.25 else ArabicFontSetup.ROLE_BODY
	var scrap_index: int = 0
	for page_entry: Dictionary in NOTEBOOK_CATALOG:
		var pid: String = str(page_entry["page_id"])
		if not (pid in collected_ids):
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _paper_box(str(PAPER_SCRAPS[scrap_index % PAPER_SCRAPS.size()]), 56.0, 56.0))
		scrap_index += 1
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		card.add_child(box)

		var title := Label.new()
		title.text = tr(str(page_entry["title_key"]))
		title.set_meta("align_reading_edge", true)
		title.set_meta("font_role", ArabicFontSetup.ROLE_HAND)
		title.add_theme_font_size_override("font_size", UITokens.SIZE_HAND_M)
		title.add_theme_color_override("font_color", UITokens.INK_BROWN)
		box.add_child(title)

		var body := RichTextLabel.new()
		body.fit_content = true
		body.scroll_active = false
		body.bbcode_enabled = false
		body.text = tr(str(page_entry["body_key"]))
		body.set_meta("font_role", body_role)
		body.add_theme_font_size_override("normal_font_size", UITokens.SIZE_BODY_M)
		body.add_theme_color_override("default_color", UITokens.INK_BROWN)
		# Generous line height for the Ruqaa baseline (about 1.95x).
		body.add_theme_constant_override("line_separation", 18 if body_role == ArabicFontSetup.ROLE_HAND else 8)
		box.add_child(body)

		notebook_list.add_child(card)

	ArabicFontSetup.apply_typography_tree(notebook_section, TranslationServer.get_locale())


func _count_collected(collected_ids: Array[String]) -> int:
	var count: int = 0
	for page_entry: Dictionary in NOTEBOOK_CATALOG:
		if str(page_entry["page_id"]) in collected_ids:
			count += 1
	return count


## One torn-out stub per missing page, flush against the spine on the content-page side.
func _refresh_torn_stubs(missing: int) -> void:
	for child: Node in spine.get_children():
		child.queue_free()
	var count: int = 0 if (_opened_from_title or _active_section != "notebook") else maxi(0, missing)
	var stub_tex: Texture2D = _paper_texture("torn_stub.png")
	if count == 0 or stub_tex == null:
		return
	var rtl: bool = is_layout_rtl()
	var center_x: float = spine.custom_minimum_size.x * 0.5
	for i: int in range(count):
		var stub := TextureRect.new()
		stub.texture = stub_tex
		stub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Positions inside an RTL parent are mirrored; place the stubs in plain LTR coordinates
		# so they meet the spine's centre line exactly.
		stub.layout_direction = Control.LAYOUT_DIRECTION_LTR
		# The stub's spine edge is its right edge (x = 40): flip it when the content page is on the right.
		stub.flip_h = not rtl
		stub.position = Vector2(center_x - stub_tex.get_width() if rtl else center_x, STUB_TOP + float(i) * STUB_STEP)
		spine.add_child(stub)


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
				btn.modulate = UITokens.INK_FOCUS_PAPER
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

	_set_ribbon_active(notebook_tab_button, section_name == "notebook")
	_set_ribbon_active(map_button, false)
	_set_ribbon_active(audio_tab_button, section_name == "audio")
	_set_ribbon_active(accessibility_tab_button, section_name == "accessibility")
	_set_ribbon_active(controls_tab_button, section_name == "controls")

	if section_name == "notebook":
		refresh_notebook()
	else:
		_refresh_torn_stubs(0)
	if section_name == "controls":
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
	motion_check.button_pressed = SettingsManager.reduce_motion
	hud_check.button_pressed = SettingsManager.hud_always_visible
	numbers_check.button_pressed = SettingsManager.show_numbers
	text_scale_slider.value = clampf(SettingsManager.text_scale, 1.0, 1.5)
	_syncing_controls = false
	_update_value_labels()


func _update_value_labels() -> void:
	master_vol_value.text = ArabicFontSetup.isolate_ltr(ArabicFontSetup.format_percent(master_vol_slider.value))
	music_vol_value.text = ArabicFontSetup.isolate_ltr(ArabicFontSetup.format_percent(music_vol_slider.value))
	sfx_vol_value.text = ArabicFontSetup.isolate_ltr(ArabicFontSetup.format_percent(sfx_vol_slider.value))
	shake_value.text = ArabicFontSetup.isolate_ltr(ArabicFontSetup.format_percent(shake_slider.value))
	assist_value.text = ArabicFontSetup.isolate_ltr(ArabicFontSetup.format_percent(assist_slider.value))
	deadzone_value.text = ArabicFontSetup.isolate_ltr(ArabicFontSetup.format_percent(deadzone_slider.value))
	if text_scale_value != null:
		text_scale_value.text = ArabicFontSetup.isolate_ltr(ArabicFontSetup.format_percent(text_scale_slider.value))


func _update_language_highlights() -> void:
	var is_ar: bool = ArabicFontSetup.is_rtl_locale()
	lang_ar_button.add_theme_color_override("font_color", UITokens.INK_FOCUS_PAPER if is_ar else UITokens.INK_MUTED)
	lang_en_button.add_theme_color_override("font_color", UITokens.INK_FOCUS_PAPER if not is_ar else UITokens.INK_MUTED)


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
	# Destructive actions ask first, on a paper slip (plan §6.9).
	confirm_layer.visible = true
	confirm_no_button.grab_focus()


func _on_confirm_yes() -> void:
	confirm_layer.visible = false
	AudioManager.play_sfx("ui_click")
	save_and_quit_requested.emit()


func _close_confirm() -> void:
	confirm_layer.visible = false
	AudioManager.play_sfx("ui_hover")
	save_quit_button.grab_focus()


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


func _on_motion_toggled(pressed: bool) -> void:
	motion_check.text = tr("UI_ON") if pressed else tr("UI_OFF")
	if _syncing_controls:
		return
	SettingsManager.set_reduce_motion(pressed)


func _on_hud_always_toggled(pressed: bool) -> void:
	hud_check.text = tr("UI_ON") if pressed else tr("UI_OFF")
	if _syncing_controls:
		return
	SettingsManager.set_hud_always_visible(pressed)


func _on_show_numbers_toggled(pressed: bool) -> void:
	numbers_check.text = tr("UI_ON") if pressed else tr("UI_OFF")
	if _syncing_controls:
		return
	SettingsManager.set_show_numbers(pressed)


func _on_text_scale_changed(val: float) -> void:
	_update_value_labels()
	if _syncing_controls:
		return
	# Only 3 steps (100/125/150%), so re-laying out the UI on each change is cheap.
	SettingsManager.set_text_scale(val)


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


# --- Notebook & Ember skin -------------------------------------------------------------

func _apply_notebook_skin() -> void:
	($Dimmer as ColorRect).color = Color(UITokens.NIGHT_DEEP, 0.82)
	var paper_theme: Theme = _build_paper_theme()
	main_panel.theme = paper_theme
	confirm_slip.theme = paper_theme
	main_panel.add_theme_stylebox_override("panel", _spread_box())
	confirm_slip.add_theme_stylebox_override("panel", _paper_box("paper_slip.png", 64.0, 56.0, 48))
	($CenterContainer/MainPanel/HBox/Sidebar as VBoxContainer).custom_minimum_size.x = 600.0
	($CenterContainer/MainPanel/HBox/PageEnd as VBoxContainer).custom_minimum_size.x = 600.0
	spine.custom_minimum_size.x = 144.0

	header_title_label.set_meta("font_role", ArabicFontSetup.ROLE_HAND)
	header_title_label.set_meta("align_reading_edge", true)
	header_title_label.add_theme_font_size_override("font_size", UITokens.SIZE_HAND_L)
	header_title_label.custom_minimum_size.y = 150.0
	header_title_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	for lbl: Label in [notebook_header_label, audio_header_label, access_header_label, controls_header_label, language_header_label]:
		lbl.set_meta("font_role", ArabicFontSetup.ROLE_HAND)
		lbl.add_theme_font_size_override("font_size", UITokens.SIZE_HAND_M)

	for btn: Button in [resume_button, save_quit_button, back_button]:
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", UITokens.SIZE_BODY_L)
	# Destructive action is visually different: desert-red ink.
	save_quit_button.add_theme_color_override("font_color", UITokens.INK_DESTRUCTIVE_PAPER)
	save_quit_button.add_theme_color_override("font_focus_color", UITokens.INK_DESTRUCTIVE_PAPER)
	save_quit_button.add_theme_color_override("font_hover_color", UITokens.INK_DESTRUCTIVE_PAPER)
	confirm_yes_button.add_theme_color_override("font_color", UITokens.INK_DESTRUCTIVE_PAPER)
	confirm_yes_button.add_theme_color_override("font_focus_color", UITokens.INK_DESTRUCTIVE_PAPER)

	var furjat_path: String = UI_ART_DIR + "furjat_divider.png"
	if ResourceLoader.exists(furjat_path):
		var furjat := TextureRect.new()
		furjat.texture = load(furjat_path) as Texture2D
		furjat.stretch_mode = TextureRect.STRETCH_KEEP
		furjat.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		furjat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sidebar: VBoxContainer = $CenterContainer/MainPanel/HBox/Sidebar as VBoxContainer
		sidebar.add_child(furjat)
		sidebar.move_child(furjat, save_quit_button.get_index())

	for ribbon: Button in [notebook_tab_button, map_button, audio_tab_button, accessibility_tab_button, controls_tab_button]:
		_style_ribbon(ribbon)

	# Keep both pages at their fixed width so the spine stays on the spread's centre line:
	# setting labels wrap instead of widening the page.
	for section: Control in [audio_section, accessibility_section]:
		for row: Node in section.get_children():
			if row is HBoxContainer and row.has_node("Label"):
				var row_label: Label = row.get_node("Label") as Label
				row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				row_label.custom_minimum_size.x = 160.0


func _paper_texture(file_name: String) -> Texture2D:
	var path: String = UI_ART_DIR + file_name
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _spread_box() -> StyleBox:
	var tex: Texture2D = _paper_texture("notebook_spread.png")
	if tex == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = UITokens.PAPER_ASH
		return flat
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.content_margin_left = 96.0
	box.content_margin_right = 96.0
	box.content_margin_top = 20.0
	box.content_margin_bottom = 72.0
	return box


## Paper surface; with slice > 0 it is a 9-slice (paper_slip uses 48 px on every side).
func _paper_box(file_name: String, margin_h: float, margin_v: float, slice: int = 0) -> StyleBox:
	var tex: Texture2D = _paper_texture(file_name)
	if tex == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = UITokens.PAPER_SCRAP
		flat.set_content_margin_all(margin_v)
		return flat
	var box := StyleBoxTexture.new()
	box.texture = tex
	if slice > 0:
		box.texture_margin_left = float(slice)
		box.texture_margin_right = float(slice)
		box.texture_margin_top = float(slice)
		box.texture_margin_bottom = float(slice)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	return box


func _ribbon_box(active: bool) -> StyleBox:
	var tex: Texture2D = _paper_texture("notebook_ribbon_active.png" if active else "notebook_ribbon.png")
	if tex == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = UITokens.INK_FOCUS_PAPER if active else UITokens.INK_MUTED
		return flat
	var box := StyleBoxTexture.new()
	box.texture = tex
	# The label sits on the ribbon's dark woven band, horizontally (DROP-002 §6.4 #2).
	box.content_margin_top = 80.0 if active else 40.0
	box.content_margin_bottom = 28.0 if active else 16.0
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	return box


func _style_ribbon(ribbon: Button) -> void:
	ribbon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ribbon.clip_text = true
	ribbon.set_meta("font_role", ArabicFontSetup.ROLE_BODY)
	ribbon.add_theme_font_size_override("font_size", UITokens.SIZE_CAPTION)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		ribbon.add_theme_color_override(state, UITokens.PAPER_SCRAP)
	ribbon.add_theme_color_override("font_focus_color", UITokens.PALE_GOLD)
	_set_ribbon_active(ribbon, false)


func _set_ribbon_active(ribbon: Button, active: bool) -> void:
	var box: StyleBox = _ribbon_box(active)
	for slot: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		ribbon.add_theme_stylebox_override(slot, box)
	# Focus keeps the same ribbon, lit by a pale-gold label instead of an outline.
	ribbon.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	ribbon.custom_minimum_size = Vector2(RIBBON_WIDTH, RIBBON_ACTIVE_HEIGHT if active else RIBBON_HEIGHT)


## Ink-on-paper theme for everything inside the notebook (dual-surface tokens, DROP-002 §6.4 #1).
func _build_paper_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", UITokens.INK_BROWN)
	t.set_color("default_color", "RichTextLabel", UITokens.INK_BROWN)
	# Ink has no drop shadow (the dark-surface theme adds one to Label / RichTextLabel).
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_color("font_shadow_color", "RichTextLabel", Color(0, 0, 0, 0))

	var empty := StyleBoxEmpty.new()
	var underline := StyleBoxFlat.new()
	underline.bg_color = Color(0, 0, 0, 0)
	underline.border_width_bottom = 2
	underline.border_color = UITokens.INK_FOCUS_PAPER
	for type_name: String in ["Button", "CheckButton"]:
		t.set_color("font_color", type_name, UITokens.INK_BROWN)
		t.set_color("font_hover_color", type_name, UITokens.INK_FOCUS_PAPER)
		t.set_color("font_focus_color", type_name, UITokens.INK_FOCUS_PAPER)
		t.set_color("font_pressed_color", type_name, UITokens.INK_FOCUS_PAPER)
		t.set_color("font_hover_pressed_color", type_name, UITokens.INK_FOCUS_PAPER)
		t.set_color("font_disabled_color", type_name, UITokens.INK_MUTED)
		for slot: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(slot, type_name, empty)
		t.set_stylebox("focus", type_name, underline)

	var toggle_on: Texture2D = _paper_texture("furjat_toggle_on.png")
	var toggle_off: Texture2D = _paper_texture("furjat_toggle_off.png")
	if toggle_on != null and toggle_off != null:
		for icon_name: String in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
			t.set_icon(icon_name, "CheckButton", toggle_on)
		for icon_name: String in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
			t.set_icon(icon_name, "CheckButton", toggle_off)

	var track: Texture2D = _paper_texture("slider_sadu_track.png")
	if track != null:
		var track_box := StyleBoxTexture.new()
		track_box.texture = track
		track_box.texture_margin_left = 12.0
		track_box.texture_margin_right = 12.0
		track_box.texture_margin_top = 2.0
		track_box.texture_margin_bottom = 2.0
		track_box.content_margin_top = 6.0
		track_box.content_margin_bottom = 6.0
		t.set_stylebox("slider", "HSlider", track_box)
		t.set_stylebox("grabber_area", "HSlider", empty)
		t.set_stylebox("grabber_area_highlight", "HSlider", empty)
	var knob: Texture2D = _paper_texture("slider_ember_knob.png")
	if knob != null:
		t.set_icon("grabber", "HSlider", knob)
		t.set_icon("grabber_highlight", "HSlider", knob)

	var rule := StyleBoxLine.new()
	rule.color = UITokens.INK_RULE
	rule.thickness = 2
	t.set_stylebox("separator", "HSeparator", rule)
	t.set_constant("separation", "HSeparator", 12)
	return t
