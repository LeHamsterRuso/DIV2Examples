//------------------------------------------------------------------------------
// TITLE:       HUDTEST.PRG
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        06/02/2026
// DESCRIPTION: Demostración de uso de HUD.DLL para DIV Games Studio 2
//
// Requiere HUD.DLL en DIV2\DLL\ (compilar con: ./build_dlls.sh HUD)
//
// Controles:
//   [H]   - Mostrar / ocultar el HUD
//   [R]   - Resetear contadores FPS min / max
//   [ESC] - Salir
//------------------------------------------------------------------------------

PROGRAM HUDTEST;

CONST
    SCREEN_W  = 320;
    SCREEN_H  = 200;
    GAME_FPS  = 50;
    TOTAL_MB  = 32;        // Ajustar segun la RAM instalada en el equipo

GLOBAL
    frame_cnt;

BEGIN
    set_mode(SCREEN_W * 1000 + SCREEN_H);
    set_fps(GAME_FPS, 0);

    // Informar al HUD del total de RAM disponible (en KB)
    HUD_SET_MEM_TOTAL(TOTAL_MB * 1024);

    // Textos estaticos del fondo (se dibujan antes que el HUD, queda debajo)
    write(0, SCREEN_W/2,  72, 4, "[ HUD.DLL  -  Demo ]");
    write(0, SCREEN_W/2,  96, 4, "[H]   mostrar / ocultar HUD");
    write(0, SCREEN_W/2, 108, 4, "[R]   resetear FPS min / max");
    write(0, SCREEN_W/2, 120, 4, "[ESC] salir");
    write(0, SCREEN_W/2, 140, 4, "Frame:");
    write_int(0, SCREEN_W/2, 152, 4, &frame_cnt);

    // Bucle principal
    loop
        // [H] alterna visibilidad del HUD (debounce con while)
        if (key(_h))
            HUD_TOGGLE();
            while (key(_h)) frame; end
        end

        // [R] reinicia estadisticas de FPS
        if (key(_r))
            HUD_RESET_FPS();
            while (key(_r)) frame; end
        end

        if (key(_esc))
            exit("", 0);
        end

        // Actualizar memoria libre en el HUD cada frame
        HUD_SET_MEM_FREE(memory_free());

        frame_cnt = frame_cnt + 1;
        frame;
    end
END
