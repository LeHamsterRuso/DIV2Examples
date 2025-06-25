/* Sebastian Moncho, 2025,
    basado en el ejemplo "TUTOR7" de David Navarro */
PROGRAM HELLO_WORLD_MODE7;
GLOBAL
    SpritesText[]=8,             // Number of faces
        3, 10, 9, 8, 7, 6, 5, 4; // ID graphic for each face
BEGIN
    set_mode(m320x200);
    set_fps(30, 0);

    // Default assets file
    load_fpg("HELLOWO.FPG");

    // Camera options
    m7[0].camera=id;
    m7[0].height=64;
    m7[0].distance=96;
    m7[1].camera=id;
    m7[1].height=251;
    m7[1].distance=96;

    // Sets regions
    define_region(1, 0, 65, 320, 200);
    define_region(2, 0, 0, 320, 64);
    // Sets fake 3D floor
    start_mode7(0, 0, 1, 1, 1, 0);
    // Sets fake 3D sky
    start_mode7(1, 0, 1, 1, 2, -64);

    // Prints the fake 3D Hello World
    M7Sprite(&SpritesText, 0, 0, 0, -pi/2);

    // Main loop
    LOOP
        if (key(_right))
            angle+=pi/4;
        END
        if (key(_left))
            angle-=pi/4;
        END

        if (key(_ESC)) exit("Bye", 0); END
        FRAME;
    END
END

/* Shows a 2D sprite from different angles
   @xgraph -> Array with the graphic ids for each angle
   @x, y, z -> Coordenates
   @angle -> Angle */
PROCESS M7Sprite(xgraph, x, y, z, angle)
BEGIN
    ctype=c_m7;
    LOOP
        FRAME;
    END
END
