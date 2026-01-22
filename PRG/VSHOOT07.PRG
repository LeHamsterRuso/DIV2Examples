//------------------------------------------------------------------------------
// TÍTULO:      VSHOOT07.PRG - Optimización del Sistema de Balas
// AUTOR:       Sebastian J. MONCHO MAQUET
// FECHA:       23/01/2026
// DESCRIPCIÓN: Versión optimizada que usa arrays/struct separados para balas del jugador y enemigas
//              en lugar de procesos individuales, mejorando el rendimiento.
//              - Sistema de balas centralizado con DOS procesos separados (jugador/enemigas)
//              - Arrays separados: bala_jugador[MAX_BALAS_JUGADOR] y bala_enemigo[MAX_BALAS_ENEMIGO]
//              - Listas enlazadas separadas para gestión eficiente de slots libres/activos
//              - Eliminación de magic numbers: constantes para márgenes, colores, tipos de dibujo, gráficos, ángulos
//              - Reduce overhead de procesos y elimina checks innecesarios por tipo
//              - Mejora rendimiento cuando hay muchas balas en pantalla (50+)
//
// NOTA:        Usa las flechas para mover la nave, espacio para disparar y ESC para salir.
//              Requiere DIV2.PAL, TANYA/LEVEL000.FPG, TANYA/PLAYER.FPG y los FNT de la caperta TANYA.
//              Código y comentarios en castellano para facilitar la comprensión.
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
    DISTANCIA_COLISION_JUGADOR = 12; // Distancia de colisión para el jugador
    TAMANO_NAVE_X = 8;              // Tamaño horizontal de la nave del jugador en píxeles
    TAMANO_NAVE_Y_BASE = 8;         // Tamaño vertical base de la nave del jugador en píxeles
    TAMANO_NAVE_Y_ALTURA = 10;      // Altura del vértice superior de la nave del jugador en píxeles

    // Parámetros de enemigos
    NUM_ENEMIGOS_INICIAL = 10;      // Número inicial de enemigos por nivel
    DISTANCIA_COLISION = 12;        // Distancia mínima para considerar una colisión entre objetos
    DISTANCIA_COLISION_CUADRADO = 144;  // DISTANCIA_COLISION * DISTANCIA_COLISION (optimización)
    DISTANCIA_COLISION_JUGADOR = 12; // Distancia de colisión para el jugador
    DISTANCIA_COLISION_JUGADOR_CUADRADO = 144;  // DISTANCIA_COLISION_JUGADOR * DISTANCIA_COLISION_JUGADOR (optimización)
    PUNTOS_POR_ENEMIGO = 10;        // Puntos otorgados por destruir a un enemigo

    // Enemigo tipo 1
    VEL_ENEMIGO1_HORIZONTAL = 2;    // Velocidad horizontal del enemigo tipo 1
    DESCENSO_ENEMIGO1 = 5;          // Descenso vertical del enemigo tipo 1 al cambiar de dirección
    TIEMPO_DISPARO_ENEMIGO1 = 80;   // Tiempo entre disparos del enemigo tipo 1 (en frames)
    COLOR_ENEMIGO1 = 114;           // Color del enemigo tipo 1 (paleta DIV2.PAL)
    TAMANO_ENEMIGO1 = 8;            // Tamaño del enemigo tipo 1 en píxeles
    TAMANO_ENEMIGO1_CIRCULO = 3;    // Tamaño del círculo interno del enemigo tipo 1 en píxeles

    // Enemigo tipo 2
    INCREMENTO_ANGULO_ENEMIGO2 = 5000;  // Incremento del ángulo para movimiento circular del enemigo tipo 2
    RADIO_MOVIMIENTO_ENEMIGO2 = 1;      // Radio del movimiento circular del enemigo tipo 2
    TIEMPO_DISPARO_ENEMIGO2 = 65;       // Tiempo entre disparos del enemigo tipo 2 (en frames)
    COLOR_ENEMIGO2 = 9;                 // Color del enemigo tipo 2 (paleta DIV2.PAL)
    TAMANO_ENEMIGO2_LINEA = 8;          // Tamaño de las líneas del enemigo tipo 2 en píxeles
    TAMANO_ENEMIGO2_CIRCULO = 2;        // Tamaño del círculo interno del enemigo tipo 2 en píxeles

    // Balas
    MAX_BALAS_JUGADOR = 50;            // Número máximo de balas simultáneas del jugador
    MAX_BALAS_ENEMIGO = 150;            // Número máximo de balas simultáneas de enemigos
    TIPO_BALA_ENEMIGA1 = 1;             // Tipo de bala: enemigo tipo 1
    TIPO_BALA_ENEMIGA2 = 2;             // Tipo de bala: enemigo tipo 2
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
    ALINEACION_IZQUIERDA = 0;           // Alineación izquierda para textos
    TIPO_DIBUJO_CIRCULO_RELLENO = 5;   // Tipo de dibujo para círculos rellenos

    // Parámetros de colisión y optimización
    MARGEN_BOUNDING_BOX = 20;           // Margen para bounding box de colisión rápida
    VARIACION_TIEMPO_DISPARO_ENEMIGO = 15; // Variación aleatoria en tiempo de disparo enemigo

    // Colores adicionales
    COLOR_EXPLOSION_PEQUENA = 61;       // Color para explosiones pequeñas
    COLOR_ENEMIGO1_CIRCULO = 4;         // Color del círculo interno del enemigo tipo 1
    COLOR_ENEMIGO2_CIRCULO = 9;         // Color del círculo interno del enemigo tipo 2

    // Parámetros de explosiones
    ITERACIONES_EXPLOSION_PEQUENA = 3; // Número de iteraciones para explosión pequeña

    // Parámetros de gráficos y rotaciones
    GRAFICO_ENEMIGO1 = 2;               // Gráfico FPG para enemigo tipo 1
    GRAFICO_ENEMIGO2 = 3;               // Gráfico FPG para enemigo tipo 2
    ANGULO_ROTACION_ENEMIGO = 15000;   // Ángulo de rotación para enemigos tipo 1 (15 grados * 1000)
    ANGULO_ROTACION_ENEMIGO_OPUESTA = 345000; // Ángulo opuesto (360° - 15°)
    ESCALA_ENEMIGO = 100;               // Escala para xput de enemigos
    CENTRO_XPUT = 0;                    // Centro X para xput
    CENTRO_YPUT = 0;                    // Centro Y para xput

    // Posiciones de texto para pantallas de cuenta regresiva
    POS_Y_CUENTA_REGRESIVA_BASE = 30;   // Posición Y base para mensajes de cuenta regresiva
    ESPACIADO_LINEA_NORMAL = 30;        // Espaciado entre líneas de texto normal

    // Posiciones de texto para pantalla de game over
    ESPACIADO_GAMEOVER = 30;            // Espaciado vertical para textos en game over
    POS_Y_GAMEOVER = CENTRO_Y - ESPACIADO_GAMEOVER;  // Posición Y para "GAME OVER!"
    POS_Y_PUNTOS_GAMEOVER = CENTRO_Y;   // Posición Y para puntos en game over
    POS_Y_PULSA_ESPACIO = CENTRO_Y + ESPACIADO_GAMEOVER;  // Posición Y para "[PULSA ESPACIO]"

