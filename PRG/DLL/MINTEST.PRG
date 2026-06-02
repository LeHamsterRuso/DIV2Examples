//------------------------------------------------------------------------------
// TITLE:       MINTEST.PRG
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        06/02/2026
// DESCRIPTION: Test minimo de DLL
// Deberias ver una linea verde en la fila 10 si MINDLL.DLL funciona.
// Si no ves nada o se cuelga: problema en compilacion/carga de DLL.
//------------------------------------------------------------------------------

PROGRAM MINTEST;

IMPORT "MINDLL.DLL";

BEGIN
    set_mode(m320x200);
    set_fps(30, 0);
    write(0, 160, 50,  4, "MINTEST - DLL de diagnostico");
    write(0, 160, 62,  4, "Linea en fila 10 = DLL OK");
    write(0, 160, 74,  4, "ESC para salir");
    LOOP
        IF (key(_esc)) exit("", 0); END
        FRAME;
    END
END
