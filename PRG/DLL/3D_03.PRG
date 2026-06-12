//------------------------------------------------------------------------------
// TITLE:       3D_03.PRG
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        05/06/2026
// DESCRIPTION: Modelo 3D con textura usando KD3DT.DLL
//
// Basado en 3D_02 (rotacion con cursores) con las siguientes mejoras:
//   - Usa KD3DT.DLL en lugar de KD3D.DLL
//   - Carga textura .MAP de DIV2 con KD3DT_SETTEX
//   - Control de rotacion Z con teclas Z / X
//   - Control de escala con Q (aumentar) / E (reducir)
//   - Toggle auto-rotacion con ESPACIO
//
// CONTROLES:
//   Cursores    : rotar X / Y
//   Z / X       : rotar Z izquierda / derecha
//   Q / E       : aumentar / reducir escala
//   ESPACIO     : activar / desactivar auto-rotacion
//   ESC         : salir
//
// FICHEROS NECESARIOS EN EL DIRECTORIO DEL JUEGO:
//   CAT.OBJ  : malla 3D exportada desde Blender con "Triangulate + Write UVs"
//   CAT.MAP  : textura exportada desde DIV2 (save_map o editor grafico)
//
// Si CAT.MAP no existe la DLL cae automaticamente a shading plano.
//------------------------------------------------------------------------------
PROGRAM MODEL_3DT;

IMPORT "KD3DT.DLL";

GLOBAL
    int rx, ry, rz;
    int escala;
    int auto_rot;
    int spc_prev;
    int file_bg;

BEGIN
    load_pal("div2.pal");
    set_mode(m320x200);
    set_fps(30, 0);
    file_bg = load_map("MAP/CAT_SCEN.MAP");
    put_screen(0, file_bg);

    rx = 0; ry = 0; rz = 0;
    escala   = 100;
    auto_rot = 0;
    spc_prev = 0;

    // Si la textura sigue mal, prueba las variantes comentadas (rotación y espejado de la textura):
    KD3DT_UVSWAP(0); KD3DT_UVMODE(0, 0);   // <-- BASE: sin flip ni swap
    //KD3DT_UVSWAP(0); KD3DT_UVMODE(1, 0);   // flip U
    //KD3DT_UVSWAP(0); KD3DT_UVMODE(0, 1);   // flip V extra
    //KD3DT_UVSWAP(0); KD3DT_UVMODE(1, 1);   // flip U+V
    //KD3DT_UVSWAP(1); KD3DT_UVMODE(0, 0);   // swap UV (giro 90)
    //KD3DT_UVSWAP(1); KD3DT_UVMODE(1, 0);   // swap + flip U
    KD3DT_LOAD("OBJ/CAT.OBJ");
    KD3DT_SETTEX("MAP/CAT.MAP");

    // Controles en la parte inferior (no solapan con el debug de la DLL)
    write(0, 2, 185, 0, "CURS/ZX:rot  Q/E:esc  SPC:auto  ESC:salir");

    LOOP
        // --- Rotacion manual ------------------------------------------------
        IF (key(_up))    rx = (rx - 4 + 360) MOD 360; END
        IF (key(_down))  rx = (rx + 4)        MOD 360; END
        IF (key(_left))  ry = (ry - 4 + 360)  MOD 360; END
        IF (key(_right)) ry = (ry + 4)        MOD 360; END
        IF (key(_z))     rz = (rz - 4 + 360)  MOD 360; END
        IF (key(_x))     rz = (rz + 4)        MOD 360; END

        // --- Escala ---------------------------------------------------------
        IF (key(_q) AND escala < 300) escala = escala + 2; END
        IF (key(_e) AND escala > 20)  escala = escala - 2; END

        // --- Toggle auto-rotacion (debounce: solo al pulsar, no al mantener)
        IF (key(_space))
            IF (spc_prev == 0)
                auto_rot = 1 - auto_rot;
                spc_prev = 1;
            END
        ELSE
            spc_prev = 0;
        END

        // --- Auto-rotacion --------------------------------------------------
        IF (auto_rot)
            rx = (rx + 1) MOD 360;
            ry = (ry + 2) MOD 360;
        END

        // --- Renderizar -----------------------------------------------------
        KD3DT_DRAW(160, 175, rx, ry, rz, escala);

        IF (key(_esc)) exit("", 0); END
        FRAME;
    END
END
