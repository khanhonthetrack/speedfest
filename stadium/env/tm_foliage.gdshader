shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// A street tree's crown (TmTrees): lumpy blobs of leaves. The leaves are noise: clumps lighter and
// darker, the silhouette broken where the surface turns away (holes the sky shows through), light
// through the leaves from behind (backlight), a sway in the wind. Each tree its own green (the
// instance colour).

uniform vec3 leaf_dark : source_color = vec3(0.06, 0.10, 0.04);
uniform vec3 leaf_light : source_color = vec3(0.24, 0.33, 0.11);
uniform float holes = 0.85;              // how much of the silhouette breaks up
global uniform float tm_night;

varying vec3 lpos;
varying vec3 tint;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	lpos = VERTEX;
	tint = INSTANCE_CUSTOM.rgb;
	// the crown sways, more at the top
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = sin(TIME * 1.3 + w.x * 0.21 + w.z * 0.17) * 0.08 + sin(TIME * 2.9 + VERTEX.y) * 0.03;
	VERTEX.x += s * max(VERTEX.y - 2.0, 0.0) * 0.12;
}

void fragment() {
	vec3 p = lpos;
	float clump = noise3(p * 1.4) * 0.6 + noise3(p * 4.3) * 0.4;
	float leaves = noise3(p * 11.0) * 0.5 + noise3(p * 27.0) * 0.5;
	vec3 col = mix(leaf_dark, leaf_light, clamp(clump * 1.1 - 0.15 + leaves * 0.25, 0.0, 1.0));
	ALBEDO = col * (tint.r > 0.0 ? tint * 1.6 : vec3(1.0));
	// the edges break up where the surface turns from the eye (sky through the leaves)
	float edge = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALPHA = 1.0 - step(1.0 - holes * edge * edge, leaves * 0.6 + clump * 0.4);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	NORMAL = normalize(NORMAL + (vec3(noise3(p * 19.0), noise3(p * 19.0 + 3.1), noise3(p * 19.0 + 6.2)) - 0.5) * 1.4);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = col * 0.6;
	AO = mix(0.55, 1.0, clump);
}
