shader_type spatial;
#include "res://env/rt.gdshaderinc"
#include "res://env/tm_occlusion.gdshaderinc"
// Our car's surfaces, in the parts' own space (they move with the car and the wheels):
// mode 0 paint (metallic flakes under a clearcoat, a white stripe along the top), 1 carbon fibre
// (a 2x2 twill weave that catches the light by direction), 2 tyre (tread grooves and sipes, a
// lettering band on the sidewall), 3 the hypercar's paint and livery (its parts in visual
// coordinates: x to the left, y up from the ground, z forward). Fine detail fades out with distance.

uniform int mode = 0;
uniform vec3 colour : source_color = vec3(0.85, 0.08, 0.06);
uniform vec3 stripe_colour : source_color = vec3(0.95);
uniform float stripe_half = 0.07;    // the stripe's half width (m); 0 = none
uniform float flakes = 1.0;          // metallic flakes in the paint (0: plain, the white parts)
uniform float tyre_radius = 0.364;
uniform float tyre_half_width = 0.182;
uniform float ground_y = -0.441;     // the road under the body, in the parts' space (TmCarVisual.VIS)

varying vec3 opos;
varying vec3 onrm;
varying vec3 cwpos;
varying vec3 cwnrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
	cwpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	cwnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// 1 between lo and hi (antialiased over fw)
float band(float v, float lo, float hi, float fw) {
	return smoothstep(lo - fw, lo + fw, v) * (1.0 - smoothstep(hi - fw, hi + fw, v));
}

// The hypercar's livery: the paint; gloss black below a sill line that rises towards the tail
// (the chin, the sills, the tail under its light bar) and on the canopy round its glass; a white
// pinstripe over the sill; two white stripes along the top, nose to tail.
vec3 hyper_livery(vec3 paint, vec3 p, vec3 n) {
	vec3 black = vec3(0.012, 0.012, 0.014);
	vec3 white = vec3(0.93, 0.93, 0.94);
	vec3 fw = fwidth(p) + 1e-4;
	float sill = 0.21 + 0.05 * smoothstep(2.6, 1.6, p.z) + 0.06 * smoothstep(0.8, -1.0, p.z) + 0.12 * smoothstep(-1.4, -2.2, p.z);
	float low = 1.0 - smoothstep(sill - fw.y, sill + fw.y, p.y);
	float pin = band(p.y, sill + 0.010, sill + 0.024, fw.y);
	float ax = abs(p.x);
	// the canopy: over its glass's lower edge, inside its shoulders, from the windscreen's foot to a
	// line sweeping back down its flanks (the fin stays painted)
	float zrear = -0.36 - (1.06 - p.y) * 1.6;
	float canopy = smoothstep(0.70 - fw.y, 0.70 + fw.y, p.y) * (1.0 - smoothstep(0.50 - fw.x, 0.50 + fw.x, ax))
		* (1.0 - smoothstep(0.97 - fw.z, 0.97 + fw.z, p.z)) * smoothstep(zrear - fw.z, zrear + fw.z, p.z)
		* smoothstep(0.010, 0.016, ax);
	float stripes = (band(ax, 0.035, 0.105, fw.x)) * smoothstep(0.2, 0.4, n.y);
	vec3 col = mix(paint, black, max(low, canopy));
	col = mix(col, white, max(pin, stripes));
	return col;
}

