shader_type canvas_item;

// SHAALA (شعلة) — Desert Sand & Wind Veil Shader (Godot 4.3)
// Renders drifting horizontal desert sand ribbons, soft ochre atmospheric haze,
// and wind-blown sand particles for foreground and midground parallax layers.

uniform vec4 sand_color : source_color = vec4(0.910, 0.769, 0.604, 1.0);
uniform vec4 dusk_veil_color : source_color = vec4(0.776, 0.545, 0.349, 1.0);
uniform float wind_speed : hint_range(-4.0, 4.0) = 0.42;
uniform float wind_angle : hint_range(-0.4, 0.4) = -0.06;
uniform float density : hint_range(0.0, 1.0) = 0.26;
uniform float streak_scale : hint_range(1.0, 30.0) = 7.0;
uniform float grain_density : hint_range(0.0, 1.0) = 0.45;
uniform float height_fade : hint_range(0.0, 1.0) = 0.35;

varying vec4 v_vertex_color;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.19);
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
}

void fragment() {
	vec2 uv = UV;
	// Shear coordinates slightly along wind_angle for slanted desert gusts.
	vec2 sheared = vec2(uv.x, uv.y + uv.x * wind_angle);

	// Layer 1: Broad drifting ochre sand veil.
	vec2 veil_coord = vec2(sheared.x * streak_scale * 0.45 - TIME * wind_speed * 0.55, sheared.y * streak_scale * 1.4);
	float veil = value_noise(veil_coord);

	// Layer 2: Faster, thinner wind-whipped sand streaks.
	vec2 streak_coord = vec2(sheared.x * streak_scale * 1.1 - TIME * wind_speed * 1.35, sheared.y * streak_scale * 5.2 + sin(sheared.x * 5.0 + TIME * 0.7) * 0.25);
	float streak = smoothstep(0.42, 0.88, value_noise(streak_coord));

	// Layer 3: Fine fast-moving sand flecks.
	vec2 fleck_coord = vec2(sheared.x * 46.0 - TIME * wind_speed * 14.0, sheared.y * 28.0);
	float fleck_cell = hash21(floor(fleck_coord));
	vec2 fleck_f = fract(fleck_coord) - vec2(0.5);
	float fleck_shape = 1.0 - smoothstep(0.06, 0.32, length(fleck_f * vec2(0.55, 1.4)));
	float flecks = step(1.0 - grain_density * 0.14, fleck_cell) * fleck_shape;

	// Concentrate slightly heavier near the lower desert floor while fading cleanly near sky top.
	float vertical_mask = mix(1.0, smoothstep(0.0, 0.85, uv.y), height_fade);

	float combined = (veil * 0.42 + streak * 0.48 + flecks * 0.65) * vertical_mask;
	vec3 rgb = mix(dusk_veil_color.rgb, sand_color.rgb, clamp(streak * 0.75 + flecks, 0.0, 1.0));
	float alpha = clamp(combined * density, 0.0, 0.85) * v_vertex_color.a;

	COLOR = vec4(rgb * v_vertex_color.rgb, alpha);
}
