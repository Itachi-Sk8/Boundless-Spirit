//Custom Functions for Player
function setOnGround(_val = true)
{
	if _val == true
	{
	onGround = true;
	coyoteHangTimer = coyoteHangFrames;
	} else {
		onGround = false;
		coyoteHangTimer = 0;
	}
}

//control setup
controlsSetup();


//Sprites
maskSpr = spr_Player_Idle;
idleSpr = spr_Player_Idle;
walkSpr = spr_Player_Walk;
runSpr = spr_Player_Run;
jumpSpr = spr_Player_Jump;
doublejumpSpr = spr_Player_AirSpin;

//Moving
face = 1;
moveDir = 0;
runType = 0;
moveSpd[0] = 2;
moveSpd[1] = 3.5;
xspd = 0;
xspd_walljump = 4;
yspd = 0;
yspd_walljump = -5;

//Jumping
grav = 0.275;
termVel = 8;
onGround = true;
jumpMax = 2;
jumpCount = 0;
jumpHoldTimer = 0;
dashSpd = 90;
dashDuration = 0;

//Jump Values for each successive jump
jumpHoldFrames[0] = 18;
jspd[0] = -3.15;
jumpHoldFrames[1] = 10;
jspd[1] = -2.85;

	//Coyote Time
	//Hang Time
	coyoteHangFrames = 2;
	coyoteHangTimer = 0;
	//Jump Buffer Time
	coyoteJumpFrames = 5;
	coyoteJumpTimer = 0;

//Random Variables


	