// Variables globales del juego
// Estas variables mantienen el estado del juego y son accesibles desde cualquier parte del programa.
GLOBAL
    INT puntos = 0;                     // Puntuación actual del jugador
    INT enemigos_vivos = 0;             // Número de enemigos vivos en el nivel actual
    INT nivel = 1;                      // Nivel actual del juego
    game_over = 0;                      // Indicador de estado de juego (0 = jugando, 1 = game over)
    enemigo_muerto_id = 0;              // ID del enemigo marcado como "muerto"
    controles_activos = 0;              // Contemplaa si los controles del jugador están activos (1) o desactivados (0), empleado, por ejemplo, durante la cuenta regresiva
    primera_bala_jugador_activa = -1;   // Índice de la primera bala jugador activa en la lista enlazada (-1 = lista vacía)
    primer_slot_libre_jugador = 0;      // Índice del primer slot libre para balas jugador
    primera_bala_enemigo_activa = -1;   // Índice de la primera bala enemigo activa en la lista enlazada (-1 = lista vacía)
    primer_slot_libre_enemigo = 0;      // Índice del primer slot libre para balas enemigo
    primera_enemigo_activo = -1;        // Índice del primer enemigo activo en la lista enlazada (-1 = lista vacía)
    FPG_LEVEL = 0;                      // Código del fichero FPG del nivel
    FPG_PLAYER = 0;                     // Código del fichero FPG del jugador
    FNT_HUD = 0;                        // Código del fichero FNT para el HUD
    FNT_NORMAL = 0;                     // Código del fichero FNT normal
    FNT_COUNTER = 0;                    // Código del fichero FNT para contadores
    FNT_PRESS = 0;                      // Código del fichero FNT para "PULSA ESPACIO"
    FNT_GAMEOVER = 0;                   // Código del fichero FNT para "GAME OVER"

// Definición de struct para enemigo
STRUCT enemigo[10]
    INT x;       // Posición X
    INT y;       // Posición Y
    INT tipo;    // Tipo de enemigo (1 o 2)
    INT activo;  // Si está activo (1) o muerto/inactivo (0)
    INT dir;     // Dirección horizontal para tipo1 (1 derecha, -1 izquierda)
    INT ang;     // Ángulo para movimiento circular de tipo2
    INT draw[5]; // Array de IDs de dibujos (5 slots por enemigo)
    INT siguiente; // Índice del siguiente enemigo activo (-1 = fin de lista)
END

// Definición de struct para balas del jugador (OPTIMIZACIÓN: Lista enlazada separada)
// Almacena balas del jugador en array con lista enlazada para optimizar acceso
STRUCT bala_jugador[MAX_BALAS_JUGADOR]
    INT x;         // Posición X de la bala
    INT y;         // Posición Y de la bala
    INT activo;    // Si está activa (1) o inactiva (0)
    INT dx;        // Delta X precalculado para movimiento (siempre 0 para jugador)
    INT dy;        // Delta Y precalculado para movimiento (hacia arriba)
    INT tamano;    // Tamaño precalculado para dibujo
    INT color;     // Color precalculado para dibujo
    INT draw_id;   // ID del dibujo de la bala
    INT siguiente; // Índice del siguiente slot en la lista (-1 = fin de lista)
END

// Definición de struct para balas enemigas (OPTIMIZACIÓN: Lista enlazada separada)
// Almacena balas enemigas en array con lista enlazada para optimizar acceso
STRUCT bala_enemigo[MAX_BALAS_ENEMIGO]
    INT x;         // Posición X de la bala
    INT y;         // Posición Y de la bala
    INT tipo;      // Tipo de bala enemiga (1=enemigo1, 2=enemigo2)
    INT activo;    // Si está activa (1) o inactiva (0)
    INT angulo;    // Ángulo de movimiento (para balas enemigo tipo 2)
    INT dx;        // Delta X precalculado para movimiento
    INT dy;        // Delta Y precalculado para movimiento
    INT tamano;    // Tamaño precalculado para dibujo
    INT color;     // Color precalculado para dibujo
    INT draw_id;   // ID del dibujo de la bala
    INT siguiente; // Índice del siguiente slot en la lista (-1 = fin de lista)
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

    // Cargar archivos FPG
    FPG_LEVEL = load_fpg("TANYA/LEVEL000.FPG");
    FPG_PLAYER = load_fpg("TANYA/PLAYER.FPG");

    // Cargar fuentes
    FNT_HUD = load_fnt("TANYA/HUD.FNT");
    FNT_NORMAL = load_fnt("TANYA/NORMAL.FNT");
    FNT_COUNTER = load_fnt("TANYA/COUNTER.FNT");
    FNT_PRESS = load_fnt("TANYA/PRESS.FNT");
    FNT_GAMEOVER = load_fnt("TANYA/GAMEOVER.FNT");

    // Mostramos los puntos y el nivel
    mostrar_textos_hud();

    // Valores por defecto al iniciar el juego
    puntos = 0;
    enemigos_vivos = NUM_ENEMIGOS_INICIAL;
    game_over = 0;

    // Mostrar fondo
    put_screen(FPG_LEVEL, 1);

    // Iniciar el primer nivel
    // Esto llena la pantalla de enemigos y prepara el juego para empezar.
    // También añade al jugador
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
    write(FNT_HUD, POS_X_ETIQUETAS, POS_Y_PUNTOS, ALINEACION_IZQUIERDA, "PUNTOS:");
    write(FNT_HUD, POS_X_ETIQUETAS, POS_Y_NIVEL, ALINEACION_IZQUIERDA, "NIVEL:");
    write(0, POS_X_ETIQUETAS, POS_Y_FPS, ALINEACION_IZQUIERDA, "FPS:");

    // Dibujar valores dinámicos usando write_int
    // Offset para pasar la dirección de la variable (puntero)
    // El valor se actualizará automáticamente al cambiar la variable
    write_int(FNT_HUD, POS_X_VALORES, POS_Y_PUNTOS, 0, OFFSET puntos);
    write_int(FNT_HUD, POS_X_VALORES, POS_Y_NIVEL, 0, OFFSET nivel);
    write_int(0, POS_X_FPS, POS_Y_FPS, 0, OFFSET fps);
