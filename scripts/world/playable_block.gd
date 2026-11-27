@tool
class_name PlayableBlock
extends StaticBody2D
## Painterly handcrafted gameplay terrain block for SHAALA (شعلة).
## Replaces plain flat rectangles with 6 themed Riyadh / Najdi surface styles:
##   - "sand_dune_ground"
##   - "collapsed_building"
##   - "najdi_mudbrick_ruin"
##   - "broken_highway_deck"
##   - "abandoned_car_platform"
##   - "cracked_glass_bridge"
## Every polygon drawn is strictly convex/simple (zero triangulation errors).

const WORLD_LAYER: int = 1
const ONE_WAY_LAYER: int = 2

@export_enum(
	"sand_dune_ground",
	"collapsed_building",
	"najdi_mudbrick_ruin",
	"broken_highway_deck",
	"abandoned_car_platform",
	"cracked_glass_bridge"
) var block_style: String = "sand_dune_ground":
	set(value):
		block_style = value
		if is_node_ready():
			queue_redraw()

@export var block_size: Vector2 = Vector2(256.0, 64.0):
	set(value):
		block_size = Vector2(maxf(24.0, value.x), maxf(16.0, value.y))
		if is_node_ready():
			_apply_geometry()
			queue_redraw()

@export var one_way: bool = false:
	set(value):
		one_way = value
		if is_node_ready():
			_apply_geometry()
			queue_redraw()

@export var tilt_degrees: float = 0.0:
	set(value):
		tilt_degrees = value
		rotation_degrees = tilt_degrees
		if is_node_ready():
			queue_redraw()

@onready var _collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	if not is_in_group("playable_blocks"):
		add_to_group("playable_blocks")
	_apply_geometry()
	queue_redraw()


func configure(style: String, size: Vector2, is_one_way: bool = false, angle_deg: float = 0.0) -> void:
	block_style = style
	block_size = Vector2(maxf(24.0, size.x), maxf(16.0, size.y))
	one_way = is_one_way
	tilt_degrees = angle_deg
	rotation_degrees = tilt_degrees
	_apply_geometry()
	queue_redraw()


func get_world_rect() -> Rect2:
	return Rect2(global_position - block_size * 0.5, block_size)


func _apply_geometry() -> void:
	collision_layer = ONE_WAY_LAYER if one_way else WORLD_LAYER
	collision_mask = 0
	rotation_degrees = tilt_degrees
	if _collision_shape == null:
		_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape == null:
		return
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = block_size
	_collision_shape.shape = rect_shape
	_collision_shape.position = Vector2.ZERO
	_collision_shape.one_way_collision = one_way
	_collision_shape.one_way_collision_margin = 8.0


func _make_rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var px: int = int(roundf(global_position.x * 3.0))
	var py: int = int(roundf(global_position.y * 7.0))
	var sx: int = int(roundf(block_size.x))
	var sy: int = int(roundf(block_size.y))
	rng.seed = int(abs(px * 73856093 ^ py * 19349663 ^ sx * 83492791 ^ sy * 2971215073 ^ block_style.hash()))
	return rng


func _draw() -> void:
	var half: Vector2 = block_size * 0.5
	var rect: Rect2 = Rect2(-half, block_size)
	var rng: RandomNumberGenerator = _make_rng()

	match block_style:
		"sand_dune_ground":
			_draw_sand_dune_ground(rect, rng)
		"collapsed_building":
			_draw_collapsed_building(rect, rng)
		"najdi_mudbrick_ruin":
			_draw_najdi_mudbrick_ruin(rect, rng)
		"broken_highway_deck":
			_draw_broken_highway_deck(rect, rng)
		"abandoned_car_platform":
			_draw_abandoned_car_platform(rect, rng)
		"cracked_glass_bridge":
			_draw_cracked_glass_bridge(rect, rng)
		_:
			_draw_sand_dune_ground(rect, rng)


