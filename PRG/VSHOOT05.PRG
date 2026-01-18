//------------------------------------------------------------------------------
// TÍTULO:      VSHOOT05.PRG - Juego de Disparos Vertical Optimizado con Arrays
// AUTOR:       Sebastian J. MONCHO MAQUET
// FECHA:       18/01/2026
// DESCRIPCIÓN: Versión optimizada del juego con mejoras en calidad de código:
//              - Procesos genéricos para enemigos (tipo 1 y 2 en uno solo).
//              - Funciones genéricas para las cuentas regresivas.
//              - Todos los enemigos manejados en un único proceso usando structs (STRUCT Enemigo).
//
// NOTA:        Usa las flechas para mover la nave, espacio para disparar y ESC para salir.
//              Requiere la paleta DIV2.PAL en el mismo directorio.
//              Código y comentarios en castellano para facilitar la comprensión (por petición).
//------------------------------------------------------------------------------

PROGRAM vshooter;
// Constantes del juego
CONST
    // Las constantes son variables inmutables que definen parámetros del juego.
    // No se pueden cambiar durante la ejecución del programa.
    // Estas constantes controlan aspectos como resolución, velocidad, colores y tamaños.
    // El compilador traduce estas constantes directamente en valores fijos en el código máquina.
    // Usar constantes reduce el consumo de memoria y los calculos en tiempo de ejecución.
    // - Si haces una resta o una suma entre constantes, el compilador lo calcula en tiempo de compilación y no entiempo de ejecución.

    // Resolución y rendimiento
    // 320x200 píxeles a 60 FPS
    ANCHO_PANTALLA = 320;
    ALTO_PANTALLA = 200;
    FPS_JUEGO = 60;

    // Parámetros del jugador
    VEL_JUGADOR = 3;                // Velocidad de movimiento de la nave del jugador
    TIEMPO_DISPARO_JUGADOR = 5;     // Tiempo mínimo entre disparos del jugador (en frames)
    VEL_BALA_JUGADOR = 5;           // Velocidad de las balas disparadas por el jugador
    COLOR_NAVE = 31;                // Color de la nave del jugador (paleta DIV2.PAL)
    TAMANO_NAVE_X = 8;              // Tamaño horizontal de la nave del jugador en píxeles
    TAMANO_NAVE_Y_BASE = 8;         // Tamaño vertical base de la nave del jugador en píxeles
    TAMANO_NAVE_Y_ALTURA = 10;      // Altura del vértice superior de la nave del jugador en píxeles
    TAMANO_NAVE_BASE = 6;           // Mitad del ancho de la base de la nave del jugador en píxeles

    // Parámetros de enemigos
    NUM_ENEMIGOS_INICIAL = 10;      // Número inicial de enemigos por nivel
    DISTANCIA_COLISION = 12;        // Distancia mínima para considerar una colisión entre objetos
    PUNTOS_POR_ENEMIGO = 10;        // Puntos otorgados por destruir a un enemigo

    // Enemigo tipo 1
    VEL_ENEMIGO1_HORIZONTAL = 2;    // Velocidad horizontal del enemigo tipo 1
    DESCENSO_ENEMIGO1 = 5;          // Descenso vertical del enemigo tipo 1 al cambiar de dirección
    TIEMPO_DISPARO_ENEMIGO1 = 120;  // Tiempo entre disparos del enemigo tipo 1 (en frames)
    COLOR_ENEMIGO1 = 114;           // Color del enemigo tipo 1 (paleta DIV2.PAL)
    TAMANO_ENEMIGO1 = 8;            // Tamaño del enemigo tipo 1 en píxeles
    TAMANO_ENEMIGO1_CIRCULO = 3;    // Tamaño del círculo interno del enemigo tipo 1 en píxeles

    // Enemigo tipo 2
    INCREMENTO_ANGULO_ENEMIGO2 = 5000;  // Incremento del ángulo para movimiento circular del enemigo tipo 2
    RADIO_MOVIMIENTO_ENEMIGO2 = 1;      // Radio del movimiento circular del enemigo tipo 2
    TIEMPO_DISPARO_ENEMIGO2 = 90;       // Tiempo entre disparos del enemigo tipo 2 (en frames)
    COLOR_ENEMIGO2 = 9;                 // Color del enemigo tipo 2 (paleta DIV2.PAL)
    TAMANO_ENEMIGO2_LINEA = 8;          // Tamaño de las líneas del enemigo tipo 2 en píxeles
    TAMANO_ENEMIGO2_CIRCULO = 2;        // Tamaño del círculo interno del enemigo tipo 2 en píxeles

    // Balas
    VEL_BALA_ENEMIGA1 = 3;              // Velocidad de las balas disparadas por el enemigo tipo 1
    VEL_BALA_ENEMIGA2 = 2;              // Velocidad de las balas disparadas por el enemigo tipo 2
    ANGULO_DEFECTO_BALA = 90000;        // Ángulo por defecto para balas enemigas (hacia abajo)
    TAMANO_BALA_JUGADOR = 3;            // Tamaño de las balas disparadas por el jugador en píxeles
    TAMANO_BALA_ENEMIGA1 = 2;           // Tamaño de las balas disparadas por el enemigo tipo 1 en píxeles
    TAMANO_BALA_ENEMIGA2 = 3;           // Tamaño de las balas disparadas por el enemigo tipo 2 en píxeles

    // Explosiones
    ITERACIONES_EXPLOSION = 10;         // Número de iteraciones para la animación de explosión
    RADIO_INICIAL_EXPLOSION = 3;        // Radio inicial de la explosión en píxeles
    INCREMENTO_RADIO_EXPLOSION = 2;     // Incremento del radio por iteración en píxeles

    // Cuenta regresiva
    SEGUNDOS_CUENTA_REGRESIVA = 3;      // Segundos para la cuenta regresiva antes de iniciar el nivel

    // Posiciones de UI
    POS_X_ETIQUETAS = 10;               // Posición X para etiquetas de texto
    POS_Y_PUNTOS = 10;                  // Posición Y para "PUNTOS:"
    POS_Y_NIVEL = 20;                   // Posición Y para "NIVEL:"
    POS_X_VALORES = 80;                 // Posición X para valores de puntos y nivel
    CENTRO_X = ANCHO_PANTALLA / 2;      // Centro horizontal de la pantalla
    CENTRO_Y = ALTO_PANTALLA / 2;       // Centro vertical de la pantalla
    POS_Y_FPS = 190;                    // Posición Y para "FPS:"
    POS_X_FPS = 40;                     // Posición X para valor de FPS

    // Espaciado de enemigos
    ESPACIADO_ENEMIGO1_X = 50;          // Espaciado horizontal inicial para enemigo tipo 1
    ESPACIADO_ENEMIGO1_Y_INICIAL = 30;  // Posición Y inicial para enemigo tipo 1
    ESPACIADO_ENEMIGO1_Y = 20;          // Espaciado vertical para enemigo tipo 1
    ESPACIADO_ENEMIGO2_X_INICIAL = 200; // Posición X inicial para enemigo tipo 2
    ESPACIADO_ENEMIGO2_Y_INICIAL = 40;  // Posición Y inicial para enemigo tipo 2
    ESPACIADO_ENEMIGO2_X = 20;          // Espaciado horizontal para enemigo tipo 2
    ESPACIADO_ENEMIGO2_Y = 15;          // Espaciado vertical para enemigo tipo 2

    // Parámetros de dibujo
    OPACIDAD_DRAW = 15;                 // Opacidad para dibujos (0-15)
    REGION_DRAW = 0;                    // Región para dibujos (normalmente 0)
    ALINEACION_CENTRADO = 4;            // Alineación centrada para textos

