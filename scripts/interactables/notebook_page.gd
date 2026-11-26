class_name NotebookPage
extends InteractableBase
## Torn Notebook Page — collectible journal fragment & map clue toward the True Ending.
## Visually depicts a weathered cream parchment page caught in desert sand/debris
## with subtle wind flutter and a faint warm pale-gold shimmer.

@export var page_id: String = ""
@export var title_key: String = ""
@export var body_key: String = ""

var _time: float = 0.0
var _collected: bool = false

@onready var _page_visual: Node2D = get_node_or_null("PageVisual") as Node2D


func _init() -> void:
	prompt_key = "PROMPT_READ_PAGE"


func _ready() -> void:
	super._ready()
	if page_id != "" and page_id in GameState.collected_pages:
		queue_free()
		return


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta

	if _page_visual != null:
		_page_visual.rotation = deg_to_rad(-8.0 + sin(_time * 3.2) * 5.5 + cos(_time * 5.1) * 1.8)
		_page_visual.position.y = -12.0 + sin(_time * 2.2) * 2.5

	queue_redraw()


func _draw() -> void:
	# Warm pale-gold beacon aura behind the fluttering parchment so it stands out cleanly.
	var glow_alpha: float = 0.18 + 0.09 * sin(_time * 2.6)
	var center: Vector2 = Vector2(0.0, -12.0 + sin(_time * 2.2) * 2.5)
	draw_circle(center, 26.0, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, glow_alpha * 0.5))
	draw_circle(center, 15.0, ShaalaPalette.with_alpha(ShaalaPalette.WARM_SAND_LIGHT, glow_alpha))

	# Small rising ink/gold glint motes.
	for i: int in range(3):
		var phase: float = fmod(_time * 0.38 + float(i) * 0.33, 1.0)
		var mx: float = sin(_time * 2.0 + float(i) * 2.2) * 14.0
		var my: float = lerpf(-2.0, -40.0, phase)
		var ma: float = sin(phase * PI) * 0.65
		draw_circle(Vector2(mx, my), 1.6, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, ma))


func _on_interact(_player: Node) -> void:
	if _collected:
		return
	_collected = true
	set_interaction_enabled(false)

	GameState.collect_page(page_id, title_key, body_key)
	EventBus.dialogue_requested.emit([
		{
			"speaker_key": title_key,
			"text_key": body_key,
		}
	])
	SaveManager.save_game()
	AudioManager.play_sfx("page_collect")
	queue_free()
