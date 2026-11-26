class_name M1RoomController
extends "res://scripts/systems/room_base.gd"
## Room controller for Milestone 1 vertical slice rooms.
## Configures ambient music mood, safely applies painterly canvas and desert wind shaders
## when present on disk, and synchronizes 2054/2034 Time Shift room containers.

const PAINTERLY_CANVAS_SHADER_PATH: String = "res://assets/placeholder/shaders/painterly_canvas.gdshader"
const SAND_WIND_SHADER_PATH: String = "res://assets/placeholder/shaders/sand_wind.gdshader"

@export var music_mood: String = "desert"
@export var apply_painterly_shader: bool = true
@export var atmosphere_tint: Color = Color("#E07A3C")
@export var shadow_tint: Color = Color("#161B33")
@export var tint_strength: float = 0.18
@export var enable_sand_wind: bool = true
@export var sand_wind_density: float = 0.24
@export var sand_wind_speed: float = 0.42


func _ready() -> void:
	super._ready()
	_apply_room_shaders()
	apply_era(GameState.current_era)
	if not EventBus.era_changed.is_connected(_on_era_changed):
		EventBus.era_changed.connect(_on_era_changed)
	AudioManager.set_music_mood(music_mood)


func _exit_tree() -> void:
	if EventBus.era_changed.is_connected(_on_era_changed):
		EventBus.era_changed.disconnect(_on_era_changed)


func _on_era_changed(era: String) -> void:
	apply_era(era)


func _apply_room_shaders() -> void:
	var parallax: ParallaxBackground = get_node_or_null("ParallaxBackground") as ParallaxBackground
	if parallax == null:
		return

	if apply_painterly_shader and ResourceLoader.exists(PAINTERLY_CANVAS_SHADER_PATH):
		var canvas_shader: Shader = load(PAINTERLY_CANVAS_SHADER_PATH) as Shader
		if canvas_shader != null:
			var canvas_mat: ShaderMaterial = ShaderMaterial.new()
			canvas_mat.shader = canvas_shader
			canvas_mat.set_shader_parameter("atmosphere_tint", atmosphere_tint)
			canvas_mat.set_shader_parameter("shadow_tint", shadow_tint)
			canvas_mat.set_shader_parameter("tint_strength", tint_strength)
			for layer_child: Node in parallax.get_children():
				if layer_child is ParallaxLayer and layer_child.name != "WindLayer":
					for visual_child: Node in layer_child.get_children():
						if visual_child is CanvasItem and (visual_child as CanvasItem).material == null:
							(visual_child as CanvasItem).material = canvas_mat

	if enable_sand_wind and ResourceLoader.exists(SAND_WIND_SHADER_PATH):
		var wind_rect: ColorRect = parallax.get_node_or_null("WindLayer/SandWindOverlay") as ColorRect
		if wind_rect != null:
			var wind_shader: Shader = load(SAND_WIND_SHADER_PATH) as Shader
			if wind_shader != null:
				var wind_mat: ShaderMaterial = ShaderMaterial.new()
				wind_mat.shader = wind_shader
				wind_mat.set_shader_parameter("density", sand_wind_density)
				wind_mat.set_shader_parameter("wind_speed", sand_wind_speed)
				wind_rect.material = wind_mat
