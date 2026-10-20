shader_type spatial;
render_mode cull_back, diffuse_burley;
// The city's ground around the Stadium (TmSkyline): a street grid drawn from the position (no
// textures): asphalt with dashed centre lines, pavements along the blocks, the blocks' plazas. Far
// off it fades to its average (no shimmer); at the city's rim to the plain beyond. At night (the
// global tm_night) street lights along both kerbs every 30 m pool warm light on the road.

uniform float pitch = 150.0;            // m, block to block
uniform float street = 26.0;            // m, kerb to kerb
uniform float radius = 5200.0;          // m, the city's rim
uniform vec3 plain_colour : source_color = vec3(0.38, 0.43, 0.32);

global uniform float tm_night;

varying vec2 lp;

void vertex() {
	lp = VERTEX.xz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 g = lp / pitch + 0.5;
	vec2 c = floor(g);
	vec2 f = (g - c) * pitch;                     // m within the cell, streets at its edges
	vec2 dd = min(f, pitch - f);                  // m to the nearest street centre, per axis
	float d = min(dd.x, dd.y);
	vec2 fw = fwidth(lp);
	float px = max(fw.x, fw.y);
	float hs = street * 0.5;
	float road = 1.0 - smoothstep(hs - px, hs + px, d);
	float walk = 1.0 - smoothstep(hs + 4.5 - px, hs + 4.5 + px, d);
	// asphalt, patched; a dashed centre line along each street (not across the junctions)
	float n = hash(floor(lp / 6.0)) * 0.03;
	vec3 asphalt = vec3(0.13, 0.135, 0.14) + n;
	float along_x = step(dd.y, dd.x);             // the street runs along x here
	float across = along_x > 0.5 ? dd.y : dd.x;
	float runs = along_x > 0.5 ? lp.x : lp.y;
	float line = (1.0 - smoothstep(0.12 - px, 0.12 + px, across)) * step(0.5, fract(runs / 9.0));
	line *= step(hs + 2.0, along_x > 0.5 ? dd.x : dd.y);
	asphalt = mix(asphalt, vec3(0.75, 0.72, 0.62), line * (1.0 - smoothstep(0.3, 1.0, px)));
	vec3 pave = vec3(0.40, 0.39, 0.37) + hash(floor(lp / 1.5)) * 0.03;
	vec3 plaza = mix(vec3(0.28, 0.28, 0.27), vec3(0.38, 0.36, 0.33), hash(c));
	vec3 col = mix(mix(plaza, pave, walk), asphalt, road);
	// far: the cell's average
	float far = clamp(px / pitch * 40.0 - 0.5, 0.0, 1.0);
	float rf = street / pitch;
	vec3 avg = mix(vec3(0.33, 0.33, 0.32), vec3(0.14), rf * 2.0 - rf * rf);
	col = mix(col, avg, far);
	// the rim: the city gives way to the plain
	col = mix(col, plain_colour, smoothstep(radius - 300.0, radius + 200.0, length(lp)));
	// street lights: their pools of light at night (a dim warm glow on average, far off)
	vec3 sodium = vec3(1.0, 0.70, 0.40);
	float kerb = d - hs;
	float al = (fract(runs / 30.0) - 0.5) * 30.0;
	float pool = exp(-kerb * kerb / 18.0) * exp(-al * al / 50.0);
	float rim = 1.0 - smoothstep(radius - 300.0, radius + 200.0, length(lp));
	EMISSION = sodium * mix(pool * 0.9, 0.06, far) * tm_night * rim;
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.95, road);
	SPECULAR = 0.3;
}
