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

// a box interior seen through the glass at o (cell metres), looking along d (into the room: d.z < 0);
// returns the lit colour of what the ray meets
vec3 room(vec2 cell, vec3 o, vec3 d, float lit, float day, vec3 lamp) {
	float fh = floor_h;
	vec3 dd = vec3(abs(d.x) < 1e-4 ? 1e-4 : d.x, abs(d.y) < 1e-4 ? 1e-4 : d.y, min(d.z, -1e-4));
	float tx = dd.x > 0.0 ? (bay_w - o.x) / dd.x : -o.x / dd.x;
	float ty = dd.y > 0.0 ? (fh - o.y) / dd.y : -o.y / dd.y;
	float tz = (-room_depth - o.z) / dd.z;
	float t = min(min(tx, ty), tz);
	vec3 p = o + dd * t;
	float r1 = hash(cell, 3.0);
	vec3 wall = mix(vec3(0.72, 0.70, 0.64), vec3(0.86, 0.87, 0.88), r1);
	vec3 carpet = mix(vec3(0.20, 0.20, 0.21), vec3(0.38, 0.35, 0.31), hash(cell, 4.0));
	vec3 col;
	float depth = clamp(-p.z / room_depth, 0.0, 1.0);
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
		float door = step(abs(p.x - bay_w * (0.3 + 0.4 * hash(cell, 8.0))), 0.45) * step(p.y, 2.2) * step(hash(cell, 9.0), 0.4);
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
	vec3 inside = inside_avg;
	if (far < 0.99) {
		inside = room(c, vec3(f.x, f.y, 0.0), -tv, lit, day, lamp);
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
	float wsum = max(frame + span + glassm, 1e-4);
	ALBEDO = (frame_alb * frame + span_alb * span + glass_tint * glassm) / wsum;
	METALLIC = (frame_metal * frame + span_metal * span + reflectivity * glassm) / wsum;
	ROUGHNESS = (frame_rough * frame + span_rough * span + (0.035 + 0.02 * hash(c, 13.0)) * glassm) / wsum;
	EMISSION = inside * glassm * mix(1.0 - fres, (1.0 - fres * 0.6) * 1.5, tm_night) * transmit;
	// a crown's floodlights wash up its frames at night
	float crown = 1.0 - step(0.75, COLOR.a);
	EMISSION += crown_light * crown * tm_night * (0.35 + 0.9 * frame + 0.4 * span) * 1.8;
	// the street's shade at a building's foot (the city casts no shadows: too far for them)
	AO = mix(0.45, 1.0, smoothstep(0.0, 14.0, world_map > 0.5 ? wpos.y - NODE_POSITION_WORLD.y : UV.y));
	AO_LIGHT_AFFECT = 0.6;
}