END

// Función: inicializar_balas_jugador (OPTIMIZACIÓN: Lista enlazada separada)
// Descripción: Inicializa la lista enlazada de slots libres para balas del jugador
FUNCTION inicializar_balas_jugador();
PRIVATE
    INT i;  // Variable de bucle
BEGIN
    // Construir lista enlazada de slots libres
    FOR (i=0; i<MAX_BALAS_JUGADOR-1; i++)
        bala_jugador[i].activo = 0;
        bala_jugador[i].draw_id = 0;
        bala_jugador[i].siguiente = i + 1;  // Apuntar al siguiente slot
    END
    // Último slot
    bala_jugador[MAX_BALAS_JUGADOR-1].activo = 0;
    bala_jugador[MAX_BALAS_JUGADOR-1].draw_id = 0;
    bala_jugador[MAX_BALAS_JUGADOR-1].siguiente = -1;  // Fin de lista
    
    // Inicializar cabeceras de listas
    primera_bala_jugador_activa = -1;  // Lista de activas vacía
    primer_slot_libre_jugador = 0;      // Lista de libres empieza en 0
END

// Función: inicializar_balas_enemigo (OPTIMIZACIÓN: Lista enlazada separada)
// Descripción: Inicializa la lista enlazada de slots libres para balas enemigas
FUNCTION inicializar_balas_enemigo();
PRIVATE
    INT i;  // Variable de bucle
BEGIN
    // Construir lista enlazada de slots libres
    FOR (i=0; i<MAX_BALAS_ENEMIGO-1; i++)
        bala_enemigo[i].activo = 0;
        bala_enemigo[i].draw_id = 0;
        bala_enemigo[i].siguiente = i + 1;  // Apuntar al siguiente slot
    END
    // Último slot
    bala_enemigo[MAX_BALAS_ENEMIGO-1].activo = 0;
    bala_enemigo[MAX_BALAS_ENEMIGO-1].draw_id = 0;
    bala_enemigo[MAX_BALAS_ENEMIGO-1].siguiente = -1;  // Fin de lista
    
    // Inicializar cabeceras de listas
    primera_bala_enemigo_activa = -1;  // Lista de activas vacía
    primer_slot_libre_enemigo = 0;      // Lista de libres empieza en 0
END

// Función: crear_bala_jugador (OPTIMIZACIÓN: Lista enlazada separada)
// Descripción: Crea una nueva bala del jugador usando lista enlazada de slots libres
// Parámetros:
//   - pos_x: Posición X inicial de la bala
//   - pos_y: Posición Y inicial de la bala
// Retorna: Índice de la bala creada, o -1 si no hay espacio
FUNCTION crear_bala_jugador(INT pos_x, INT pos_y);
PRIVATE
    INT slot;  // Índice del slot tomado
BEGIN
    // Verificar si hay slots libres
    IF (primer_slot_libre_jugador == -1)
        RETURN(-1);  // No hay espacio disponible
    END
    
    // Tomar el primer slot libre
    slot = primer_slot_libre_jugador;
    primer_slot_libre_jugador = bala_jugador[slot].siguiente;  // Avanzar la lista de libres
    
    // Inicializar la bala
    bala_jugador[slot].x = pos_x;
    bala_jugador[slot].y = pos_y;
    bala_jugador[slot].activo = 1;
    bala_jugador[slot].draw_id = 0;
    
    // OPTIMIZACIÓN: Precalcular deltas de movimiento (siempre hacia arriba para jugador)
    bala_jugador[slot].dx = 0;
    bala_jugador[slot].dy = -VEL_BALA_JUGADOR;
    
    // OPTIMIZACIÓN: Precalcular tamaño y color (fijos para jugador)
    bala_jugador[slot].tamano = TAMANO_BALA_JUGADOR;
    bala_jugador[slot].color = 10;
    
    // Añadir a la lista de balas activas (al principio)
    bala_jugador[slot].siguiente = primera_bala_jugador_activa;
    primera_bala_jugador_activa = slot;
    
    RETURN(slot);  // Retornar el índice
END

// Función: crear_bala_enemigo (OPTIMIZACIÓN: Lista enlazada separada)
// Descripción: Crea una nueva bala enemiga usando lista enlazada de slots libres
// Parámetros:
//   - pos_x: Posición X inicial de la bala
//   - pos_y: Posición Y inicial de la bala
//   - tipo_bala: Tipo de bala enemiga (1=enemigo1, 2=enemigo2)
//   - ang: Ángulo de movimiento (solo para balas enemigo tipo 2)
// Retorna: Índice de la bala creada, o -1 si no hay espacio
FUNCTION crear_bala_enemigo(INT pos_x, INT pos_y, INT tipo_bala, INT ang);
PRIVATE
    INT slot;  // Índice del slot tomado
BEGIN
    // Verificar si hay slots libres
    IF (primer_slot_libre_enemigo == -1)
        RETURN(-1);  // No hay espacio disponible
    END
    
    // Tomar el primer slot libre
    slot = primer_slot_libre_enemigo;
    primer_slot_libre_enemigo = bala_enemigo[slot].siguiente;  // Avanzar la lista de libres
    
    // Inicializar la bala
    bala_enemigo[slot].x = pos_x;
    bala_enemigo[slot].y = pos_y;
    bala_enemigo[slot].tipo = tipo_bala;
    bala_enemigo[slot].activo = 1;
    bala_enemigo[slot].angulo = ang;
    bala_enemigo[slot].draw_id = 0;
    
    // OPTIMIZACIÓN: Precalcular deltas de movimiento según tipo
    IF (tipo_bala == TIPO_BALA_ENEMIGA1)
        bala_enemigo[slot].dx = 0;
        bala_enemigo[slot].dy = VEL_BALA_ENEMIGA1;
    ELSE  // TIPO_BALA_ENEMIGA2
        bala_enemigo[slot].dx = get_distx(ang, VEL_BALA_ENEMIGA2);
        bala_enemigo[slot].dy = get_disty(ang, VEL_BALA_ENEMIGA2);
    END
    
    // OPTIMIZACIÓN: Precalcular tamaño y color según tipo
    IF (tipo_bala == TIPO_BALA_ENEMIGA1)
        bala_enemigo[slot].tamano = TAMANO_BALA_ENEMIGA1;
        bala_enemigo[slot].color = COLOR_ENEMIGO1;
    ELSE  // TIPO_BALA_ENEMIGA2
        bala_enemigo[slot].tamano = TAMANO_BALA_ENEMIGA2;
        bala_enemigo[slot].color = COLOR_ENEMIGO2;
    END
    
    // Añadir a la lista de balas activas (al principio)
    bala_enemigo[slot].siguiente = primera_bala_enemigo_activa;
    primera_bala_enemigo_activa = slot;
    
    RETURN(slot);  // Retornar el índice
