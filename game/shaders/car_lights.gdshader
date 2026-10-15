shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Car lamps. Vertex color RGB = unlit lens tint, A = lamp type:
//   1.0 headlight, 0.75 taillight, 0.5 reverse, 0.25 indicator (amber), 0.0 dark reflector.

uniform vec4 head_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float head_energy = 3.0;
uniform float tail_energy = 0.9;
uniform float brake = 0.0;
uniform float reverse = 0.0;

varying vec4 lamp;

void vertex() {
	lamp = COLOR;
}

void fragment() {
	float type = lamp.a;
	vec3 em = vec3(0.0);
	vec3 alb = lamp.rgb;
	if (type > 0.9) {
		em = head_color.rgb * head_energy;
		alb = vec3(0.9);
	} else if (type > 0.65) {
		em = vec3(1.0, 0.012, 0.02) * (tail_energy + brake * 3.5);
		alb = vec3(0.35, 0.0, 0.01);
	} else if (type > 0.4) {
		em = vec3(1.0, 0.98, 0.95) * reverse * 3.5;
		alb = vec3(0.8);
	} else if (type > 0.15) {
		em = vec3(1.0, 0.45, 0.02) * 0.9;
		alb = vec3(0.6, 0.3, 0.02);
	}
	ALBEDO = alb;
	METALLIC = 0.3;
	ROUGHNESS = 0.08;
	EMISSION = em;
}