func _draw_sand_dune_ground(rect: Rect2, rng: RandomNumberGenerator) -> void:
	var left: float = rect.position.x
	var right: float = rect.end.x
	var top: float = rect.position.y
	var bottom: float = rect.end.y
	var w: float = rect.size.x
	var h: float = rect.size.y

	# Deep desert-red / twilight earth mass.
	var deep_earth: Color = ShaalaPalette.DESERT_RED.lerp(ShaalaPalette.DEEP_SHADOW, 0.62)
	var mid_earth: Color = ShaalaPalette.DESERT_RED.lerp(ShaalaPalette.SHADE_NAJDI_DARK, 0.45)
	var upper_sand: Color = ShaalaPalette.MUD_BRICK_OCHRE.lerp(ShaalaPalette.DESERT_RED, 0.30)

	draw_rect(rect, deep_earth, true)

	# Layered organic geological desert strata bands.
	var band1_h: float = minf(h * 0.55, 42.0)
	draw_rect(Rect2(left, top, w, band1_h), mid_earth, true)

	var band2_h: float = minf(h * 0.28, 20.0)
	draw_rect(Rect2(left, top, w, band2_h), upper_sand, true)

	# Soft undulating sandstone strata lines across the earthen cross-section.
	var strata_rows: int = clampi(int(h / 36.0), 1, 5)
	for row: int in range(strata_rows):
		var sy: float = top + minf(h - 8.0, 22.0 + float(row) * 32.0)
		var pts: PackedVector2Array = PackedVector2Array()
		var segs: int = clampi(int(w / 48.0), 3, 28)
		for i: int in range(segs + 1):
			var t: float = float(i) / float(segs)
			var sx: float = lerpf(left + 4.0, right - 4.0, t)
			var wave: float = sin(t * TAU * 1.5 + float(row) * 1.9 + rng.randf_range(-0.15, 0.15)) * 3.5
			pts.append(Vector2(sx, clampf(sy + wave, top + 8.0, bottom - 4.0)))
		var strata_col: Color = ShaalaPalette.with_alpha(ShaalaPalette.MUD_BRICK_OCHRE, 0.24) if row % 2 == 0 else ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.34)
		draw_polyline(pts, strata_col, 3.0, true)

	# Embedded sandstone pebbles and buried Najdi mud-brick chips.
	var pebble_count: int = clampi(int(w * h / 4200.0), 4, 34)
	for _i: int in range(pebble_count):
		var px: float = rng.randf_range(left + 12.0, right - 12.0)
		var py: float = rng.randf_range(top + 10.0, bottom - 8.0)
		var pr: float = rng.randf_range(2.5, 6.5)
		if rng.randf() < 0.32 and h > 34.0:
			# Buried mud-brick fragment (simple rotated quad-like rect).
			var bw: float = rng.randf_range(10.0, 18.0)
			var bh: float = rng.randf_range(5.0, 8.0)
			draw_rect(Rect2(px - bw * 0.5, py - bh * 0.5, bw, bh), ShaalaPalette.with_alpha(ShaalaPalette.MUD_BRICK_OCHRE, 0.55), true)
			draw_rect(Rect2(px - bw * 0.5, py - bh * 0.5, bw, 2.0), ShaalaPalette.with_alpha(ShaalaPalette.WARM_SAND_LIGHT, 0.45), true)
		else:
			draw_circle(Vector2(px + 1.0, py + 1.5), pr, ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.40))
			draw_circle(Vector2(px, py), pr, ShaalaPalette.with_alpha(ShaalaPalette.SHADE_NAJDI_DARK, 0.85))
			draw_circle(Vector2(px - pr * 0.25, py - pr * 0.25), pr * 0.45, ShaalaPalette.with_alpha(ShaalaPalette.WARM_SAND_LIGHT, 0.65))

	# Rounded sunlit sand crest along the top edge (strictly convex trapezoidal segments).
	var crest_segs: int = clampi(int(w / 40.0), 4, 36)
	var step_w: float = w / float(crest_segs)
	for i: int in range(crest_segs):
		var x0: float = left + float(i) * step_w
		var x1: float = x0 + step_w
		var bump0: float = 0.0 if i == 0 else sin(float(i) * 0.9 + left * 0.02) * 2.2
		var bump1: float = 0.0 if i == crest_segs - 1 else sin(float(i + 1) * 0.9 + left * 0.02) * 2.2
		var poly: PackedVector2Array = PackedVector2Array([
			Vector2(x0, top - maxf(0.0, bump0)),
			Vector2(x1, top - maxf(0.0, bump1)),
			Vector2(x1, top + 9.0),
			Vector2(x0, top + 9.0),
		])
		draw_colored_polygon(poly, ShaalaPalette.SUNSET_ORANGE.lerp(ShaalaPalette.MUD_BRICK_OCHRE, 0.45))

	# Crisp 5px sunlit walkable sand lip right along y = top.
	draw_rect(Rect2(left + 2.0, top, maxf(4.0, w - 4.0), 5.0), ShaalaPalette.WARM_SAND_LIGHT, true)
	draw_line(Vector2(left + 3.0, top + 1.0), Vector2(right - 3.0, top + 1.0), ShaalaPalette.PALE_GOLD_ORB, 1.8, true)

	# Delicate wind-bent desert grass tufts sprouting along the dune crest.
	var tuft_count: int = clampi(int(w / 95.0), 2, 16)
	for _t: int in range(tuft_count):
		var gx: float = rng.randf_range(left + 16.0, right - 16.0)
		var base_pt: Vector2 = Vector2(gx, top + 1.0)
		for b: int in range(3):
			var lean: float = rng.randf_range(-9.0, 12.0) + float(b - 1) * 4.5
			var blade_h: float = rng.randf_range(7.0, 14.0)
			var blade_col: Color = ShaalaPalette.SHADE_NAJDI_DARK if b == 0 else ShaalaPalette.MUD_BRICK_OCHRE
			draw_line(base_pt, base_pt + Vector2(lean, -blade_h), blade_col, 1.8, true)

	# Subtle dark silhouette side and bottom grounding frame.
	draw_line(Vector2(left, top + 3.0), Vector2(left, bottom), ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.7), 2.5, true)
	draw_line(Vector2(right, top + 3.0), Vector2(right, bottom), ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.7), 2.5, true)
	draw_line(Vector2(left, bottom), Vector2(right, bottom), ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.85), 3.0, true)


