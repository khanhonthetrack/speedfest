shader_type canvas_item;
// Menu backdrop: deep navy gradient, a glowing horizon, a scrolling synthwave perspective grid
// and slow diagonal light streaks. Works on Forward+ and Compatibility (no screen textures).

uniform vec4 tint : source_color = vec4(1.0, 0.17, 0.84, 1.0);
uniform vec4 tint2 : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform float horizon = 0.62;
uniform float speed = 0.35;
uniform float grid_strength = 1.0;

float grid_line(float x, float w) {
	float f = abs(fract(x) - 0.5);
	return smoothstep(0.5 - w, 0.5, f);
}

void fragment() {
	vec2 uv = UV;
	float aspect = (1.0 / SCREEN_PIXEL_SIZE.x) / (1.0 / SCREEN_PIXEL_SIZE.y);
	vec3 navy = vec3(0.027, 0.043, 0.102);
	vec3 col = mix(navy * 0.55, navy * 1.6, smoothstep(0.0, horizon, uv.y));
	// horizon glow
	float hd = uv.y - horizon;
	col += tint.rgb * 0.55 * exp(-abs(hd) * 14.0);
	col += tint2.rgb * 0.18 * exp(-abs(hd) * 40.0);
	// floor grid below the horizon
	if (hd > 0.0) {
		float depth = 0.18 / max(hd, 0.002);
		float gx = (uv.x - 0.5) * aspect * depth * 1.6;
		float gz = depth + TIME * speed * 2.0;
		float w = clamp(0.02 * depth, 0.015, 0.45);
		float lines = max(grid_line(gx, w), grid_line(gz, w));
		float fade = smoothstep(0.0, 0.08, hd) * (1.0 - smoothstep(0.25, 0.55, hd) * 0.5);
		col += mix(tint.rgb, tint2.rgb, smoothstep(0.0, 0.4, hd)) * lines * 0.55 * fade * grid_strength;
		col *= 0.85;
	}
	// diagonal streaks
	float s = fract((uv.x * aspect + uv.y * 0.6) * 1.3 - TIME * 0.05);
	col += tint2.rgb * 0.035 * smoothstep(0.985, 1.0, s);
	float s2 = fract((uv.x * aspect * 0.7 - uv.y * 0.4) * 2.1 + TIME * 0.03);
	col += tint.rgb * 0.03 * smoothstep(0.99, 1.0, s2);
	// vignette
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 0.9;
	COLOR = vec4(col, 1.0);
}
