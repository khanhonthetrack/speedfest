shader_type spatial;
render_mode cull_back, diffuse_burley;
// A city track's field (TmSkyline.field): paved instead of grass. Concrete slabs (2 m) with dark
// joints, each 32 m cell a lot of its own tone, stains of wear; averaged far off (no shimmer).
// World-space (the field is flat at the map's ground). At night it is wet: darker, with puddles
// that mirror the lights (SSR on Ultra).

global uniform float tm_night;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = wp.xz;
	vec2 fw = fwidth(p);
	float px = max(fw.x, fw.y);
	vec2 lot = floor(p / 32.0);
	vec2 s = p / 2.0;                       // the slabs
	vec2 sf = fract(s);
	vec2 sd = min(sf, 1.0 - sf) * 2.0;      // m to the slab's edge
	float joint = 1.0 - smoothstep(0.03 - px, 0.03 + px, min(sd.x, sd.y));
	float slab = hash(floor(s)) * 0.06;
	float tone = hash(lot) * 0.08;
	float wear = vnoise(p / 7.0) * 0.6 + vnoise(p / 23.0) * 0.4;
	vec3 col = vec3(0.25, 0.248, 0.24) + slab * 0.8 + tone * 0.8 - wear * 0.06;
	col = mix(col, vec3(0.16, 0.16, 0.16), joint * (1.0 - smoothstep(0.08, 0.4, px)));
	float far = smoothstep(0.1, 0.6, px);
	col = mix(col, vec3(0.25, 0.248, 0.24) + 0.05, far * 0.8);
	// wet at night: darker, glossy, puddles where the slabs sag
	float puddle = smoothstep(0.66, 0.74, vnoise(p / 6.5) * 0.7 + vnoise(p / 1.9) * 0.3) * tm_night;
	col *= mix(1.0, 0.7, tm_night) * (1.0 - 0.4 * puddle);
	ALBEDO = col;
	ROUGHNESS = mix(0.88 - wear * 0.1, mix(0.72, 0.12, puddle), tm_night);
	SPECULAR = mix(0.35, mix(0.25, 0.4, puddle), tm_night);
}
