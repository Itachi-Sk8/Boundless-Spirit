//Get Player Movement
var _keyLeft = keyboard_check(vk_left) or keyboard_check(ord("A"));
var _keyRight = keyboard_check(vk_right) or keyboard_check(ord("D"));
var _keyJump = keyboard_check_pressed(vk_space);


//Gamepad Controls
if (_keyLeft) or (_keyRight) or (_keyJump)
{
	controller = 0;
}

if (abs(gamepad_axis_value(0,gp_axislh)) > 0.2)
{
	_keyLeft = abs(min(gamepad_axis_value(0,gp_axislh), 0));
	_keyRight = max(gamepad_axis_value(0,gp_axislh), 0);
	controller = 1;
}

if (gamepad_button_check(0,gp_face1))
{
	_keyJump = 1;
	controller = 1;
}

//Calculate Movement (Horizontal)
hsp = (_keyRight - _keyLeft) * hspWalk;

//Calculate Movement (Vertical)
vsp = vsp + grv;

//Work out if we should jump
if (canJump --> 0) and (_keyJump)
{
	vsp = vspJump;
	canJump = 0;
}

//Collide and Move

	//Horizontal Collision
	if (place_meeting(x + hsp,y,obj_Wall))
	{
		while (abs(hsp) > 0.1)
		{
			hsp*= 0.5;
			if (!place_meeting(x + hsp, y, obj_Wall)) x += hsp;
		}
		hsp = 0;
	}
	x += hsp;

	//Vertical Collision
	if (place_meeting(x,y + vsp,obj_Wall))
	{
		if (vsp > 0) canJump = 4;
		while (abs(vsp) > 0.1)
		{
			vsp*= 0.5;
			if (!place_meeting(x, y + vsp, obj_Wall)) x += vsp;
		}
		vsp = 0;
	}
	y += vsp;
	
// Animation 
if (!place_meeting(x,y+1,obj_Wall))
{
	sprite_index = spr_Player_Jump_Test;
	image_speed = 0;
	if (sign (vsp) > 0) image_index = 1; else image_index = 0;
} 
else 
{
	image_speed = 1;
	if (hsp == 0)
		{
			sprite_index = spr_Player_Idle;
		} 
		else 
		{
			sprite_index = spr_Player_Walk;
		}
}
//Animation Direction
if (hsp != 0) image_xscale = sign(hsp);
