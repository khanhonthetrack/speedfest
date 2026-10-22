// The underglow's colours (TmUnderglow), shared by its tubes and halos: the gas's colour at a place
// t along the car (0 the nose, 1 the tail): the front's fading to the rear's (one colour: both the
// same), or a rainbow whose hues flow along the car (TmUnderglow.colour_at does the same sums).
uniform vec4 front : source_color = vec4(0.1, 0.4, 1.0, 1.0);
uniform vec4 rear : source_color = vec4(0.1, 0.4, 1.0, 1.0);
uniform float rainbow = 0.0;
uniform float phase = 0.0;
uniform float span = 0.45;

vec3 hue(float h) {
	vec3 c = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

vec3 gas(float t) {
	if (rainbow > 0.5) {
		return hue(fract(phase - span * t));
	}
	return mix(front.rgb, rear.rgb, smoothstep(0.0, 1.0, t));
}
