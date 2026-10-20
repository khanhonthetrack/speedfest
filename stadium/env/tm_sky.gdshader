shader_type sky;
// The Stadium's Day sky (our own shader): a vertical gradient through the mood's sky colours
// (zenith at the first stop, the horizon at the last, linear in elevation), the sun's disc and
// glow, and a layer of fair-weather clouds (value-noise fbm on a plane) between the mood's darkest
// and brightest cloud colours (a seamless noise texture, three octaves). Colours arrive linear
// (set by TmStadiumEnv). At night: the Night mood's gradient, stars, the moon's disc.

uniform vec3 stops[17];
uniform vec3 cloud_lo = vec3(0.55, 0.64, 0.70);
uniform vec3 cloud_hi = vec3(0.95, 0.96, 0.96);
uniform float cloud_cover = 0.50;    // 0 = overcast .. 1 = clear
uniform float cloud_scale = 0.9;
uniform vec2 cloud_offset = vec2(0.0);
uniform float sun_size = 0.9995;     // cos of the disc's radius
uniform float sun_glow = 0.35;
uniform float disc_energy = 6.0;     // the sun's (or, at night, the moon's) disc
uniform float stars = 0.0;           // night: a starfield above the haze

uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;

// fair-weather cloud density: three octaves of a seamless noise texture
float fbm(vec2 p) {
	return texture(cloud_noise, p * 0.11).r * 0.55 + texture(cloud_noise, p * 0.29 + vec2(0.37, 0.11)).r * 0.3
		+ texture(cloud_noise, p * 0.83 + vec2(0.71, 0.53)).r * 0.15;
}

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
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
	if (stars > 0.0 && d.y > 0.0) {
		// a star in one cell of a fine grid of directions in three hundred
		vec3 q = d * 300.0;
		vec3 cell = floor(q);
		float h = h3(cell);
		if (h > 0.996) {
			vec3 sp = cell + 0.5 + (vec3(h3(cell + 1.3), h3(cell + 2.7), h3(cell + 4.1)) - 0.5) * 0.6;
			float b = smoothstep(0.4, 0.0, length(q - sp)) * (0.3 + 2.5 * pow(h3(cell + 7.7), 3.0));
			col += vec3(0.9, 0.93, 1.0) * b * stars * smoothstep(0.03, 0.25, d.y);
		}
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
		col = LIGHT0_COLOR * disc_energy;
	}
	COLOR = col;
}
