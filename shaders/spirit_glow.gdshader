// Draws a sprite as a glowing blue spirit: its brightness becomes shades of the head's blue,
// with a soft pulse.
shader_type canvas_item;

uniform vec3 glow_color : source_color = vec3(0.37, 0.80, 0.89);
uniform float pulse_speed = 6.0;
uniform float alpha = 0.85;

void fragment() {
	float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);
	COLOR.rgb = mix(glow_color, vec3(1.0), luma * 0.6) * pulse;
	COLOR.a *= alpha;
}
