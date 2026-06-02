//-----------------------------------------------------------------------
// PARTDEMO.PRG - Demostracion de PARTS.DLL
// Las particulas se dibujan en post_process_buffer encima de todo lo
// que DIV2 haya renderizado ese frame.
//
// Controles:
//   Boton izquierdo raton  ->  explosion de chispas en la posicion del raton
//   Boton derecho raton    ->  lluvia de particulas desde arriba
//   1 / 2 / 3             ->  cambiar color de emision
//   G / H                  ->  aumentar / reducir gravedad
//   C                      ->  limpiar todas las particulas
//   ESC                    ->  salir
//-----------------------------------------------------------------------

PROGRAM PARTDEMO;

IMPORT "DLL\PARTS.DLL";

PRIVATE
    INT color_actual;
    INT grav_actual;
    INT i;

BEGIN
    set_mode(m320x200);
    set_fps(30, 5);

    color_actual = 15;    // blanco en la mayoria de paletas
    grav_actual  = 1;

    parts_set_gravity(grav_actual);

    // Instrucciones en pantalla - las particulas se dibujan ENCIMA
    write(0, 160,  8, 4, "PARTS.DLL - Sistema de particulas");
    write(0, 160, 18, 4, "Boton IZQ: explosion   Boton DER: lluvia");
    write(0, 160, 28, 4, "1/2/3: color   G/H: gravedad   C: limpiar");
    write(0, 160, 38, 4, "ESC: salir");

    write(0,  10,  58, 0, "Color:");
    write_int(0, 60, 58, 0, &color_actual);
    write(0,  10,  68, 0, "Gravedad:");
    write_int(0, 80, 68, 0, &grav_actual);

    // Fondo visual para que las particulas contrasten
    write(0, 160, 100, 4, "Haz clic en cualquier punto de la pantalla");
    write(0, 160, 112, 4, "para emitir particulas");
    write(0, 160, 130, 4, "*** DEMO DIV GAMES STUDIO 2.0 ***");
    write(0, 160, 145, 4, "Las particulas siguen la fisica:");
    write(0, 160, 155, 4, "velocidad inicial + gravedad + tiempo de vida");

    LOOP
        IF (key(_esc)) exit("", 0); END

        // Cambiar color de emision
        IF (key(_1)) color_actual = 15;  END   // blanco
        IF (key(_2)) color_actual = 63;  END   // amarillo/naranja
        IF (key(_3)) color_actual = 12;  END   // rojo

        // Ajustar gravedad
        IF (key(_g))
            grav_actual = grav_actual + 1;
            IF (grav_actual > 20) grav_actual = 20; END
            parts_set_gravity(grav_actual);
            WHILE (key(_g)) FRAME; END
        END
        IF (key(_h))
            grav_actual = grav_actual - 1;
            IF (grav_actual < -10) grav_actual = -10; END
            parts_set_gravity(grav_actual);
            WHILE (key(_h)) FRAME; END
        END

        // Limpiar particulas
        IF (key(_c))
            parts_clear();
            WHILE (key(_c)) FRAME; END
        END

        // Boton izquierdo: explosion de chispas en la posicion del raton
        IF (mouse.left)
            // parts_emit(x, y, count, color, speed, vida)
            parts_emit(mouse.x, mouse.y, 40, color_actual, 8, 60);
        END

        // Boton derecho: lluvia de particulas desde la parte superior
        IF (mouse.right)
            FROM i = 0 TO 9;
                parts_emit(rand(0, 319), 0, 3, color_actual, 2, 80);
            END
        END

        FRAME;
    END
END