END

// Proceso: proceso_balas_jugador (OPTIMIZACIÓN: Proceso separado para balas del jugador)
// Descripción: Proceso dedicado que gestiona solo balas del jugador usando lista enlazada
// - Solo procesa balas activas del jugador siguiendo la lista enlazada
// - Mueve, dibuja y verifica colisiones con enemigos
// - Elimina balas que salen de pantalla o colisionan
PROCESS proceso_balas_jugador();
PRIVATE
    INT actual;             // Índice de la bala actual en la lista
    INT anterior;           // Índice de la bala anterior en la lista
    INT siguiente;          // Índice de la bala siguiente (guardado antes de posible eliminación)
    INT enemigo_index;      // Índice del enemigo colisionado
    INT color_explosion;    // Color de explosión
    INT debe_eliminar;      // Flag para marcar si debe eliminarse
BEGIN
    LOOP
        // Si el juego terminó, salimos
        IF (game_over == 1) RETURN; END

        // PROCESAR BALAS DEL JUGADOR
        anterior = -1;
        actual = primera_bala_jugador_activa;
        
        WHILE (actual != -1)
            // Guardar el siguiente antes de posibles modificaciones
            siguiente = bala_jugador[actual].siguiente;
            debe_eliminar = 0;
            
            IF (bala_jugador[actual].draw_id != 0)
                delete_draw(bala_jugador[actual].draw_id);
                bala_jugador[actual].draw_id = 0;
            END

            // Mover la bala según deltas precalculados
            bala_jugador[actual].x += bala_jugador[actual].dx;
            bala_jugador[actual].y += bala_jugador[actual].dy;
            
            // Verificar si sale de pantalla
            IF (bala_jugador[actual].y < 0 OR bala_jugador[actual].y > ALTO_PANTALLA OR bala_jugador[actual].x < 0 OR bala_jugador[actual].x > ANCHO_PANTALLA)
                debe_eliminar = 1;
            ELSE
                // Colisión con enemigos
                enemigo_index = comprobar_colision_bala_enemigos(bala_jugador[actual].x, bala_jugador[actual].y);
                IF (enemigo_index != -1)
                    puntos += PUNTOS_POR_ENEMIGO;
                    IF (enemigo[enemigo_index].tipo == 1)
                        color_explosion = COLOR_ENEMIGO1;
                    ELSE
                        color_explosion = COLOR_ENEMIGO2;
                    END
                    explosion(enemigo[enemigo_index].x, enemigo[enemigo_index].y, color_explosion);
                    enemigo[enemigo_index].activo = 0;
                    remover_enemigo_lista(enemigo_index);
                    enemigos_vivos--;
                    debe_eliminar = 1;
                END
            END
            
            // Eliminar bala de la lista si es necesario
            IF (debe_eliminar == 1)
                // Sacar de lista de activas
                IF (anterior == -1)
                    primera_bala_jugador_activa = siguiente;
                ELSE
                    bala_jugador[anterior].siguiente = siguiente;
                END
                
                // Marcar como inactiva
                bala_jugador[actual].activo = 0;
                
                // Devolver a lista de libres
                bala_jugador[actual].siguiente = primer_slot_libre_jugador;
                primer_slot_libre_jugador = actual;
            ELSE
                // Dibujar la bala
                bala_jugador[actual].draw_id = draw(TIPO_DIBUJO_CIRCULO_RELLENO, bala_jugador[actual].color, OPACIDAD_DRAW, REGION_DRAW, bala_jugador[actual].x - bala_jugador[actual].tamano, bala_jugador[actual].y - bala_jugador[actual].tamano, bala_jugador[actual].x + bala_jugador[actual].tamano, bala_jugador[actual].y + bala_jugador[actual].tamano);
                
                // Avanzar anterior solo si no eliminamos
                anterior = actual;
            END
            
            // Avanzar al siguiente
            actual = siguiente;
        END

        FRAME;  // Esperar al siguiente frame
    END
END

// Proceso: proceso_balas_enemigo (OPTIMIZACIÓN: Proceso separado para balas enemigas)
// Descripción: Proceso dedicado que gestiona solo balas enemigas usando lista enlazada
// - Solo procesa balas activas enemigas siguiendo la lista enlazada
// - Mueve, dibuja y verifica colisiones con el jugador
// - Elimina balas que salen de pantalla o colisionan
PROCESS proceso_balas_enemigo();
PRIVATE
    INT actual;             // Índice de la bala actual en la lista
    INT anterior;           // Índice de la bala anterior en la lista
    INT siguiente;          // Índice de la bala siguiente (guardado antes de posible eliminación)
    INT id_player;          // ID del jugador
    INT debe_eliminar;      // Flag para marcar si debe eliminarse
    INT dx, dy;             // Diferencias para cálculo de distancia
    INT dist_cuadrado;      // Distancia al cuadrado (optimización)
