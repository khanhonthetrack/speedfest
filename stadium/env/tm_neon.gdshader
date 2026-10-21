shader_type spatial;
render_mode cull_back;
// A neon blade sign (TmCitySigns): a dark box whose broad faces carry a word in glass tubes, one
// letter under the next (each letter tubes on a 9-segment grid, chosen by the word's hash), and a
// tube round the face's edge. The tube colour is the vertex colour; faces whose colour alpha is
// under 0.5 are the box's plain sides. UV: x across the face (0..1), y metres down from the top;
// UV2.x the face's height (m).
// The tubes glow (bloom carries their halo), faintly by day, brightly at night (tm_night).

global uniform float tm_night;
instance uniform float word = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec3 tube = COLOR.rgb;
	ALBEDO = vec3(0.03, 0.03, 0.035);
	METALLIC = 0.5;
	ROUGHNESS = 0.35;
	if (COLOR.a > 0.5) {
		float width = 1.6;
		vec2 p = vec2(UV.x * width, UV.y);              // metres on the face
		float h = 1.25;                                 // a letter's height
		float li = floor((p.y - 0.25) / h);
		vec2 q = vec2((p.x - width * 0.5) / 0.8 + 0.5, (p.y - 0.25 - li * h) / 1.0);    // the glyph box 0..1
		vec2 P[6] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 0.5), vec2(1.0, 0.5), vec2(0.0, 1.0), vec2(1.0, 1.0));
		float d = 9.0;
		float letters = floor(hash(vec2(word, 0.0)) * 3.0) + 4.0;
		if (li >= 0.0 && li < letters) {
			float bits = floor(hash(vec2(word, li + 1.0)) * 448.0) + 63.0;      // at least a few tubes
			for (int k = 0; k < 9; k++) {
				if (mod(floor(bits / pow(2.0, float(k))), 2.0) < 0.5) {
					continue;
				}
				vec2 a;
				vec2 b;
				if (k == 0) { a = P[0]; b = P[1]; }
				else if (k == 1) { a = P[1]; b = P[3]; }
				else if (k == 2) { a = P[3]; b = P[5]; }
				else if (k == 3) { a = P[4]; b = P[5]; }
				else if (k == 4) { a = P[2]; b = P[4]; }
				else if (k == 5) { a = P[0]; b = P[2]; }
				else if (k == 6) { a = P[2]; b = P[3]; }
				else if (k == 7) { a = P[0]; b = P[3]; }
				else { a = P[2]; b = P[5]; }
				d = min(d, seg(q, a, b));
			}
			d *= 0.8;                                    // back to metres (roughly)
		}
		// the tube round the face's edge
		float edge = min(min(p.x - 0.08, width - 0.08 - p.x), min(p.y - 0.08, UV2.x - 0.08 - p.y));
		d = min(d, abs(edge));
		float fw = fwidth(p.y);
		float core = 1.0 - smoothstep(0.03, 0.03 + fw * 1.5, d);
		float halo = exp(-d * 22.0);
		ALBEDO = mix(ALBEDO, tube * 0.5 + 0.3, core);
		EMISSION = tube * (core * mix(1.6, 7.0, tm_night) + halo * mix(0.15, 1.1, tm_night));
	}
}
