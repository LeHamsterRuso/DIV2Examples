PROGRAM HELLO_WORLD_3D;
CONST
    SCREEN_SIZE_X = 640;
    SCREEN_SIZE_Y = 480;
    FILE_WLD = "HELLO3D.WLD";
    FILE_FPG = "HELLOWO.FPG";
GLOBAL
    SpritesText[]=8,             // Number of faces
        3, 10, 9, 8, 7, 6, 5, 4; // ID graphic for each face
PRIVATE
    mouse_xBefore;
    zBefore;
    jumpHeight;
    isJumping;
    originalHeight;
    originalEyeHeight;

BEGIN
    set_mode(SCREEN_SIZE_X*1000 + SCREEN_SIZE_Y);
    set_fps(30, 0);

    load_fpg(FILE_FPG);
    load_wld(FILE_WLD, 0);

    start_mode8(id, 0, 0);

    ctype=c_m8;
    height=128;
    radius=64;
    m8.height=128;
    go_to_flag(0);
    mouse_xBefore=mouse.x;
    jumpHeight=0;
    isJumping=0;

    originalHeight = height;
    originalEyeHeight = m8.height;

    set_fog(0, 128);
    set_env_color(100, 100, 100);

    // Prints the fake 3D Hello World
    M7Sprite(&SpritesText, 1, -pi/2);

    loop
        if (key(_esc)) exit("Bye", 0); end

        /* lateral movement */
        if (key(_d)) xadvance(angle-90000,16); end
        if (key(_a)) xadvance(angle+90000,16); end

        /* Walk (SHIFT for run) */
        if (key(_w))
            if(key(_l_shift) or key(_r_shift))
                advance(40);
            else
                advance(10);
            end
        end

        /* Back (SHIFT for run) */
        if (key(_s))
            if (key(_l_shift) or key(_r_shift))
                advance(-20);
            else
                advance(-10);
            end
        end

        /* Jump */
        if (key(_space) and not isJumping and zBefore == z)
            isJumping = 1;
            jumpHeight = 30;
        end

        if (isJumping)
            z = z + jumpHeight;
            jumpHeight = jumpHeight - 2;
            if (jumpHeight <= 0)
                isJumping = 0;
            end
        else
            z -= 25;
        end
        zBefore = z+25;

        /* Duck */
        if (key(_control))
            height = originalHeight * 2 / 3;
            m8.height = originalEyeHeight * 2 / 3;
        else
            height = originalHeight;
            m8.height = originalEyeHeight;
        end

        /* Mouse mouvement (for camera view) */
        angle -= (mouse.x - mouse_xBefore) * 350;
        m8.angle = 128 - (mouse.y*256)/(SCREEN_SIZE_Y);

        if (mouse.x <= 0 or mouse.x >= (SCREEN_SIZE_X-1))
            mouse.x = SCREEN_SIZE_X/2;
        end
        mouse_xBefore = mouse.x;

        frame;
    end
end

/* Shows a 2D sprite from different angles
   @xgraph -> Array with the graphic ids for each angle
   @flag -> Localization
   @angle -> Angle */
PROCESS M7Sprite(xgraph, flag, angle)
BEGIN
    ctype=c_m8;
    go_to_flag(flag);
    LOOP
        FRAME;
    END
END