// Variables globales del juego
// Estas variables mantienen el estado del juego y son accesibles desde cualquier parte del programa.
GLOBAL
    INT puntos = 0;                     // Puntuación actual del jugador
    INT enemigos_vivos = 0;             // Número de enemigos vivos en el nivel actual
    INT nivel = 1;                      // Nivel actual del juego
    game_over = 0;                      // Indicador de estado de juego (0 = jugando, 1 = game over)
    enemigo_muerto_id = 0;              // ID del enemigo marcado como "muerto"
    controles_activos = 0;              // Contemplaa si los controles del jugador están activos (1) o desactivados (0), empleado, por ejemplo, durante la cuenta regresiva

// Definición de struct para enemigo
STRUCT enemigo[10]
    INT x;       // Posición X
    INT y;       // Posición Y
    INT tipo;    // Tipo de enemigo (1 o 2)
    INT activo;  // Si está activo (1) o muerto/inactivo (0)
    INT dir;     // Dirección horizontal para tipo1 (1 derecha, -1 izquierda)
    INT ang;     // Ángulo para movimiento circular de tipo2
    INT draw[5]; // Array de IDs de dibujos (5 slots por enemigo)
END

// Variables internas
// Estas variables son utilizadas dentro del programa principal para gestionar la lógica del juego.
// No son accesibles desde otros procesos o funciones, incluyendo sus procesos hijos.
PRIVATE
    procesos_tipo1 = 0;                 // Contador temporal de procesos vivos del enemigo tipo 1
    procesos_tipo2 = 0;                 // Contador temporal de procesos vivos del enemigo tipo 2
    temp_id = 0;                        // ID temporal para iterar sobre procesos
    INT i = 0;                          // Variable de bucle
// Programa principal
// Posee el bucle principal del juego que gestiona la lógica general, niveles y condiciones de victoria/derrota.
BEGIN
    // Arrancamos el juego a 320x200 a 60 FPS con la paleta cargada
    /* En DIV se suelen usar constantes como m320x200, pero aquí definimos la resolución manualmente
       Al compilar, estas constantes se traducen en valores numéricos.
       Podemos poner esos valores fijos directamente si queremos.
    Resoluiones disponibles en DIV y DIV2:
        m320x200 = 320200   VGA estándar
        m320x240 = 320240   Modo X
        m320x400 = 320400   Modo X
        m360x240 = 360240   Modo X
        m360x360 = 360360   Modo X
        m376x282 = 376282   Modo X
        m640x400 = 640400   SVGA VESA
        m640x480 = 640480   SVGA VESA
        m800x600 = 800600   SVGA VESA
        m1024x768 = 1024768 SVGA VESA
     */
    set_mode(ANCHO_PANTALLA * 1000 + ALTO_PANTALLA);
    set_fps(FPS_JUEGO, 0);
    load_pal("DIV2.PAL");   // Paleta disponible en DIV2

    // Mostramos los puntos y el nivel
    mostrar_textos_hud();

    // Valores por defecto al iniciar el juego
    puntos = 0;
    enemigos_vivos = NUM_ENEMIGOS_INICIAL;
    game_over = 0;

    // Iniciar el primer nivel
    // Esto llena la pantalla de enemigos y prepara el juego para empezar.
    // Tambiíen añade al jugador
    inicio_nivel();

    // Bucle principal del juego
    LOOP
        // Salir con ESC en cualquier momento
        IF (key(_ESC))
            // Salimos del juego
            // 0 = salida normal, sin errores
            exit("Gracias por jugar.", 0);
        END
        IF (game_over == 1)
            // Esperar a que se vea la explosión del jugador
            FROM i=0 to 4;
                FRAME;  // 5 frames para ver la explosión
            END
            // Nos aseguramos que éste sea el único proceso en ejecución
            let_me_alone();

            // Mostramos la pantalla de game over
            pantalla_game_over();

            // Reiniciamos las variables del juego
            puntos = 0;
            game_over = 0;
            nivel = 1;
            enemigos_vivos = NUM_ENEMIGOS_INICIAL;

            // Iniciamos un nuevo nivel
            delete_draw(all_drawing);  // Limpiar todos los dibujos de la partida anterior
            inicio_nivel();
        END
        // Pasar al siguiente nivel si no quedan enemigos
        IF (enemigos_vivos <= 0)
            cuenta_regresiva();
            nivel++;
            enemigos_vivos = NUM_ENEMIGOS_INICIAL;
            let_me_alone();
            inicio_nivel();
        END

        FRAME;
    END
END

// Función: mostrar_textos_hud
// Descripción: Escribe en pantalla la puntuación, nivel y los frames por segundo reales
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION mostrar_textos_hud();
BEGIN
    // Dibujar labels estáticos para los textos
    write(0, POS_X_ETIQUETAS, POS_Y_PUNTOS, 0, "PUNTOS:");
    write(0, POS_X_ETIQUETAS, POS_Y_NIVEL, 0, "NIVEL:");
    write(0, POS_X_ETIQUETAS, POS_Y_FPS, 0, "FPS:");

    // Dibujar valores dinámicos usando write_int
    // Offset para pasar la dirección de la variable (puntero)
    // El valor se actualizará automáticamente al cambiar la variable
    write_int(0, POS_X_VALORES, POS_Y_PUNTOS, 0, OFFSET puntos);
    write_int(0, POS_X_VALORES, POS_Y_NIVEL, 0, OFFSET nivel);
    write_int(0, POS_X_FPS, POS_Y_FPS, 0, OFFSET fps);