func _draw_collapsed_building(rect: Rect2, rng: RandomNumberGenerator) -> void:
	var left: float = rect.position.x
	var right: float = rect.end.x
	var top: float = rect.position.y
	var bottom: float = rect.end.y
	var w: float = rect.size.x
	var h: float = rect.size.y

	var concrete_dark: Color = ShaalaPalette.NIGHT_INDIGO
	var concrete_mid: Color = ShaalaPalette.NIGHT_INDIGO.lerp(ShaalaPalette.GLASS_TEAL, 0.30)
	var concrete_light: Color = ShaalaPalette.GLASS_TEAL.lerp(ShaalaPalette.WARM_SAND_LIGHT, 0.25)

	# Core shattered concrete slab.
	draw_rect(rect, concrete_dark, true)
	draw_rect(Rect2(left + 3.0, top + 5.0, maxf(4.0, w - 6.0), maxf(4.0, h - 10.0)), concrete_mid, true)

	# Recessed shattered glass-teal window bays & mullions when slab is tall enough.
	if h >= 38.0 and w >= 72.0:
		var bay_w: float = 40.0
		var gap: float = 12.0
		var bay_count: int = maxi(1, int((w - 24.0) / (bay_w + gap)))
		var total_w: float = float(bay_count) * bay_w + float(bay_count - 1) * gap
		var start_x: float = left + (w - total_w) * 0.5
		var bay_h: float = clampf(h - 22.0, 14.0, 48.0)
		var bay_y: float = top + 12.0

		for i: int in range(bay_count):
			var bx: float = start_x + float(i) * (bay_w + gap)
			var bay_rect: Rect2 = Rect2(bx, bay_y, bay_w, bay_h)
			draw_rect(bay_rect, ShaalaPalette.DEEP_SHADOW, true)
			# Broken glass-teal pane triangle (strictly convex 3-vertex polygon).
			if rng.randf() < 0.78:
				var shard_h: float = bay_h * rng.randf_range(0.45, 0.92)
				var shard: PackedVector2Array = PackedVector2Array([
					Vector2(bx + 2.0, bay_y + 2.0),
					Vector2(bx + bay_w - 2.0, bay_y + 2.0),
					Vector2(bx + bay_w * rng.randf_range(0.25, 0.85), bay_y + shard_h),
				])
				draw_colored_polygon(shard, ShaalaPalette.with_alpha(ShaalaPalette.GLASS_TEAL, 0.55))
				# Pale gold dust-light reflection streak on glass.
				draw_line(
					Vector2(bx + 5.0, bay_y + 5.0),
					Vector2(bx + bay_w * 0.55, bay_y + shard_h * 0.55),
					ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, 0.35),
					1.5,
					true
				)
			# Vertical mullion bar.
			draw_line(Vector2(bx + bay_w * 0.5, bay_y), Vector2(bx + bay_w * 0.5, bay_y + bay_h), concrete_dark, 2.5, true)
			draw_rect(bay_rect, ShaalaPalette.with_alpha(ShaalaPalette.GLASS_TEAL, 0.45), false, 1.5)

	# Structural fracture cracks across concrete face.
	var crack_count: int = clampi(int(w / 80.0), 2, 10)
	for _c: int in range(crack_count):
		var cx: float = rng.randf_range(left + 16.0, right - 16.0)
		var cy: float = top + 5.0
		var c_pts: PackedVector2Array = PackedVector2Array([Vector2(cx, cy)])
		var steps: int = rng.randi_range(2, 4)
		for _s: int in range(steps):
			cx = clampf(cx + rng.randf_range(-16.0, 16.0), left + 4.0, right - 4.0)
			cy = minf(bottom - 4.0, cy + rng.randf_range(8.0, maxf(10.0, h * 0.35)))
			c_pts.append(Vector2(cx, cy))
		draw_polyline(c_pts, ShaalaPalette.DEEP_SHADOW, 2.0, true)

	# Exposed rusted rebar rods poking cleanly from broken left/right slab edges.
	var rebar_per_side: int = clampi(int(h / 24.0), 1, 4)
	var rebar_col: Color = ShaalaPalette.SHADE_NAJDI_DARK.lerp(ShaalaPalette.DESERT_RED, 0.45)
	for r: int in range(rebar_per_side):
		var ry: float = lerpf(top + 10.0, bottom - 8.0, (float(r) + 0.5) / float(rebar_per_side))
		var left_len: float = rng.randf_range(10.0, 22.0)
		var right_len: float = rng.randf_range(10.0, 22.0)
		draw_line(Vector2(left + 3.0, ry), Vector2(left - left_len, ry + rng.randf_range(-4.0, 5.0)), rebar_col, 2.2, true)
		draw_line(Vector2(right - 3.0, ry), Vector2(right + right_len, ry + rng.randf_range(-4.0, 5.0)), rebar_col, 2.2, true)

	# Rubble chips resting along bottom underside.
	var rubble_count: int = clampi(int(w / 70.0), 2, 10)
	for _rb: int in range(rubble_count):
		var rx: float = rng.randf_range(left + 12.0, right - 12.0)
		var rw: float = rng.randf_range(8.0, 18.0)
		var rh: float = rng.randf_range(4.0, 8.0)
		draw_rect(Rect2(rx - rw * 0.5, bottom - rh, rw, rh), ShaalaPalette.DEEP_SHADOW, true)

	# Crisp 5px sunlit concrete + wind-blown ochre dust walkable lip.
	draw_rect(Rect2(left, top, w, 5.5), concrete_light, true)
	draw_line(Vector2(left + 2.0, top + 1.2), Vector2(right - 2.0, top + 1.2), ShaalaPalette.WARM_SAND_LIGHT, 2.0, true)
	# Scattered ochre sand patches settled on top of the fallen building slab.
	var patch_count: int = clampi(int(w / 110.0), 1, 8)
	for _p: int in range(patch_count):
		var px: float = rng.randf_range(left + 10.0, right - 44.0)
		var pw: float = minf(right - px - 6.0, rng.randf_range(24.0, 56.0))
		draw_rect(Rect2(px, top, pw, 4.0), ShaalaPalette.with_alpha(ShaalaPalette.MUD_BRICK_OCHRE, 0.72), true)

	draw_rect(rect, ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.8), false, 2.0)


