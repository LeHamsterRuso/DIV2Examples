//------------------------------------------------------------------------------
// TITLE:       MODEL_3D.PRG
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        04/06/2026
// DESCRIPTION: Ejemplo de programa que muestra un modelo 3D rotando, usando la DLL KD3D.
//------------------------------------------------------------------------------
PROGRAM MODEL_3D_CTRL;

IMPORT "KD3D.DLL";

GLOBAL
    int rx, ry, rz;

BEGIN
    set_mode(m320x200);
    set_fps(30, 0);

    KD3D_SETCOLOR(20, 40, 60);
    KD3D_LOAD("CAT.OBJ");

    rx = 0; ry = 0; rz = 0;

    LOOP
        // Rotacion con cursores
        IF (key(_up))    rx = (rx - 6 + 360) MOD 360; END
        IF (key(_down))  rx = (rx + 6)        MOD 360; END
        IF (key(_left))  ry = (ry - 6 + 360)  MOD 360; END
        IF (key(_right)) ry = (ry + 6)        MOD 360; END

        KD3D_DRAW(160, 175, rx, ry, rz, 100);

        IF (key(_esc)) exit("", 0); END
        FRAME;
    END
END