END

// Función: crear_enemigos
// Descripción: Inicializa el STRUCT de enemigos al inicio de cada nivel.
// - Genera 5 enemigos tipo 1 (a la izquierda) y 5 tipo 2 (a la derecha) en el array STRUCT.
PROCESS crear_enemigos();
PRIVATE
    i;  // Variable para el bucle
    j;  // Variable para inicializar draws
BEGIN
    // Crea 5 enemigos tipo 1 en posiciones espaciadas en la izquierda
    FROM i=0 TO 4;
        enemigo[i].x = ESPACIADO_ENEMIGO1_X + i * ESPACIADO_ENEMIGO1_X;
        enemigo[i].y = ESPACIADO_ENEMIGO1_Y_INICIAL + i * ESPACIADO_ENEMIGO1_Y;
        enemigo[i].tipo = 1;
        enemigo[i].activo = 1;
        enemigo[i].dir = 1;
        enemigo[i].ang = 0;
        FROM j=0 TO 4; enemigo[i].draw[j] = 0; END
    END

    // Crea 5 enemigos tipo 2 en posiciones espaciadas en la derecha
    FROM i=5 TO 9;
        enemigo[i].x = ESPACIADO_ENEMIGO2_X_INICIAL + (i-5) * ESPACIADO_ENEMIGO2_X;
        enemigo[i].y = ESPACIADO_ENEMIGO2_Y_INICIAL + (i-5) * ESPACIADO_ENEMIGO2_Y;
        enemigo[i].tipo = 2;
        enemigo[i].activo = 1;
        enemigo[i].dir = 0;
        enemigo[i].ang = 0;
        FROM j=0 TO 4; enemigo[i].draw[j] = 0; END
    END

    // Crear el proceso único de enemigos
    proceso_enemigos();
END

// Proceso: jugador
// Descripción: Controla la nave del jugador.
// - Maneja el dibujo, movimientos, disparos y colisiones en un bucle continuo.
// - Se detiene si el juego termina (game_over).
PROCESS jugador();
PRIVATE
    vel = VEL_JUGADOR;  // Velocidad de movimiento de la nave
    tiempo_disparo = 0; // Contador para controlar la frecuencia de disparos

    // El dibujo de la nave se compone de varias partes para que resulte "bonito" (un botijo espacial)
    nave_circulo;       // ID del dibujo del círculo de la nave
    nave_linea1;        // ID del dibujo de la primera línea de la nave
    nave_linea2;        // ID del dibujo de la segunda línea de la nave
    nave_linea3;        // ID del dibujo de la tercera línea de la nave
BEGIN
    // Posición inicial de la nave en el centro inferior de la pantalla
    x = CENTRO_X;  // Posición inicial x en el centro
    y = ALTO_PANTALLA - TAMANO_NAVE_Y_ALTURA / 2;  // Posición inicial y cerca del fondo

    // Bucle principal del jugador
    LOOP
        // Si el jugador ha muerto, paramos el proceso
        IF (game_over == 1)
            // La sentencia RETURN finaliza el proceso actual de forma inmediata
            RETURN;
        END

        // Dibujamos la nave del jugador
        // Borrar los dibujos anteriores
        IF (nave_circulo != 0) delete_draw(nave_circulo); END
        IF (nave_linea1 != 0) delete_draw(nave_linea1); END
        IF (nave_linea2 != 0) delete_draw(nave_linea2); END
        IF (nave_linea3 != 0) delete_draw(nave_linea3); END

        // Dibujar la nave
        nave_circulo = draw(5, COLOR_NAVE, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_NAVE_X, y - TAMANO_NAVE_Y_BASE, x + TAMANO_NAVE_X, y + TAMANO_NAVE_Y_BASE);
        nave_linea1 = draw(1, COLOR_NAVE, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_NAVE_BASE, y + TAMANO_NAVE_Y_BASE, x, y - TAMANO_NAVE_Y_ALTURA);
        nave_linea2 = draw(1, COLOR_NAVE, OPACIDAD_DRAW, REGION_DRAW, x + TAMANO_NAVE_BASE, y + TAMANO_NAVE_Y_BASE, x, y - TAMANO_NAVE_Y_ALTURA);
        nave_linea3 = draw(1, COLOR_NAVE, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_NAVE_BASE, y + TAMANO_NAVE_Y_BASE, x + TAMANO_NAVE_BASE, y + TAMANO_NAVE_Y_BASE);

        // Verificamos si los controles están activos (para evitar mover durante la cuenta regresiva)
        IF (controles_activos == 1)
            // Mover la nave según las teclas
            manejar_controles_jugador(&x, &y, vel);
            // Disparar si pulsamos la tecla de disparo
            manejar_disparo_jugador(&tiempo_disparo, x, y);
            // Comprobar colisiones con enemigos
            comprobar_colision_jugador_enemigos(x, y);
        END

        FRAME;  // Esperar al siguiente frame
    END
END

// Función: manejar_controles_jugador
// Descripción: Maneja el movimiento de la nave del jugador según las teclas de flecha, respetando los límites de la pantalla.
// Parámetros:
//   - x_offset: Puntero a la posición x de la nave. -> Usamos el puntero para modificar la variable original.
//   - y_offset: Puntero a la posición y de la nave. -> Usamos el puntero para modificar la variable original.
//   - vel: Velocidad de movimiento (por valor, ya que no se modifica).
// Los punteros sirven para modificar las variables originales fuera de la función.
// - Si modificas una varariable del puntero dentro de la función, se refleja fuera también.
// - Sirve para evitar el uso de variables globales innecesarias.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION manejar_controles_jugador(INT x_offset, INT y_offset, INT vel);
BEGIN
    // Mover a la izquierda si se presiona la flecha izquierda
    // Controlamos que no podamos salirnos de la pantalla con > TAMANO_NAVE_X (margen izquierdo basado en el tamaño de la nave)
    IF (key(_left) AND *x_offset > TAMANO_NAVE_X)
        *x_offset -= vel;
    END

    // Mover a la derecha si se presiona la flecha derecha y no se sale de la pantalla
    IF (key(_right) AND *x_offset < ANCHO_PANTALLA - TAMANO_NAVE_X)
        *x_offset += vel;
    END

    // Mover arriba si se presiona la flecha arriba y no se sale de la pantalla
    IF (key(_up) AND *y_offset > TAMANO_NAVE_Y_ALTURA)
        *y_offset -= vel;
    END

    // Mover abajo si se presiona la flecha abajo y no se sale de la pantalla
    IF (key(_down) AND *y_offset < ALTO_PANTALLA - TAMANO_NAVE_Y_BASE)
        *y_offset += vel;
    END
