//------------------------------------------------------------------------------
// TITLE:       WIPEDEMO.PRG
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        06/02/2026
// DESCRIPTION: Demostración de WIPE.DLL
// Muestra 4 transiciones de pantalla en secuencia.
// La transición actúa en post_process_buffer: el contenido se dibuja
// normalmente cada frame y luego la WIPE lo oculta progresivamente.
//
// Flujo:
//   Se muestra texto de demo -> ESPACIO inicia la siguiente wipe ->
//   la wipe avanza sola hasta 100% -> pausa -> retrocede a 0% -> espera.
//
// Controles:
//   ESPACIO          ->  iniciar siguiente transicion
//   ESC              ->  salir
//-----------------------------------------------------------------------

PROGRAM WIPEDEMO;

IMPORT "DLL\WIPE.DLL";

PRIVATE
    INT tipo_wipe;        // 0-3: tipo de transicion actual
    INT progreso;         // valor devuelto por wipe_advance()
    INT estado;           // 0=esperando  1=avanzando  2=retrocediendo
    STRING nombres[4];    // nombres de cada efecto para mostrar en pantalla

BEGIN
    set_mode(m320x200);
    set_fps(30, 5);

    tipo_wipe = 0;
    progreso  = 0;
    estado    = 0;

    // Contenido de fondo: texto repartido por toda la pantalla
    // para que el efecto wipe sea claramente visible
    write(0, 160,  8, 4, "=== WIPE.DLL - Transiciones ===");
    write(0, 160, 20, 4, "ESPACIO para iniciar la siguiente transicion");
    write(0, 160, 30, 4, "ESC para salir");

    write(0,  10,  50, 0, "Cortina hacia abajo    [tipo 0]");
    write(0,  10,  62, 0, "Cortina hacia arriba   [tipo 1]");
    write(0,  10,  74, 0, "Disolucion aleatoria   [tipo 2]");
    write(0,  10,  86, 0, "Persianas horizontales [tipo 3]");

    write(0,  10, 106, 0, "DIV Games Studio 2.0 - DLL Demos");
    write(0,  10, 116, 0, "||||||||||||||||||||||||||||||||||||||||");
    write(0,  10, 126, 0, "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789");
    write(0,  10, 136, 0, "Texto de relleno para visualizar el efecto");
    write(0,  10, 146, 0, "||||||||||||||||||||||||||||||||||||||||");
    write(0,  10, 156, 0, "Comparar la velocidad y el estilo de cada wipe");
    write(0,  10, 166, 0, "Este texto reaparece cuando la wipe retrocede");
    write(0,  10, 176, 0, "||||||||||||||||||||||||||||||||||||||||");
    write(0,  10, 186, 0, ">>> PULSA ESPACIO <<<");

    LOOP
        IF (key(_esc))
            exit("", 0);
        END

        IF (estado == 0)
            // Esperando ESPACIO para iniciar siguiente transicion
            IF (key(_space))
                wipe_start(tipo_wipe);
                estado = 1;
                WHILE (key(_space))
                    FRAME;
                END
            END

        ELSE
            IF (estado == 1)
            // Avanzando la transicion hasta 100
                progreso = wipe_advance(3);
                IF (progreso >= 100)
                    estado = 2;
                END

            ELSE
                IF (estado == 2)
                // Retrocediendo la transicion hasta 0
                progreso = wipe_advance(-3);
                IF (progreso <= 0)
                    wipe_stop();
                    tipo_wipe = tipo_wipe + 1;
                    IF (tipo_wipe > 3) tipo_wipe = 0; END
                        estado = 0;
                    END
                END
            END
        END

        FRAME;
    END
END
