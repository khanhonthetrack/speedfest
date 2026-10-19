shader_type spatial;
// Ground patches lying on the road (session 4): grass, gravel or sand. Grip and drag live in
// res://weather/track_surface.gd; this only draws them. Works on Forward+ and Compatibility.
// UV = meters from the left edge / from the start of the patch, UV2 = meters to the right edge /
// to the end (so the distance to every edge is known per pixel).
// The edges are ragged (alpha scissor), so a patch reads as ground spilling onto the asphalt.

uniform int kind = 1;              // 1 grass, 2 gravel, 3 sand, 4 dirt, 5 ice, 6 plastic
uniform float brightness = 1.0;    // compat night scenes have no fog lift: brighten a little

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 m = UV;                       // meters
	float fw = max(fwidth(m.x), fwidth(m.y));
	float fine = 1.0 - clamp(fw * 3.0, 0.0, 1.0);     // fade fine detail with distance
	// ragged edges: the patch frays out over its outer ~0.8 m
	float edge_m = min(min(UV.x, UV2.x), min(UV.y, UV2.y));
	float rag = vnoise(m * 1.7) * 0.8 + vnoise(m * 5.0) * 0.2;
	ALPHA = step(0.35, clamp(edge_m / 0.8, 0.0, 1.0) * (0.6 + 0.8 * rag));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 col;
	float rough;
	if (kind == 1) {
		// grass: mown stripes along the patch, patchy greens, blade noise
		float stripe = step(0.5, fract(m.y / 8.0));
		float n = vnoise(m * 0.3) * 0.6 + vnoise(m * 1.1) * 0.4;
		col = mix(vec3(0.07, 0.19, 0.05), vec3(0.1, 0.25, 0.07), stripe) * (0.8 + 0.35 * n);
		col *= 1.0 + (vnoise(m * 9.0) - 0.5) * 0.4 * fine;
		col = mix(col, vec3(0.2, 0.17, 0.08), smoothstep(0.72, 0.9, vnoise(m * 0.45 + 7.0)) * 0.5); // worn patches
		rough = 0.9;
	} else if (kind == 2) {
		// gravel: grey-brown stones, speckled, tyre ruts along the patch
		float n = vnoise(m * 0.5);
		float stones = vnoise(m * 6.0) * 0.6 + vnoise(m * 17.0) * 0.4 * fine;
		col = mix(vec3(0.26, 0.24, 0.21), vec3(0.42, 0.39, 0.34), stones) * (0.85 + 0.25 * n);
		float rut = exp(-pow((fract(m.x / 4.2) - 0.5) / 0.12, 2.0)) * 0.25;
		col *= 1.0 - rut;
		rough = 0.95;
	} else if (kind == 4) {
		// dirt: packed red-brown earth, darker tyre-worn racing line, pebbles
		float n = vnoise(m * 0.35) * 0.65 + vnoise(m * 1.6) * 0.35;
		col = vec3(0.36, 0.2, 0.12) * (0.8 + 0.3 * n);
		float line = exp(-pow((fract(m.x / 5.0) - 0.5) / 0.18, 2.0));
		col *= 1.0 - 0.18 * line;
		col *= 1.0 + (vnoise(m * 12.0) - 0.5) * 0.3 * fine;
		rough = 0.9;
	} else if (kind == 5) {
		// ice: pale blue-white, glossy, with cracks and frost
		float n = vnoise(m * 0.2) * 0.6 + vnoise(m * 0.9) * 0.4;
		col = mix(vec3(0.55, 0.7, 0.82), vec3(0.85, 0.92, 0.97), n);
		float crack = smoothstep(0.02, 0.0, abs(vnoise(m * 0.7) - 0.5)) * fine;
		col = mix(col, vec3(0.92, 0.97, 1.0), crack * 0.6);
		rough = 0.08 + 0.2 * vnoise(m * 2.0);
	} else if (kind == 6) {
		// plastic: glossy yellow panels with dark seams
		vec2 g = fract(m / 2.0);
		float seam = max(smoothstep(0.03, 0.0, min(g.x, 1.0 - g.x)), smoothstep(0.03, 0.0, min(g.y, 1.0 - g.y)));
		col = mix(vec3(0.9, 0.72, 0.05), vec3(0.08, 0.07, 0.04), seam * fine);
		rough = 0.25;
	} else {
		// sand: warm beige, wind ripples across, darker damp streaks
		float ripple = sin(m.y * 2.2 + vnoise(m * 0.4) * 6.0) * 0.5 + 0.5;
		float n = vnoise(m * 0.25) * 0.7 + vnoise(m * 1.3) * 0.3;
		col = vec3(0.62, 0.52, 0.36) * (0.86 + 0.18 * n) * (0.95 + 0.07 * ripple * fine);
		col = mix(col, vec3(0.45, 0.37, 0.25), smoothstep(0.6, 0.85, vnoise(m * 0.12 + 3.0)) * 0.6);
		rough = 0.92;
	}
	ALBEDO = col * brightness;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
