PROGRAM HELLOWORLD;
BEGIN
    set_mode(m640x480);
    set_fps(30, 0);

    write(0, 320, 240, 4, "Hello World!");

    LOOP
        IF (KEY(_ESC))
            exit("Bye", 0);
        END

        FRAME;
    END
END