BEGIN
    id_player = get_id(type jugador);
    LOOP
        // Si el juego terminó, salimos
        IF (game_over == 1) RETURN; END

        // PROCESAR BALAS ENEMIGAS
        anterior = -1;
        actual = primera_bala_enemigo_activa;
        
        WHILE (actual != -1)
            // Guardar el siguiente antes de posibles modificaciones
            siguiente = bala_enemigo[actual].siguiente;
            debe_eliminar = 0;
            
            IF (bala_enemigo[actual].draw_id != 0)
                delete_draw(bala_enemigo[actual].draw_id);
                bala_enemigo[actual].draw_id = 0;
            END

            // Mover la bala según deltas precalculados
            bala_enemigo[actual].x += bala_enemigo[actual].dx;
            bala_enemigo[actual].y += bala_enemigo[actual].dy;
            
            // Verificar si sale de pantalla
            IF (bala_enemigo[actual].y < 0 OR bala_enemigo[actual].y > ALTO_PANTALLA OR bala_enemigo[actual].x < 0 OR bala_enemigo[actual].x > ANCHO_PANTALLA)
                debe_eliminar = 1;
            ELSE
                // Colisión con jugador
                IF (id_player != 0)
                    // Bounding box rápida
                    IF (abs(bala_enemigo[actual].x - id_player.x) < MARGEN_BOUNDING_BOX AND abs(bala_enemigo[actual].y - id_player.y) < MARGEN_BOUNDING_BOX)
                        // Calcular distancia al cuadrado
                        dx = bala_enemigo[actual].x - id_player.x;
                        dy = bala_enemigo[actual].y - id_player.y;
                        dist_cuadrado = dx * dx + dy * dy;
                        IF (dist_cuadrado < DISTANCIA_COLISION_CUADRADO)
                            explosion(id_player.x, id_player.y, COLOR_NAVE);
                            game_over = 1;
                            debe_eliminar = 1;
                        END
                    END
                END
            END
            
            // Eliminar bala de la lista si es necesario
            IF (debe_eliminar == 1)
                // Sacar de lista de activas
                IF (anterior == -1)
                    primera_bala_enemigo_activa = siguiente;
                ELSE
                    bala_enemigo[anterior].siguiente = siguiente;
                END
                
                // Marcar como inactiva
                bala_enemigo[actual].activo = 0;
                
                // Devolver a lista de libres
                bala_enemigo[actual].siguiente = primer_slot_libre_enemigo;
                primer_slot_libre_enemigo = actual;
            ELSE
                // Dibujar la bala
                bala_enemigo[actual].draw_id = draw(TIPO_DIBUJO_CIRCULO_RELLENO, bala_enemigo[actual].color, OPACIDAD_DRAW, REGION_DRAW, bala_enemigo[actual].x - bala_enemigo[actual].tamano, bala_enemigo[actual].y - bala_enemigo[actual].tamano, bala_enemigo[actual].x + bala_enemigo[actual].tamano, bala_enemigo[actual].y + bala_enemigo[actual].tamano);
                
                // Avanzar anterior solo si no eliminamos
                anterior = actual;
            END
            
            // Avanzar al siguiente
            actual = siguiente;
        END

        FRAME;  // Esperar al siguiente frame
    END
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

    // OPTIMIZACIÓN: Construir lista enlazada de enemigos activos
    primera_enemigo_activo = 0;
    FOR (i=0; i<9; i++)
        enemigo[i].siguiente = i + 1;
    END
    enemigo[9].siguiente = -1; // Fin de lista

    // Crear el proceso único de enemigos
    proceso_enemigos();
END

// Proceso: jugador
// Descripción: Controla la nave del jugador.
// - Maneja el dibujo, movimientos, disparos y colisiones en un bucle continuo.
// - Se detiene si el juego termina (game_over).
// Ahora usa sprites desde FPG en lugar de draw()
PROCESS jugador();
PRIVATE
    vel = VEL_JUGADOR;  // Velocidad de movimiento de la nave
    tiempo_disparo = 0; // Contador para controlar la frecuencia de disparos
    disparando = 0;        // Estado de disparo (0 = no dispara, 1 = disparando)
    dir_x = 0;             // Dirección de movimiento (-1, 0, 1)
    dir_y = 0;             // Dirección de movimiento (-1, 0, 1)
    grafico_actual = 1;    // Gráfico actual a mostrar
BEGIN
    // Posición inicial de la nave en el centro inferior de la pantalla
    x = CENTRO_X;  // Posición inicial x en el centro
    y = ALTO_PANTALLA - 20;  // Posición inicial y cerca del fondo
    file = FPG_PLAYER;
    graph = 1;
    z = -10;  // Asegurar que el jugador esté sobre el fondo

    // Bucle principal del jugador
    LOOP
        // Si el jugador ha muerto, paramos el proceso
        IF (game_over == 1)
            // La sentencia RETURN finaliza el proceso actual de forma inmediata
            RETURN;
        END

        // Verificamos si los controles están activos (para evitar mover durante la cuenta regresiva)
        IF (controles_activos == 1)
            // Mover la nave según las teclas
            manejar_controles_jugador(&x, &y, &dir_x, &dir_y, vel);
            // Disparar si pulsamos la tecla de disparo
            manejar_disparo_jugador(&tiempo_disparo, x, y, &disparando);
            // Seleccionar gráfico según dirección y estado de disparo
            grafico_actual = calcular_grafico_jugador(dir_x, dir_y, disparando);
            graph = grafico_actual;
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
//   - dir_x_offset: Puntero a la dirección x. -> Usamos el puntero para modificar la variable original.
//   - dir_y_offset: Puntero a la dirección y. -> Usamos el puntero para modificar la variable original.
//   - vel: Velocidad de movimiento (por valor, ya que no se modifica).
// Los punteros sirven para modificar las variables originales fuera de la función.
// - Si modificas una varariable del puntero dentro de la función, se refleja fuera también.
// - Sirve para evitar el uso de variables globales innecesarias.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION manejar_controles_jugador(INT x_offset, INT y_offset, INT dir_x_offset, INT dir_y_offset, INT vel);
BEGIN
    // Resetear dirección
    *dir_x_offset = 0;
    *dir_y_offset = 0;

    // Mover a la izquierda si se presiona la flecha izquierda
    // Controlamos que no podamos salirnos de la pantalla con > TAMANO_NAVE_X (margen izquierdo basado en el tamaño de la nave)
    IF (key(_left) AND *x_offset > TAMANO_NAVE_X)
        *x_offset -= vel;
        *dir_x_offset = -1;
    END

     // Mover a la derecha si se presiona la flecha derecha y no se sale de la pantalla
   IF (key(_right) AND *x_offset < ANCHO_PANTALLA - TAMANO_NAVE_X)
        *x_offset += vel;
        *dir_x_offset = 1;
    END

    // Mover arriba si se presiona la flecha arriba y no se sale de la pantalla
    IF (key(_up) AND *y_offset > TAMANO_NAVE_Y_ALTURA)
        *y_offset -= vel;
        *dir_y_offset = -1;
    END

    // Mover abajo si se presiona la flecha abajo y no se sale de la pantalla
    IF (key(_down) AND *y_offset < ALTO_PANTALLA - TAMANO_NAVE_Y_BASE)
        *y_offset += vel;
        *dir_y_offset = 1;
    END
END

