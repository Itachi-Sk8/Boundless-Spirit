// The glow filling a Spirit Room's doorway: soft bands of light drifting upward, brightest in
// the middle and fading at the edges, in the color that waits inside.
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.92, 0.5, 0.2, 1.0);
uniform float speed = 1.4;

void fragment() {
	vec2 uv = UV;
	// Fade toward the sides and the top so the glow sits inside the opening.
	float edge = smoothstep(0.0, 0.3, uv.x) * smoothstep(1.0, 0.7, uv.x) * smoothstep(0.0, 0.25, uv.y);
	float bands = 0.5 + 0.5 * sin(uv.y * 14.0 + TIME * speed * 3.0 + sin(uv.x * 7.0 + TIME * speed) * 1.5);
	float shimmer = 0.5 + 0.5 * sin(TIME * speed * 2.0 + uv.x * 3.0);
	float alpha = edge * (0.28 + 0.22 * bands + 0.1 * shimmer);
	// Pixel-art friendly: snap the light to a few steps.
	alpha = floor(alpha * 8.0) / 8.0;
	COLOR = vec4(glow_color.rgb * (0.85 + 0.3 * bands), alpha);
}