END

// Función: manejar_disparo_jugador
// Descripción: Controla el disparo de balas por parte del jugador.
// - Incrementa un contador de tiempo y dispara si se presiona espacio y ha pasado suficiente tiempo.
// Parámetros:
//   - tiempo_disparo_offset: Puntero al contador de tiempo entre disparos. -> Usamos el puntero para modificar la variable original.
//   - x: Posición x de la nave (por valor, ya que no se modifica).
//   - y: Posición y de la nave (por valor, ya que no se modifica).
// Los punteros sirven para modificar las variables originales fuera de la función.
// - Si modificas una varariable del puntero dentro de la función, se refleja fuera también.
// - Sirve para evitar el uso de variables globales innecesarias.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION manejar_disparo_jugador(INT tiempo_disparo_offset, INT x, INT y);
BEGIN
    // Incrementar el contador de tiempo
    // Esto controla la frecuencia de disparo
    // Permite tener un espacio mínimo entre disparos
    // *tiempo_disparo_offset es un puntero, por eso usamos el operador *
    // Lo ponemos entre paréntesis para que la suma se haga sobre el valor apuntado
    (*tiempo_disparo_offset)++;

    // Si se presiona espacio y ha pasado el tiempo mínimo, disparamos una bala
    IF (key(_space) AND *tiempo_disparo_offset > TIEMPO_DISPARO_JUGADOR)
        bala_jugador(x, y - TAMANO_NAVE_Y_ALTURA);  // Crea una bala, situado arriba de la nave
        *tiempo_disparo_offset = 0;  // Reiniciamos el timer
    END
END

// Función: comprobar_colision_jugador_enemigos
// Descripción: Verifica si la nave del jugador colisiona con algún enemigo.
// - Si hay colisión, suma puntos, crea explosiones y termina el juego.
// Parámetros:
//   - x: Posición x de la nave (por valor, ya que no se modifica).
//   - y: Posición y de la nave (por valor, ya que no se modifica).
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION comprobar_colision_jugador_enemigos(INT x, INT y);
PRIVATE
    id_enemigo;  // ID del enemigo para iterar
    INT i;
BEGIN
    // Comprobamos la colisión con enemigos iterando sobre el STRUCT
    FOR (id_enemigo=0; id_enemigo<10; id_enemigo++)
        IF (enemigo[id_enemigo].activo == 1)
            // Calculamos distancia entre jugador y enemigo
            IF (fget_dist(x, y, enemigo[id_enemigo].x, enemigo[id_enemigo].y) < DISTANCIA_COLISION)
                // Significa que ambos han chocado y ambos mueren
                puntos += PUNTOS_POR_ENEMIGO;  // Sumamos los puntos
                IF (enemigo[id_enemigo].tipo == 1)
                    explosion(enemigo[id_enemigo].x, enemigo[id_enemigo].y, COLOR_ENEMIGO1);  // Explosión del enemigo
                ELSE
                    explosion(enemigo[id_enemigo].x, enemigo[id_enemigo].y, COLOR_ENEMIGO2);  // Explosión del enemigo
                END
                enemigo[id_enemigo].activo = 0;  // Marcar enemigo como muerto
                FROM i=0 TO 4;
                    IF (enemigo[id_enemigo].draw[i] != 0) delete_draw(enemigo[id_enemigo].draw[i]); END
                END
                enemigos_vivos--;  // Reducir contador
                explosion(x, y, COLOR_NAVE);  // Explosión del jugador
                game_over = 1;  // Marcamos game over (lo leerá el process principal y actuará en consecuencia)
                RETURN;
            END
        END
    END
END

// Proceso: bala_jugador
// Descripción: Controla el movimiento de una bala disparada por el jugador.
// - Se mueve hacia arriba, dibuja y borra su gráfico, y verifica colisiones con enemigos.
// - Se elimina si sale de la pantalla o colisiona.
// Parámetros:
//   - x: Posición inicial x de la bala.
//   - y: Posición inicial y de la bala.
PROCESS bala_jugador(x, y);
PRIVATE
    bala_draw;  // ID del dibujo de la bala
    INT enemigo_index;      // Index del enemigo con el que colisiona (-1 si no hay colisión)
    INT color_explosion;    // Color de la explosión según el tipo de enemigo
    INT i;                  // Variable para bucles
BEGIN
    LOOP
        // Borramos el  dibujo anterior si existe
        // Si no existe, el ID es 0
        IF (bala_draw != 0) delete_draw(bala_draw); END

        // Dibujamos la bala como una elipse rellena
        // draw(<tipo>, <color>, <opacidad>, <región>, <x0>, <y0>, <x1>, <y1>,)
        /* <tipo> - Tipo de primitiva, dentro de los siguientes:
                1 - Línea recta.
                2 - Rectángulo.
                3 - Rectángulo relleno.
                4 - Elipse.
                5 - Elipse rellena. */
        bala_draw = draw(5, 10, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_BALA_JUGADOR, y - TAMANO_BALA_JUGADOR, x + TAMANO_BALA_JUGADOR, y + TAMANO_BALA_JUGADOR);

        // Movemos la bala hacia arriba
        y -= VEL_BALA_JUGADOR;

        // Borramos la bala si sale de la pantalla por el límite superior
        IF (y < 0)
            delete_draw(bala_draw);  // La bala ha salido de la pantalla, borramos el dibujo y paramos el proceso
            RETURN;
        END

        // Comprobamos si colisiona con algún enemigo
        enemigo_index = comprobar_colision_bala_enemigos(x, y);
        IF (enemigo_index != -1)
            puntos += PUNTOS_POR_ENEMIGO;
            IF (enemigo[enemigo_index].tipo == 1)
                color_explosion = COLOR_ENEMIGO1;
            ELSE
                color_explosion = COLOR_ENEMIGO2;
            END
            explosion(enemigo[enemigo_index].x, enemigo[enemigo_index].y, color_explosion);
            enemigo[enemigo_index].activo = 0;
            FROM i=0 TO 4;
                IF (enemigo[enemigo_index].draw[i] != 0) delete_draw(enemigo[enemigo_index].draw[i]); END
            END
            enemigos_vivos--;
            delete_draw(bala_draw);  // Ha colisionado, borramos el dibujo antes de salir
            RETURN;
        END

        FRAME;  // Esperar al siguiente frame
    END
