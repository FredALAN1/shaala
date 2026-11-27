class_name UIRoot
extends CanvasLayer
## Top-level UI coordinator for SHAALA (شعلة).
## Mounts TitleScreen, HUD, VignettePlayer, MinimapOverlay, and PauseSettingsMenu,
## listens to EventBus signals, and refreshes RTL/LTR layout & translations live.

signal new_game_requested
signal continue_game_requested
signal quit_to_title_requested

@onready var root_control: Control = $RootControl
@onready var hud: HUDController = $RootControl/HUD
@onready var title_screen: TitleScreen = $RootControl/TitleScreen
@onready var minimap_overlay: MinimapOverlay = $RootControl/MinimapOverlay
@onready var pause_settings_menu: PauseSettingsMenu = $RootControl/PauseSettingsMenu
@onready var vignette_player: VignettePlayer = $RootControl/VignettePlayer

var _in_gameplay: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10

	_connect_child_signals()
	_connect_event_bus()

	refresh_localization(TranslationServer.get_locale())
	show_title_screen()


func _connect_child_signals() -> void:
	title_screen.new_game_pressed.connect(_on_title_new_game_pressed)
	title_screen.continue_pressed.connect(_on_title_continue_pressed)
	title_screen.settings_pressed.connect(_on_title_settings_pressed)
	title_screen.quit_pressed.connect(_on_title_quit_pressed)

	pause_settings_menu.resume_requested.connect(_on_pause_resume_requested)
	pause_settings_menu.map_requested.connect(_on_pause_map_requested)
	pause_settings_menu.save_and_quit_requested.connect(_on_pause_save_and_quit_requested)
	pause_settings_menu.closed_from_title.connect(_on_settings_closed_from_title)

	minimap_overlay.closed.connect(_on_minimap_closed)
	vignette_player.finished.connect(_on_story_finished)


func _connect_event_bus() -> void:
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.room_loaded.connect(_on_room_loaded)
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.vignette_requested.connect(_on_vignette_requested)
	EventBus.pause_toggled.connect(_on_pause_toggled)
	EventBus.map_toggled.connect(_on_map_toggled)
	EventBus.shrine_rested.connect(_on_shrine_rested)
	EventBus.notebook_page_collected.connect(_on_notebook_page_collected)
	EventBus.boss_defeated.connect(_on_boss_defeated)


func _unhandled_input(event: InputEvent) -> void:
	if not _in_gameplay:
		return
	if vignette_player.is_playing() or pause_settings_menu.is_rebinding():
		if event.is_action_pressed("pause") or event.is_action_pressed("toggle_map"):
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if minimap_overlay.visible:
			minimap_overlay.close_map()
		else:
			EventBus.pause_toggled.emit(not pause_settings_menu.visible)
	elif event.is_action_pressed("toggle_map"):
		get_viewport().set_input_as_handled()
		if not pause_settings_menu.visible:
			EventBus.map_toggled.emit()


func show_title_screen() -> void:
	_in_gameplay = false
	get_tree().paused = false
	hud.visible = false
	minimap_overlay.visible = false
	pause_settings_menu.visible = false
	vignette_player.force_close()
	title_screen.visible = true
	title_screen.refresh_state()
	refresh_localization(TranslationServer.get_locale())


func show_gameplay_ui() -> void:
	show_gameplay_hud()


func hide_title_screen() -> void:
	show_gameplay_hud()


func show_gameplay_hud() -> void:
	_in_gameplay = true
	get_tree().paused = false
	title_screen.visible = false
	minimap_overlay.visible = false
	pause_settings_menu.visible = false
	hud.visible = true
	hud.set_cinematic(vignette_player.is_playing())
	hud.refresh_all()
	refresh_localization(TranslationServer.get_locale())


func refresh_localization(locale: String = "") -> void:
	var active_locale: String = locale if not locale.is_empty() else TranslationServer.get_locale()
	ArabicFontSetup.apply_to_control(root_control, active_locale)
	title_screen.refresh_texts()
	hud.refresh_texts()
	vignette_player.refresh_texts()
	minimap_overlay.refresh_texts()
	pause_settings_menu.refresh_texts()


func _on_locale_changed(locale: String) -> void:
	refresh_localization(locale)


func _on_room_loaded(_room_id: String, _area_id: String, _room_title_key: String) -> void:
	if not _in_gameplay:
		show_gameplay_hud()
	if minimap_overlay.visible:
		minimap_overlay.refresh_map()


func _on_story_finished() -> void:
	hud.set_cinematic(false)


func _on_dialogue_requested(lines: Array) -> void:
	if not _in_gameplay:
		return
	hud.set_cinematic(true)
	vignette_player.play_dialogue(lines)


func _on_vignette_requested(title_key: String, lines: Array, ability_id: String) -> void:
	if not _in_gameplay:
		return
	hud.set_cinematic(true)
	vignette_player.play_vignette(title_key, lines, ability_id)


func _on_pause_toggled(paused: bool) -> void:
	if not _in_gameplay:
		return
	if paused:
		minimap_overlay.visible = false
		get_tree().paused = true
		pause_settings_menu.open_pause()
	else:
		pause_settings_menu.visible = false
		get_tree().paused = false


func _on_map_toggled() -> void:
	if not _in_gameplay or pause_settings_menu.visible or vignette_player.is_playing():
		return
	if minimap_overlay.visible:
		minimap_overlay.close_map()
	else:
		minimap_overlay.open_map()


func _on_shrine_rested(_shrine_id: String, _room_id: String) -> void:
	hud.show_toast("UI_RESTED_AT_SHRINE")


func _on_notebook_page_collected(_page_id: String, _title_key: String, _body_key: String) -> void:
	hud.show_toast("UI_PAGE_FOUND")
	if pause_settings_menu.visible:
		pause_settings_menu.refresh_notebook()


func _on_boss_defeated(boss_id: String) -> void:
	if boss_id == "boss_spire_warden":
		hud.show_toast("UI_DEMO_COMPLETE", 5.5)


func _on_title_new_game_pressed() -> void:
	new_game_requested.emit()


func _on_title_continue_pressed() -> void:
	continue_game_requested.emit()


func _on_title_settings_pressed() -> void:
	title_screen.visible = false
	pause_settings_menu.open_from_title()


func _on_title_quit_pressed() -> void:
	get_tree().quit()


func _on_pause_resume_requested() -> void:
	EventBus.pause_toggled.emit(false)


func _on_pause_map_requested() -> void:
	pause_settings_menu.visible = false
	get_tree().paused = false
	minimap_overlay.open_map()


func _on_pause_save_and_quit_requested() -> void:
	SaveManager.save_game()
	hud.show_toast("UI_SAVED", 1.5)
	pause_settings_menu.visible = false
	get_tree().paused = false
	quit_to_title_requested.emit()
	show_title_screen()


func _on_settings_closed_from_title() -> void:
	pause_settings_menu.visible = false
	title_screen.visible = true
	title_screen.refresh_state()


func _on_minimap_closed() -> void:
	minimap_overlay.visible = false
