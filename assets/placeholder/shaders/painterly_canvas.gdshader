shader_type canvas_item;

// SHAALA (شعلة) — Painterly Canvas Shader (Godot 4.3)
// Adds subtle woven canvas grain, organic brushstroke UV warp,
// and soft dusk/indigo atmospheric grading for multi-layer parallax backdrops.
// Works on both Sprite2D textures and untextured Polygon2D / ColorRect surfaces.

uniform vec4 atmosphere_tint : source_color = vec4(0.878, 0.478, 0.235, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.086, 0.106, 0.200, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.20;
uniform float grain_strength : hint_range(0.0, 0.25) = 0.055;
uniform float grain_scale : hint_range(2.0, 64.0) = 20.0;
uniform float warp_amount : hint_range(0.0, 0.03) = 0.0035;
uniform float brush_scale : hint_range(1.0, 32.0) = 9.0;
uniform float time_speed : hint_range(0.0, 2.0) = 0.12;

varying vec4 v_vertex_color;
varying vec2 v_local_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	v_vertex_color = COLOR;
	v_local_pos = VERTEX;
}

void fragment() {
	// Combine local coordinates with UV so untextured polygons and textured sprites
	// both display coherent brushstroke and linen texture.
	vec2 paint_coord = v_local_pos * 0.015 + UV * brush_scale;
	float t = TIME * time_speed;

	float stroke_x = value_noise(paint_coord + vec2(t, 0.0)) - 0.5;
	float stroke_y = value_noise(paint_coord * 1.37 + vec2(17.3, -t * 0.7)) - 0.5;
	vec2 warped_uv = clamp(UV + vec2(stroke_x, stroke_y) * warp_amount, vec2(0.0), vec2(1.0));

	vec4 base = texture(TEXTURE, warped_uv) * v_vertex_color;

	// Subtle horizontal gouache brushstroke banding + fine linen canvas tooth.
	float brush_band = value_noise(vec2(paint_coord.x * 0.6, paint_coord.y * 2.4));
	float weave_x = sin(v_local_pos.x * 0.85 + UV.x * grain_scale * 6.28318);
	float weave_y = sin(v_local_pos.y * 0.85 + UV.y * grain_scale * 6.28318);
	float canvas_tooth = (weave_x * weave_y) * 0.35 + (value_noise(v_local_pos * 0.12 + UV * grain_scale) - 0.5);

	vec3 painterly_rgb = base.rgb;
	painterly_rgb += (brush_band - 0.5) * grain_strength * 0.9;
	painterly_rgb += canvas_tooth * grain_strength;

	// Soft dusk/indigo atmospheric luminance blend (preserves silhouette depth).
	float luma = dot(painterly_rgb, vec3(0.299, 0.587, 0.114));
	vec3 atmo = mix(shadow_tint.rgb, atmosphere_tint.rgb, smoothstep(0.12, 0.82, luma));
	painterly_rgb = mix(painterly_rgb, atmo, tint_strength);

	COLOR = vec4(clamp(painterly_rgb, vec3(0.0), vec3(1.0)), base.a);
}
