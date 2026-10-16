shader_type spatial;
// SpeedFest gameplay puddle (weather). Works on Forward+ and Compatibility.
// UV  in [-1, 1]^2 over the puddle at its STORM size; `extent` < 1 shrinks it (rain).
// UV2 = meters (x across, y along) for ripples.
// Opaque with discard (not alpha-blended), so Forward+ SSR mirrors the neon world in it; the
// fresnel sheen keeps it readable where there is no SSR (web).
render_mode depth_draw_opaque, cull_back;

uniform float extent = 1.0;
uniform float rain = 1.0;                  // ripple strength (0 = still water)
uniform vec4 water_color : source_color = vec4(0.015, 0.02, 0.03, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.45, 0.6, 1.0, 1.0);   // horizon glow tint
uniform vec4 light_color : source_color = vec4(0.2, 0.9, 1.0, 1.0);   // reflected light streaks
uniform float sheen = 1.0;                 // fake reflection strength (lower where SSR is on)
uniform float rim_glow = 0.4;              // thin bright rim so puddles read at speed
#if !defined(RT)
instance uniform float seed = 0.0;
#endif

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Gradient of one layer of raindrop rings (one ring per cell, random phase).
vec2 ripple_grad(vec2 m, float cell, float t, float salt) {
	vec2 g = floor(m / cell);
	vec2 c = (g + vec2(hash(g + salt), hash(g + salt + 7.3)) * 0.6 + 0.2) * cell;
	float ph = fract(t * (0.9 + 0.5 * hash(g + salt + 3.1)) + hash(g + salt + 1.7));
	vec2 dv = m - c;
	float dist = length(dv) + 1e-4;
	float r = ph * cell * 0.55;
	float x = dist - r;
	// ring profile: a short damped wave around radius r, fading as it grows
	float dh = cos(x * 60.0) * exp(-abs(x) * 22.0) * (1.0 - ph);
	return dv / dist * dh;
}

void fragment() {
#if defined(RT)
	// RTX fork: instance uniforms don't exist in ray-tracing hit shaders; seed from the position
	float seed = fract(dot(MODEL_MATRIX[3].xz, vec2(0.0173, 0.0291))) * 3.0 + 0.11;
#endif
	vec2 uv = UV / max(extent, 0.001);
	float n = vnoise(UV * 2.1 + seed * 13.7) * 0.65 + vnoise(UV * 5.3 + seed * 5.1) * 0.35;
	float e = dot(uv, uv) + (n - 0.5) * 0.45;
#if !defined(RT)
	// Ray-tracing hit shaders have no discard. (Track hides puddles under path tracing for now:
	// docs/RTX.md, "Known issues".)
	if (e > 1.0) {
		discard;
	}
#endif
	float rim = smoothstep(0.8, 1.0, e);

	vec2 grad = vec2(0.0);
	if (rain > 0.0) {
		grad += ripple_grad(UV2, 0.9, TIME * 1.3, seed);
		grad += ripple_grad(UV2 + vec2(0.45, 0.31), 0.7, TIME * 1.7, seed + 11.0) * 0.7;
		grad *= rain;
	}
	NORMAL_MAP = normalize(vec3(-grad.x * 0.35, -grad.y * 0.35, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	// Fake wet-street reflection from the reflected view ray (world space): a bright horizon band
	// (city glow / sunset) plus vertical streaks of lights, shimmered by the ripples.
	vec3 nv = normalize(NORMAL + (VIEW_MATRIX * vec4(grad.x, 0.0, grad.y, 0.0)).xyz * 0.25);
	vec3 r = reflect(-VIEW, nv);
	vec3 rw = (INV_VIEW_MATRIX * vec4(r, 0.0)).xyz;
	float el = rw.y;
	float az = atan(rw.z, rw.x);
	float band = exp(-abs(el) * 5.0);
	float streak = smoothstep(0.62, 0.95, vnoise(vec2(az * 18.0 + seed * 3.0, 0.5))) * exp(-abs(el) * 2.2);
	vec3 refl = sheen_color.rgb * band * 0.9 + light_color.rgb * streak * 1.6;
	float fres = 0.04 + 0.96 * pow(1.0 - clamp(dot(nv, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(water_color.rgb, water_color.rgb * 3.0, rim);
	ROUGHNESS = mix(0.015, 0.25, rim);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = refl * fres * sheen + sheen_color.rgb * rim * rim_glow;
}
