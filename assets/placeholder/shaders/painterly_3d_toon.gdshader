shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;

// SHAALA (شعلة) — Painterly 3D Gouache & Twilight Cel Shader (Godot 4.3)
// Renders 3D architectural columns, ledges, and silhouettes in a matte hand-painted
// desert-ruin aesthetic matching ShaalaPalette (warm ochre/sunset light into cool
// night-indigo shadows, subtle canvas/brush grain, and warm Fresnel rim light).

uniform vec4 albedo_color : source_color = vec4(0.776, 0.545, 0.349, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.086, 0.106, 0.200, 1.0);
uniform vec4 rim_color : source_color = vec4(0.878, 0.478, 0.235, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.72;
uniform float grain_strength : hint_range(0.0, 0.35) = 0.085;
uniform float cel_steps : hint_range(2.0, 5.0) = 3.0;
uniform float emission_strength : hint_range(0.0, 3.0) = 0.0;

varying vec3 v_world_pos;

float hash31(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);
	float nxy0 = mix(nx00, nx10, u.y);
	float nxy1 = mix(nx01, nx11, u.y);
	return mix(nxy0, nxy1, u.z);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Tri-planar world-space gouache brushstroke + fine linen canvas tooth.
	float brush = noise3d(v_world_pos * vec3(1.1, 2.4, 1.1));
	float tooth = noise3d(v_world_pos * 9.5);
	float painterly_var = (brush - 0.5) * 0.72 + (tooth - 0.5) * 0.28;

	vec3 base_rgb = clamp(albedo_color.rgb + vec3(painterly_var * grain_strength), vec3(0.0), vec3(1.0));
	ALBEDO = base_rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;

	// Soft twilight Fresnel rim glow so silhouettes pop crisply against dusk sky.
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, 2.7);
	float rim_mask = smoothstep(0.28, 0.85, fresnel);
	EMISSION = rim_color.rgb * rim_mask * rim_strength * 0.42 + albedo_color.rgb * emission_strength;
}

void light() {
	// Stepped warm-to-cool twilight cel shading (no plastic speculars).
	float ndl = dot(NORMAL, LIGHT);
	float half_lambert = clamp(ndl * 0.5 + 0.5, 0.0, 1.0);
	float steps = max(cel_steps, 2.0);
	float stepped = floor(half_lambert * steps) / (steps - 1.0);
	float lit_band = smoothstep(0.18, 0.92, stepped) * clamp(ATTENUATION, 0.0, 1.0);

	vec3 shaded = mix(shadow_color.rgb, ALBEDO, lit_band);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float sun_rim = pow(1.0 - ndv, 3.0) * smoothstep(-0.05, 0.45, ndl) * rim_strength * 0.48;

	DIFFUSE_LIGHT += (shaded * LIGHT_COLOR + rim_color.rgb * sun_rim) * 0.55;
}
