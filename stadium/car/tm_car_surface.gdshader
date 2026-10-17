shader_type spatial;
#include "res://env/rt.gdshaderinc"
// Our car's surfaces, in the parts' own space (they move with the car and the wheels):
// mode 0 paint (metallic flakes under a clearcoat, a white stripe along the top), 1 carbon fibre
// (a 2x2 twill weave that catches the light by direction), 2 tyre (tread grooves and sipes, a
// lettering band on the sidewall). Fine detail fades out with distance.

uniform int mode = 0;
uniform vec3 colour : source_color = vec3(0.85, 0.08, 0.06);
uniform vec3 stripe_colour : source_color = vec3(0.95);
uniform float stripe_half = 0.07;    // the stripe's half width (m); 0 = none
uniform float flakes = 1.0;          // metallic flakes in the paint (0: plain, the white parts)
uniform float tyre_radius = 0.364;
uniform float tyre_half_width = 0.182;

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	float dist = length(VERTEX);
	if (mode == 0) {
		vec3 col = colour;
		if (stripe_half > 0.0 && onrm.y > 0.35) {
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
		CLEARCOAT = 0.5;              // (the RTX fork's hit shaders have no clearcoat)
		CLEARCOAT_ROUGHNESS = 0.12;
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
