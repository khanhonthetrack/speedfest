shader_type canvas_item;
// A HUD pill as TMNF draws them (M10-5): a rounded rectangle filled with a vertical gradient,
// each corner its own radius (pills hung from a screen edge keep that side square).

uniform vec4 top_colour : source_color = vec4(0.0, 0.0, 0.0, 0.25);
uniform vec4 bottom_colour : source_color = vec4(0.0, 0.0, 0.0, 0.25);
uniform vec4 radii = vec4(26.0, 26.0, 0.0, 0.0);    // top left, top right, bottom right, bottom left (px)
uniform vec2 rect_size = vec2(300.0, 60.0);

void fragment() {
	vec2 p = UV * rect_size;
	vec2 c = rect_size * 0.5;
	vec2 q = p - c;
	// the corner's radius for this quadrant
	float r = q.x < 0.0 ? (q.y < 0.0 ? radii.x : radii.w) : (q.y < 0.0 ? radii.y : radii.z);
	vec2 d = abs(q) - c + vec2(r);
	float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
	float a = clamp(0.5 - dist, 0.0, 1.0);
	vec4 col = mix(top_colour, bottom_colour, UV.y);
	COLOR = vec4(col.rgb, col.a * a);
}
