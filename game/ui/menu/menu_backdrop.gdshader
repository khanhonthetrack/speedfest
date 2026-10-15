shader_type canvas_item;
// Menu backdrop: a static, dark graphite gradient with a soft overhead light pool, faint film
// grain and a vignette. No grid and no animation (owner, session 4: "I don't like neon futuristic
// grids ... for menu make it static"). Works on Forward+ and Compatibility.

uniform vec4 tint : source_color = vec4(1.0, 0.17, 0.84, 1.0);
uniform vec4 tint2 : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform float tint_amount = 0.06;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float aspect = (1.0 / SCREEN_PIXEL_SIZE.x) / (1.0 / SCREEN_PIXEL_SIZE.y);
	vec3 top = vec3(0.075, 0.08, 0.095);
	vec3 bottom = vec3(0.025, 0.028, 0.036);
	vec3 col = mix(top, bottom, smoothstep(0.0, 1.0, uv.y));
	// soft light pool, upper centre-right, faintly tinted
	vec2 c = vec2((uv.x - 0.62) * aspect, uv.y - 0.18);
	float pool = exp(-dot(c, c) * 2.4);
	col += mix(vec3(0.16, 0.17, 0.19), tint2.rgb * 0.25, tint_amount) * pool;
	// a low, wide floor glow
	float floor_glow = exp(-pow((uv.y - 0.86) * 7.0, 2.0)) * 0.05;
	col += mix(vec3(1.0), tint.rgb, tint_amount * 2.0) * floor_glow;
	// static grain (screen-space, no TIME) and vignette
	col += (hash(floor(FRAGCOORD.xy)) - 0.5) * 0.012;
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 0.85;
	COLOR = vec4(col, 1.0);
}
