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
uniform float storefront = 0.0;         // m: a shop floor this tall at the foot (0: none)
uniform sampler2D ads : source_color, filter_linear_mipmap_anisotropic, repeat_enable;   // the adverts
uniform sampler2D ads_fill : source_color, filter_linear, repeat_disable;             // their backgrounds
uniform float has_ads = 0.0;            // 1: the shops carry the adverts' brands
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
		col = mix(col, lamp * mix(5.0, 2.4, day), panel * lit);
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
	vec3 light = vec3(day * (0.70 - 0.45 * depth)) + lit * lamp * (0.9 + 0.25 * hash(cell, 5.0));
	return col * light;
}

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
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
	float litf = clamp(mix(lit_fraction, 0.45, tm_night) * (0.2 + 1.6 * hash(band, 15.0)), 0.0, 0.95);
	float lit = lobby > 0.5 ? 1.0 : step(hash(rc, 2.0), litf);
	// the rooms' lamps: warm in most, cool white in offices with fluorescent panels
	vec3 lamp = mix(vec3(1.05, 0.90, 0.68), vec3(0.88, 0.95, 1.05), step(0.55, hash(rc, 14.0)));
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
	vec3 inside = inside_avg;
	if (far < 0.99) {
		inside = room(c, vec3(g.x, g.y, 0.0), -tv, lit, day, lamp, vec3(bay_w, fh, room_depth));
		// blinds: some rooms have them down part way (right behind the glass)
		float blind_frac = hash(rc, 6.0) < 0.45 ? hash(rc, 7.0) * 0.75 : 0.0;
		float win_y = (f.y - span_top) / max(fh - span_top, 0.1);
		float blind = lobby > 0.5 ? 0.0 : step(1.0 - blind_frac, win_y);
		vec3 blind_col = vec3(0.78, 0.76, 0.70) * (day * 0.55 + lit * 0.7);
		inside = mix(mix(inside, blind_col, blind), inside_avg, far);
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
	float glass_eff = glassm * (1.0 - rev);
	float rev_m = glassm * rev;
	float wsum = max(frame + span + glassm, 1e-4);
	ALBEDO = (frame_alb * frame + span_alb * span + frame_colour * COLOR.rgb * rev_light * rev_m + glass_tint * glass_eff) / wsum;
	METALLIC = (frame_metal * (frame + rev_m) + span_metal * span + reflectivity * glass_eff) / wsum;
	ROUGHNESS = (frame_rough * (frame + rev_m) + span_rough * span + (0.035 + 0.02 * hash(c, 13.0)) * glass_eff) / wsum;
	EMISSION = inside * glass_eff * mix(1.0 - fres, (1.0 - fres * 0.6) * 1.5, tm_night) * transmit;
	// a crown's floodlights wash up its frames at night
	float crown = step(0.4, COLOR.a) * (1.0 - step(0.75, COLOR.a));      // 0.4..0.75 (under 0.4: plain)
	EMISSION += crown_light * crown * tm_night * (0.35 + 0.9 * frame + 0.4 * span) * 1.8;
	// a shop floor at the foot, as modern shops are: floor-to-ceiling glass in slim black frames
	// with a door, a fascia above carrying the shop's brand (the adverts: its logo on its own
	// background colour, backlit at night), behind the glass a bright shop in the brand's colour
	if (storefront > 0.0 && UV.y < storefront && world_map < 0.5 && lobby < 0.5 && plain < 0.5) {
		float sw = 6.0;
		float sc = floor(m.x / sw);
		float sx = sw - (m.x - sc * sw);        // left to right as one in front of the wall sees it (u runs the other way)
		float sy = UV.y;
		float ad = floor(hash(vec2(sc, 9.0), 50.0) * 15.999);
		float f0 = storefront - 1.0;                      // the fascia's foot
		float fascia = step(f0, sy);
		vec3 brand = has_ads > 0.5 ? texture(ads_fill, vec2((ad + 0.5) / 16.0, 0.5)).rgb : vec3(0.1, 0.3, 0.6);
		// the fascia: the logo (2:1) centred, the ad's background out to the shop's ends
		vec3 fascia_col = brand;
		if (has_ads > 0.5) {
			float lv = clamp(1.0 - (sy - f0) / 0.9, 0.0, 1.0);
			float lu = (sx - (sw - 1.8) * 0.5) / 1.8;
			fascia_col = texture(ads_fill, vec2((ad + 0.5) / 16.0, lv)).rgb;
			if (lu > 0.0 && lu < 1.0 && sy < storefront - 0.1) {
				fascia_col = texture(ads, vec2((ad + clamp(lu, 0.002, 0.998)) / 16.0, lv)).rgb;
			}
		}
		fascia_col = mix(fascia_col, vec3(0.05), step(storefront - 0.1, sy));      // its dark cap
		// the glazing: mullions every 2 m, a door in the middle, a slim plinth
		float gx = mod(sx, 2.0);
		float mull = 1.0 - smoothstep(0.03 - fw.x, 0.03 + fw.x, min(gx, 2.0 - gx));
		mull = max(mull, 1.0 - smoothstep(0.05 - fw.x, 0.05 + fw.x, min(sx, sw - sx)));
		float door = step(abs(sx - sw * 0.5), 0.95) * step(sy, 2.4);
		float door_frame = door * (1.0 - smoothstep(0.03, 0.03 + fw.x, min(abs(abs(sx - sw * 0.5) - 0.95), abs(sy - 2.4))));
		door_frame = max(door_frame, step(abs(sx - sw * 0.5), 0.95) * (1.0 - smoothstep(0.03 - fw.y, 0.03 + fw.y, abs(sy - 2.4))));
		float plinth = step(sy, 0.15);
		float sframe = max(max(mull, door_frame), plinth) * (1.0 - fascia);
		float spane = (1.0 - fascia) * (1.0 - sframe);
		// the shop: a box 9 m deep; white walls, a light polished floor, a ceiling of spotlights,
		// the back wall in the brand's colour with its logo, shelves down the sides
		vec3 so = vec3(sx, sy - 0.15, 0.0);
		vec3 sd = -tv;
		sd.x = -sd.x;                                     // the shop's x runs as sx does (flipped)
		vec3 sdd = vec3(abs(sd.x) < 1e-4 ? 1e-4 : sd.x, abs(sd.y) < 1e-4 ? 1e-4 : sd.y, min(sd.z, -1e-4));
		float hh = f0 - 0.15;
		float stx = sdd.x > 0.0 ? (sw - so.x) / sdd.x : -so.x / sdd.x;
		float sty = sdd.y > 0.0 ? (hh - so.y) / sdd.y : -so.y / sdd.y;
		float stz = (-9.0 - so.z) / sdd.z;
		float st = min(min(stx, sty), stz);
		vec3 sp = so + sdd * st;
		// each shop its own: a dark boutique or a bright store, warm or cool light, clothes rails
		// or shelves of goods
		float kind = hash(vec2(sc, 3.0), 54.0);
		bool dark = kind < 0.45;
		bool rails = hash(vec2(sc, 4.0), 55.0) < 0.5;
		vec3 light = mix(vec3(1.0, 0.82, 0.6), vec3(0.92, 0.97, 1.05), step(0.7, hash(vec2(sc, 5.0), 56.0)));
		vec3 wall = dark ? vec3(0.06, 0.055, 0.05) + brand * 0.05 : vec3(0.58, 0.57, 0.55);
		vec3 shop;
		vec2 spots = fract(sp.xz / vec2(1.5, 1.5)) - 0.5;
		if (st == sty && sdd.y > 0.0) {
			float spot = 1.0 - smoothstep(0.05, 0.1, length(spots));
			shop = mix(wall * 0.8, light * 4.0, spot);
		} else if (st == sty) {
			// a polished floor, a pool of light under each spot
			float pool = exp(-dot(spots, spots) * 9.0);
			shop = (dark ? vec3(0.05) : vec3(0.32, 0.3, 0.28)) * (0.5 + 1.3 * pool) * light;
		} else if (st == stz) {
			shop = mix(wall, brand * 0.7, 0.75);
			if (has_ads > 0.5) {
				float bu = (sp.x - (sw - 2.4) * 0.5) / 2.4;
				float bv = 1.0 - (sp.y - 1.4) / 1.2;
				if (bu > 0.0 && bu < 1.0 && bv > 0.0 && bv < 1.0) {
					shop = texture(ads, vec2((ad + bu) / 16.0, bv)).rgb * 1.2;
				}
			}
		} else {
			shop = wall;
			float near_px = 1.0 - smoothstep(0.02, 0.08, max(fw.x, fw.y));
			if (rails) {
				// clothes on a rail: hanging strips of colour from 0.6 to 1.7 m
				float strip = floor(-sp.z / 0.09);
				vec3 cloth = mix(vec3(0.15), vec3(hash(vec2(strip, sc), 57.0), hash(vec2(strip, sc), 58.0), hash(vec2(strip, sc), 59.0)), 0.6);
				float hang = step(0.6 + 0.3 * hash(vec2(strip, sc), 60.0), sp.y) * step(sp.y, 1.7);
				shop = mix(shop, mix(vec3(0.3), cloth, near_px), hang);
			} else {
				float shelf = step(0.3, sp.y) * step(sp.y, 2.1);
				float item = step(0.12, fract(-sp.z / 0.5)) * step(fract(sp.y / 0.45), 0.7) * step(0.12, fract(sp.y / 0.45));
				vec3 goods = mix(vec3(0.6), vec3(hash(floor(vec2(sp.z / 0.5, sp.y / 0.45)), 52.0), hash(floor(vec2(sp.z / 0.5, sp.y / 0.45)), 53.0), 0.6), 0.5);
				shop = mix(shop, mix(vec3(0.4), goods, near_px), shelf * item);
			}
			shop *= light;
		}
		shop *= 1.0 - 0.35 * clamp(-sp.z / 9.0, 0.0, 1.0);
		vec3 alb = mix(mix(vec3(0.02), vec3(0.03, 0.03, 0.035), sframe), fascia_col * 0.85, fascia);
		ALBEDO = alb;
		METALLIC = mix(0.2, 0.7, sframe) * (1.0 - fascia);
		ROUGHNESS = mix(0.05, 0.35, max(sframe, fascia));
		SPECULAR = 0.5;
		NORMAL = N;
		float fres_s = 0.06 + 0.94 * pow(1.0 - ndv, 5.0);
		EMISSION = shop * spane * (1.0 - fres_s) * mix(0.55, 0.9, tm_night) + fascia_col * fascia * mix(0.25, 1.4, tm_night)
			* (1.0 - step(storefront - 0.1, sy));
		// a neon tube under the fascia on many shops (pink, cyan, violet, amber)
		float tube_on = step(0.45, hash(vec2(sc, 6.0), 61.0));
		vec3 tube_col = hash(vec2(sc, 7.0), 62.0) < 0.25 ? vec3(1.0, 0.2, 0.65) : (hash(vec2(sc, 7.0), 62.0) < 0.5 ? vec3(0.2, 0.9, 1.0)
			: (hash(vec2(sc, 7.0), 62.0) < 0.75 ? vec3(0.65, 0.3, 1.0) : vec3(1.0, 0.65, 0.15)));
		float tube = (1.0 - smoothstep(0.025, 0.025 + fw.y * 1.5, abs(sy - (f0 - 0.06)))) * step(0.15, sx) * step(sx, sw - 0.15) * tube_on;
		EMISSION += tube_col * tube * mix(1.5, 8.0, tm_night) + tube_col * tube_on * exp(-abs(sy - (f0 - 0.06)) * 8.0) * 0.35 * tm_night * spane;
		ALBEDO = mix(ALBEDO, tube_col * 0.6 + 0.3, tube);
	}
	// the street's shade at a building's foot (the city casts no shadows: too far for them)
	AO = mix(0.45, 1.0, smoothstep(0.0, 14.0, world_map > 0.5 ? wpos.y - NODE_POSITION_WORLD.y : UV.y));
	AO_LIGHT_AFFECT = 0.6;
}
