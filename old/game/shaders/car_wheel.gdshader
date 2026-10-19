shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Wheels and calipers. Vertex color R * 8 = part class:
//   0 tire tread, 1 rim (rim_color), 2 polished lip, 3 brake disc, 4 caliper, 5 dark hub/nuts,
//   6 tire sidewall (with molded lettering band). UV.x = angle 0..1, UV.y = profile position.

uniform vec4 rim_color : source_color = vec4(0.85, 0.85, 0.85, 1.0);
uniform vec4 caliper_color : source_color = vec4(0.9, 0.05, 0.05, 1.0);

varying float cls;
varying vec3 lpos;

void vertex() {
	cls = COLOR.r * 8.0;
	lpos = VERTEX;
}

void fragment() {
	int c = int(cls + 0.5);
	vec3 alb = vec3(0.03);
	float metal = 0.0;
	float rough = 0.85;
	if (c == 0) {
		// tread: circumferential grooves + blocks
		float a = UV.x * 120.0;
		float g = abs(fract(lpos.x * 22.0) - 0.5);
		float groove = 1.0 - smoothstep(0.07, 0.12, g);
		float blk = step(0.85, fract(a + step(0.5, fract(lpos.x * 11.0)) * 0.5));
		alb = vec3(0.028) * (1.0 - 0.5 * max(groove, blk));
		rough = 0.9;
	} else if (c == 1) {
		alb = rim_color.rgb;
		metal = 0.85;
		rough = 0.28;
	} else if (c == 2) {
		alb = mix(rim_color.rgb, vec3(0.95), 0.75);
		metal = 1.0;
		rough = 0.08;
	} else if (c == 3) {
		float r = length(lpos.yz);
		float slots = step(0.92, fract(atan(lpos.y, lpos.z) * 3.0 + r * 9.0));
		alb = vec3(0.32) * (0.85 + 0.15 * sin(r * 600.0)) * (1.0 - 0.4 * slots);
		metal = 0.9;
		rough = 0.4;
	} else if (c == 4) {
		alb = caliper_color.rgb;
		metal = 0.2;
		rough = 0.3;
	} else if (c == 5) {
		alb = vec3(0.05);
		metal = 0.7;
		rough = 0.35;
	} else {
		// sidewall: molded letters ring
		float ring = smoothstep(0.42, 0.45, UV.y) * (1.0 - smoothstep(0.58, 0.61, UV.y));
		float letters = step(0.45, fract(UV.x * 28.0)) * step(0.15, fract(UV.x * 3.0));
		alb = vec3(0.035) + vec3(0.12) * ring * letters;
		rough = 0.8;
	}
	ALBEDO = alb;
	METALLIC = metal;
	ROUGHNESS = rough;
}
