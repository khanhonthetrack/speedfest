shader_type spatial;
// The Sky maps' road decks (M19, our own; TmSkyPieces). UV: x across the deck (0 left .. 1 right),
// y metres along it. mag = 1: mag-road (magnetic: it holds the car on walls and upside down),
// dark glass-black with violet chevrons running the way the road goes and hot magenta edges, so a
// driver reads it at a glance; mag = 0: the rooftops' lanes (runway lights, arrows), drawn as
// a thin decal over the roof.

uniform float mag = 1.0;
uniform vec3 base : source_color = vec3(0.035, 0.03, 0.055);
uniform vec3 glow : source_color = vec3(0.62, 0.26, 1.0);
uniform vec3 edge_colour : source_color = vec3(1.0, 0.16, 0.62);
uniform vec3 left_colour : source_color = vec3(0.1, 0.85, 1.0);
uniform float energy = 2.0;
uniform float speed = 1.6;          // chevrons per second, forwards
global uniform float tm_neon;
global uniform float tm_wet;

float band(float x, float a, float b, float w) {
	return smoothstep(a - w, a + w, x) * (1.0 - smoothstep(b - w, b + w, x));
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float x = abs(u - 0.5) * 2.0;                 // 0 at the centre line .. 1 at the rails
	float fw = max(fwidth(v), 0.002);
	float lit = max(tm_neon, 0.35);
	vec3 e = vec3(0.0);
	if (mag > 0.5) {
		// chevrons: a V every 10 m, its arms swept back 6 m, running forwards
		float ph = fract((v - x * 6.0) / 10.0 - TIME * speed * 0.4);
		float chev = band(ph, 0.03, 0.085, fw / 10.0 + 0.006) * step(x, 0.78);
		// a fine grid (the magnet's plates) and the hot edges
		float gx = 1.0 - smoothstep(0.0, 0.035, abs(fract(u * 8.0) - 0.5) * 2.0 - 0.93);
		float gy = 1.0 - smoothstep(0.0, fw * 0.25 + 0.01, abs(fract(v / 4.0) - 0.5) * 2.0 - 0.96);
		float grid = clamp(max(1.0 - gx, 1.0 - gy), 0.0, 1.0) * 0.1;
		float edge = smoothstep(0.86, 0.94, x);
		ALBEDO = base + glow * (chev * 0.25 + grid * 0.2);
		ROUGHNESS = mix(0.18, 0.05, tm_wet);
		METALLIC = 0.55;
		SPECULAR = 0.7;
		e = glow * (chev * 0.9 + grid * 0.35) + mix(left_colour, edge_colour, step(0.5, u)) * edge * 1.2;
	} else {
		// a roof's lane: two lines of runway lights, arrows down the middle
		float side = band(x, 0.80, 0.86, 0.01);
		float lights = side * step(fract(v / 6.0), 0.45);
		float ph = fract((v - x * 3.0) / 16.0 - TIME * speed * 0.25);
		float arrow = band(ph, 0.0, 0.07, 0.01) * step(x, 0.35);
		float a = clamp(lights + arrow, 0.0, 1.0);
		if (a < 0.02) {
			discard;
		}
		ALBEDO = vec3(0.9);
		ROUGHNESS = 0.4;
		e = mix(left_colour, edge_colour, step(0.5, u)) * lights * 1.4 + vec3(1.0, 0.85, 0.5) * arrow * 0.9;
	}
	EMISSION = e * energy * lit;
}
