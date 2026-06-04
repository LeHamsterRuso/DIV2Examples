//------------------------------------------------------------------------------
// TITLE:       MODEL_3D.PRG
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        04/06/2026
// DESCRIPTION: Ejemplo de programa que muestra un modelo 3D rotando, usando la DLL KD3D.
//------------------------------------------------------------------------------
PROGRAM MODEL_3D;

IMPORT "KD3D.DLL";

GLOBAL
    int rx, ry, rz;

BEGIN
    set_mode(m320x200);
    set_fps(30, 0);

    // Asigna el color al objeto 3D.
    KD3D_SETCOLOR(20, 40, 60);  // azul-acero
    // Carga el modelo 3D desde un archivo OBJ. El modelo se centra automáticamente.
    KD3D_LOAD("CUBE.OBJ");

    LOOP
        // Dibuja el modelo 3D rotando en el centro de la pantalla. El tamaño es 80.
        KD3D_DRAW(160, 100, rx, ry, rz, 80);

        // Rota el modelo para la siguiente frame.
        rx = (rx + 1) MOD 360;
        ry = (ry + 2) MOD 360;

        // Permite salir del programa pulsando ESC.
        IF (key(_esc)) exit("", 0); END
        FRAME;
    END
END