func _draw_najdi_mudbrick_ruin(rect: Rect2, rng: RandomNumberGenerator) -> void:
	var left: float = rect.position.x
	var right: float = rect.end.x
	var top: float = rect.position.y
	var bottom: float = rect.end.y
	var w: float = rect.size.x
	var h: float = rect.size.y

	var adobe_base: Color = ShaalaPalette.MUD_BRICK_OCHRE.lerp(ShaalaPalette.SHADE_NAJDI_DARK, 0.35)
	var adobe_dark: Color = ShaalaPalette.SHADE_NAJDI_DARK.lerp(ShaalaPalette.DEEP_SHADOW, 0.40)

	draw_rect(rect, adobe_base, true)
	# Deeper lower shadow wash for grounded masonry weight.
	draw_rect(Rect2(left, bottom - minf(h * 0.35, 28.0), w, minf(h * 0.35, 28.0)), ShaalaPalette.with_alpha(adobe_dark, 0.55), true)

	# Subtle staggered Najdi mud-brick masonry courses.
	var course_h: float = 16.0
	var rows: int = maxi(1, int((h - 8.0) / course_h))
	for row: int in range(rows):
		var cy: float = top + 8.0 + float(row) * course_h
		if cy >= bottom - 4.0:
			break
		draw_line(Vector2(left + 3.0, cy), Vector2(right - 3.0, cy), ShaalaPalette.with_alpha(adobe_dark, 0.45), 1.4, true)
		var offset: float = 20.0 if row % 2 == 1 else 0.0
		var bx: float = left + 24.0 + offset
		while bx < right - 12.0:
			var y_end: float = minf(bottom - 2.0, cy + course_h)
			draw_line(Vector2(bx, cy), Vector2(bx, y_end), ShaalaPalette.with_alpha(adobe_dark, 0.38), 1.3, true)
			if rng.randf() < 0.25:
				draw_rect(
					Rect2(bx + 2.0, cy + 2.0, minf(34.0, right - bx - 4.0), maxf(2.0, y_end - cy - 4.0)),
					ShaalaPalette.with_alpha(ShaalaPalette.NAJDI_PLASTER_HIGHLIGHT, 0.22),
					true
				)
			bx += rng.randf_range(36.0, 54.0)

	# Traditional stepped Najdi shurfat (crenellation) trim frieze inset near the upper lip.
	var frieze_y: float = top + 12.0
	if h >= 28.0:
		var tri_step: float = 22.0
		var tx: float = left + 14.0
		while tx + 14.0 < right - 10.0:
			var tri: PackedVector2Array = PackedVector2Array([
				Vector2(tx, frieze_y),
				Vector2(tx + 7.0, frieze_y - 6.0),
				Vector2(tx + 14.0, frieze_y),
			])
			draw_colored_polygon(tri, ShaalaPalette.with_alpha(ShaalaPalette.NAJDI_PLASTER_HIGHLIGHT, 0.45))
			tx += tri_step

	# Recessed triangular Najdi ventilation slits (furjat) in rhythmic trios.
	if h >= 44.0 and w >= 72.0:
		var group_spacing: float = 112.0
		var gx: float = left + 44.0
		while gx < right - 40.0:
			var fy: float = top + minf(h * 0.56, 36.0)
			for t_idx: int in range(-1, 2):
				var cx: float = gx + float(t_idx) * 14.0
				var furja: PackedVector2Array = PackedVector2Array([
					Vector2(cx - 5.0, fy + 6.0),
					Vector2(cx, fy - 5.0),
					Vector2(cx + 5.0, fy + 6.0),
				])
				draw_colored_polygon(furja, ShaalaPalette.DEEP_SHADOW)
				draw_line(Vector2(cx - 5.0, fy + 6.5), Vector2(cx + 5.0, fy + 6.5), ShaalaPalette.WARM_SAND_LIGHT, 1.3, true)
			gx += group_spacing

	# Tamarisk wooden roof-beam stubs (athl) beneath the upper parapet.
	if h >= 34.0 and w >= 80.0:
		var beam_x: float = left + 26.0
		var beam_y: float = top + 16.0
		while beam_x < right - 22.0:
			draw_circle(Vector2(beam_x + 1.0, beam_y + 1.5), 4.0, ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.65))
			draw_circle(Vector2(beam_x, beam_y), 3.6, ShaalaPalette.CAMEL_OCHRE_SHADOW)
			draw_circle(Vector2(beam_x - 1.0, beam_y - 1.0), 1.4, ShaalaPalette.MUD_BRICK_OCHRE)
			beam_x += 64.0

	# Hairline mud-plaster weathering cracks.
	var crack_n: int = clampi(int(w / 100.0), 1, 8)
	for _k: int in range(crack_n):
		var px: float = rng.randf_range(left + 16.0, right - 16.0)
		var py: float = rng.randf_range(top + 10.0, bottom - 10.0)
		draw_polyline(
			PackedVector2Array([
				Vector2(px, py),
				Vector2(px + rng.randf_range(-9.0, 9.0), minf(bottom - 3.0, py + 9.0)),
				Vector2(px + rng.randf_range(-14.0, 14.0), minf(bottom - 2.0, py + 17.0)),
			]),
			ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.5),
			1.4,
			true
		)

	# Crisp 5px sunlit Najdi ochre plaster walkable lip.
	draw_rect(Rect2(left, top, w, 5.5), ShaalaPalette.NAJDI_PLASTER_HIGHLIGHT, true)
	draw_line(Vector2(left + 2.0, top + 1.2), Vector2(right - 2.0, top + 1.2), ShaalaPalette.WARM_SAND_LIGHT, 2.0, true)
	draw_rect(rect, ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.72), false, 2.0)


