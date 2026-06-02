//-----------------------------------------------------------------------
// CRTDEMO.PRG - Demostracion de CRT.DLL
// Muestra una escena con texto y sprites de texto, luego aplica el efecto
// de monitor CRT (scanlines). El efecto actua sobre el buffer ya renderizado.
//
// Controles:
//   ESPACIO          ->  activar / desactivar CRT
//   1                ->  intensidad 1 (ghost blend - mas suave)
//   2                ->  intensidad 2 (negro puro - mas marcado)
//   ESC              ->  salir
//-----------------------------------------------------------------------

PROGRAM CRTDEMO;

IMPORT "DLL\CRT.DLL";

PRIVATE
    INT crt_activo;
    INT nivel;
    INT i;

BEGIN
    set_mode(m320x200);
    set_fps(30, 5);

    crt_activo = 1;
    nivel      = 1;

    // Contenido de pantalla: texto distribuido para que el efecto sea visible
    write(0, 160,  10, 4, "== CRT.DLL - Efecto monitor CRT ==");
    write(0, 160,  25, 4, "Las lineas de escaner oscurecen filas alternas");
    write(0, 160,  35, 4, "del buffer usando la tabla GHOST de DIV2.");
    write(0, 160,  50, 4, "ESPACIO: activar/desactivar   1/2: intensidad");
    write(0, 160,  60, 4, "ESC: salir");

    write(0,  10,  80, 0, "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789");
    write(0,  10,  90, 0, "abcdefghijklmnopqrstuvwxyz !?.,;:-_()");
    write(0,  10, 100, 0, "DIV Games Studio 2.0  (c) 1998 Divission");
    write(0,  10, 110, 0, "Comparar con/sin efecto pulsando ESPACIO");
    write(0,  10, 120, 0, "Nivel 1 = ghost blend (suave)");
    write(0,  10, 130, 0, "Nivel 2 = scanlines negras (marcado)");

    // Proceso de pantalla parpadeo activo/inactivo
    FROM i = 150 TO 190 STEP 10;
        write(0, 10, i, 0, "||||||||||||||||||||||||||||||||||||||||");
    END

    LOOP
        // Alternar CRT con ESPACIO
        IF (key(_space))
            IF (crt_activo == 1)
                crt_activo = 0;
                crt_set_intensity(0);
            ELSE
                crt_activo = 1;
                crt_set_intensity(nivel);
            END
            // Esperar a que se suelte la tecla para evitar flicker
            WHILE (key(_space)) FRAME; END
        END

        IF (key(_1))
            nivel = 1;
            IF (crt_activo == 1) crt_set_intensity(1); END
            WHILE (key(_1)) FRAME; END
        END

        IF (key(_2))
            nivel = 2;
            IF (crt_activo == 1) crt_set_intensity(2); END
            WHILE (key(_2)) FRAME; END
        END

        IF (key(_esc)) exit("", 0); END
        FRAME;
    END
END