END

// Función: comprobar_colision_bala_enemigos
// Descripción: Verifica si la bala del jugador colisiona con algún enemigo. Si hay colisión, retorna el index del enemigo.
// Parámetros:
//   - x: Posición x de la bala.
//   - y: Posición y de la bala.
// Retorna: Index del enemigo colisionado (0-4), o -1 si no hay colisión.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION comprobar_colision_bala_enemigos(INT x, INT y);
PRIVATE
    INT i;  // Variable para el bucle
BEGIN
    // Comprobamos si hay colisión con enemigos iterando sobre el array
    FOR (i=0; i<10; i++)
        IF (enemigo[i].activo == 1)
            // Obtenemos la distancia entre bala y enemigo
            IF (fget_dist(x, y, enemigo[i].x, enemigo[i].y) < DISTANCIA_COLISION)
                RETURN(i);  // Retornamos el index del enemigo colisionado
            END
        END
    END
    RETURN(-1);  // No hay colisión
END

// Proceso: proceso_enemigos
// Descripción: Controla el comportamiento de todos los enemigos usando un STRUCT array.
// - Maneja movimiento, disparos y eliminación de enemigos tipo 1 y 2.
// (OPTIMIZACIÓN: Proceso genérico para ambos tipos de enemigos.
// Reduce duplicación de código. Usa parámetro 'tipo' para diferenciar comportamiento.
// Mejora mantenibilidad: cambios en un lugar afectan a ambos tipos.)
PROCESS proceso_enemigos();
PRIVATE
    INT i, j;
    INT tiempo_disparo[10];  // Contador de tiempo para disparos de cada enemigo
BEGIN
    // Dibujo inicial de todos los enemigos
    FOR (i=0; i<10; i++)
        IF (enemigo[i].activo == 1)
            IF (enemigo[i].tipo == 1)
                // Dibujamos el enemigo
                dibujar_enemigo_tipo1(&enemigo[i].draw[0], &enemigo[i].draw[1], enemigo[i].x, enemigo[i].y);
            ELSE
                // Dibujamos el enemigo de tipo 2
                dibujar_enemigo_tipo2(&enemigo[i].draw[0], &enemigo[i].draw[1], &enemigo[i].draw[2], &enemigo[i].draw[3], &enemigo[i].draw[4], enemigo[i].x, enemigo[i].y);
            END
        END
    END

    LOOP
        // Si el juego ha terminado, salimos del proceso
        IF (game_over == 1) RETURN; END

        // Por cada enemigo
        FOR (i=0; i<10; i++)
            // Verificamos si está vivo
            IF (enemigo[i].activo == 1)
                // Verificamos si los controles están activos (p. ej., no durante la cuenta regresiva)
                IF (controles_activos == 1)
                    // Movemos en función del tipo
                    IF (enemigo[i].tipo == 1)
                        // Movemos el enemigo tipo 1
                        mover_enemigo_tipo1(&enemigo[i].x, &enemigo[i].y, &enemigo[i].dir);
                    ELSE
                        // Movemos el enemigo tipo 2
                        mover_enemigo_tipo2(&enemigo[i].x, &enemigo[i].y, &enemigo[i].ang);
                    END

                    // Verificar si sale de pantalla
                    IF (enemigo[i].tipo == 1 AND enemigo[i].y > ALTO_PANTALLA + TAMANO_ENEMIGO1)
                        enemigo[i].activo = 0;
                        FROM j=0 TO 4;
                            IF (enemigo[i].draw[j] != 0) delete_draw(enemigo[i].draw[j]); END
                        END
                    END

                    // Dibujamos el enemigo en función del tipo
                    IF (enemigo[i].tipo == 1)
                        dibujar_enemigo_tipo1(&enemigo[i].draw[0], &enemigo[i].draw[1], enemigo[i].x, enemigo[i].y);
                    ELSE
                        dibujar_enemigo_tipo2(&enemigo[i].draw[0], &enemigo[i].draw[1], &enemigo[i].draw[2], &enemigo[i].draw[3], &enemigo[i].draw[4], enemigo[i].x, enemigo[i].y);
                    END

                    // Disparar en función del tipo
                    IF (enemigo[i].tipo == 1)
                        disparar_enemigo_tipo1(&tiempo_disparo[i], enemigo[i].x, enemigo[i].y);
                    ELSE
                        disparar_enemigo_tipo2(&tiempo_disparo[i], enemigo[i].x, enemigo[i].y);
                    END
                END
            END
        END

        FRAME;
    END
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
    // Movemos horizontalmente el enemigo según su dirección actual
    *x_offset += *dir_offset * VEL_ENEMIGO1_HORIZONTAL;
    // Si llega a los bordes, cambiamos dirección y lo hacemos bajar un poco
    IF (*x_offset > ANCHO_PANTALLA - (TAMANO_ENEMIGO1 + DISTANCIA_COLISION) OR *x_offset < TAMANO_ENEMIGO1 + DISTANCIA_COLISION)
        *dir_offset = -*dir_offset;     // Cambiamos dirección  
        *y_offset += DESCENSO_ENEMIGO1; // Descendemos
    END
END