func _draw_broken_highway_deck(rect: Rect2, rng: RandomNumberGenerator) -> void:
	var left: float = rect.position.x
	var right: float = rect.end.x
	var top: float = rect.position.y
	var bottom: float = rect.end.y
	var w: float = rect.size.x
	var h: float = rect.size.y

	var asphalt_col: Color = ShaalaPalette.NIGHT_INDIGO.lerp(ShaalaPalette.DEEP_SHADOW, 0.32)
	var girder_col: Color = ShaalaPalette.NIGHT_INDIGO.lerp(ShaalaPalette.GLASS_TEAL, 0.22)

	# Upper asphalt layer + lower concrete box-girder deck.
	var asphalt_h: float = clampf(h * 0.36, 10.0, 22.0)
	draw_rect(rect, girder_col, true)
	draw_rect(Rect2(left, top, w, asphalt_h), asphalt_col, true)
	draw_line(Vector2(left, top + asphalt_h), Vector2(right, top + asphalt_h), ShaalaPalette.DEEP_SHADOW, 2.5, true)

	# Structural concrete viaduct ribs underneath the deck.
	if h >= 36.0:
		var rib_x: float = left + 28.0
		while rib_x < right - 24.0:
			draw_rect(Rect2(rib_x, top + asphalt_h + 2.0, 10.0, maxf(4.0, h - asphalt_h - 6.0)), ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.45), true)
			rib_x += 58.0

	# Faded ochre-gold dashed highway lane markings along the upper roadway strip.
	var dash_y: float = top + minf(asphalt_h * 0.55, 11.0)
	var dx: float = left + 16.0
	while dx + 22.0 < right - 12.0:
		var dash_w: float = minf(28.0, right - dx - 12.0)
		draw_rect(Rect2(dx, dash_y, dash_w, 3.0), ShaalaPalette.with_alpha(ShaalaPalette.SADDLE_TRIM_GOLD, 0.62), true)
		dx += 52.0

	# Chipped concrete guardrail stubs rising subtly along the back edge (non-blocking silhouette).
	var post_x: float = left + 22.0
	while post_x < right - 22.0:
		if rng.randf() < 0.72:
			var post_h: float = rng.randf_range(7.0, 12.0)
			draw_rect(Rect2(post_x, top - post_h, 5.0, post_h), ShaalaPalette.with_alpha(ShaalaPalette.GLASS_TEAL, 0.72), true)
		post_x += 74.0

	# Asphalt fracture cracks & exposed rebar at broken deck edges.
	var rebar_col: Color = ShaalaPalette.SHADE_NAJDI_DARK.lerp(ShaalaPalette.DESERT_RED, 0.5)
	draw_line(Vector2(left + 2.0, top + asphalt_h * 0.7), Vector2(left - 14.0, top + asphalt_h * 0.7 + 2.0), rebar_col, 2.0, true)
	draw_line(Vector2(right - 2.0, top + asphalt_h * 0.7), Vector2(right + 14.0, top + asphalt_h * 0.7 - 2.0), rebar_col, 2.0, true)

	var cracks: int = clampi(int(w / 90.0), 2, 10)
	for _c: int in range(cracks):
		var cx: float = rng.randf_range(left + 16.0, right - 16.0)
		draw_polyline(
			PackedVector2Array([
				Vector2(cx, top + 2.0),
				Vector2(cx + rng.randf_range(-10.0, 10.0), top + minf(h - 4.0, 14.0)),
				Vector2(cx + rng.randf_range(-16.0, 16.0), top + minf(h - 2.0, 26.0)),
			]),
			ShaalaPalette.DEEP_SHADOW,
			1.8,
			true
		)

	# Drifted desert-red & ochre sand wedges accumulated at both deck corners.
	var drift_w: float = minf(w * 0.24, 58.0)
	var drift_h: float = minf(h * 0.35, 16.0)
	var left_drift: PackedVector2Array = PackedVector2Array([
		Vector2(left, top + 3.0),
		Vector2(left + drift_w, top + 3.0),
		Vector2(left, top + 3.0 + drift_h),
	])
	var right_drift: PackedVector2Array = PackedVector2Array([
		Vector2(right - drift_w, top + 3.0),
		Vector2(right, top + 3.0),
		Vector2(right, top + 3.0 + drift_h),
	])
	draw_colored_polygon(left_drift, ShaalaPalette.with_alpha(ShaalaPalette.MUD_BRICK_OCHRE, 0.75))
	draw_colored_polygon(right_drift, ShaalaPalette.with_alpha(ShaalaPalette.DESERT_RED, 0.72))

	# Crisp 5px sunlit sandy-asphalt top walkable lip.
	draw_rect(Rect2(left, top, w, 5.0), ShaalaPalette.MUD_BRICK_OCHRE.lerp(ShaalaPalette.GLASS_TEAL, 0.42), true)
	draw_line(Vector2(left + 2.0, top + 1.0), Vector2(right - 2.0, top + 1.0), ShaalaPalette.WARM_SAND_LIGHT, 1.8, true)
	draw_rect(rect, ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.8), false, 2.0)