// Función: manejar_disparo_jugador (MODIFICADA)
// Descripción: Controla el disparo de balas por parte del jugador.
// - Incrementa un contador de tiempo y dispara si se presiona espacio y ha pasado suficiente tiempo.
// - Ahora usa el sistema de balas optimizado con crear_bala()
// Parámetros:
//   - tiempo_disparo_offset: Puntero al contador de tiempo entre disparos. -> Usamos el puntero para modificar la variable original.
//   - x: Posición x de la nave (por valor, ya que no se modifica).
//   - y: Posición y de la nave (por valor, ya que no se modifica).
//   - disparando_offset: Puntero al estado de disparo. -> Usamos el puntero para modificar la variable original.
// Los punteros sirven para modificar las variables originales fuera de la función.
// - Si modificas una varariable del puntero dentro de la función, se refleja fuera también.
// - Sirve para evitar el uso de variables globales innecesarias.
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION manejar_disparo_jugador(INT tiempo_disparo_offset, INT x, INT y, INT disparando_offset);
BEGIN
    // Incrementar el contador de tiempo
    // Esto controla la frecuencia de disparo
    // Permite tener un espacio mínimo entre disparos
    // *tiempo_disparo_offset es un puntero, por eso usamos el operador *
    // Lo ponemos entre paréntesis para que la suma se haga sobre el valor apuntado
    (*tiempo_disparo_offset)++;

    // Mostrar sprite de disparo mientras se mantenga pulsado el botón
    IF (key(_space))
        *disparando_offset = 1;
        IF (*tiempo_disparo_offset > TIEMPO_DISPARO_JUGADOR)
            explosion_pequena(x, y - 30, COLOR_EXPLOSION_PEQUENA);  // Explosión pequeña al disparar
            crear_bala_jugador(x, y - 30);  // Crear bala en el array (NUEVO)
            *tiempo_disparo_offset = 0;
        END
    ELSE
        *disparando_offset = 0;
    END
END

// Función: comprobar_colision_jugador_enemigos (OPTIMIZADA)
// Descripción: Verifica si la nave del jugador colisiona con algún enemigo.
// - Si hay colisión, suma puntos, crea explosiones y termina el juego.
// Parámetros:
//   - x: Posición x de la nave (por valor, ya que no se modifica).
//   - y: Posición y de la nave (por valor, ya que no se modifica).
// OPTIMIZACIÓN: Usa distancia al cuadrado para evitar raíz cuadrada y lista enlazada
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION comprobar_colision_jugador_enemigos(INT x, INT y);
PRIVATE
    INT actual;  // Índice actual en la lista
    INT dx, dy;  // Diferencias para cálculo de distancia
    INT dist_cuadrado;  // Distancia al cuadrado
BEGIN
    // OPTIMIZACIÓN: Recorrer solo enemigos activos siguiendo la lista enlazada
    actual = primera_enemigo_activo;
    WHILE (actual != -1)
        // OPTIMIZACIÓN: Calcular distancia al cuadrado (evita raíz cuadrada)
        dx = x - enemigo[actual].x;
        dy = y - enemigo[actual].y;
        dist_cuadrado = dx * dx + dy * dy;
        IF (dist_cuadrado < DISTANCIA_COLISION_JUGADOR_CUADRADO)
            // Significa que ambos han chocado y ambos mueren
            puntos += PUNTOS_POR_ENEMIGO;  // Sumamos los puntos
            IF (enemigo[actual].tipo == 1)
                explosion(enemigo[actual].x, enemigo[actual].y, COLOR_ENEMIGO1);  // Explosión del enemigo
            ELSE
                explosion(enemigo[actual].x, enemigo[actual].y, COLOR_ENEMIGO2);  // Explosión del enemigo
            END
            enemigo[actual].activo = 0;  // Marcar enemigo como muerto
            remover_enemigo_lista(actual);
            enemigos_vivos--;  // Reducir contador
            explosion(x, y, COLOR_NAVE);  // Explosión del jugador
            game_over = 1;  // Marcamos game over (lo leerá el process principal y actuará en consecuencia)
            RETURN;
        END
        actual = enemigo[actual].siguiente;
    END
END

// Función: calcular_grafico_jugador
// Descripción: Calcula el ID del gráfico según dirección y estado de disparo
// Retorna: ID del gráfico (1-18)
FUNCTION calcular_grafico_jugador(INT dir_x, INT dir_y, INT disparando);
PRIVATE
    INT base_grafico = 0;
    INT offset_direccion = 0;
BEGIN
    // Base: 0 si no dispara, 9 si dispara
    IF (disparando == 1)
        base_grafico = 9;
    ELSE
        base_grafico = 0;
    END

    // Calcular offset según dirección
    // Quieto
    IF (dir_x == 0 AND dir_y == 0)
        offset_direccion = 1;
    END
    // Arriba
    IF (dir_x == 0 AND dir_y == -1)
        offset_direccion = 2;
    END
    // Arriba derecha
    IF (dir_x == 1 AND dir_y == -1)
        offset_direccion = 3;
    END
    // Derecha
    IF (dir_x == 1 AND dir_y == 0)
        offset_direccion = 4;
    END
    // Derecha abajo
    IF (dir_x == 1 AND dir_y == 1)
        offset_direccion = 5;
    END
    // Abajo
    IF (dir_x == 0 AND dir_y == 1)
        offset_direccion = 6;
    END
    // Abajo izquierda
    IF (dir_x == -1 AND dir_y == 1)
        offset_direccion = 7;
    END
    // Izquierda
    IF (dir_x == -1 AND dir_y == 0)
        offset_direccion = 8;
    END
    // Arriba izquierda
    IF (dir_x == -1 AND dir_y == -1)
        offset_direccion = 9;
    END

    RETURN(base_grafico + offset_direccion);
END

// Función: comprobar_colision_bala_enemigos (OPTIMIZADA)
// Descripción: Verifica si la bala del jugador colisiona con algún enemigo. Si hay colisión, retorna el index del enemigo.
// Parámetros:
//   - x: Posición x de la bala.
//   - y: Posición y de la bala.
// Retorna: Index del enemigo colisionado (0-9), o -1 si no hay colisión.
// OPTIMIZACIÓN: Usa distancia al cuadrado para evitar raíz cuadrada y lista enlazada para solo activos
// Los PROCESS se ejecutan en paralelo, mientras que las FUNCTION se ejecutan de forma secuencial
// - Es decir, hasta que no termine esta función, el proceso que lo llama queda bloqueado
FUNCTION comprobar_colision_bala_enemigos(INT x, INT y);
PRIVATE
    INT actual;  // Índice actual en la lista
    INT dx, dy;  // Diferencias para cálculo de distancia
    INT dist_cuadrado;  // Distancia al cuadrado