// Función: disparar_enemigo_tipo1
// Descripción: Controla el disparo periódico del enemigo tipo 1.
// Parámetros:
//   - tiempo_offset: Puntero al contador de tiempo. -> Usamos el puntero para modificar la variable original.
//   - x: Posición x para disparar.
//   - y: Posición y para disparar.
// Los punteros sirven para modificar las variables originales fuera de la función.
// - Si modificas una varariable del puntero dentro de la función, se refleja fuera también.
// - Sirve para evitar el uso de variables globales innecesarias.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION disparar_enemigo_tipo1(INT tiempo_offset, x, y);
BEGIN
    (*tiempo_offset)++;     // (*tiempo_offset) es el valor apuntado por el puntero, con ++ lo incrementamos en una unidad.
    // Verificamos si se cumple con el espaciado (para que las balas no estén muy juntas)
    IF (*tiempo_offset > TIEMPO_DISPARO_ENEMIGO1)
        // Cumplido el tiempo, disparamos una bala
        bala_enemiga_tipo1(x, y);   // Cremos una bala enemiga tipo 1
        *tiempo_offset = 0;         // Reiniciamos el contador de tiempo
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
    *box_offset = draw(3, COLOR_ENEMIGO1, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_ENEMIGO1, y - TAMANO_ENEMIGO1, x + TAMANO_ENEMIGO1, y + TAMANO_ENEMIGO1);
    *circulo_offset = draw(5, 4, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_ENEMIGO1_CIRCULO, y - TAMANO_ENEMIGO1_CIRCULO, x + TAMANO_ENEMIGO1_CIRCULO, y + TAMANO_ENEMIGO1_CIRCULO);
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
    // Incrementamos el ángulo y nos movemos en círculo
    *ang_offset += INCREMENTO_ANGULO_ENEMIGO2;
    *x_offset += get_distx(*ang_offset, RADIO_MOVIMIENTO_ENEMIGO2);
    *y_offset += get_disty(*ang_offset, RADIO_MOVIMIENTO_ENEMIGO2);
    
    // Verificamos que no salgamos de los límites de la pantalla
    IF (*x_offset < TAMANO_ENEMIGO2_LINEA + TAMANO_ENEMIGO2_CIRCULO)
         *x_offset = TAMANO_ENEMIGO2_LINEA + TAMANO_ENEMIGO2_CIRCULO;
    ELSE
        IF (*x_offset > ANCHO_PANTALLA - (TAMANO_ENEMIGO2_LINEA + TAMANO_ENEMIGO2_CIRCULO))
            *x_offset = ANCHO_PANTALLA - (TAMANO_ENEMIGO2_LINEA + TAMANO_ENEMIGO2_CIRCULO);
        END
    END
    IF (*y_offset < TAMANO_ENEMIGO2_LINEA + TAMANO_ENEMIGO2_CIRCULO)
        *y_offset = TAMANO_ENEMIGO2_LINEA + TAMANO_ENEMIGO2_CIRCULO;
    ELSE
        IF (*y_offset > ALTO_PANTALLA - (TAMANO_ENEMIGO2_LINEA + TAMANO_ENEMIGO2_CIRCULO))
            *y_offset = ALTO_PANTALLA - (TAMANO_ENEMIGO2_LINEA + TAMANO_ENEMIGO2_CIRCULO);
        END
    END
END

// Función: disparar_enemigo_tipo2
// Descripción: Controla el disparo periódico del enemigo tipo 2.
// Parámetros:
//   - tiempo_offset: Puntero al contador de tiempo. -> Usamos el puntero para modificar la variable original.
//   - x: Posición x para disparar.
//   - y: Posición y para disparar.
// Los punteros sirven para modificar las variables originales fuera de la función.
// - Si modificas una varariable del puntero dentro de la función, se refleja fuera también.
// - Sirve para evitar el uso de variables globales innecesarias.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION disparar_enemigo_tipo2(INT tiempo_offset, x, y);
BEGIN
    (*tiempo_offset)++; // Incrementamos el contador de tiempo. (*tiempo_offset) es el valor apuntado por el puntero, con ++ lo incrementamos en una unidad.
    // Verificamos si se cumple con el espaciado (para que las balas no estén muy juntas)
    IF (*tiempo_offset > TIEMPO_DISPARO_ENEMIGO2)
        // Cumplido el tiempo, disparamos una bala
        bala_enemiga_tipo2(x, y);   // Creamos una bala enemiga tipo 2
        *tiempo_offset = 0;         // Reiniciamos el contador de tiempo
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
    // Borramos los dibujos del anterior frame
    // Comprobamos que existen (ID != 0) antes de borrarlos
    // Si no lo comprobamos, tendríamos una excepción en el primer FRAME y el juego se colgaría
    IF (*linea1_offset != 0) delete_draw(*linea1_offset); END
    IF (*linea2_offset != 0) delete_draw(*linea2_offset); END
    IF (*linea3_offset != 0) delete_draw(*linea3_offset); END
    IF (*linea4_offset != 0) delete_draw(*linea4_offset); END
    IF (*circulo_offset != 0) delete_draw(*circulo_offset); END

    // Dibujamos el enemigo de tipo 2
    *linea1_offset = draw(1, COLOR_ENEMIGO2, OPACIDAD_DRAW, REGION_DRAW, x, y - TAMANO_ENEMIGO2_LINEA, x + TAMANO_ENEMIGO2_LINEA, y);
    *linea2_offset = draw(1, COLOR_ENEMIGO2, OPACIDAD_DRAW, REGION_DRAW, x + TAMANO_ENEMIGO2_LINEA, y, x, y + TAMANO_ENEMIGO2_LINEA);
    *linea3_offset = draw(1, COLOR_ENEMIGO2, OPACIDAD_DRAW, REGION_DRAW, x, y + TAMANO_ENEMIGO2_LINEA, x - TAMANO_ENEMIGO2_LINEA, y);
    *linea4_offset = draw(1, COLOR_ENEMIGO2, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_ENEMIGO2_LINEA, y, x, y - TAMANO_ENEMIGO2_LINEA);
    *circulo_offset = draw(5, 9, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_ENEMIGO2_CIRCULO, y - TAMANO_ENEMIGO2_CIRCULO, x + TAMANO_ENEMIGO2_CIRCULO, y + TAMANO_ENEMIGO2_CIRCULO);
END


// Proceso: bala_enemiga_tipo1
// Descripción: Controla el movimiento de una bala disparada por un enemigo tipo 1.
// - Se mueve hacia abajo, dibuja y verifica colisiones con el jugador.
// - Se elimina si sale de la pantalla o colisiona.
// Parámetros:
//   - x: Posición inicial x.
//   - y: Posición inicial y.
PROCESS bala_enemiga_tipo1(x, y);
PRIVATE
    bala_draw;  // ID del dibujo de la bala
    id_player;  // ID del jugador (para detectar la colisión)