void fragment() {
	// darker under bridges, roofs and gates (the map's sky occlusion); the body (paint, carbon) also
	// darker low down and on surfaces facing the road, which blocks their sky
	AO = tm_sky_visibility(cwpos, normalize(cwnrm));
	if (mode != 2) {
		float h = opos.y - ground_y;
		float facing = clamp(normalize(onrm).y * 0.5 + 0.5, 0.0, 1.0);
		AO *= mix(0.45, 1.0, smoothstep(0.1, 0.55, h)) * mix(0.55, 1.0, facing);
	}
	AO_LIGHT_AFFECT = 0.0;
	float dist = length(VERTEX);
	if (mode == 0 || mode == 3) {
		vec3 col = colour;
		if (mode == 3) {
			col = hyper_livery(colour, opos, normalize(onrm));
		} else if (stripe_half > 0.0 && onrm.y > 0.35) {
			float fw = fwidth(opos.x) + 1e-4;
			float s = 1.0 - smoothstep(stripe_half - fw, stripe_half + fw, abs(opos.x));
			float edge = 1.0 - smoothstep(0.012 - fw, 0.012 + fw, abs(abs(opos.x) - stripe_half - 0.02));
			col = mix(col, stripe_colour, s);
			col = mix(col, vec3(0.05), edge * (1.0 - s));
		}
		float flake = hash3(floor(opos * 900.0));
		// flakes only where one covers a pixel or more (smaller ones sparkled like frost)
		float fpx = length(fwidth(opos)) * 900.0;
		float fade = (1.0 - smoothstep(0.35, 1.0, fpx)) * flakes;
		ALBEDO = col;
		// painted, not chrome: a high metallic under a full clearcoat mirrored the horizon all
		// round the body (a "jelly" look)
		METALLIC = 0.12 + (flake - 0.5) * 0.2 * fade;
		ROUGHNESS = 0.36 + (flake - 0.5) * 0.15 * fade;
#if !defined(RT)
		CLEARCOAT = 0.85;             // (the RTX fork's hit shaders have no clearcoat)
		CLEARCOAT_ROUGHNESS = 0.06;
#endif
	} else if (mode == 1) {
		vec3 a = abs(onrm);
		vec2 uv = a.y > a.x && a.y > a.z ? opos.xz : (a.x > a.z ? opos.zy : opos.xy);
		uv *= 110.0;                           // 9 mm tows
		vec2 cell = floor(uv);
		vec2 f = fract(uv);
		bool along = mod(cell.x + floor(cell.y * 0.5) * 2.0 + cell.y, 4.0) < 2.0;
		float tow = along ? f.y : f.x;
		float ridge = 1.0 - pow(abs(tow - 0.5) * 2.0, 2.0);
		float fade = 1.0 - smoothstep(0.0, 0.35, fwidth(uv.x));
		// a faint weave (strong, it read as bricks or a maze)
		float sheen = mix(0.5, (along ? 0.58 : 0.42) * (0.7 + 0.3 * ridge), fade);
		ALBEDO = vec3(0.025, 0.026, 0.03) + vec3(0.04) * sheen;
		METALLIC = 0.35;
		ROUGHNESS = mix(0.4, 0.25 + 0.2 * (1.0 - ridge), fade);
#if !defined(RT)
		CLEARCOAT = 0.8;
		CLEARCOAT_ROUGHNESS = 0.1;
#endif
	} else {
		float r = length(opos.yz);
		float ang = atan(opos.z, opos.y);
		vec3 col = vec3(0.035, 0.035, 0.04);
		float rough = 0.9;
		float fade = 1.0 - smoothstep(3.0, 14.0, dist);
		if (r > tyre_radius * 0.9 && abs(opos.x) < tyre_half_width * 0.85) {
			// the tread: two circumferential grooves and sipes across
			float g = abs(abs(opos.x) - tyre_half_width * 0.35);
			float groove = 1.0 - smoothstep(0.008, 0.014, g);
			float sipe = step(0.85, fract(ang * 18.0 / 3.14159 + abs(opos.x) * 6.0));
			col *= 1.0 - (groove * 0.6 + sipe * 0.35) * fade;
			rough = 0.95;
		} else if (r > tyre_radius * 0.74 && r < tyre_radius * 0.84) {
			// the sidewall's lettering: two words a side, each a row of letter-like blocks of
			// varying width, in a dull grey (moulded rubber, not paint)
			float u = ang / 6.28318 + 0.5;
			float word = fract(u * 2.0);
			float inword = step(0.08, word) * step(word, 0.36);
			float g = fract(word * 34.0);
			float stem = step(0.18, g) * step(g, 0.72 + 0.2 * fract(sin(floor(word * 34.0) * 12.9) * 43758.5));
			float band = smoothstep(0.0, 0.15, (r / tyre_radius - 0.74) / 0.10) * smoothstep(1.0, 0.85, (r / tyre_radius - 0.74) / 0.10);
			col = mix(col, vec3(0.16), inword * stem * band * 0.9 * fade);
		}
		ALBEDO = col;
		ROUGHNESS = rough;
	}
}