BEGIN
    // OPTIMIZACIÓN: Recorrer solo enemigos activos siguiendo la lista enlazada
    actual = primera_enemigo_activo;
    WHILE (actual != -1)
        // OPTIMIZACIÓN: Calcular distancia al cuadrado (evita raíz cuadrada)
        dx = x - enemigo[actual].x;
        dy = y - enemigo[actual].y;
        dist_cuadrado = dx * dx + dy * dy;
        IF (dist_cuadrado < DISTANCIA_COLISION_CUADRADO)
            RETURN(actual);  // Retornamos el index del enemigo colisionado
        END
        actual = enemigo[actual].siguiente;
    END
    RETURN(-1);  // No hay colisión
END

// Función: remover_enemigo_lista (OPTIMIZACIÓN)
// Descripción: Remueve un enemigo de la lista enlazada de activos
// Parámetros:
//   - index: Índice del enemigo a remover
// OPTIMIZACIÓN: Mantiene la lista enlazada actualizada para colisiones eficientes
FUNCTION remover_enemigo_lista(INT index);
PRIVATE
    INT actual;  // Índice actual en la lista
    INT anterior; // Índice anterior en la lista
BEGIN
    anterior = -1;
    actual = primera_enemigo_activo;
    
    WHILE (actual != -1)
        IF (actual == index)
            // Encontrado, remover
            IF (anterior == -1)
                // Es el primero
                primera_enemigo_activo = enemigo[actual].siguiente;
            ELSE
                // Está en medio o al final
                enemigo[anterior].siguiente = enemigo[actual].siguiente;
            END
            RETURN;
        END
        anterior = actual;
        actual = enemigo[actual].siguiente;
    END
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
                        remover_enemigo_lista(i);
                        enemigos_vivos--;
                    END

                    // Dibujar enemigo con put() o xput() según su tipo
                    IF (enemigo[i].tipo == 1)
                        // Usar xput para rotar según dirección de movimiento
                        IF (enemigo[i].dir == 1)
                            xput(FPG_LEVEL, GRAFICO_ENEMIGO1, enemigo[i].x, enemigo[i].y, ANGULO_ROTACION_ENEMIGO, ESCALA_ENEMIGO, CENTRO_XPUT, CENTRO_YPUT);  // Rotar 15° a la derecha
                        ELSE
                            xput(FPG_LEVEL, GRAFICO_ENEMIGO1, enemigo[i].x, enemigo[i].y, ANGULO_ROTACION_ENEMIGO_OPUESTA, ESCALA_ENEMIGO, CENTRO_XPUT, CENTRO_YPUT);  // Rotar 15° a la izquierda
                        END
                    ELSE
                        put(FPG_LEVEL, GRAFICO_ENEMIGO2, enemigo[i].x, enemigo[i].y);  // Gráfico para tipo 2
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
        
        // Limpiar pantalla y redibujar fondo para el siguiente frame
        clear_screen();
        put_screen(FPG_LEVEL, 1);
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

// Función: disparar_enemigo_tipo1 (MODIFICADA)
// Descripción: Controla el disparo periódico del enemigo tipo 1.
// - Ahora usa el sistema de balas optimizado con crear_bala()
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
PRIVATE
    INT tiempo_disparo_aleatorio;  // Tiempo de disparo con componente aleatorio
BEGIN
    (*tiempo_offset)++;     // (*tiempo_offset) es el valor apuntado por el puntero, con ++ lo incrementamos en una unidad.
    // Añadimos aleatoriedad al tiempo de disparo para evitar que todos disparen a la vez
    tiempo_disparo_aleatorio = TIEMPO_DISPARO_ENEMIGO1 + rand(-VARIACION_TIEMPO_DISPARO_ENEMIGO, VARIACION_TIEMPO_DISPARO_ENEMIGO);
    // Verificamos si se cumple con el espaciado (para que las balas no estén muy juntas)
    IF (*tiempo_offset > tiempo_disparo_aleatorio)
        // Cumplido el tiempo, disparamos una bala
        crear_bala_enemigo(x, y, TIPO_BALA_ENEMIGA1, 0);   // Crear bala en el array (MODIFICADO)
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
    *circulo_offset = draw(TIPO_DIBUJO_CIRCULO_RELLENO, COLOR_ENEMIGO1_CIRCULO, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_ENEMIGO1_CIRCULO, y - TAMANO_ENEMIGO1_CIRCULO, x + TAMANO_ENEMIGO1_CIRCULO, y + TAMANO_ENEMIGO1_CIRCULO);
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

// Función: disparar_enemigo_tipo2 (MODIFICADA)
// Descripción: Controla el disparo periódico del enemigo tipo 2.
// - Ahora usa el sistema de balas optimizado con crear_bala()
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
PRIVATE
    INT tiempo_disparo_aleatorio;  // Tiempo de disparo con componente aleatorio
    INT id_jugador;                // ID del jugador para calcular ángulo
    INT angulo;                    // Ángulo de disparo
BEGIN
    (*tiempo_offset)++; // Incrementamos el contador de tiempo. (*tiempo_offset) es el valor apuntado por el puntero, con ++ lo incrementamos en una unidad.
    // Añadimos aleatoriedad al tiempo de disparo para evitar que todos disparen a la vez
    tiempo_disparo_aleatorio = TIEMPO_DISPARO_ENEMIGO2 + rand(-12, 12);
    // Verificamos si se cumple con el espaciado (para que las balas no estén muy juntas)
    IF (*tiempo_offset > tiempo_disparo_aleatorio)
        // Cumplido el tiempo, disparamos una bala
        // Calcular ángulo hacia el jugador
        id_jugador = get_id(type jugador);
        IF (id_jugador != 0)
            // El jugador está vivo, calculamos el ángulo hacia él
            angulo = fget_angle(x, y, id_jugador.x, id_jugador.y);
        ELSE
            // No hay jugador, disparamos hacia abajo por defecto
            angulo = ANGULO_DEFECTO_BALA;
        END
        crear_bala_enemigo(x, y, TIPO_BALA_ENEMIGA2, angulo);   // Crear bala en el array (MODIFICADO)
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
    *circulo_offset = draw(TIPO_DIBUJO_CIRCULO_RELLENO, COLOR_ENEMIGO2_CIRCULO, OPACIDAD_DRAW, REGION_DRAW, x - TAMANO_ENEMIGO2_CIRCULO, y - TAMANO_ENEMIGO2_CIRCULO, x + TAMANO_ENEMIGO2_CIRCULO, y + TAMANO_ENEMIGO2_CIRCULO);
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
        exp_draw = draw(TIPO_DIBUJO_CIRCULO_RELLENO, color, OPACIDAD_DRAW, REGION_DRAW, x - radio, y - radio, x + radio, y + radio);  // Dibujamos un círculo
        radio += INCREMENTO_RADIO_EXPLOSION;  // Augmentamos radio
        FRAME;  // Esperamos al siguiente frame
    END
    
    // Borramos el último dibujo, si no es game over
    IF (game_over == 0)
        delete_draw(exp_draw);
    END
