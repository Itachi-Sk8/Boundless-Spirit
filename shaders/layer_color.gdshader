// The world's color, layer by layer. Each layer of the world (sky, far hills, near forest,
// trees behind, front decoration, ground and gameplay, hazards) is drawn grey, with its color
// mixed back in by a strength from 0 to 1. The strengths are global, set by WorldColor from
// the orbs collected, so every room and the backdrop follow them at once.
shader_type canvas_item;

// Strengths: x sky, y far hills, z near forest, w trees behind.
global uniform vec4 world_color_back;
// Strengths: x front decoration, y ground and gameplay, z hazards, w unused.
global uniform vec4 world_color_front;

// Which layer this is: 0 sky, 1 far hills, 2 near forest, 3 trees behind,
// 4 front decoration, 5 ground and gameplay, 6 hazards.
uniform int layer = 5;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

float strength() {
	if (layer == 0) return world_color_back.x;
	if (layer == 1) return world_color_back.y;
	if (layer == 2) return world_color_back.z;
	if (layer == 3) return world_color_back.w;
	if (layer == 4) return world_color_front.x;
	if (layer == 5) return world_color_front.y;
	return world_color_front.z;
}

void fragment() {
	COLOR.rgb = mix(vec3(dot(COLOR.rgb, LUMA)), COLOR.rgb, strength());
}
