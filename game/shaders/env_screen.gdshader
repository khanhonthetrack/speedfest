shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Animated screens: billboards, gantry panels, stadium jumbotrons.
// UV = 0..1 across the panel. UV2.x = program, UV2.y = seed. COLOR = theme color.
// 1 info panel (dark gradient), 2 scrolling chevrons, 3 equalizer bars, 4 sweeping gradient/scanlines,
// 5 jumbotron (speed lines + pulse ring).

uniform float energy = 2.0;
varying float prog;
varying float seed;

float h11(float x) { return fract(sin(x * 91.3458) * 47453.5453); }

void vertex() {
#if defined(RT)
	prog = 4.0;   // UV2 reads as UV under the path tracer: show the sweeping gradient everywhere
	seed = 0.0;
#else
	prog = UV2.x;
	seed = UV2.y;
#endif
}

void fragment() {
	vec2 uv = UV;
	vec3 base = COLOR.rgb;
	vec3 col;
	float t = TIME + seed * 37.0;
	// panel border
	float border = step(0.02, uv.x) * step(uv.x, 0.98) * step(0.04, uv.y) * step(uv.y, 0.96);
	if (prog < 1.5) {
		col = mix(vec3(0.01, 0.03, 0.12), vec3(0.02, 0.08, 0.3), uv.y) * 1.2;
	} else if (prog < 2.5) {
		float c = fract((uv.x * 3.0 - abs(uv.y - 0.5) * 2.0) - t * 0.6);
		float chev = smoothstep(0.45, 0.5, c) * (1.0 - smoothstep(0.75, 0.8, c));
		col = mix(base * 0.08, base, chev * 0.8) + vec3(0.03);
	} else if (prog < 3.5) {
		float bars = 16.0;
		float bi = floor(uv.x * bars);
		float hgt = 0.25 + 0.6 * abs(sin(t * (1.3 + h11(bi + seed) * 2.0) + bi));
		float on = step(1.0 - uv.y, hgt) * step(0.15, fract(uv.x * bars));
		col = mix(base * 0.06, mix(base, vec3(1.0), 1.0 - uv.y) , on);
	} else if (prog < 4.5) {
		float g = 0.5 + 0.5 * sin(uv.x * 4.0 - t * 1.2 + uv.y * 2.0);
		vec3 c2 = vec3(base.b, base.r, base.g);
		col = mix(base, c2, g) * (0.55 + 0.45 * step(0.5, fract(uv.y * 60.0)));
		col *= 0.6;
	} else {
		vec2 p = (uv - 0.5) * vec2(1.8, 1.0);
		float r = length(p);
		float ring = smoothstep(0.03, 0.0, abs(r - fract(t * 0.4) * 0.9));
		float lines = step(0.92, fract(atan(p.y, p.x) * 6.0 + t * 0.5)) * smoothstep(0.1, 0.6, r);
		col = base * 0.12 + base * ring * 1.5 + vec3(1.0) * lines * 0.35;
		col += mix(vec3(0.0), base, 0.3 * (0.5 + 0.5 * sin(t * 2.0)));
	}
	// subtle LED pixel grid
	vec2 px = fract(uv * vec2(160.0, 90.0));
	col *= 0.75 + 0.25 * step(0.2, px.x) * step(0.2, px.y);
#if defined(RT)
	ALBEDO = vec3(0.01) * (1.0 - border);
	EMISSION = col * energy * border;
#else
	ALBEDO = col * energy * border + vec3(0.01) * (1.0 - border);
#endif
}
