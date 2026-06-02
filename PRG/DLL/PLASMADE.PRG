//------------------------------------------------------------------------------
// TITLE:       PLASMADE.PRG
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        06/02/2026
// DESCRIPTION: Demostración de PLASMA.DLL
// El plasma cubre toda la pantalla en cada frame con colores del arco iris
// generados por combinación de ondas sinusoidales.
//
// Controles:
//   ARRIBA           ->  aumentar velocidad
//   ABAJO            ->  reducir velocidad
//   ESC              ->  salir
//-----------------------------------------------------------------------

PROGRAM PLASMADE;

IMPORT "DLL\PLASMA.DLL";

PRIVATE
    INT velocidad;

BEGIN
    set_mode(m320x200);
    set_fps(30, 5);

    velocidad = 2;

    // Nota: el plasma sobreescribe el buffer entero, pero DIV2 dibuja
    // los textos ANTES de llamar a post_process_buffer. El plasma los
    // tapa. Los controles funcionan aunque no se vea el texto.

    LOOP
        IF (key(_up))
            velocidad = velocidad + 1;
            IF (velocidad > 16) velocidad = 16; END
            plasma_set_speed(velocidad);
        END

        IF (key(_down))
            velocidad = velocidad - 1;
            IF (velocidad < 1) velocidad = 1; END
            plasma_set_speed(velocidad);
        END

        IF (key(_esc)) exit("", 0); END
        FRAME;
    END
END
