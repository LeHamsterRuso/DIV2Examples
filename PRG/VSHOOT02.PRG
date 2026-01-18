//------------------------------------------------------------------------------
// TÍTULO:      VSHOOT02.PRG - Nave Jugador con 2 Enemigos
// AUTOR:       Sebastian J. MONCHO MAQUET
// FECHA:       18/01/2026
// DESCRIPCIÓN: Versión con nave del jugador y 2 enemigos (uno tipo 1, uno tipo 2).
// NOTA:        Usa las flechas para mover la nave, espacio para disparar y ESC para salir.
//              Requiere la paleta DIV2.PAL en el mismo directorio.
//              Código y comentarios en castellano para facilitar la comprensión (por petición).
//------------------------------------------------------------------------------

PROGRAM vshoot02;

// Variables globales
GLOBAL
    INT controles_activos = 1;

// Programa principal
BEGIN
    // Arrancamos el juego a 320x200 a 60 FPS con la paleta cargada
    set_mode(m320x200);  // 320x200
    set_fps(60, 0);
    load_pal("DIV2.PAL");

    // Creamos la nave del jugador
    jugador();

    // Creamos 2 enemigos: uno tipo 1 y uno tipo 2
    enemigo_tipo1(50, 30);
    enemigo_tipo2(200, 40);

    // Bucle principal del juego
    LOOP
        FRAME;
    END
END

// Proceso: jugador
// Descripción: Controla la nave del jugador.
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
        IF (key(_esc)) EXIT("Gracias por jugar.", 0); END

        FRAME;  // Esperar al siguiente frame
    END
END

// Proceso: bala_jugador
// Descripción: Controla el movimiento de una bala disparada por el jugador.
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

// Función: dibujar_enemigo_tipo1
// Descripción: Dibuja el enemigo tipo 1, borrando los dibujos anteriores.
// Parámetros:
//   - box_offset: Puntero al ID de la caja.  -> Usamos el puntero para modificar la variable original.
//   - circulo_offset: Puntero al ID del círculo.  -> Usamos el puntero para modificar la variable original.
//   - x: Posición x.
//   - y: Posición y.
// Los punteros sirven para modificar las variables originales fuera de la función.
// - Si modificas una varariable del puntero dentro de la función, se refleja fuera también.
// - Sirve para evitar el uso de variables globales innecesarias.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION dibujar_enemigo_tipo1(INT box_offset, INT circulo_offset, INT x, INT y);
BEGIN
    // Borramos los dibujos del frame anterior
    // Controlamos que existe ya una box y un círculo (ID != 0) antes de borrarlos
    // Si no lo comprobamos, tendríamos una excepción en el primer FRAME y el juego se colgaría
    IF (*box_offset != 0) delete_draw(*box_offset); END
    IF (*circulo_offset != 0) delete_draw(*circulo_offset); END

    // Dibujamos el enemigo
    *box_offset = draw(3, 114, 15, 0, x - 8, y - 8, x + 8, y + 8);
    *circulo_offset = draw(5, 4, 15, 0, x - 3, y - 3, x + 3, y + 3);
END

// Función: mover_enemigo_tipo1
// Descripción: Maneja el movimiento horizontal del enemigo tipo 1, cambiando dirección al llegar a los bordes y descendiendo.
// Parámetros:
//   - x_offset: Puntero a la posición x. -> Usamos el puntero para modificar la variable original.
//   - y_offset: Puntero a la posición y. -> Usamos el puntero para modificar la variable original.
//   - dir_offset: Puntero a la dirección (1 o -1). -> Usamos el puntero para modificar la variable original.
// Los punteros sirven para modificar las variables originales fuera de la función.
// - Si modificas una varariable del puntero dentro de la función, se refleja fuera también.
// - Sirve para evitar el uso de variables globales innecesarias.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION mover_enemigo_tipo1(INT x_offset, INT y_offset, INT dir_offset);
BEGIN
    *x_offset += *dir_offset * 2;  // Movimiento horizontal

    // Cambiar dirección al llegar a los bordes
    IF (*x_offset < 10 OR *x_offset > 310)
        *dir_offset = -*dir_offset;
        *y_offset += 5;  // Descenso
    END
END

// Proceso: enemigo_tipo1
// Descripción: Controla el comportamiento de un enemigo tipo 1.
// - Se mueve horizontalmente, dispara balas y verifica si muere o llega abajo.
// Parámetros:
//   - x: Posición inicial x.
//   - y: Posición inicial y.
PROCESS enemigo_tipo1(x, y);
PRIVATE
    dir = 1;  // Dirección inicial
    tiempo = 0;
    enemigo_box;  // ID del dibujo de la caja
    enemigo_circulo;  // ID del dibujo del círculo