func _draw_abandoned_car_platform(rect: Rect2, rng: RandomNumberGenerator) -> void:
	var left: float = rect.position.x
	var right: float = rect.end.x
	var top: float = rect.position.y
	var bottom: float = rect.end.y
	var w: float = rect.size.x
	var h: float = rect.size.y

	var is_bus: bool = w >= 260.0
	var rust_body: Color = ShaalaPalette.DESERT_RED.lerp(ShaalaPalette.NIGHT_INDIGO, 0.56)
	var rust_patch: Color = ShaalaPalette.DESERT_RED.lerp(ShaalaPalette.SHADE_NAJDI_DARK, 0.45)
	var roof_highlight: Color = ShaalaPalette.WARM_SAND_LIGHT

	if is_bus:
		# Abandoned Riyadh desert commuter bus with full flat walkable roof at y = top.
		var roof_h: float = 6.0
		var body_top: float = top + roof_h
		var body_h: float = maxf(16.0, h - roof_h)
		draw_rect(Rect2(left + 4.0, body_top, w - 8.0, body_h), rust_body, true)

		# Weathered desert-ochre & crimson livery stripe along lower hull.
		var stripe_y: float = top + h * 0.60
		draw_rect(Rect2(left + 5.0, stripe_y, w - 10.0, maxf(5.0, h * 0.14)), ShaalaPalette.with_alpha(ShaalaPalette.MUD_BRICK_OCHRE, 0.82), true)
		draw_rect(Rect2(left + 5.0, stripe_y + maxf(5.0, h * 0.14), w - 10.0, 3.0), ShaalaPalette.with_alpha(ShaalaPalette.DESERT_RED, 0.85), true)

		# Row of darkened & cracked bus windows.
		var win_y: float = body_top + 6.0
		var win_h: float = clampf(h * 0.34, 10.0, 32.0)
		var win_w: float = 34.0
		var win_gap: float = 8.0
		var wx: float = left + 18.0
		while wx + win_w < right - 16.0:
			draw_rect(Rect2(wx, win_y, win_w, win_h), ShaalaPalette.DEEP_SHADOW, true)
			if rng.randf() < 0.8:
				var glass_tri: PackedVector2Array = PackedVector2Array([
					Vector2(wx + 2.0, win_y + 2.0),
					Vector2(wx + win_w - 2.0, win_y + 2.0),
					Vector2(wx + 2.0, win_y + win_h - 2.0),
				])
				draw_colored_polygon(glass_tri, ShaalaPalette.with_alpha(ShaalaPalette.GLASS_TEAL, 0.45))
			draw_rect(Rect2(wx, win_y, win_w, win_h), ShaalaPalette.NIGHT_INDIGO, false, 1.5)
			wx += win_w + win_gap

		# Half-buried bus tires.
		var wheel_r: float = clampf(h * 0.24, 9.0, 18.0)
		for wheel_x: float in [left + w * 0.22, right - w * 0.22]:
			draw_circle(Vector2(wheel_x, bottom - wheel_r * 0.45), wheel_r, ShaalaPalette.DEEP_SHADOW)
			draw_circle(Vector2(wheel_x, bottom - wheel_r * 0.45), wheel_r * 0.48, ShaalaPalette.GLASS_TEAL)

		# Flat walkable roof deck matching collision top exactly.
		draw_rect(Rect2(left + 2.0, top, w - 4.0, roof_h), ShaalaPalette.MUD_BRICK_OCHRE.lerp(rust_body, 0.35), true)
		draw_line(Vector2(left + 3.0, top + 1.2), Vector2(right - 3.0, top + 1.2), roof_highlight, 2.2, true)
	else:
		# Detailed rusted sedan half-buried in sand, with crisp flat roof aligned at y = top.
		var cabin_inset: float = w * 0.14
		var waist_y: float = top + h * 0.44

		# Lower car chassis (convex trapezoid).
		var chassis: PackedVector2Array = PackedVector2Array([
			Vector2(left + 6.0, waist_y),
			Vector2(right - 6.0, waist_y),
			Vector2(right - 2.0, bottom - 4.0),
			Vector2(left + 2.0, bottom - 4.0),
		])
		draw_colored_polygon(chassis, rust_body)

		# Upper sedan cabin trapezoid rising cleanly to y = top.
		var cabin: PackedVector2Array = PackedVector2Array([
			Vector2(left + cabin_inset, top),
			Vector2(right - cabin_inset, top),
			Vector2(right - cabin_inset * 0.35, waist_y + 2.0),
			Vector2(left + cabin_inset * 0.35, waist_y + 2.0),
		])
		draw_colored_polygon(cabin, rust_body.lerp(ShaalaPalette.NIGHT_INDIGO, 0.22))

		# Cracked glass-teal side windows inside cabin (guarded for very short blocks).
		if waist_y - top > 11.0 and w > 48.0:
			var win_pad: float = 5.0
			var win_poly: PackedVector2Array = PackedVector2Array([
				Vector2(left + cabin_inset + win_pad, top + 5.0),
				Vector2(right - cabin_inset - win_pad, top + 5.0),
				Vector2(right - cabin_inset * 0.50 - win_pad, waist_y - 1.0),
				Vector2(left + cabin_inset * 0.50 + win_pad, waist_y - 1.0),
			])
			draw_colored_polygon(win_poly, ShaalaPalette.DEEP_SHADOW)
			draw_line(
				Vector2(left + w * 0.5, top + 5.0),
				Vector2(left + w * 0.5, waist_y - 1.0),
				rust_body,
				3.0,
				true
			)
			if waist_y - top > 14.0:
				var glint: PackedVector2Array = PackedVector2Array([
					Vector2(left + cabin_inset + win_pad + 2.0, top + 6.0),
					Vector2(left + w * 0.46, top + 6.0),
					Vector2(left + cabin_inset + win_pad + 2.0, waist_y - 3.0),
				])
				draw_colored_polygon(glint, ShaalaPalette.with_alpha(ShaalaPalette.GLASS_TEAL, 0.55))

		# Rust patches & faded amber headlight bezel.
		draw_rect(Rect2(left + 12.0, waist_y + 5.0, w * 0.22, 6.0), ShaalaPalette.with_alpha(rust_patch, 0.78), true)
		draw_rect(Rect2(right - 12.0, waist_y + 4.0, 6.0, 5.0), ShaalaPalette.with_alpha(ShaalaPalette.SUNSET_ORANGE, 0.75), true)

		# Half-buried tires.
		var wheel_r: float = clampf(h * 0.24, 8.0, 15.0)
		for wx: float in [left + w * 0.24, right - w * 0.24]:
			draw_circle(Vector2(wx, bottom - wheel_r * 0.45), wheel_r, ShaalaPalette.DEEP_SHADOW)
			draw_circle(Vector2(wx, bottom - wheel_r * 0.45), wheel_r * 0.45, ShaalaPalette.GLASS_TEAL)

		# Walkable sunlit top surface across full collision width (roof + hood/trunk dust bar).
		draw_rect(Rect2(left + 4.0, top, w - 8.0, 4.5), ShaalaPalette.with_alpha(ShaalaPalette.MUD_BRICK_OCHRE, 0.88), true)
		draw_line(Vector2(left + 6.0, top + 1.0), Vector2(right - 6.0, top + 1.0), roof_highlight, 2.2, true)

	# Drifted desert sand mound banking up around lower undercarriage.
	var sand_h: float = clampf(h * 0.24, 7.0, 18.0)
	var sand_mound: PackedVector2Array = PackedVector2Array([
		Vector2(left - 8.0, bottom),
		Vector2(left + w * 0.16, bottom - sand_h),
		Vector2(right - w * 0.16, bottom - sand_h * 0.75),
		Vector2(right + 8.0, bottom),
	])
	draw_colored_polygon(sand_mound, ShaalaPalette.with_alpha(ShaalaPalette.MUD_BRICK_OCHRE, 0.85))
	draw_line(
		Vector2(left + w * 0.14, bottom - sand_h),
		Vector2(right - w * 0.14, bottom - sand_h * 0.75),
		ShaalaPalette.with_alpha(ShaalaPalette.WARM_SAND_LIGHT, 0.65),
		1.8,
		true
	)


