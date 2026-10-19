shader_type spatial;
// Flat ground: city pavement (wet), or (style 1) the arena's stadium lawn. UV = world XZ.

uniform vec4 base_color : source_color = vec4(0.06, 0.06, 0.08, 1.0);
uniform vec4 grid_color : source_color = vec4(0.35, 0.1, 1.0, 1.0);
uniform float grid_energy = 1.5;
uniform float wetness = 0.3;
uniform float tile = 20.0;
uniform int style = 0;          // 0 pavement, 1 stadium lawn (no grid)
uniform float lawn_brightness = 1.0;

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
	vec2 p = UV;
	if (style == 1) {
		float n = vnoise(p * 0.035) * 0.6 + vnoise(p * 0.12) * 0.4;
		float sx = fract(p.x / 24.0);
		float stripe = smoothstep(0.48, 0.52, sx) * (1.0 - smoothstep(0.98, 1.0, sx));
		vec3 c = mix(vec3(0.055, 0.15, 0.045), vec3(0.085, 0.2, 0.065), stripe) * (0.82 + 0.3 * n);
		float fwl = max(fwidth(p.x), fwidth(p.y));
		float blades = vnoise(p * 6.0) * 0.5 + vnoise(p * 17.0) * 0.5;
		c *= 1.0 + (blades - 0.5) * 0.35 * (1.0 - clamp(fwl * 4.0, 0.0, 1.0));
		ALBEDO = c * lawn_brightness;
		ROUGHNESS = 0.88;
	} else {
		vec2 g = abs(fract(p / tile - 0.5) - 0.5) * tile;
		vec2 fw = max(fwidth(p), vec2(0.001));
		float line = 1.0 - smoothstep(0.0, fw.x * 1.2 + 0.03, min(g.x, g.y));
		float n = vnoise(p * 0.15) * 0.6 + vnoise(p * 1.3) * 0.4;
		vec3 col = base_color.rgb * (0.8 + 0.4 * n);
		float slab = 1.0 - smoothstep(0.0, fw.x * 1.5 + 0.04, min(g.x, g.y));
		col *= 1.0 - 0.35 * slab;
		float puddle = smoothstep(0.55, 0.75, vnoise(p * 0.11) * 0.7 + vnoise(p * 0.5) * 0.3);
		float wet = wetness * (0.75 + 0.25 * puddle);
		ALBEDO = col * (1.0 - 0.25 * wet);
		ROUGHNESS = mix(0.85, 0.18, wet) - 0.1 * puddle * wetness;
		float fade = 1.0 - smoothstep(60.0, 420.0, length(VERTEX));
		EMISSION = grid_color.rgb * line * grid_energy * fade;
	}
}
