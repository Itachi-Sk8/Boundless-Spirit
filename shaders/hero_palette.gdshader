// Turns each of the hero's body parts grey until its color is earned.
//
// The hero art gives every body part its own hue, so a pixel's hue says which part it
// belongs to. Locked parts are drawn as grey at the pixel's own brightness, which keeps
// each part's shading. Low-saturation pixels (dust, slide and dash effects) pass through.
shader_type canvas_item;

// One switch per color, in unlock order. The game sets these from the game state.
uniform bool torso_orange = false;    // 1. Dash
uniform bool back_leg_yellow = false; // 2. Double jump
uniform bool back_arm_green = false;  // 3. Wall jump
uniform bool front_leg_red = false;   // 4. Slide
uniform bool front_arm_purple = false; // 5. Climb
uniform bool head_blue = false;       // 6. Spirit Phase

const float EFFECT_SATURATION = 0.25;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

bool part_unlocked(float hue_degrees) {
	if (hue_degrees < 15.0 || hue_degrees >= 330.0) return front_leg_red;
	if (hue_degrees < 40.0) return torso_orange;
	if (hue_degrees < 75.0) return back_leg_yellow;
	if (hue_degrees < 150.0) return back_arm_green;
	if (hue_degrees < 250.0) return head_blue;
	return front_arm_purple;
}

// COLOR arrives as texture times modulate. Classify by the raw texture so a modulate
// tint can't change which part a pixel belongs to, then grey the final color.
void fragment() {
	vec3 hsv = rgb_to_hsv(texture(TEXTURE, UV).rgb);
	if (hsv.y >= EFFECT_SATURATION && !part_unlocked(hsv.x * 360.0)) {
		COLOR.rgb = vec3(dot(COLOR.rgb, vec3(0.299, 0.587, 0.114)));
	}
}
