shader_type canvas_item;

// SHAALA (شعلة) — Painterly Silhouette Shader (Godot 4.3)
// High-contrast silhouette shading with directional rim light (sunset orange or pale gold),
// gentle hand-inked edge wobble, subtle paper grain, and hit-flash support via `flash_amount`.

uniform vec4 rim_color : source_color = vec4(0.878, 0.478, 0.235, 1.0);
uniform float rim_strength : hint_range(0.0, 1.5) = 0.45;
uniform float rim_width : hint_range(0.5, 8.0) = 2.0;
uniform vec2 light_direction = vec2(0.75, -0.65);
uniform float ink_wobble_px : hint_range(0.0, 4.0) = 0.75;
uniform float ink_wobble_speed : hint_range(0.0, 6.0) = 1.5;
uniform float shadow_depth : hint_range(0.0, 1.0) = 0.22;
uniform float paper_grain : hint_range(0.0, 0.15) = 0.035;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(0.965, 0.886, 0.600, 1.0);

varying vec4 v_vertex_color;
varying vec2 v_local_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void vertex() {
	v_vertex_color = COLOR;
	v_local_pos = VERTEX;

	// Subtle stepped hand-drawn ink boil so silhouettes feel organically painted.
	float step_time = floor(TIME * 6.0 * max(ink_wobble_speed, 0.001));
	float wobble_x = sin(VERTEX.y * 0.14 + step_time * 1.7) * ink_wobble_px;
	float wobble_y = cos(VERTEX.x * 0.14 + step_time * 1.3) * ink_wobble_px * 0.65;
	VERTEX += vec2(wobble_x, wobble_y);
}

void fragment() {
	vec4 tex_sample = texture(TEXTURE, UV);
	vec4 base = tex_sample * v_vertex_color;

	// Detect sprite alpha edge in the incoming light direction for crisp Sprite2D rim light.
	vec2 light_dir = normalize(light_direction + vec2(0.0001, 0.0));
	vec2 offset_uv = light_dir * TEXTURE_PIXEL_SIZE * rim_width;
	float neighbor_alpha = texture(TEXTURE, clamp(UV + offset_uv, vec2(0.0), vec2(1.0))).a;
	float sprite_edge = clamp((tex_sample.a - neighbor_alpha) * 1.6, 0.0, 1.0);

	// Painterly directional tonal gradient so untextured Polygon2D silhouettes also catch rim light.
	vec2 dir_coord = normalize(vec2(v_local_pos.x, v_local_pos.y) + vec2(0.001, -0.001));
	float poly_rim = smoothstep(0.25, 0.95, dot(dir_coord, light_dir)) * 0.35;
	float combined_rim = clamp(max(sprite_edge, poly_rim) * rim_strength, 0.0, 1.0);

	// Deepen interior shadow for iconic high-contrast silhouette readability.
	vec3 indigo_core = vec3(0.051, 0.063, 0.129);
	vec3 shaded = mix(base.rgb, base.rgb * 0.72 + indigo_core * 0.28, shadow_depth);

	// Apply painterly rim highlight and subtle ink/paper texture.
	float grain = (hash21(floor(v_local_pos * 0.65)) - 0.5) * paper_grain;
	shaded = mix(shaded, rim_color.rgb, combined_rim) + vec3(grain);

	// Hit-flash uniform (used by combat & stagger systems).
	shaded = mix(shaded, flash_color.rgb, clamp(flash_amount, 0.0, 1.0));

	COLOR = vec4(clamp(shaded, vec3(0.0), vec3(1.0)), base.a);
}