BEGIN
    // Bucle principal de la bala enemiga tipo 1
    LOOP
        // Si el juego terminó, acabamos el proceso
        IF (game_over == 1)
            RETURN;
        END

        // Borramos dibujo anterior si existe
        IF (bala_draw != 0) delete_draw(bala_draw); END

        // Dibujamos bala enemiga como un círculo rojo
        bala_draw = draw(5, COLOR_ENEMIGO1, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_BALA_ENEMIGA1, y - TAMANO_BALA_ENEMIGA1, x + TAMANO_BALA_ENEMIGA1, y + TAMANO_BALA_ENEMIGA1);

        // Desplazamos la bala hacia abajo
       y += VEL_BALA_ENEMIGA1;

        // Eliminamos la bala si sale de la pantalla
        IF (y > ALTO_PANTALLA)
            // Estamos fuera de la pantalla, borramos el dibujo y paramos el proceso
            delete_draw(bala_draw);
            RETURN;
        END

        // Obtenemos el ID del jugador para comprobar colisión
        id_player = get_id(type jugador);
        IF (id_player != 0)
            IF (fget_dist(x, y, id_player.x, id_player.y) < DISTANCIA_COLISION)
                // El jugador está vivo y hay colisión
                explosion(id_player.x, id_player.y, COLOR_NAVE);  // Dibujamos la explosión del jugador
                game_over = 1;                                    // Marcamos game over
                RETURN;                                           // Paramamos el proceso
            END
        END
        
        FRAME;  // Esperamos al siguiente frame
    END
END

// Proceso: bala_enemiga_tipo2
// Descripción: Controla el movimiento de una bala disparada por un enemigo tipo 2.
// - Apunta al jugador y se mueve en esa dirección.
// - Una vez disparado, no vuelve a cambiar de dirección.
// - Se elimina si sale de la pantalla o colisiona.
// Parámetros:
//   - x: Posición inicial x.
//   - y: Posición inicial y.
PROCESS bala_enemiga_tipo2(x, y);
PRIVATE
    angulo;         // Ángulo de dirección hacia el jugador
    id_jugador;     // ID del jugador (para calcular ángulo y detectar colisión)
    bala_draw;      // ID del dibujo de la bala
BEGIN
    // Buscamos al jugador para calcular el ángulo de disparo
    id_jugador = get_id(type jugador);
    
    IF (id_jugador != 0)
        // El jugador está vivo, calculamos el ángulo hacia él
        angulo = fget_angle(x, y, id_jugador.x, id_jugador.y);
    ELSE
        // No hay jugador, disparamos hacia abajo por defecto
        angulo = ANGULO_DEFECTO_BALA;
    END
    
    // Bucle principal de la bala enemiga tipo 2    
    LOOP
         // Si el juego terminó, salimos
        IF (game_over == 1)
            RETURN;
        END

        // Borramos dibujo anterior si existe
        IF (bala_draw != 0) delete_draw(bala_draw); END
        
        // Dibujamos bala enemiga tipo 2 como círculo azul
        bala_draw = draw(5, COLOR_ENEMIGO2, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_BALA_ENEMIGA2, y - TAMANO_BALA_ENEMIGA2, x + TAMANO_BALA_ENEMIGA2, y + TAMANO_BALA_ENEMIGA2);
        
        // Desplazamos la bala a la dirección calculada
        x += get_distx(angulo, VEL_BALA_ENEMIGA2);
        y += get_disty(angulo, VEL_BALA_ENEMIGA2);

        // Eliminamos la bala si sale de la pantalla
        IF (y > ALTO_PANTALLA OR y < 0 OR x < 0 OR x > ANCHO_PANTALLA)
            // Estamos fuera de la pantalla, borramos el dibujo y paramos el proceso
            delete_draw(bala_draw);
            RETURN;
        END

        // Comprobamos colisión con el jugador
        // Obtenemos el ID del jugador
        id_jugador = get_id(type jugador);
        IF (id_jugador != 0)
            IF (fget_dist(x, y, id_jugador.x, id_jugador.y) < DISTANCIA_COLISION)
                // El jugador está vivo y hay colisión matamos al jugador
                explosion(id_jugador.x, id_jugador.y, COLOR_NAVE);  // Explosión del jugador
                game_over = 1;                                      // Marcamos game over
                RETURN;                                             // Paramamos el proceso
            END
        END

        FRAME;  // Esperamos al siguiente frame
    END
END

// Proceso: explosion
// Descripción: Crea una animación de explosión en la posición dada.
// - Dibuja círculos crecientes de color especificado durante varias iteraciones.
// - Borra el último dibujo si no es game over (así podemos ver la explosión "parada" en game over y entender qué ha pasado).
// Parámetros:
//   - x: Posición x de la explosión.
//   - y: Posición y de la explosión.
//   - color: Color de la explosión.
PROCESS explosion(x, y, color);
PRIVATE
    i;                                  // Contador para el bucle
    radio = RADIO_INICIAL_EXPLOSION;    // Radio inicial del círculo
    exp_draw;                           // ID del dibujo de la explosión
BEGIN
    // Animamos la explosión con círculos crecientes
    FROM i=0 TO 9; // Animación de 9 frames
        IF (exp_draw != 0) delete_draw(exp_draw); END  // Borramos dibujo anterior, si existe
        exp_draw = draw(5, color, OPACIDAD_DRAW, REGION_DRAW, x - radio, y - radio, x + radio, y + radio);  // Dubujamos un círculo
        radio += INCREMENTO_RADIO_EXPLOSION;  // Augmentamos radio
        FRAME;  // Esperamos al siguiente frame
    END
    
    // Borramos el último dibujo, si no es game over
    IF (game_over == 0)
        delete_draw(exp_draw);
    END
END

// Función: cuenta_regresiva (OPTIMIZACIÓN: Función genérica para cuentas regresivas.
// Reduce duplicación entre cuenta_regresiva e inicio_nivel.)
// Descripción: Muestra una pantalla de felicitación con puntos y una cuenta regresiva antes del siguiente nivel.
// - Espera a que el usuario pulse espacio para continuar.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Aunque tenga FRAME dentro, es una función y bloquea el proceso que la llama (hack de DIV)
// - Según la documentación de DIV, el compilador si detecta un FRAME lo transforma en un PROCESS automáticamente
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION cuenta_regresiva();
PRIVATE
    INT contador = SEGUNDOS_CUENTA_REGRESIVA;   // Segundos para el siguiente nivel
    INT tiempo = 0;                             // Contador de frames
    STRING puntos_str;                          // String para mostrar puntos
    STRING contador_str;                        // String para mostrar contador
