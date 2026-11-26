shader_type canvas_item;

// SHAALA (شعلة) — Memory Orb & Shrine Glow Shader (Godot 4.3)
// Renders an ethereal pale-gold pulsing halo, soft luminous core,
// concentric memory ripple, and drifting golden dust motes.
// Best applied to a centered ColorRect (guaranteed 0..1 UVs) or radial Sprite2D.

uniform vec4 core_color : source_color = vec4(1.0, 0.973, 0.863, 1.0);
uniform vec4 halo_color : source_color = vec4(0.965, 0.886, 0.600, 1.0);
uniform vec4 outer_tint : source_color = vec4(0.878, 0.478, 0.235, 1.0);
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 0.4) = 0.12;
uniform float core_radius : hint_range(0.03, 0.4) = 0.15;
uniform float halo_softness : hint_range(0.1, 1.2) = 0.48;
uniform float mote_intensity : hint_range(0.0, 1.5) = 0.7;
uniform float glow_intensity : hint_range(0.0, 2.5) = 1.2;
uniform float burst_amount : hint_range(0.0, 1.0) = 0.0;

varying vec4 v_vertex_color;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float soft_mote(vec2 centered, vec2 pos, float radius) {
	float d = length(centered - pos);
	return 1.0 - smoothstep(0.0, radius, d);
}

void vertex() {
	v_vertex_color = COLOR;
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float angle = atan(centered.y, centered.x);

	// Dual-harmonic organic breathing pulse + optional shrine/orb burst boost.
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount + cos(TIME * pulse_speed * 0.53) * (pulse_amount * 0.45);
	float burst_scale = 1.0 + burst_amount * 0.55;
	float eff_dist = dist / (pulse * burst_scale);

	// Inner white-gold core + mid pale-gold halo + soft sunset outer aura.
	float core = 1.0 - smoothstep(core_radius * 0.18, core_radius * 1.15, eff_dist);
	float mid_halo = exp(-eff_dist * (3.2 / max(halo_softness, 0.1))) * (1.0 - smoothstep(0.05, 0.5, dist));
	float outer_aura = (1.0 - smoothstep(0.08, 0.5, dist)) * (0.28 + 0.12 * sin(angle * 3.0 + TIME * 1.1));

	// Subtle ethereal memory ring expanding gently outward.
	float ring_radius = fract(TIME * 0.22) * 0.42 + 0.08;
	float ring = (1.0 - smoothstep(0.0, 0.025, abs(dist - ring_radius))) * (1.0 - ring_radius * 2.0) * 0.35;

	// Drifting golden memory motes orbiting the sphere.
	float motes = 0.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float orbit_speed = 0.45 + fi * 0.13;
		float orbit_r = 0.18 + 0.16 * hash21(vec2(fi, 3.1));
		float phase = fi * 1.0472 + TIME * orbit_speed * (mod(fi, 2.0) < 0.5 ? 1.0 : -1.0);
		vec2 mote_pos = vec2(cos(phase), sin(phase * 1.15)) * orbit_r;
		mote_pos.y -= sin(TIME * 0.8 + fi) * 0.03;
		float twinkle = 0.55 + 0.45 * sin(TIME * 3.2 + fi * 2.1);
		motes += soft_mote(centered, mote_pos, 0.024 + 0.008 * twinkle) * twinkle;
	}
	motes *= mote_intensity * (1.0 - smoothstep(0.35, 0.5, dist));

	vec3 rgb = mix(outer_tint.rgb, halo_color.rgb, clamp(mid_halo * 1.4, 0.0, 1.0));
	rgb = mix(rgb, core_color.rgb, clamp(core + burst_amount * 0.45, 0.0, 1.0));
	rgb += halo_color.rgb * (ring + motes * 0.85);
	rgb *= glow_intensity * (1.0 + burst_amount * 0.5);

	float alpha = clamp(core + mid_halo * 0.78 + outer_aura * 0.42 + ring + motes, 0.0, 1.0);
	alpha *= (1.0 - smoothstep(0.44, 0.5, dist)) * v_vertex_color.a;

	COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), alpha);
}