BEGIN
    LOOP
        // Dibujar enemigo
        dibujar_enemigo_tipo1(&enemigo_box, &enemigo_circulo, x, y);

        // Mover enemigo
        mover_enemigo_tipo1(&x, &y, &dir);

        // Salir si llega abajo
        IF (y > 210) RETURN; END

        FRAME;
    END
END

// Función: dibujar_enemigo_tipo2
// Descripción: Dibuja el enemigo tipo 2, borrando los dibujos anteriores.
// Parámetros:
//   - linea1_offset: Puntero al ID de la línea 1.  -> Usamos el puntero para modificar la variable original.
//   - linea2_offset: Puntero al ID de la línea 2.  -> Usamos el puntero para modificar la variable original.
//   - linea3_offset: Puntero al ID de la línea 3.  -> Usamos el puntero para modificar la variable original.
//   - linea4_offset: Puntero al ID de la línea 4.  -> Usamos el puntero para modificar la variable original.
//   - circulo_offset: Puntero al ID del círculo.  -> Usamos el puntero para modificar la variable original.
//   - x: Posición x.
//   - y: Posición y.
// Los punteros sirven para modificar las variables originales fuera de la función.
// - Si modificas una varariable del puntero dentro de la función, se refleja fuera también.
// - Sirve para evitar el uso de variables globales innecesarias.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION dibujar_enemigo_tipo2(INT linea1_offset, INT linea2_offset, INT linea3_offset, INT linea4_offset, INT circulo_offset, INT x, INT y);
BEGIN
    // Borramos los dibujos anteriores
    IF (*linea1_offset != 0) delete_draw(*linea1_offset); END
    IF (*linea2_offset != 0) delete_draw(*linea2_offset); END
    IF (*linea3_offset != 0) delete_draw(*linea3_offset); END
    IF (*linea4_offset != 0) delete_draw(*linea4_offset); END
    IF (*circulo_offset != 0) delete_draw(*circulo_offset); END

    // Dibujamos el enemigo
    *linea1_offset = draw(1, 9, 15, 0, x, y - 8, x + 8, y);
    *linea2_offset = draw(1, 9, 15, 0, x + 8, y, x, y + 8);
    *linea3_offset = draw(1, 9, 15, 0, x, y + 8, x - 8, y);
    *linea4_offset = draw(1, 9, 15, 0, x - 8, y, x, y - 8);
    *circulo_offset = draw(5, 9, 15, 0, x - 2, y - 2, x + 2, y + 2);
END

// Función: mover_enemigo_tipo2
// Descripción: Maneja el movimiento circular del enemigo tipo 2, manteniéndolo dentro de la pantalla.
// Parámetros:
//   - x_offset: Puntero a la posición x. -> Usamos el puntero para modificar la variable original.
//   - y_offset: Puntero a la posición y. -> Usamos el puntero para modificar la variable original.
//   - ang_offset: Puntero al ángulo de movimiento. -> Usamos el puntero para modificar la variable original.
// Los punteros sirven para modificar las variables originales fuera de la función.
// - Si modificas una varariable del puntero dentro de la función, se refleja fuera también.
// - Sirve para evitar el uso de variables globales innecesarias.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION mover_enemigo_tipo2(INT x_offset, INT y_offset, INT ang_offset);
BEGIN
    *ang_offset += 5000;  // Incremento del ángulo

    // Movimiento circular
    *x_offset += get_distx(*ang_offset / 1000, 1);
    *y_offset += get_disty(*ang_offset / 1000, 1);

    // Mantener dentro de la pantalla
    IF (*x_offset < 10) *x_offset = 10; END
    IF (*x_offset > 310) *x_offset = 310; END
    IF (*y_offset < 10) *y_offset = 10; END
    IF (*y_offset > 190) *y_offset = 190; END
END

// Proceso: enemigo_tipo2
// Descripción: Controla el comportamiento de un enemigo tipo 2.
// - Se mueve en círculos, dispara balas dirigidas y verifica si muere.
// Parámetros:
//   - x: Posición inicial x.
//   - y: Posición inicial y.
PROCESS enemigo_tipo2(x, y);
PRIVATE
    ang = 0;  // Ángulo inicial
    tiempo = 0;
    enemigo_linea1;  // IDs de dibujos
    enemigo_linea2;
    enemigo_linea3;
    enemigo_linea4;
    enemigo_circulo;
BEGIN
    LOOP
        // Dibujar enemigo
        dibujar_enemigo_tipo2(&enemigo_linea1, &enemigo_linea2, &enemigo_linea3, &enemigo_linea4, &enemigo_circulo, x, y);

        // Mover enemigo
        mover_enemigo_tipo2(&x, &y, &ang);

        FRAME;
    END
END