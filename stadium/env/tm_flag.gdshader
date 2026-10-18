shader_type spatial;
render_mode cull_disabled;
// The Stadium's flags (env/tm_stadium_build.gd): a cell of the flags atlas (stadium/tools/texgen/
// flags.py) on a subdivided plane that waves in the wind, more towards its free end; seen from
// behind it shows mirrored, as a real flag does. Per flag (instance uniforms): its cell and phase.

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
instance uniform vec4 cell = vec4(0.0, 0.0, 1.0, 1.0);   // u0, v0, du, dv in the atlas
instance uniform float phase = 0.0;
uniform float length_m = 26.0;
uniform float amp = 1.1;             // the wave's height at the free end (m)
uniform float wave_m = 11.0;         // its length
uniform float speed = 1.3;           // cycles per second

varying float wave_shade;

void vertex() {
	float x = VERTEX.x + length_m * 0.5;            // 0 at the pole
	float t = clamp(x / length_m, 0.0, 1.0);
	float k = 6.2831853 / wave_m;
	float a = TIME * speed * 6.2831853 - x * k + phase;
	float reach = amp * t * (0.6 + 0.4 * t);
	VERTEX.z += sin(a) * reach + sin(a * 0.43 + VERTEX.y * 0.2) * 0.25 * t;
	VERTEX.y -= t * t * 0.5;                        // the free end sags a little
	float slope = -cos(a) * reach * k;
	NORMAL = normalize(vec3(-slope, 0.0, 1.0));
	wave_shade = 0.82 + 0.18 * cos(a);
}

void fragment() {
	vec2 uv = cell.xy + UV * cell.zw;
	ALBEDO = texture(atlas, uv).rgb * wave_shade;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.35);                         // thin cloth: the sun shows through
}
