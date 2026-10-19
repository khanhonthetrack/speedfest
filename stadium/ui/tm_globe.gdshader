shader_type canvas_item;
// The menus' globe (M10-5: TMNF's menus turn a green Earth behind them): a lit sphere drawn on a
// square ColorRect from stadium/assets/tex/globe_map_albedo.jpg (R land, G a band along the coasts,
// B relief noise; tools/texgen/globe.py). Pale glossy green seas, olive land with a light rim along
// its coasts, lit from the upper left, darker toward the right, a thin bright edge.

uniform sampler2D globe_map : filter_linear_mipmap, repeat_enable;
uniform float spin = 0.0;            // longitude turned to the front, radians
uniform float tilt = 0.32;           // the north pole leaning toward the viewer, radians
uniform vec3 light = vec3(-0.55, 0.45, 0.7);
uniform vec4 sea_lit : source_color = vec4(0.62, 0.78, 0.47, 1.0);
uniform vec4 sea_dark : source_color = vec4(0.20, 0.33, 0.17, 1.0);
uniform vec4 land_lit : source_color = vec4(0.60, 0.57, 0.36, 1.0);
uniform vec4 land_dark : source_color = vec4(0.21, 0.20, 0.11, 1.0);
uniform vec4 rim_colour : source_color = vec4(0.93, 0.92, 0.70, 1.0);
uniform float dim = 1.0;             // the whole globe's brightness (pages darken it)

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float edge = 1.0 - smoothstep(0.985, 1.0, sqrt(r2));
	if (edge <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec3 n = vec3(p.x, -p.y, sqrt(max(0.0, 1.0 - r2)));
		// the sphere's point in the globe's frame: tilt about x, then the spin about the pole
		float ct = cos(tilt), st = sin(tilt);
		vec3 g = vec3(n.x, n.y * ct + n.z * st, -n.y * st + n.z * ct);
		float lon = atan(g.x, g.z) + spin;
		float lat = asin(clamp(g.y, -1.0, 1.0));
		vec2 uv = vec2(fract(lon / (2.0 * PI) + 0.5), 0.5 - lat / PI);
		vec3 m = texture(globe_map, uv).rgb;
		float land = smoothstep(0.35, 0.65, m.r);
		vec3 l = normalize(light);
		// the land stands up from the sea like a plate: its edges bent toward the light or away
		// (the mask's slope east and north, in the sphere's tangent frame)
		vec2 px = vec2(1.5 / 2048.0, 1.5 / 1024.0);
		float de = texture(globe_map, uv + vec2(px.x, 0.0)).r - texture(globe_map, uv - vec2(px.x, 0.0)).r;
		float dn = texture(globe_map, uv - vec2(0.0, px.y)).r - texture(globe_map, uv + vec2(0.0, px.y)).r;
		vec3 up_g = vec3(0.0, ct, -st);                   // the pole in screen space
		vec3 east = normalize(cross(up_g, n) + vec3(1e-4, 0.0, 0.0));
		vec3 north = cross(n, east);
		vec3 nb = normalize(n - (east * de + north * dn) * 2.2);
		float diff = clamp(dot(nb, l), 0.0, 1.0);
		float shade = 0.18 + 0.82 * diff;
		vec3 sea = mix(sea_dark.rgb, sea_lit.rgb, shade);
		// land: relief from the noise, raised along the coasts
		float relief = 0.75 + 0.5 * m.b;
		// broad soft shade over everything (TMNF's globe is mottled, not evenly lit)
		float mottle = texture(globe_map, uv * vec2(0.25, 0.5) + vec2(0.37, 0.11)).b;
		shade *= mix(0.55, 1.1, smoothstep(0.25, 0.75, mottle));
		vec3 ground = mix(land_dark.rgb, land_lit.rgb, clamp(shade * relief, 0.0, 1.0));
		ground = mix(ground, rim_colour.rgb * (0.35 + 0.65 * diff), m.g * 0.75);
		vec3 col = mix(sea, ground, land);
		// the sea's gloss: a broad highlight toward the light
		vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
		float spec = pow(clamp(dot(nb, h), 0.0, 1.0), 14.0) * (1.0 - land * 0.6);
		col += vec3(0.88, 0.96, 0.78) * spec * 0.7;
		// a thin bright edge (the atmosphere) and the limb darkening
		float fres = pow(1.0 - n.z, 3.0);
		col = mix(col, vec3(0.86, 0.92, 0.70), fres * 0.45 * (0.4 + 0.6 * diff));
		col *= mix(1.0, 0.55, smoothstep(0.2, 1.0, -dot(n.xy, l.xy) * 0.9 + 0.1) * 0.6);
		COLOR = vec4(col * dim, edge);
	}
}
