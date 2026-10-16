shader_type sky;
// The Stadium's Day sky (our own shader): a vertical gradient through the mood's sky colours
// (zenith at the first stop, the horizon at the last, linear in elevation), the sun's disc and
// glow, and a layer of fair-weather clouds (value-noise fbm on a plane) between the mood's darkest
// and brightest cloud colours. Colours arrive linear (set by TmStadiumEnv).

uniform vec3 stops[17];
uniform vec3 cloud_lo = vec3(0.55, 0.64, 0.70);
uniform vec3 cloud_hi = vec3(0.95, 0.96, 0.96);
uniform float cloud_cover = 0.52;    // 0 = overcast .. 1 = clear
uniform float cloud_scale = 0.9;
uniform vec2 cloud_offset = vec2(0.0);
uniform float sun_size = 0.9995;     // cos of the disc's radius
uniform float sun_glow = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

vec3 gradient(float elev) {
	float t = clamp(1.0 - elev / 1.5707963, 0.0, 1.0) * 16.0;
	int i = int(floor(t));
	if (i >= 16) {
		return stops[16];
	}
	return mix(stops[i], stops[i + 1], t - float(i));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float elev = asin(clamp(d.y, -1.0, 1.0));
	vec3 col = gradient(max(elev, 0.0));
	vec3 sun_dir = LIGHT0_DIRECTION;
	float cs = dot(d, sun_dir);
	if (LIGHT0_ENABLED) {
		col += LIGHT0_COLOR * sun_glow * pow(max(cs, 0.0), 64.0);
		col += LIGHT0_COLOR * 0.08 * pow(max(cs, 0.0), 6.0);
	}
	if (d.y > 0.01) {
		vec2 p = d.xz / (d.y + 0.08) * cloud_scale + cloud_offset;
		float n = fbm(p);
		float dens = smoothstep(cloud_cover, cloud_cover + 0.22, n);
		float lit = clamp(0.5 + 2.2 * (n - fbm(p + sun_dir.xz * 0.06)), 0.0, 1.0);
		vec3 cc = mix(cloud_lo, cloud_hi, lit);
		dens *= smoothstep(0.01, 0.22, d.y);
		col = mix(col, cc, dens * 0.92);
	}
	if (LIGHT0_ENABLED && cs > sun_size) {
		col = LIGHT0_COLOR * 6.0;
	}
	COLOR = col;
}
