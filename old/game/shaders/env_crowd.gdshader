shader_type spatial;
render_mode cull_disabled;
// Stadium crowd on the stand tiers. UV.y = metres along the stand ring.
// Seats are cells (along the ring x height); each holds a person blob with a random shirt colour,
// lit softly from the floodlights plus a little emission, a travelling "wave" and phone flashes.

uniform vec3 seat_color : source_color = vec3(0.05, 0.05, 0.08);
uniform float crowd_density = 0.8;
uniform float emission_energy = 0.35;



float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 g = vec2(UV.y / 0.75, wpos.y / 0.9);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float r = h21(cell);
	float occupied = step(r, crowd_density);
	vec3 shirt = vec3(h21(cell + 1.3), h21(cell + 2.7), h21(cell + 5.1));
	shirt = mix(shirt, vec3(dot(shirt, vec3(0.33))), 0.3);
	// team colours: lots of cyan and magenta
	float team = h21(cell + 9.0);
	if (team < 0.25) shirt = vec3(0.0, 0.8, 1.0);
	else if (team < 0.45) shirt = vec3(1.0, 0.2, 0.8);
	// stadium wave travelling along the ring
	float wave = smoothstep(0.85, 1.0, sin(UV.y * 0.02 - TIME * 1.6) * 0.5 + 0.5);
	float bob = wave * 0.25 + 0.05 * sin(TIME * 4.0 + r * 30.0);
	// blob: body + head
	vec2 c = f - vec2(0.5, 0.35 + bob);
	float body = step(length(c * vec2(1.3, 1.0)), 0.3);
	float head = step(length(f - vec2(0.5, 0.78 + bob)), 0.13);
	float person = max(body, head) * occupied;
	vec3 skin = mix(vec3(0.35, 0.22, 0.15), vec3(0.85, 0.65, 0.5), h21(cell + 3.3));
	vec3 col = mix(seat_color, mix(shirt, skin, head), person);
	// far away: average
	vec2 fw = fwidth(g);
	float aa = clamp(1.0 - (max(fw.x, fw.y) - 0.25) * 2.5, 0.0, 1.0);
	vec3 avg = mix(seat_color, vec3(0.45, 0.4, 0.5), crowd_density * 0.45);
	col = mix(avg, col, aa);
	// phone flashes
	float flash = step(0.997, h21(cell + floor(TIME * 3.0))) * occupied;
	ALBEDO = col;
	ROUGHNESS = 0.9;
	EMISSION = col * emission_energy * (1.0 + wave * 2.0) + vec3(1.0) * flash * 3.0 * aa;
}
