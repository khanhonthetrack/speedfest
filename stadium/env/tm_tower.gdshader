shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// A skyscraper's curtain wall (TmTower): UV is metres (u around the tower, v up from its foot).
// Every window cell is a bay (bay_w) by a floor (floor_h): aluminium mullions and transoms, an
// opaque spandrel at the floor's foot (the slab behind it), and glass above it, coated (tinted,
// mostly mirror) with a room behind it: the ray through the glass is traced into a box the size of
// the cell (room_depth deep; interior mapping) and lands on its back wall, a side wall, the floor
// or the ceiling, each shaded per room (walls, carpet, ceiling panels lit or not, blinds, desks).
// The glass panes tilt a hair each, so the reflections break at the panes as real ones do. Far off,
// where a cell is a few pixels, it all fades to its average (no shimmer). The walls are vertical:
// their frame (along u, up) comes from the normal and the view's up, so meshes need no tangents.
// The vertex colour tints the walls (a city's merged blocks: each building its own shade); its
// alpha under 1 marks a crown, floodlit at night. At night (the global tm_night, TmStadiumEnv) more
// rooms are lit, warm or cool, and the coating lets more of them through (the sky it mirrors is dark).

uniform vec3 glass_tint : source_color = vec3(0.30, 0.42, 0.52);
uniform float reflectivity = 0.80;      // the coating: metallic of the glass
uniform vec3 frame_colour : source_color = vec3(0.62, 0.65, 0.68);
uniform vec3 spandrel_colour : source_color = vec3(0.10, 0.13, 0.17);
uniform float seed = 0.0;               // each tower's rooms differ
uniform float floor_h = 4.0;            // m
uniform float bay_w = 3.0;              // m
uniform float mullion = 0.12;           // m, the vertical frames
uniform float transom = 0.16;           // m, the horizontal ones
uniform float spandrel = 1.15;          // m, the opaque band at a floor's foot
uniform float room_depth = 7.0;         // m
uniform float lit_fraction = 0.20;      // rooms with their lights on (by day; more at night)
uniform float daylight = 1.0;           // 1 by day, 0 at night
uniform float lobby = 0.0;              // 1: the podium (one tall storey of clear glass, all lit)
uniform float pane_tilt = 0.018;        // the panes' small tilts (reflections break at them)
uniform float fin_every = 0.0;          // a deeper vertical fin every this many bays (0: none)
uniform float fin_w = 0.45;             // m
uniform float reveal = 0.0;             // m: the glass set back in its opening (masonry; 0: flush)
uniform float storefront = 0.0;         // m: the base storey this tall at the foot (0: none)
uniform float brick = 0.0;              // 1: the wall laid in brick courses
uniform float panels = 0.0;             // 1: precast panels (joints at each floor and every two bays)
uniform float grime = 0.0;              // dirt washed down from the sills (0..1)
uniform float world_map = 0.0;          // 1: windows from the world position (models without our
                                        // metre UVs: each planar wall's horizontal run, metres up)
uniform float frame_metal = 1.0;        // the frames: aluminium (1) or stone and concrete (0)
uniform float frame_rough = 0.32;
uniform float span_metal = 0.45;        // the spandrels: enamelled glass (0.45) or masonry (0)
uniform float span_rough = 0.28;
uniform vec3 crown_light : source_color = vec3(1.0, 0.95, 0.85);   // the crown's floodlights at night
global uniform float tm_night;
global uniform float tm_city_led;      // the storefronts' LED lines (1; a story's set turns them off)
global uniform float tm_city_lit;      // the share of rooms lit at night (0.30; a story's set lights more)

