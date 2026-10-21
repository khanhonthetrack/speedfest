shader_type spatial;
render_mode cull_back;
// An LED billboard's screen (TmCitySigns): the adverts (env/tm_adverts.gd), each board its own,
// the next sliding in every PERIOD seconds; the LED pixels show up close (dark gaps between them),
// fading to the picture far off. Bright by day, brighter at night (the global tm_night).

uniform sampler2D ads : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ads_fill : source_color, filter_linear, repeat_disable;
instance uniform float board = 0.0;     // each board its own ads and moment
global uniform float tm_night;

const float PERIOD = 10.0;
const float WIPE = 0.7;

void fragment() {
	float t = TIME + board * 3.7;
	float slot = floor(t / PERIOD);
	float since = t - slot * PERIOD;
	float first = floor(board * 16.0);
	float ad = mod(slot * 7.0 + first, 16.0);
	float prev = mod((slot - 1.0) * 7.0 + first, 16.0);
	float use = UV.x < since / WIPE ? ad : prev;
	vec3 c = texture(ads, vec2((use + clamp(UV.x, 0.002, 0.998)) / 16.0, UV.y)).rgb;
	vec2 cell = fract(UV * vec2(256.0, 128.0));
	float fwp = max(fwidth(UV.x) * 256.0, fwidth(UV.y) * 128.0);
	float lit = smoothstep(0.0, 0.2, min(min(cell.x, 1.0 - cell.x), min(cell.y, 1.0 - cell.y)));
	lit = mix(lit, 0.8, clamp(fwp * 1.5, 0.0, 1.0));
	ALBEDO = vec3(0.02);
	ROUGHNESS = 0.22;
	SPECULAR = 0.45;
	EMISSION = c * lit * mix(1.1, 2.4, tm_night);
}
