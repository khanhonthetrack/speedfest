shader_type spatial;
// Our car's surfaces, in the parts' own space (they move with the car and the wheels):
// mode 0 paint (metallic flakes under a clearcoat, a white stripe along the top), 1 carbon fibre
// (a 2x2 twill weave that catches the light by direction), 2 tyre (tread grooves and sipes, a
// lettering band on the sidewall). Fine detail fades out with distance.

uniform int mode = 0;
uniform vec3 colour : source_color = vec3(0.85, 0.08, 0.06);
uniform vec3 stripe_colour : source_color = vec3(0.95);
uniform float stripe_half = 0.07;    // the stripe's half width (m); 0 = none
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
		float fade = 1.0 - smoothstep(2.0, 10.0, dist);
		ALBEDO = col;
		METALLIC = 0.55 + (flake - 0.5) * 0.4 * fade;
		ROUGHNESS = 0.32 + (flake - 0.5) * 0.2 * fade;
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.06;
	} else if (mode == 1) {
		vec3 a = abs(onrm);
		vec2 uv = a.y > a.x && a.y > a.z ? opos.xz : (a.x > a.z ? opos.zy : opos.xy);
		uv *= 55.0;                            // 18 mm tows
		vec2 cell = floor(uv);
		vec2 f = fract(uv);
		bool along = mod(cell.x + floor(cell.y * 0.5) * 2.0 + cell.y, 4.0) < 2.0;
		float tow = along ? f.y : f.x;
		float ridge = 1.0 - pow(abs(tow - 0.5) * 2.0, 2.0);
		float fade = 1.0 - smoothstep(0.0, 0.5, fwidth(uv.x));
		float sheen = mix(0.5, (along ? 0.75 : 0.35) * ridge, fade);
		ALBEDO = vec3(0.025, 0.026, 0.03) + vec3(0.05) * sheen;
		METALLIC = 0.35;
		ROUGHNESS = mix(0.4, 0.25 + 0.2 * (1.0 - ridge), fade);
		CLEARCOAT = 0.8;
		CLEARCOAT_ROUGHNESS = 0.1;
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
			// the sidewall's lettering band: dashes like letters, in pale grey
			float letters = step(0.45, fract(ang * 40.0 / 3.14159)) * step(0.6, sin(ang * 3.0) * 0.5 + 0.5);
			col = mix(col, vec3(0.55), letters * 0.8 * fade);
		}
		ALBEDO = col;
		ROUGHNESS = rough;
	}
}