END

// Proceso: explosion_pequena
// Descripción: Crea una animación de explosión pequeña para efectos de disparo
// - Más pequeña y rápida que la explosión normal
// Parámetros:
//   - x: Posición x de la explosión.
//   - y: Posición y de la explosión.
//   - color: Color de la explosión.
PROCESS explosion_pequena(x, y, color);
PRIVATE
    i;  // Contador para el bucle
    radio = 3;  // Radio inicial más pequeño
    exp_draw;  // ID del dibujo de la explosión
BEGIN
    // Animamos la explosión pequeña
    FROM i=0 TO ITERACIONES_EXPLOSION_PEQUENA;  // Menos iteraciones para que sea más rápida
        IF (exp_draw != 0) delete_draw(exp_draw); END
        exp_draw = draw(TIPO_DIBUJO_CIRCULO_RELLENO, color, OPACIDAD_DRAW, REGION_DRAW, x - radio, y - radio, x + radio, y + radio);
        radio++;  // Incremento menor
        FRAME;
    END
    delete_draw(exp_draw);
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
        write(FNT_PRESS, CENTRO_X, POS_Y_CUENTA_REGRESIVA_BASE, 1, "¡ENHORABUENA!");       // Mensaje de felicitación
        write(FNT_NORMAL, CENTRO_X, POS_Y_CUENTA_REGRESIVA_BASE + ESPACIADO_LINEA_NORMAL, 1, "NIVEL COMPLETADO!");
        puntos_str = "Puntos: " + itoa(puntos);                     // Convertimos los puntos a string
        write(FNT_NORMAL, CENTRO_X, POS_Y_CUENTA_REGRESIVA_BASE + ESPACIADO_LINEA_NORMAL * 2, 1, puntos_str);             // Mostramos puntos
        write(FNT_NORMAL, CENTRO_X, POS_Y_CUENTA_REGRESIVA_BASE + ESPACIADO_LINEA_NORMAL * 3, 1, "Siguiente nivel en:");  // Texto estático
        contador_str = itoa(contador);                              // Convertimos el contador a string
        write(FNT_COUNTER, CENTRO_X, POS_Y_CUENTA_REGRESIVA_BASE + ESPACIADO_LINEA_NORMAL * 4, 1, contador_str);         // Mostramos contador regresivo con fuente grande
        
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
    INT parpadeo = 0;   // Contador para el parpadeo del texto
    INT id_texto_parpadeo = 0;  // ID del texto parpadeante
BEGIN
    delete_text(all_text);  // Limpiamos TODOS los textos anteriores
    mostrar_textos_hud();   // Volvemos a dibujar los textos del HUD
    write(FNT_GAMEOVER, CENTRO_X, POS_Y_GAMEOVER, ALINEACION_CENTRADO, "GAME OVER!");  // Mensaje de game over
    puntos_str = "Puntos: " + itoa(puntos);  // Mostramos los puntos
    write(FNT_NORMAL, CENTRO_X, POS_Y_PUNTOS_GAMEOVER, ALINEACION_CENTRADO, puntos_str);
    id_texto_parpadeo = write(FNT_PRESS, CENTRO_X, POS_Y_PULSA_ESPACIO, ALINEACION_CENTRADO, "[PULSA ESPACIO]");
    
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

        // Borrar solo el texto parpadeante y redibujarlo según el parpadeo
        IF (id_texto_parpadeo != 0)
            delete_text(id_texto_parpadeo);
            id_texto_parpadeo = 0;
        END
        
        IF ((parpadeo / 30) MOD 2 == 0)
            id_texto_parpadeo = write(FNT_PRESS, CENTRO_X, POS_Y_PULSA_ESPACIO, ALINEACION_CENTRADO, "[PULSA ESPACIO]");
        END
        parpadeo++;

        FRAME; // Siguiente frame
    END
END

// Función: inicio_nivel (MODIFICADA)
// Descripción: Inicializa un nuevo nivel mostrando una cuenta regresiva (3, 2, 1, GO!) y creando los procesos de enemigos y jugador.
// - Desactiva controles durante la cuenta y los activa al final.
// - Ahora inicializa el sistema de balas y arranca el proceso_balas
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
    signal(type proceso_balas_jugador, s_kill);  // Matar procesos de balas del jugador anteriores
    signal(type proceso_balas_enemigo, s_kill);  // Matar procesos de balas enemigas anteriores
    // No matar explosiones para que se vean durante la cuenta regresiva

    // Limpiar dibujos, textos y procesos residuales del nivel anterior
    delete_draw(all_drawing);
    delete_text(all_text);
    mostrar_textos_hud();   // Volmemos a dibujar los textos del HUD

    // Inicializar el sistema de balas
    inicializar_balas_jugador();
    inicializar_balas_enemigo();

    // Desactivamos controles durante la cuenta regresiva
    controles_activos = 0;

    // Creamos naves pero sin movimiento
    crear_enemigos();  // Creamos enemigos
    // Crear jugador solo si no existe
    IF (get_id(type jugador) == 0)
        jugador();  // Crear jugador
    END
    // OPTIMIZACIÓN: Dos procesos separados para balas del jugador y enemigas
    proceso_balas_jugador();  // Proceso dedicado a balas del jugador
    proceso_balas_enemigo();   // Proceso dedicado a balas enemigas
    
    // Resetear posición del jugador para el nuevo nivel
    
    // Esperar un momento para que se vean las naves
    FRAME;
    FRAME;
    
    // Cuenta regresiva 3, 2, 1, GO!
    contador = 3;   // Cuenta regresiva: 3, 2, 1, GO!
    tiempo = 0;     // Contador de frames
    WHILE (contador > 0)
        contador_str = itoa(contador);        // Convertimos el número a string (itoi = integer to ascii)
        write(FNT_COUNTER, CENTRO_X, CENTRO_Y, ALINEACION_CENTRADO, contador_str);  // 4 = centrado
        
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
    write(FNT_COUNTER, CENTRO_X, CENTRO_Y, ALINEACION_CENTRADO, "GO!"); // 4 = centrado
    tiempo = 0;
    WHILE (tiempo < FPS_JUEGO / 2)
        FRAME;
        tiempo++;
    END  // Mostramos GO! por 0,5 segundos
    
    delete_text(all_text);  // Limpiamos todos los textos
    mostrar_textos_hud();   // Volmemos a dibujar los textos del HUD
    controles_activos = 1;  // Activar controles para empezar el juego
END
