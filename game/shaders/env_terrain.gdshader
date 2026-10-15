shader_type spatial;
// Ground for all themes. UV = world XZ, UV2.x = distance to the road edge (m).
// mode 0 city: wet asphalt lots + paved sidewalks with puddles.
// mode 1 arena: glossy dark stadium floor with a neon grid.
// mode 2 coast: grass, dry brush, rock on slopes, sand and surf near sea level.

uniform int mode = 0;
uniform float sea_level = 0.0;
uniform float wetness = 1.0;
uniform vec3 grid_color : source_color = vec3(0.0, 0.9, 1.0);
uniform vec3 grid_color2 : source_color = vec3(1.0, 0.17, 0.84);
uniform float grid_energy = 1.4;

varying vec3 wpos;
varying vec3 wnrm;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += vnoise(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	float ed = UV2.x;
	vec3 alb;
	float rough;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	if (mode == 0) {
		// sidewalk band next to the road, then dark lots
		float n = fbm(p * 0.15);
		float tiles = 0.0;
		vec2 tp = fract(p / 1.5);
		vec2 tw = fwidth(p / 1.5);
		float line = smoothstep(0.0, tw.x * 1.5 + 0.02, tp.x) * smoothstep(0.0, tw.y * 1.5 + 0.02, tp.y);
		float walk = 1.0 - smoothstep(4.0, 5.0, ed);
		vec3 asphalt = vec3(0.035, 0.035, 0.042) * (0.7 + 0.6 * n);
		vec3 paving = vec3(0.09, 0.085, 0.09) * mix(0.55, 1.0, line) * (0.8 + 0.4 * h21(floor(p / 1.5)));
		alb = mix(asphalt, paving, walk);
		// curb line
		float curb = smoothstep(0.0, 0.25, ed) * (1.0 - smoothstep(0.35, 0.6, ed));
		alb = mix(alb, vec3(0.16), curb);
		float puddle = smoothstep(0.52, 0.6, fbm(p * 0.07 + 3.0));
		rough = mix(mix(0.45, 0.3, walk), 0.03, puddle * wetness);
		alb *= mix(1.0, 0.45, puddle);
		metal = 0.0;
	} else if (mode == 1) {
		float n = fbm(p * 0.05);
		alb = vec3(0.012, 0.012, 0.02) * (0.8 + 0.4 * n);
		rough = 0.18 + 0.12 * n;
		// neon grid: thin lines every 10 m, brighter every 50 m
		vec2 g = p / 10.0;
		vec2 fw = fwidth(g);
		vec2 gl = abs(fract(g - 0.5) - 0.5) / max(fw, vec2(0.0001));
		float l1 = 1.0 - min(min(gl.x, gl.y), 1.0);
		vec2 g2 = p / 50.0;
		vec2 fw2 = fwidth(g2);
		vec2 gl2 = abs(fract(g2 - 0.5) - 0.5) / max(fw2 * 1.6, vec2(0.0001));
		float l2 = 1.0 - min(min(gl2.x, gl2.y), 1.0);
		float fade = clamp(1.0 - max(fw.x, fw.y) * 3.0, 0.0, 1.0);
		float t = 0.5 + 0.5 * sin(p.x * 0.004 + p.y * 0.003);
		vec3 gc = mix(grid_color, grid_color2, t);
		float near_road = smoothstep(1.0, 6.0, ed);
		emit = gc * grid_energy * (l1 * 0.25 * fade + l2 * 0.9) * near_road;
		alb = mix(alb, vec3(0.03), 1.0 - near_road);
	} else {
		float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
		float n = fbm(p * 0.02);
		float n2 = fbm(p * 0.13 + 7.0);
		vec3 grass = mix(vec3(0.12, 0.16, 0.05), vec3(0.23, 0.22, 0.09), n);
		vec3 brush = mix(vec3(0.24, 0.19, 0.11), vec3(0.32, 0.27, 0.16), n2);
		vec3 rock = mix(vec3(0.17, 0.14, 0.13), vec3(0.3, 0.26, 0.23), n2) * (0.8 + 0.4 * fbm(wpos.xy * 0.2 + wpos.zy * 0.2));
		vec3 sand = vec3(0.55, 0.46, 0.33) * (0.85 + 0.2 * n2);
		alb = mix(grass, brush, smoothstep(0.35, 0.65, n + n2 * 0.3));
		float rk = smoothstep(0.32, 0.5, slope + (n2 - 0.5) * 0.25);
		alb = mix(alb, rock, rk);
		rough = mix(0.9, 0.75, rk);
		float hs = wpos.y - sea_level;
		float beach = 1.0 - smoothstep(1.5, 4.5 + n * 3.0, hs);
		alb = mix(alb, mix(sand, rock * 0.8, rk * 0.6), beach);
		// wet band and foam right at the water line
		float wet = 1.0 - smoothstep(0.0, 1.2, hs);
		alb *= mix(1.0, 0.55, wet);
		rough = mix(rough, 0.25, wet);
		float foam = (1.0 - smoothstep(0.0, 0.5, abs(hs - 0.25 - 0.25 * sin(TIME * 0.8 + p.x * 0.05 + p.y * 0.03)))) * step(-1.0, hs);
		alb = mix(alb, vec3(0.85, 0.85, 0.82), foam * 0.7);
		// gravel shoulder next to the road
		float shoulder = 1.0 - smoothstep(1.0, 3.5, ed);
		alb = mix(alb, vec3(0.2, 0.18, 0.17) * (0.8 + 0.4 * n2), shoulder);
	}
	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