float hash(vec2 p, float k) {
	return fract(sin(dot(p + vec2(k * 17.31, seed * 3.17), vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 u = fract(p);
	u = u * u * (3.0 - 2.0 * u);
	return mix(mix(hash(i, 21.0), hash(i + vec2(1.0, 0.0), 21.0), u.x), mix(hash(i + vec2(0.0, 1.0), 21.0), hash(i + vec2(1.0, 1.0), 21.0), u.x), u.y);
}

// a box interior seen through the glass at o (cell metres), looking along d (into the room: d.z < 0);
// returns the lit colour of what the ray meets
vec3 room(vec2 cell, vec3 o, vec3 d, float lit, float day, vec3 lamp, vec3 box) {
	float fh = box.y;
	vec3 dd = vec3(abs(d.x) < 1e-4 ? 1e-4 : d.x, abs(d.y) < 1e-4 ? 1e-4 : d.y, min(d.z, -1e-4));
	float tx = dd.x > 0.0 ? (box.x - o.x) / dd.x : -o.x / dd.x;
	float ty = dd.y > 0.0 ? (fh - o.y) / dd.y : -o.y / dd.y;
	float tz = (-box.z - o.z) / dd.z;
	float t = min(min(tx, ty), tz);
	vec3 p = o + dd * t;
	float r1 = hash(cell, 3.0);
	vec3 wall = mix(vec3(0.72, 0.70, 0.64), vec3(0.86, 0.87, 0.88), r1);
	vec3 carpet = mix(vec3(0.20, 0.20, 0.21), vec3(0.38, 0.35, 0.31), hash(cell, 4.0));
	vec3 col;
	float depth = clamp(-p.z / box.z, 0.0, 1.0);
	if (t == ty && dd.y > 0.0) {
		// the ceiling: tiles and, lit, light panels
		col = vec3(0.82);
		vec2 q = fract(p.xz / vec2(1.5, 1.5));
		float panel = step(0.2, q.x) * step(q.x, 0.8) * step(0.3, q.y) * step(q.y, 0.7);
		col = mix(col, lamp * mix(mix(5.0, 2.6, tm_night), 2.4, day), panel * lit);
	} else if (t == ty) {
		col = carpet;
	} else if (t == tz) {
		col = wall * 0.92;
		// the back wall: a door or a dark doorway now and then, a desk row's edge in front of it
		float door = step(abs(p.x - box.x * (0.3 + 0.4 * hash(cell, 8.0))), 0.45) * step(p.y, 2.2) * step(hash(cell, 9.0), 0.4);
		col = mix(col, vec3(0.18, 0.16, 0.15), door);
	} else {
		col = wall;
	}
	// desks: a band at 0.75 m on the walls the ray meets low, darker under it
	if (t != ty) {
		float desk = smoothstep(0.70, 0.74, p.y) * (1.0 - smoothstep(0.76, 0.80, p.y));
		col = mix(col, vec3(0.30, 0.27, 0.24), desk * step(hash(cell, 10.0), 0.7));
		col *= mix(0.55, 1.0, smoothstep(0.0, 0.7, p.y));
	}
	// daylight from the window falls off into the room; the lamps light it evenly
	vec3 light = vec3(day * (0.70 - 0.45 * depth)) + lit * lamp * (0.9 + 0.25 * hash(cell, 5.0)) * mix(1.0, 0.6, tm_night);
	return col * light;
}

varying flat vec3 bcol;       // the building's tint, not interpolated (it seeds the base's hash)
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	bcol = COLOR.rgb;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float fh = floor_h;
	vec2 cs = vec2(bay_w, fh);
	vec2 m = UV;
	if (world_map > 0.5) {
		// along a planar wall: its run over the axis it faces least, divided by that (metres along it)
		vec3 n = normalize(wnrm);
		m = abs(n.x) > abs(n.z) ? vec2(wpos.z * sign(n.x) / max(abs(n.x), 0.3), wpos.y)
			: vec2(-wpos.x * sign(n.z) / max(abs(n.z), 0.3), wpos.y);
	}
	vec2 c = floor(m / cs);
	vec2 f = m - c * cs;
	vec2 fw = fwidth(m);
	// how many pixels a cell covers: under a few, its average
	float far = clamp(max(fw.x / bay_w, fw.y / fh) * 1.8 - 0.5, 0.0, 1.0);
	// frames: mullions at the bays' edges, transoms at the slab and the spandrel's top
	float dx = min(f.x, bay_w - f.x);
	float frame_v = 1.0 - smoothstep(mullion * 0.5 - fw.x, mullion * 0.5 + fw.x, dx);
	float span_top = lobby > 0.5 ? 0.0 : spandrel;
	float dy = min(abs(f.y - span_top), min(f.y, fh - f.y));
	float frame_h = 1.0 - smoothstep(transom * 0.5 - fw.y, transom * 0.5 + fw.y, dy);
	float frame = max(frame_v, frame_h);
	if (fin_every > 0.5) {
		// architectural fins: every few bays a wider pier of the frame's metal
		float period = bay_w * fin_every;
		float fx = m.x - floor(m.x / period) * period;
		float fd = min(fx, period - fx);
		frame = max(frame, 1.0 - smoothstep(fin_w * 0.5 - fw.x, fin_w * 0.5 + fw.x, fd));
	}
	float span = lobby > 0.5 ? 0.0 : 1.0 - smoothstep(span_top - fw.y, span_top + fw.y, f.y);
	// a plain wall (cornices, parapets: the vertex colour's alpha under 0.4) has no windows
	float plain = 1.0 - step(0.4, COLOR.a);
	// a model's flat faces (roofs, ledges: world-mapped) are plain wall too
	if (world_map > 0.5 && abs(normalize(wnrm).y) > 0.6) {
		plain = 1.0;
	}
	frame = max(frame, plain);
	// averages far off
	float frame_avg = clamp(mullion / bay_w + transom * 2.0 / fh + (fin_every > 0.5 ? fin_w / (bay_w * fin_every) : 0.0), 0.0, 1.0);
	float span_avg = lobby > 0.5 ? 0.0 : span_top / fh;
	frame = mix(frame, frame_avg, far);
	span = mix(span * (1.0 - frame), span_avg, far);
	float glassm = clamp(1.0 - frame - span, 0.0, 1.0);
	// the view in the wall's frame: x along u, y up (v), z out of the wall
	vec3 V = normalize(VIEW);
	vec3 N = normalize(NORMAL);
	vec3 B = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 T = normalize(cross(N, B));
	vec3 tv = vec3(dot(V, T), dot(V, B), dot(V, N));
	// rooms two bays wide: they share their lights and blinds
	vec2 rc = vec2(floor(c.x / 2.0), c.y);
	float day = daylight * (1.0 - tm_night);
	// lit in patches: each band of floors and bays its own share (offices, empty floors)
	vec2 band = vec2(floor(c.x / 6.0), floor(c.y / 3.0));
	float litf = clamp(mix(lit_fraction, tm_city_lit, tm_night) * (0.2 + 1.6 * hash(band, 15.0)), 0.0, 0.95);
	float lit = lobby > 0.5 ? 1.0 : step(hash(rc, 2.0), litf);
	// the rooms' lamps: warm in most, cool white in offices with fluorescent panels
	vec3 lamp = mix(vec3(1.05, 0.90, 0.68), vec3(0.88, 0.95, 1.05), step(0.55, hash(rc, 14.0)));
	// at night some rooms glow in colour (screens, mood lights): violet, blue, pink
	float hue = hash(rc, 16.0);
	vec3 tint_room = hue < 0.33 ? vec3(0.55, 0.32, 1.0) : (hue < 0.66 ? vec3(0.25, 0.55, 1.05) : vec3(1.0, 0.35, 0.65));
	lamp = mix(lamp, tint_room, step(hash(rc, 17.0), 0.14) * tm_night);
	vec3 inside_avg = vec3(0.10, 0.10, 0.10) * day + litf * mix(vec3(0.55, 0.50, 0.42), vec3(0.55, 0.47, 0.36), tm_night);
	// masonry: the glass sits `reveal` back in its opening; the eye meets it further along its
	// ray, or meets the opening's sides first: the sill (lit from above), the head (in shade), jambs
	vec2 g = f;
	float rev = 0.0;
	float rev_light = 0.7;
	vec2 o0 = vec2(mullion * 0.5, span_top + transom * 0.5);
	vec2 o1 = vec2(bay_w - mullion * 0.5, fh - transom * 0.5);
	if (reveal > 0.0 && far < 0.99) {
		g = f - tv.xy / max(tv.z, 0.05) * reveal;
		vec2 lo = step(g, o0);
		vec2 hi = step(o1, g);
		rev = max(max(lo.x, hi.x), max(lo.y, hi.y)) * (1.0 - far);
		rev_light = lo.y > 0.5 ? 1.0 : (hi.y > 0.5 ? 0.42 : 0.68);
	}
	// far off at night: not the windows' average (a grey glow) but lit strips, four bays of a
	// floor at a time, warm, cool or now and then coloured, as offices are; only at a great
	// distance (a strip under a pixel or two) the average
	vec3 far_room = inside_avg;
	if (tm_night > 0.0) {
		vec2 strip = vec2(floor(c.x / 4.0), c.y);
		float lit_s = step(hash(strip, 21.0), litf * 1.15);
		float hue_s = hash(strip, 22.0);
		vec3 lamp_s = hue_s < 0.5 ? vec3(1.0, 0.82, 0.58) : (hue_s < 0.85 ? vec3(0.82, 0.92, 1.05)
			: (hue_s < 0.93 ? vec3(0.55, 0.32, 1.0) : vec3(0.25, 0.55, 1.05)));
		float vfar = clamp(max(fw.x / (bay_w * 4.0), fw.y / fh) * 1.5 - 0.5, 0.0, 1.0);
		far_room = mix(mix(inside_avg, lamp_s * lit_s * 0.8, tm_night), inside_avg, vfar);
	}
	vec3 inside = far_room;
	if (far < 0.99) {
		inside = room(c, vec3(g.x, g.y, 0.0), -tv, lit, day, lamp, vec3(bay_w, fh, room_depth));
		// blinds: some rooms have them down part way (right behind the glass)
		float blind_frac = hash(rc, 6.0) < 0.45 ? hash(rc, 7.0) * 0.75 : 0.0;
		float win_y = (f.y - span_top) / max(fh - span_top, 0.1);
		float blind = lobby > 0.5 ? 0.0 : step(1.0 - blind_frac, win_y);
		vec3 blind_col = vec3(0.78, 0.76, 0.70) * (day * 0.55 + lit * 0.7);
		inside = mix(mix(inside, blind_col, blind), far_room, far);
	}
	// the glass: a coating that reflects most, more at grazing angles; through it, the room
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	float fres = reflectivity + (1.0 - reflectivity) * pow(1.0 - ndv, 5.0);
	float transmit = lobby > 0.5 ? mix(0.5, 1.2, tm_night) : mix(0.75, 0.32, day);
	// each pane tilts a hair (its own random), so the reflections break at the panes
	vec2 tilt = (vec2(hash(c, 11.0), hash(c, 12.0)) - 0.5) * pane_tilt * (1.0 - far);
	NORMAL = normalize(N + T * tilt.x * glassm + B * tilt.y * glassm);
	vec3 frame_alb = frame_colour * COLOR.rgb;
	vec3 span_alb = spandrel_colour * COLOR.rgb;
	float near = 1.0 - far;
	// the wall's own grain: brick courses or precast panel joints, a sill's stone under each
	// opening, dirt washed down from the sills, a building's large-scale weathering
	vec3 wall_tone = vec3(1.0);
	if (brick > 0.5) {
		float row = floor(m.y / 0.075);
		vec2 bq = vec2((m.x + mod(row, 2.0) * 0.1125) / 0.225, m.y / 0.075);
		vec2 bf = fract(bq);
		float joint = max(1.0 - smoothstep(0.0, 0.12, min(bf.y, 1.0 - bf.y)), 1.0 - smoothstep(0.0, 0.05, min(bf.x, 1.0 - bf.x)));
		float fine = 1.0 - smoothstep(0.004, 0.02, max(fw.x, fw.y));
		wall_tone = mix(vec3(1.0), mix(vec3(0.82 + 0.3 * hash(floor(bq), 31.0), 0.9 + 0.15 * hash(floor(bq), 32.0), 0.95),
			vec3(1.45, 1.6, 1.7), joint), fine);
	}
	if (panels > 0.5) {
		vec2 pj = vec2(min(mod(m.x, bay_w * 2.0), bay_w * 2.0 - mod(m.x, bay_w * 2.0)), min(f.y, fh - f.y));
		float j = 1.0 - smoothstep(0.015, 0.015 + max(fw.x, fw.y) * 1.5, min(pj.x, pj.y));
		wall_tone *= mix(1.0, 0.55, j * near) * (0.94 + 0.12 * hash(floor(m / vec2(bay_w * 2.0, fh)), 33.0));
	}
	float in_x = step(o0.x - 0.12, f.x) * step(f.x, o1.x + 0.12);
	float sill = in_x * step(o0.y - 0.12, f.y) * step(f.y, o0.y) * step(0.01, reveal) * near;
	float streak = in_x * step(f.y, o0.y - 0.12) * (1.0 - smoothstep(0.0, 1.6, o0.y - 0.12 - f.y))
		* (0.4 + 0.6 * hash(vec2(floor(m.x * 5.0), c.y), 34.0)) * grime * near;
	wall_tone *= (1.0 + 0.3 * sill) * (1.0 - 0.35 * streak) * (0.9 + 0.2 * vnoise(m / 9.0 + seed));
	frame_alb *= wall_tone;
	span_alb *= mix(vec3(1.0), wall_tone, step(0.5, brick + panels));
	// at night the walls in the dark (the moon and the sky's little light): the lit windows and
	// the neon carry the towers
	frame_alb *= mix(1.0, 0.42, tm_night);
	span_alb *= mix(1.0, 0.42, tm_night);
	float glass_eff = glassm * (1.0 - rev);
	float rev_m = glassm * rev;
	float wsum = max(frame + span + glassm, 1e-4);
	ALBEDO = (frame_alb * frame + span_alb * span + frame_colour * COLOR.rgb * rev_light * rev_m + glass_tint * glass_eff) / wsum;
	METALLIC = (frame_metal * (frame + rev_m) + span_metal * span + reflectivity * glass_eff) / wsum;
	ROUGHNESS = (frame_rough * (frame + rev_m) + span_rough * span + (0.035 + 0.02 * hash(c, 13.0)) * glass_eff) / wsum;
	EMISSION = inside * glass_eff * mix(1.0 - fres, (1.0 - fres * 0.6) * 1.0, tm_night) * transmit;
	// a crown's floodlights wash up its frames at night
	float crown = step(0.4, COLOR.a) * (1.0 - step(0.75, COLOR.a));      // 0.4..0.75 (under 0.4: plain)
	EMISSION += crown_light * crown * tm_night * (0.35 + 0.9 * frame + 0.4 * span) * 1.8;
	// the base (owner: no shops on the ground floors): the first storey as a modern building's foot:
	// a polished dark stone plinth, above it dark smoked glass between slim black fins with a dim
	// deep interior, a lit lobby entrance every few bays, and along its top an LED line in the
	// building's own colour (cyan, magenta, violet, amber or white), bright at night
	if (storefront > 0.0 && UV.y < storefront && world_map < 0.5 && lobby < 0.5 && plain < 0.5) {
		float sy = UV.y;
		float bid = fract(sin(dot(bcol, vec3(12.9898, 78.233, 37.719))) * 43758.5453);    // the building's own
		float led_y = storefront - 0.32;
		float cap = step(led_y + 0.12, sy);                       // the dark band over the LED
		float plinth = 1.0 - step(0.55, sy);
		// fins every 1.5 m, a wider pier every 9 m
		float fx = mod(m.x, 1.5);
		float fin = 1.0 - smoothstep(0.04 - fw.x, 0.04 + fw.x, min(fx, 1.5 - fx));
		float px = mod(m.x, 9.0);
		fin = max(fin, 1.0 - smoothstep(0.22 - fw.x, 0.22 + fw.x, min(px, 9.0 - px)));
		fin = mix(fin, 0.06, far);
		// an entrance: one 3 m bay in every 24-36 m, its door frame and a warm lobby behind it
		float ew = 24.0 + 12.0 * step(0.5, bid);
		float ex = mod(m.x + bid * 37.0, ew);
		float entrance = step(ex, 3.0) * step(0.55, sy) * step(sy, led_y - 0.25);
		fin *= 1.0 - entrance * step(0.2, ex) * step(ex, 2.8);
		// the interior, seen through the glass: a box 12 m deep (floor and ceiling), dark; the lobby
		// warm, brightest near the glass and up under its ceiling
		vec3 so = vec3(0.0, sy - 0.55, 0.0);
		vec3 sd = -tv;
		vec3 sdd = vec3(sd.x, abs(sd.y) < 1e-4 ? 1e-4 : sd.y, min(sd.z, -1e-4));
		float hh = led_y - 0.25 - 0.55;
		float sty = sdd.y > 0.0 ? (hh - so.y) / sdd.y : -so.y / sdd.y;
		float stz = (-12.0 - so.z) / sdd.z;
		vec3 sp = so + sdd * min(sty, stz);
		float depth = clamp(-sp.z / 12.0, 0.0, 1.0);
		vec3 inner = vec3(0.010, 0.012, 0.016) * (1.0 - 0.5 * depth);
		inner = mix(inner, vec3(1.0, 0.84, 0.62) * (0.65 - 0.45 * depth) * (0.7 + 0.5 * clamp(sp.y / max(hh, 0.1), 0.0, 1.0)), entrance);
		float glass_b = (1.0 - fin) * (1.0 - plinth) * (1.0 - cap);
		vec3 led = bid < 0.24 ? vec3(0.15, 0.85, 1.0) : (bid < 0.46 ? vec3(1.0, 0.18, 0.62)
			: (bid < 0.66 ? vec3(0.6, 0.28, 1.0) : (bid < 0.82 ? vec3(1.0, 0.62, 0.18) : vec3(0.9, 0.95, 1.0))));
		float led_line = 1.0 - smoothstep(0.045, 0.045 + fw.y * 1.5, abs(sy - led_y));
		ALBEDO = mix(mix(vec3(0.012, 0.013, 0.016), vec3(0.03, 0.031, 0.035), fin), vec3(0.025), plinth + cap);
		METALLIC = mix(0.85, 0.0, plinth + cap) * (1.0 - fin * 0.5);
		ROUGHNESS = mix(mix(0.04, 0.3, fin), 0.12, plinth) + cap * 0.4;
		SPECULAR = 0.5;
		NORMAL = N;
		float fres_b = 0.04 + 0.96 * pow(1.0 - ndv, 5.0);
		EMISSION = inner * glass_b * (1.0 - fres_b) * mix(0.6, 1.0, tm_night);
		EMISSION += (led * led_line * mix(0.8, 9.0, tm_night) + led * exp(-abs(sy - led_y) * 5.0) * 0.18 * tm_night * glass_b) * tm_city_led;
		ALBEDO = mix(ALBEDO, led * 0.5 + 0.4, led_line * tm_city_led);
	}
	// the street's shade at a building's foot (the city casts no shadows: too far for them)
	AO = mix(0.45, 1.0, smoothstep(0.0, 14.0, world_map > 0.5 ? wpos.y - NODE_POSITION_WORLD.y : UV.y));
	AO_LIGHT_AFFECT = 0.6;
}
