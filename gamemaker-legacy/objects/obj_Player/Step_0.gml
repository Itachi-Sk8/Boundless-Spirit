//Get Inputs
getControls();

//X Movement
	//Diretion
	moveDir = rightKey - leftKey;
	//Get my face
	if moveDir !=0 { face = moveDir; };
	//Get xspd
	runType = runKey;
	xspd = moveDir * moveSpd[runType];

	//X Collision 
	var _subPixel = 0.5;
	if place_meeting(x +xspd, y, obj_Wall )
	{
		//Scoot up to wall precisely
		var _pixelCheck = _subPixel * sign(xspd);
		while !place_meeting( x + _pixelCheck, y, obj_Wall )
		{
			x += _pixelCheck;
		}
		//Set xspd to zero to collide
		xspd = 0;
	}
	
	//Move
	x += xspd;
	
// Y Movement
	//Gravity
	if coyoteHangTimer > 0
	{
		//Count the timer down
		coyoteHangTimer--;
	} else  {
		//Apply gravity to the player
		yspd += grav;
		//We're no longer on the ground
		setOnGround(false);
	}
	
	//Reset/Prepare jumping variables
	if onGround
	{
		jumpCount = 0;
		jumpHoldTimer = 0;
		coyoteJumpTimer = coyoteJumpTimer;
	} else {
		//If the player is in the air, make sure they can't do an extra jump
		coyoteJumpTimer--;
		if jumpCount == 0 && coyoteJumpTimer <= 0 { jumpCount = 1; };
	}
	
	//Initiate the  Jump
	if jumpKeyBuffered && jumpCount < jumpMax
	{
		//Reset the buffer
		jumpKeyBuffered = false;
		jumpKeyBufferTimer = 0;
		//Increase the number of performed jumps
		jumpCount++;
		//Set the jump hold timer
		jumpHoldTimer = jumpHoldFrames[jumpCount-1];
	}
	//Cut off the jump by releasing the jump button
	if !jumpKey
	{
		jumpHoldTimer = 0;
	}
	//Jump based on the timer/holding the button
	if jumpHoldTimer > 0
	{
		//Tell yourself youre no longer on the ground
		setOnGround(false);
		coyoteJumpTimer = 0; //Maybe remove if bug *
		
		//Constantly set the yspd to be jumping speed
		yspd = jspd[jumpCount-1];
		//Count down the timer
		jumpHoldTimer--;
	}
		
	//Y Collision and movement
		//Cap falling speed
		if yspd > termVel {yspd = termVel; };
		
		//Collision
		var _subPixel = 0.5;
		if place_meeting(x, y +yspd, obj_Wall )
		{
			//Scoot up to wall precisely
			var _pixelCheck = _subPixel * sign(yspd);
			while !place_meeting( x , y + _pixelCheck, obj_Wall )
			{
				y += _pixelCheck;
			}
			//Bonk Code (Optional)
			if yspd < 0
			{
				jumpHoldTimer = 0;
			}
			//Set yspd to 0 to collide
			yspd = 0;
		}
		
		//Set if I'm on the ground
		if yspd >= 0 && place_meeting( x, y+1, obj_Wall )
		{
			setOnGround(true);
		}
	
	//Move
	y += yspd;

//Sprite Control
	//Walking
	if abs(xspd) > 0 { sprite_index = walkSpr; };
	//Running
	if abs(xspd) >= moveSpd[1] { sprite_index = runSpr; };
	//Not Moving
	if xspd == 0 { sprite_index = idleSpr; };
	//In the air
	if !onGround { sprite_index = jumpSpr; };
	if jumpCount > 1 {sprite_index = doublejumpSpr; };
		//Set the Collison Mask
		mask_index = idleSpr;
		
	
		