BEGIN
    // Bucle de cuenta regresiva
    WHILE (contador > 0)
        delete_text(all_text);  // Limpiamos TODS los textos anteriores
        mostrar_textos_hud();   // Dibujamos los textos del HUD
        write(0, CENTRO_X, 60, 1, "ENHORABUENA!");       // Mensaje de felicitación
        write(0, CENTRO_X, 80, 1, "NIVEL COMPLETADO!");
        puntos_str = "Puntos: " + itoa(puntos);                     // Convertimos los puntos a string
        contador_str = "Siguiente nivel en: " + itoa(contador);     // Convertimos el contador a string
        write(0, CENTRO_X, 100, 1, puntos_str);             // Mostramos puntos
        write(0, CENTRO_X, 120, 1, contador_str);           // Mostramos contador regresivo
        
        tiempo++;   // Incrementamos el contador de frames
        IF (tiempo >= FPS_JUEGO)
            // Ha pasado 1 segundo, actualizamos la cuenta atrás
            contador--;
            tiempo = 0;
        END
        
        // Siguiente frame
        FRAME;
    END
    
    // Esperamos a que se suelte la tecla espacio
    // Evita que se salte la pantalla si se mantiene pulsada
    // scan_code contiene el código de la última tecla pulsada
    // Si scan_code es 0, no hay ninguna tecla pulsada
    WHILE (scan_code != 0)
        FRAME;
    END
    delete_draw(all_drawing);  // Limpiamos todos los dibujos de la pantalla
    delete_text(all_text);     // Limpiamos todos los textos
    mostrar_textos_hud();      // Volmemos a dibujar los textos del HUD
END

// Función: pantalla_game_over
// Descripción: Muestra la pantalla de game over con puntos y una cuenta regresiva para reiniciar.
//              Espera a que el usuario pulse espacio para continuar.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Aunque tenga FRAME dentro, es una función y bloquea el proceso que la llama (hack de DIV)
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION pantalla_game_over();
PRIVATE
    STRING puntos_str;  // String para mostrar puntos
BEGIN
    delete_text(all_text);  // Limpiamos TODOS los textos anteriores
    mostrar_textos_hud();   // Volvemos a dibujar los textos del HUD
    write(0, CENTRO_X, CENTRO_Y - 20, ALINEACION_CENTRADO, "GAME OVER!");  // Mensaje de game over
    puntos_str = "Puntos: " + itoa(puntos);  // Mostramos los puntos
    write(0, CENTRO_X, CENTRO_Y, ALINEACION_CENTRADO, puntos_str);
    write(0, CENTRO_X, CENTRO_Y + 20, ALINEACION_CENTRADO, "Pulsa ESPACIO para continuar");
    
    // Esperamos a que se suelte la tecla espacio
    // Evita que se salte la pantalla si se mantiene pulsada
    // scan_code contiene el código de la última tecla pulsada
    // Si scan_code es 0, no hay ninguna tecla pulsada
    WHILE (scan_code != 0)
        FRAME;
    END

    // Ahora esperar a que se pulse espacio
    LOOP
        IF (key(_space))
            // Se ha pulsado espacio, paramos la función para reiniciar la partida  
            delete_text(all_text);// Limpiamos TODOS textos
            mostrar_textos_hud(); // Volvemos a dibujar los textos del HUD
            RETURN;
        END

        FRAME; // Siguiente frame
    END
END

// Función: inicio_nivel
// Descripción: Inicializa un nuevo nivel mostrando una cuenta regresiva (3, 2, 1, GO!) y creando los procesos de enemigos y jugador.
// - Desactiva controles durante la cuenta y los activa al final.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Aunque tenga FRAME dentro, es una función y bloquea el proceso que la llama (hack de DIV)
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION inicio_nivel();
PRIVATE
    INT contador;   // Cuenta regresiva: 3, 2, 1, GO!
    INT tiempo;     // Contador de frames
    STRING contador_str;// String para mostrar contador
BEGIN
    // Limpiar procesos residuales del nivel anterior para evitar IDs inválidos
    signal(type jugador, s_kill);
    signal(type bala_jugador, s_kill);
    signal(type bala_enemiga_tipo1, s_kill);
    signal(type bala_enemiga_tipo2, s_kill);
    // No matar explosiones para que se vean durante la cuenta regresiva

    // Limpiar dibujos, textos y procesos residuales del nivel anterior
    delete_draw(all_drawing);
    delete_text(all_text);
    mostrar_textos_hud();   // Volmemos a dibujar los textos del HUD

    // Desactivamos controles durante la cuenta regresiva
    controles_activos = 0;

    // Creamos naves pero sin movimiento
    crear_enemigos();  // Creamos enemigos
    // Crear jugador solo si no existe
    IF (get_id(type jugador) == 0)
        jugador();  // Crear jugador
    END
    // Resetear posición del jugador para el nuevo nivel
    
    // Esperar un momento para que se vean las naves
    FRAME;
    FRAME;
    
    // Cuenta regresiva 3, 2, 1, GO!
    contador = 3;   // Cuenta regresiva: 3, 2, 1, GO!
    tiempo = 0;     // Contador de frames
    WHILE (contador > 0)
        contador_str = itoa(contador);        // Convertimos el número a string (itoi = integer to ascii)
        write(0, CENTRO_X, CENTRO_Y, ALINEACION_CENTRADO, contador_str);  // 4 = centrado
        
        tiempo++;
        IF (tiempo >= FPS_JUEGO)
            // Ha pasado un segundo, actualizamos la cuenta atrás
            contador--;
            tiempo = 0;
            delete_text(all_text);  // Limpiamos todos los textos
            mostrar_textos_hud();   // Volmemos a dibujar los textos del HUD
        END
        
        FRAME; // Siguiente frame
    END
    
    // Mostramos el GO!
    write(0, CENTRO_X, CENTRO_Y, ALINEACION_CENTRADO, "GO!"); // 4 = centrado
    tiempo = 0;
    WHILE (tiempo < FPS_JUEGO / 2)
        FRAME;
        tiempo++;
    END  // Mostramos GO! por 0,5 segundos
    
    delete_text(all_text);  // Limpiamos todos los textos
    mostrar_textos_hud();   // Volmemos a dibujar los textos del HUD
    controles_activos = 1;  // Activar controles para empezar el juego
END
