shader_type canvas_item;
// Radial speed streaks toward the screen edges (HUD overlay, quality >= High).
// Cheap: a handful of ALU ops per pixel, no textures. Works on Compatibility.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.75, 0.95, 1.0, 1.0);
uniform float aspect = 1.7778;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float lanes = 150.0;
	float lane = floor((a / 6.2831853 + 0.5) * lanes);
	float h = hash(lane);
	float h2 = hash(lane + 31.7);
	// Streak travels outward; each lane has its own speed and phase.
	float speed = 1.6 + 2.4 * h2;
	float phase = fract(h * 7.0 - TIME * speed);
	float pos = r * 1.15 - phase;
	float streak = smoothstep(0.0, 0.03, pos) * (1.0 - smoothstep(0.03, 0.22 + 0.2 * h, pos));
	// Thin lines: fade toward the lane edges.
	float across = fract((a / 6.2831853 + 0.5) * lanes);
	streak *= 1.0 - smoothstep(0.08, 0.4, abs(across - 0.5));
	// Only some lanes are active; more with intensity.
	streak *= step(h2, 0.25 + 0.6 * intensity);
	// Keep the center clear, strongest near the edges.
	float mask = smoothstep(0.32, 0.85, r);
	float alpha = streak * mask * intensity * 0.55;
	// A soft edge vignette that grows with speed.
	float vig = smoothstep(0.55, 1.05, r) * intensity * 0.35;
	COLOR = vec4(tint.rgb, clamp(alpha, 0.0, 1.0));
	COLOR = mix(COLOR, vec4(0.0, 0.02, 0.06, 1.0), vig * (1.0 - COLOR.a));
	COLOR.a = max(COLOR.a, vig);
}
