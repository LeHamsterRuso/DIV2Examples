//------------------------------------------------------------------------------
// TÍTULO:      VSHOOT01.PRG - Nave Jugador Simple
// AUTOR:       Sebastian J. MONCHO MAQUET
// FECHA:       18/01/2026
// DESCRIPCIÓN: Versión simplificada con solo la nave del jugador y controles.
// NOTA:        Usa las flechas para mover la nave, espacio para disparar y ESC para salir.
//              Requiere la paleta DIV2.PAL en el mismo directorio.
//              Código y comentarios en castellano para facilitar la comprensión (por petición).
//------------------------------------------------------------------------------

PROGRAM vshooter;
// Programa principal
BEGIN
    // Arrancamos el juego a 320x200 a 60 FPS con la paleta cargada
    set_mode(m320x200);  // 320x200
    set_fps(60, 0);
    load_pal("DIV2.PAL");

    // Creamos la nave del jugador
    jugador();

    // Bucle principal del juego
    LOOP
        FRAME;
    END
END

// Proceso: jugador
// Descripción: Controla la nave del jugador.
// - Maneja el dibujo, movimientos y disparos en un bucle continuo.
PROCESS jugador();
PRIVATE
    vel = 3;  // Velocidad de movimiento
    tiempo_disparo = 0; // Contador para controlar la frecuencia de disparos

    // El dibujo de la nave se compone de varias partes
    nave_circulo;       // ID del dibujo del círculo de la nave
    nave_linea1;        // ID del dibujo de la primera línea de la nave
    nave_linea2;        // ID del dibujo de la segunda línea de la nave
    nave_linea3;        // ID del dibujo de la tercera línea de la nave
BEGIN
    // Posición inicial de la nave en el centro inferior de la pantalla
    x = 160;  // Centro horizontal
    y = 170;  // Cerca del fondo

    // Bucle principal del jugador
    LOOP
        // Dibujamos la nave del jugador
        // Borrar los dibujos anteriores
        IF (nave_circulo != 0) delete_draw(nave_circulo); END
        IF (nave_linea1 != 0) delete_draw(nave_linea1); END
        IF (nave_linea2 != 0) delete_draw(nave_linea2); END
        IF (nave_linea3 != 0) delete_draw(nave_linea3); END

        // Dibujar la nave
        nave_circulo = draw(5, 31, 15, 0, x - 8, y - 8, x + 8, y + 8);
        nave_linea1 = draw(1, 31, 15, 0, x - 6, y + 8, x, y - 10);
        nave_linea2 = draw(1, 31, 15, 0, x + 6, y + 8, x, y - 10);
        nave_linea3 = draw(1, 31, 15, 0, x - 6, y + 8, x + 6, y + 8);

        // Movimiento de la nave
        IF (key(_left) AND x > 10) x -= vel; END
        IF (key(_right) AND x < 310) x += vel; END
        IF (key(_up) AND y > 10) y -= vel; END
        IF (key(_down) AND y < 190) y += vel; END

        // Disparar
        tiempo_disparo++;
        IF (key(_space) AND tiempo_disparo > 5)
            // Crear bala
            bala_jugador(x, y - 15);
            tiempo_disparo = 0;
        END

        // Salir con ESC
        IF (key(_esc))
            EXIT("Gracias por jugar.", 0);
        END

        FRAME;  // Esperar al siguiente frame
    END
END

// Proceso: bala_jugador
// Descripción: Controla el movimiento de una bala disparada por el jugador.
// - Se mueve hacia arriba y se elimina si sale de la pantalla.
PROCESS bala_jugador(x, y);
PRIVATE
    bala_draw;  // ID del dibujo de la bala
BEGIN
    LOOP
        // Borramos dibujo anterior si existe
        IF (bala_draw != 0) delete_draw(bala_draw); END

        // Dibujamos la bala
        bala_draw = draw(5, 10, 15, 0, x - 3, y - 3, x + 3, y + 3);

        // Movemos la bala hacia arriba
        y -= 5;

        // Eliminamos la bala si sale de la pantalla
        IF (y < -10) RETURN; END

        FRAME;  // Esperar al siguiente frame
    END
END