func _draw_cracked_glass_bridge(rect: Rect2, rng: RandomNumberGenerator) -> void:
	var left: float = rect.position.x
	var right: float = rect.end.x
	var top: float = rect.position.y
	var bottom: float = rect.end.y
	var w: float = rect.size.x
	var h: float = rect.size.y

	# Translucent mall skylight glass slab in Glass Teal.
	draw_rect(rect, ShaalaPalette.with_alpha(ShaalaPalette.GLASS_TEAL, 0.56), true)
	draw_rect(Rect2(left, top + h * 0.55, w, h * 0.45), ShaalaPalette.with_alpha(ShaalaPalette.NIGHT_INDIGO, 0.42), true)

	# Architectural steel skylight cross-mullions.
	var bay_step: float = 56.0
	var mx: float = left + bay_step
	while mx < right - 12.0:
		draw_line(Vector2(mx, top + 2.0), Vector2(mx, bottom - 2.0), ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, 0.75), 2.5, true)
		draw_line(Vector2(mx + 2.0, top + 3.0), Vector2(mx + 2.0, bottom - 3.0), ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, 0.22), 1.0, true)
		mx += bay_step

	# Diagonal glass specular sheen panels (convex quads).
	var sheen_count: int = clampi(int(w / 95.0), 1, 8)
	for _s: int in range(sheen_count):
		var sx: float = rng.randf_range(left + 12.0, right - 34.0)
		var sw: float = minf(24.0, right - sx - 8.0)
		var sheen: PackedVector2Array = PackedVector2Array([
			Vector2(sx, top + 4.0),
			Vector2(sx + sw, top + 4.0),
			Vector2(sx + sw - 8.0, bottom - 3.0),
			Vector2(sx - 8.0, bottom - 3.0),
		])
		draw_colored_polygon(sheen, ShaalaPalette.with_alpha(ShaalaPalette.WARM_SAND_LIGHT, 0.18))

	# Glowing pale-gold fracture veins branching across the glass deck.
	var vein_count: int = clampi(int(w / 72.0), 2, 12)
	for _v: int in range(vein_count):
		var vx: float = rng.randf_range(left + 14.0, right - 14.0)
		var vy: float = rng.randf_range(top + 5.0, bottom - 5.0)
		var p1: Vector2 = Vector2(vx, vy)
		var p2: Vector2 = Vector2(clampf(vx + rng.randf_range(-24.0, 24.0), left + 4.0, right - 4.0), top + 3.0)
		var p3: Vector2 = Vector2(clampf(vx + rng.randf_range(-22.0, 22.0), left + 4.0, right - 4.0), bottom - 2.0)
		draw_line(p1, p2, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, 0.72), 1.5, true)
		draw_line(p1, p3, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, 0.55), 1.2, true)

	# Delicate decorative hanging glass shards below the walkway (strictly convex triangles).
	var shard_count: int = clampi(int(w / 54.0), 2, 14)
	for _sh: int in range(shard_count):
		var hx: float = rng.randf_range(left + 10.0, right - 10.0)
		var hw: float = rng.randf_range(4.0, 9.0)
		var hh: float = rng.randf_range(8.0, 20.0)
		var shard: PackedVector2Array = PackedVector2Array([
			Vector2(hx - hw * 0.5, bottom),
			Vector2(hx + hw * 0.5, bottom),
			Vector2(hx + rng.randf_range(-2.0, 2.0), bottom + hh),
		])
		draw_colored_polygon(shard, ShaalaPalette.with_alpha(ShaalaPalette.GLASS_TEAL, 0.58))
		draw_line(shard[0], shard[2], ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, 0.55), 1.0, true)

	# Crisp 5px luminous frosted-teal & pale-gold top walkable lip.
	draw_rect(Rect2(left, top, w, 5.0), ShaalaPalette.GLASS_TEAL.lerp(ShaalaPalette.PALE_GOLD_ORB, 0.45), true)
	draw_line(Vector2(left + 1.0, top + 1.0), Vector2(right - 1.0, top + 1.0), ShaalaPalette.PALE_GOLD_ORB, 2.0, true)
	draw_rect(rect, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, 0.35), false, 1.5)
