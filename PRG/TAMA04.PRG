//------------------------------------------------------------------------------
// TÍTULO:      TAMA04.PRG - Persistencia de stats y pantalla de intro (entregable 4)
// AUTOR:       Sebastian J. MONCHO MAQUET
// FECHA:       21/02/2026
// DESCRIPCIÓN: Basado en TAMA03.PRG. Añade:
//              - Nuevos stats: limpieza, descanso, salud
//              - Fichero de guardado TAMA.SAV con los stats de la mascota
//                · Si no existe: Aisha se presenta (primera vez)
//                · Si existe:    Aisha saluda al estilo Outlaw Stars
//              - Cada acción modifica los stats y guarda al terminar
//              - normalizar_stats() mantiene todos los stats en [0..10]
//------------------------------------------------------------------------------

PROGRAM TAMA_WAIFU;

CONST
    PERMISO_ESCRITURA = "w";    // w = escritura, r = lectura, a = append (añadir al final)
    PERMISO_LECTURA   = "r";    // modo lectura para cargar el fichero SAV

    // ID de los gráficos
    CG_AISHA = 4;         // ID del gráfico que muestra a Aisha
    MARCO_DIALOGO = 16;   // ID del marco del cuadro de diálogo

    // Índices para HUD, recorremos un bucle para mostrar los textos en pantalla
    HUD_HAMBRE = 0;     // Índice para el texto "Hambre:" y su valor
    HUD_FELICIDAD = 1;  // Índice para el texto "Felicidad:" y su valor
    HUD_DISCIPLINA = 2; // Índice para el texto "Disciplina:" y su valor
    HUD_LIMPIEZA = 3;   // Índice para el texto "Limpieza:" y su valor
    HUD_DESCANSO = 4;   // Índice para el texto "Descanso:" y su valor
    HUD_SALUD = 5;      // Índice para el texto "Salud:" y su valor
    HUD_COUNT = 6;      // Número total de labels del HUD (fin del bucle)

    // Índices para los textos del reloj, recorremos un bucle para mostrar los textos en pantalla
    RL_HORA_LABEL = 0;  // 'Hora:' antes de la hora
    RL_SEP_T1 = 1;      // ':' entre horas y minutos
    RL_SEP_T2 = 2;      // ':' entre minutos y segundos
    RL_FECHA_LABEL = 3; // 'Fecha:' antes de la fecha
    RL_SEP_D_M = 4;     // '/' entre día y mes
    RL_SEP_M_Y = 5;     // '/' entre mes y año
    RL_COUNT = 6;       // Número total de labels del reloj (fin del bucle)

    // Índice para los valores del reloj, recorremos un bucle para mostrar los valores en pantalla
    RV_HORA = 0;        // Índice para escribir la hora (write_int)
    RV_MIN = 1;         // Índice para escribir los minutos (write_int)
    RV_SEG = 2;         // Índice para escribir los segundos (write_int)
    RV_DIA = 3;         // Índice para escribir el día (write_int)
    RV_MES = 4;         // Índice para escribir el mes (write_int)
    RV_ANO = 5;         // Índice para escribir el año (write_int)
    RV_COUNT = 6;       // Número total de valores del reloj (fin del bucle)

GLOBAL
    // Estructura de configuración general
    STRUCT configuracion
        STRUCT pantalla     // Resolución de pantalla de 320x200
            ancho = 320;
            alto = 200;
        END
        fps = 60;           // Frames por segundo para el juego
        frameskip = 0;      // Frameskip (0 = desactivado)
        STRUCT cuadro_dialogo
            alto = 50;      // alto total del cuadro de diálogo (px)
        END
    END

    // Estructura para constantes de UI (fuente, alineación y márgenes)
    STRUCT fuente
        fichero = 0; // ID o fuente por defecto
        STRUCT alineacion
            izq = 3;
            centro = 4;
        END
    END

    // Estructura para almacenar los ficheros FPG
    STRUCT fpg
        aisha;  // ID del FPG de CG de Aisha
        hud;    // ID del FPG del HUD
    END

    // Estructura global del HUD (labels como array)
    STRUCT hud
        STRUCT label[HUD_COUNT] // Lista de labels ("Hambre:", "Felicidad:", ...)
            STRUCT pos          // Posición de cada label en pantalla
                x = 0;
                y = 0;
            END
            STRUCT text         // Texto de cada label
                label = "";
            END
            STRUCT value_pos    // Posición para escribir el valor numérico (write_int) de cada stat
                x = 0;
                y = 0;
            END
        END

        // Reloj: separa labels (texto) y values (posiciones para write_int)
        STRUCT reloj
            STRUCT labels[RL_COUNT] // Lista de labels del reloj ("Hora:", ":", ":", "Fecha:", "/", "/")
                STRUCT pos          // Posición de cada label del reloj en pantalla
                    x = 0;
                    y = 0;
                END
                STRUCT text         // Texto de cada label del reloj ("Hora:", ":", ":", "Fecha:", "/", "/")
                    label = "";
                END
            END
            STRUCT values[RV_COUNT] // Posiciones para escribir los valores numéricos del reloj (hora, minutos, segundos, día, mes, año)
                STRUCT pos
                    x = 0;
                    y = 0;
                END
            END
        END

        STRUCT background // Parámetros para el fondo del HUD (rectángulo negro semitransparente)
            tipo = 3;     // tipo de dibujo (rectángulo)
            color = 2;    // color del rectángulo
            opacity = 8;  // opacidad (0-15)
            region = 0;   // región para draw
            x = 0;        // posición de esquina superior izquierda
            y = 0;
            width = 320;  // ancho del rectángulo (se ajusta en tiempo de ejecución)
            height = 30;  // alto del rectángulo (ampliado para 2 filas de stats + reloj)
        END
    END

    // Estructura de rutas de assets
    STRUCT rutas
        aisha = "tama/aisha.fpg";    // Fichero con los gráficos de la chica mascota
        hud = "tama/hud.fpg";        // Fichero con los gráficos de la interfaz
        tmp_nombre = "tm_time.tmp";  // Fichero temporal para obtener la hora del sistema
        save = "tama/tama.sav";      // Fichero de guardado de stats
    END

    // Estructura de reloj para fecha/hora del sistema
    STRUCT reloj
        dia = 0;
        mes = 0;
        ano = 0;
        hora = 0;
        minutos = 0;
        segundos = 0;
    END

    // Estructura de estado de la mascota (gráfico actual, etc.)
    STRUCT mascota
        graph = 4;   // gráfico actualmente mostrado por `mostrar_mascota`

        // Stats de la mascota — encapsulan el estado
        STRUCT stats
            hambre = 5;
            felicidad = 5;
            disciplina = 5;
            limpieza = 10;
            descanso = 10;
            salud = 10;
        END
    END

    // Estructura del menú de comandos
    STRUCT menu
        spacing = 64;        // separación horizontal entre columnas
        selected = 0;        // índice seleccionado (flat)
        active = 0;          // 1 = acción activa (modal)
        accion_id = -1;      // id de la acción activa
        count = 7;           // número de comandos
        cols = 4;            // columnas de la rejilla
        rows = 2;            // filas de la rejilla

        STRUCT comando[7]    // Lista de 7 comandos (Jugar, Alimentar, Estudiar, Baño, Curar, Luces, Salir)
            STRUCT label
                text = "";   // Texto a mostrar
            END
            cg = 4;           // gráfico asociado a la acción (por defecto CG_AISHA)
            action_text = ""; // texto que se muestra cuando la acción está activa
        END
    END

PRIVATE
    i = 0; // Contador de frames para actualizar reloj cada segundo

BEGIN
    // Configurar modo de video y FPS
    set_mode(configuracion.pantalla.ancho * 1000 + configuracion.pantalla.alto);
    set_fps(configuracion.fps, 0);

    // Cargamos la paleta
    load_pal(rutas.hud);

    // Cargamos los archivos FPG
    fpg.aisha = load_fpg(rutas.aisha);
    fpg.hud = load_fpg(rutas.hud);

    // Inicializamos el reloj con la hora del sistema
    get_hora();
    // Inicializamos el menú
    init_menu();

    // Usamos el proceso main como marco del cuadro de diálogo durante la intro
    file  = fpg.hud;
    graph = MARCO_DIALOGO;
    x     = configuracion.pantalla.ancho / 2;
    y     = configuracion.pantalla.alto - configuracion.cuadro_dialogo.alto / 2;

    mostrar_mascota();  // lanzamos el sprite de Aisha antes de la intro

    intro_aisha();      // presentación o saludo; bloquea hasta que el jugador pulsa ENTER/SPACE

    graph = 0;          // quitamos el gráfico del proceso main

    // Iniciamos los procesos que correrán en paralelo
    mostrar_hud();      // Información en pantalla
    mostrar_comandos(); // La lista de comandos
    controlar_menu();   // Gestiona la entrada del menú

    // Loop principal
    LOOP
        // Actualizar contador de frames y reloj cada segundo
        i = i + 1;
        IF (i > FPS)   // La constante FPS contiene cuantos frames hubo en el último segundo, más fiable que usar configuracion.fps
            actualiza_reloj();
            i = 0;
        END

        FRAME;
    END
END

//------------------------------------------------------------------------------
// FUNCTION: get_hora
// DESCRIPCIÓN: Rellena la STRUCT `reloj` con la fecha/hora actual del sistema.
// Para ello creamos un fichero temporal y consultamos su fecha de modificación
//------------------------------------------------------------------------------
FUNCTION get_hora();
PRIVATE
    tmp_dato;
    tmp_id;
BEGIN
    tmp_dato = 0;
    tmp_id = fopen(rutas.tmp_nombre, PERMISO_ESCRITURA);
    fwrite(OFFSET tmp_dato, sizeof(tmp_dato), tmp_id);
    fclose(tmp_id);

    get_fileinfo(rutas.tmp_nombre);

    reloj.dia = fileinfo.day;
    reloj.mes = fileinfo.month;
    reloj.ano = fileinfo.year;

    reloj.hora = fileinfo.hour;
    reloj.minutos = fileinfo.min;
    reloj.segundos = fileinfo.sec;

    return(0);
END

//------------------------------------------------------------------------------
// FUNCTION: actualiza_reloj
// DESCRIPCIÓN: Incrementa el reloj en +1 segundo y normaliza minutos/horas/días
//------------------------------------------------------------------------------
FUNCTION actualiza_reloj();
PRIVATE
    maxd;
BEGIN
    reloj.segundos = reloj.segundos + 1;
    IF (reloj.segundos >= 60)
        reloj.segundos = 0;
        reloj.minutos = reloj.minutos + 1;
    END

    IF (reloj.minutos >= 60)
        reloj.minutos = 0;
        reloj.hora = reloj.hora + 1;
    END

    IF (reloj.hora >= 24)
        reloj.hora = 0;
        reloj.dia = reloj.dia + 1;

        // Normalizamos día/mes/año según días del mes
        maxd = dias_mes(reloj.mes, reloj.ano);
        IF (reloj.dia > maxd)
            reloj.dia = 1;
            reloj.mes = reloj.mes + 1;
            IF (reloj.mes > 12)
                reloj.mes = 1;
                reloj.ano = reloj.ano + 1;
            END
        END
    END

    return(0);
END

//------------------------------------------------------------------------------
// FUNCTION: dias_mes
// DESCRIPCIÓN: Devuelve número de días del mes `m` en el año `y` (gestión de bisiestos)
//------------------------------------------------------------------------------
FUNCTION dias_mes(INT m, INT y);
BEGIN
    SWITCH (m)
        CASE 1,3,5,7,8,10,12:
            return(31);
        END
        CASE 4,6,9,11:
            return(30);
        END
        CASE 2:
            // Febrero - comprobamos si es bisiesto: si el año es divisible por 400, o es divisible por 4 pero no por 100, entonces tiene 29 días
            IF ((y MOD 400 == 0) OR ((y MOD 4 == 0) AND (y MOD 100 <> 0)))
                return(29);
            END
            return(28);
        END
        DEFAULT:
            return(31);
        END
    END
END

//------------------------------------------------------------------------------
// PROCESS: mostrar_mascota
// DESCRIPCIÓN: Muestra la CG de la mascota (Aisha) en el centro de la pantalla
//------------------------------------------------------------------------------
PROCESS mostrar_mascota();
BEGIN
    file = fpg.aisha;   // Fichero FPG a utilizar
    mascota.graph = CG_AISHA;   // ID del gráfico a mostrar

    // X = mitad del ancho de la pantalla, para que quede centrado
    x = configuracion.pantalla.ancho / 2;

    // Y = centro de la pantalla - mitad del alto del cuadro de diálogo para que quede justo encima del texto inferior
    y = configuracion.pantalla.alto / 2 - configuracion.cuadro_dialogo.alto / 2;

    // El gráfico mostrado se toma de `mascota.graph` para que otros procesos puedan cambiarlo
    LOOP
        graph = mascota.graph;
        FRAME;
    END
END

//------------------------------------------------------------------------------
// FUNCTION: init_hud
// DESCRIPCIÓN: Inicializa posiciones y textos del HUD con 6 stats en 2 filas.
//   Fila 1 (y=5):  Hambre | Felicidad | Disciplina
//   Fila 2 (y=14): Limpieza | Descanso | Salud
//   Reloj  (y=23): Hora HH:MM:SS  |  Fecha DD/MM/AAAA
//------------------------------------------------------------------------------
FUNCTION init_hud();
BEGIN
    // --- Fila 1: Hambre, Felicidad, Disciplina ---
    hud.label[HUD_HAMBRE].pos.x = 8;
    hud.label[HUD_HAMBRE].pos.y = 5;
    hud.label[HUD_HAMBRE].text.label = "Hambre:";
    hud.label[HUD_HAMBRE].value_pos.x = 64;
    hud.label[HUD_HAMBRE].value_pos.y = 5;

    hud.label[HUD_FELICIDAD].pos.x = 109;
    hud.label[HUD_FELICIDAD].pos.y = 5;
    hud.label[HUD_FELICIDAD].text.label = "Felicidad:";
    hud.label[HUD_FELICIDAD].value_pos.x = 181;
    hud.label[HUD_FELICIDAD].value_pos.y = 5;

    hud.label[HUD_DISCIPLINA].pos.x = 210;
    hud.label[HUD_DISCIPLINA].pos.y = 5;
    hud.label[HUD_DISCIPLINA].text.label = "Disciplina:";
    hud.label[HUD_DISCIPLINA].value_pos.x = 286;
    hud.label[HUD_DISCIPLINA].value_pos.y = 5;

    // --- Fila 2: Limpieza, Descanso, Salud ---
    hud.label[HUD_LIMPIEZA].pos.x = 8;
    hud.label[HUD_LIMPIEZA].pos.y = 14;
    hud.label[HUD_LIMPIEZA].text.label = "Limpieza:";
    hud.label[HUD_LIMPIEZA].value_pos.x = 72;
    hud.label[HUD_LIMPIEZA].value_pos.y = 14;

    hud.label[HUD_DESCANSO].pos.x = 109;
    hud.label[HUD_DESCANSO].pos.y = 14;
    hud.label[HUD_DESCANSO].text.label = "Descanso:";
    hud.label[HUD_DESCANSO].value_pos.x = 181;
    hud.label[HUD_DESCANSO].value_pos.y = 14;

    hud.label[HUD_SALUD].pos.x = 210;
    hud.label[HUD_SALUD].pos.y = 14;
    hud.label[HUD_SALUD].text.label = "Salud:";
    hud.label[HUD_SALUD].value_pos.x = 254;
    hud.label[HUD_SALUD].value_pos.y = 14;

    // --- Reloj (fila 3, y=23) ---
    hud.reloj.labels[RL_HORA_LABEL].pos.x = 4;
    hud.reloj.labels[RL_HORA_LABEL].pos.y = 23;
    hud.reloj.labels[RL_HORA_LABEL].text.label = "Hora:";

    hud.reloj.values[RV_HORA].pos.x = 40;
    hud.reloj.values[RV_HORA].pos.y = 23;

    hud.reloj.labels[RL_SEP_T1].pos.x = 56;
    hud.reloj.labels[RL_SEP_T1].pos.y = 23;
    hud.reloj.labels[RL_SEP_T1].text.label = ":";

    hud.reloj.values[RV_MIN].pos.x = 64;
    hud.reloj.values[RV_MIN].pos.y = 23;

    hud.reloj.labels[RL_SEP_T2].pos.x = 80;
    hud.reloj.labels[RL_SEP_T2].pos.y = 23;
    hud.reloj.labels[RL_SEP_T2].text.label = ":";

    hud.reloj.values[RV_SEG].pos.x = 88;
    hud.reloj.values[RV_SEG].pos.y = 23;

    hud.reloj.labels[RL_FECHA_LABEL].pos.x = 140;
    hud.reloj.labels[RL_FECHA_LABEL].pos.y = 23;
    hud.reloj.labels[RL_FECHA_LABEL].text.label = "Fecha:";

    hud.reloj.values[RV_DIA].pos.x = 184;
    hud.reloj.values[RV_DIA].pos.y = 23;

    hud.reloj.labels[RL_SEP_D_M].pos.x = 200;
    hud.reloj.labels[RL_SEP_D_M].pos.y = 23;
    hud.reloj.labels[RL_SEP_D_M].text.label = "/";

    hud.reloj.values[RV_MES].pos.x = 208;
    hud.reloj.values[RV_MES].pos.y = 23;

    hud.reloj.labels[RL_SEP_M_Y].pos.x = 224;
    hud.reloj.labels[RL_SEP_M_Y].pos.y = 23;
    hud.reloj.labels[RL_SEP_M_Y].text.label = "/";

    hud.reloj.values[RV_ANO].pos.x = 232;
    hud.reloj.values[RV_ANO].pos.y = 23;

    // Ajustamos el ancho del fondo del HUD al ancho de la pantalla
    hud.background.width = configuracion.pantalla.ancho;

    return(0);
END

//------------------------------------------------------------------------------
// FUNCTION: mostrar_hud
// DESCRIPCIÓN: Muestra el HUD superior con los stats del personaje y el reloj
//------------------------------------------------------------------------------
FUNCTION mostrar_hud();
PRIVATE
    INT idx;    // Índice para bucles
BEGIN
    // Inicializamos los componentes del HUD
    init_hud();

    // Dibujamos un fondo semitransparente
    // Uso de draw: draw(<tipo>, <color>, <opacidad>, <región>, <x0>, <y0>, <x1>, <y1>)
    draw(hud.background.tipo, hud.background.color, hud.background.opacity, hud.background.region,
            hud.background.x, hud.background.y,
            hud.background.x + hud.background.width, hud.background.y + hud.background.height);

    // Escribimos los labels del HUD uno a uno
    FOR (idx = 0; idx < HUD_COUNT; idx++)
        write(fuente.fichero, hud.label[idx].pos.x, hud.label[idx].pos.y, fuente.alineacion.izq, hud.label[idx].text.label);
    END

    // Escribimos los valores de los stats (OFFSET)
    write_int(fuente.fichero, hud.label[HUD_HAMBRE].value_pos.x, hud.label[HUD_HAMBRE].value_pos.y, fuente.alineacion.izq, OFFSET mascota.stats.hambre);
    write_int(fuente.fichero, hud.label[HUD_FELICIDAD].value_pos.x, hud.label[HUD_FELICIDAD].value_pos.y, fuente.alineacion.izq, OFFSET mascota.stats.felicidad);
    write_int(fuente.fichero, hud.label[HUD_DISCIPLINA].value_pos.x, hud.label[HUD_DISCIPLINA].value_pos.y, fuente.alineacion.izq, OFFSET mascota.stats.disciplina);
    write_int(fuente.fichero, hud.label[HUD_LIMPIEZA].value_pos.x,   hud.label[HUD_LIMPIEZA].value_pos.y,   fuente.alineacion.izq, OFFSET mascota.stats.limpieza);
    write_int(fuente.fichero, hud.label[HUD_DESCANSO].value_pos.x,   hud.label[HUD_DESCANSO].value_pos.y,   fuente.alineacion.izq, OFFSET mascota.stats.descanso);
    write_int(fuente.fichero, hud.label[HUD_SALUD].value_pos.x,      hud.label[HUD_SALUD].value_pos.y,      fuente.alineacion.izq, OFFSET mascota.stats.salud);

    // Escribimos los labels del reloj uno a uno
    FOR (idx = 0; idx < RL_COUNT; idx++)
        write(fuente.fichero, hud.reloj.labels[idx].pos.x, hud.reloj.labels[idx].pos.y, fuente.alineacion.izq, hud.reloj.labels[idx].text.label);
    END

    // Escribimos los valores del reloj (OFFSET)
    write_int(fuente.fichero, hud.reloj.values[RV_HORA].pos.x, hud.reloj.values[RV_HORA].pos.y, fuente.alineacion.izq, OFFSET reloj.hora);
    write_int(fuente.fichero, hud.reloj.values[RV_MIN].pos.x, hud.reloj.values[RV_MIN].pos.y, fuente.alineacion.izq, OFFSET reloj.minutos);
    write_int(fuente.fichero, hud.reloj.values[RV_SEG].pos.x, hud.reloj.values[RV_SEG].pos.y, fuente.alineacion.izq, OFFSET reloj.segundos);
    write_int(fuente.fichero, hud.reloj.values[RV_DIA].pos.x, hud.reloj.values[RV_DIA].pos.y, fuente.alineacion.izq, OFFSET reloj.dia);
    write_int(fuente.fichero, hud.reloj.values[RV_MES].pos.x, hud.reloj.values[RV_MES].pos.y, fuente.alineacion.izq, OFFSET reloj.mes);
    write_int(fuente.fichero, hud.reloj.values[RV_ANO].pos.x, hud.reloj.values[RV_ANO].pos.y, fuente.alineacion.izq, OFFSET reloj.ano);

    // write_int actualiza los valores en pantalla en tiempo real, no necesitamos ningún bucle o reescribir estos textos
    return(0);
END

//------------------------------------------------------------------------------
// PROCESS: mostrar_comandos
// DESCRIPCIÓN: Renderiza el marco de diálogo y las opciones del menú inferior.
//              Utiliza la `STRUCT menu` y los `menu.comando[]` para ser totalmente data-driven.
//------------------------------------------------------------------------------
PROCESS mostrar_comandos();
PRIVATE
    idx = 0;                 // índice de ítem actual
    row = 0;                 // fila del ítem (idx / cols)
    col = 0;                 // columna del ítem (idx MOD cols)
    row_gap = 14;            // separación vertical entre filas
    action_text = "";        // texto de la acción activa (si hay alguna)
    action_graph = CG_AISHA; // gráfico de la acción activa (si hay alguna)
    startX = 0;              // X de la primera columna (calculada para centrar la tabla)
    startY = 0;              // Y de la primera fila   (calculada para centrar la tabla)
    px = 0;                  // X calculada para cada ítem
    py = 0;                  // Y calculada para cada ítem
    INT id_menu_textos[7];   // IDs para los textos de cada comando (se eliminan cada frame)
    id_action_text = 0;      // ID del texto de la acción activa (se elimina cada frame)
    string texto_seleccionado[50];
BEGIN
    file = fpg.hud;         // Fichero FPG a utilizar
    graph = MARCO_DIALOGO;  // ID del gráfico del marco del cuadro de diálogo

    // Calcular posiciones locales del marco (no forman parte de la STRUCT `menu`)
    x = configuracion.pantalla.ancho / 2;
    y = configuracion.pantalla.alto - configuracion.cuadro_dialogo.alto / 2;

    LOOP
        // Limpieza: borramos los textos del frame anterior usando sus IDs
        FOR (idx = 0; idx < menu.count; idx++)
            IF (id_menu_textos[idx] != 0)
                delete_text(id_menu_textos[idx]);
                id_menu_textos[idx] = 0;
            END
        END

        IF (id_action_text != 0)
            delete_text(id_action_text);
            id_action_text = 0;
        END

        // Si la acción está activa, NO dibujamos los comandos; mostramos solo el texto dentro del marco.
        IF (menu.active == 1)
            IF (menu.accion_id >= 0 AND menu.accion_id < menu.count)
                action_graph = menu.comando[menu.accion_id].cg;
                action_text = menu.comando[menu.accion_id].action_text;
            ELSE
                action_graph = CG_AISHA;
                action_text = "";
            END

            // Cambiamos el gráfico de la mascota y mostramos el texto de la acción
            mascota.graph = action_graph;
            id_action_text = write(fuente.fichero, x, y, fuente.alineacion.centro, action_text);
        ELSE
            // --- Rejilla exacta: cada columna tiene la misma X, cada fila la misma Y ---
            // startX centra la tabla horizontalmente: (cols-1)*spacing es el ancho entre extremos
            startX = x - (menu.cols - 1) * menu.spacing / 2;
            // startY centra la tabla verticalmente en el cuadro de diálogo
            startY = y - (menu.rows - 1) * row_gap / 2;

            FOR (idx = 0; idx < menu.count; idx++)
                row = idx / menu.cols;
                col = idx MOD menu.cols;
                px = startX + col * menu.spacing;
                py = startY + row * row_gap;

                IF (menu.selected == idx)
                    texto_seleccionado = "> " + menu.comando[idx].label.text;
                    id_menu_textos[idx] = write(fuente.fichero, px, py, fuente.alineacion.centro, texto_seleccionado);
                ELSE
                    id_menu_textos[idx] = write(fuente.fichero, px, py, fuente.alineacion.centro, menu.comando[idx].label.text);
                END
            END
        END

        FRAME;
    END
END

//------------------------------------------------------------------------------
// FUNCTION: init_menu
// DESCRIPCIÓN: Inicializa labels, CGs y posición del menú de comandos
//------------------------------------------------------------------------------
FUNCTION init_menu();
BEGIN
    menu.spacing = 64;
    menu.selected = 0;
    menu.active = 0;
    menu.accion_id = -1;
    menu.count = 7;
    menu.cols = 4;
    menu.rows = 2;

    menu.comando[0].label.text = "Jugar";
    menu.comando[0].cg = 015;
    menu.comando[0].action_text = "Aisha está jugando.";

    menu.comando[1].label.text = "Alimentar";
    menu.comando[1].cg = 010;
    menu.comando[1].action_text = "Aisha está comiendo.";

    menu.comando[2].label.text = "Estudiar";
    menu.comando[2].cg = 016;
    menu.comando[2].action_text = "Aisha está estudiando.";

    menu.comando[3].label.text = "Baño";
    menu.comando[3].cg = 013;
    menu.comando[3].action_text = "Aisha se está bañando.";

    menu.comando[4].label.text = "Curar";
    menu.comando[4].cg = 014;
    menu.comando[4].action_text = "Aisha toma sus medicinas.";

    menu.comando[5].label.text = "Luces";
    menu.comando[5].cg = 020;
    menu.comando[5].action_text = "Aisha se prepara para dormir.";

    menu.comando[6].label.text = "Salir";
    menu.comando[6].cg = CG_AISHA;
    menu.comando[6].action_text = "";

    return(0);
END

//------------------------------------------------------------------------------
// PROCESS: controlar_menu
// DESCRIPCIÓN: Gestiona la entrada del menú (navegación y selección). Usa la STRUCT `menu`.
//------------------------------------------------------------------------------
PROCESS controlar_menu();
BEGIN
    LOOP
        IF (NOT menu.active)
            IF (key(_right))
                menu_mover_h(+1);
            END
            IF (key(_left))
                menu_mover_h(-1);
            END
            IF (key(_down))
                menu_mover_v(+1);
            END
            IF (key(_up))
                menu_mover_v(-1);
            END

            // Selección con ENTER / SPACE
            IF (key(_enter) OR key(_space))
                IF (menu.selected == menu.count - 1)
                    // Salir: guardamos y salimos
                    guardar_partida();
                    exit("Hasta pronto.", 0);
                ELSE
                    menu.active = 1;
                    menu.accion_id = menu.selected;
                END
            END
        ELSE
            // Cerrar acción activa → aplicar efecto, guardar, volver al menú
            IF (key(_enter) OR key(_space) OR key(_esc))
                aplicar_efecto(menu.accion_id);
                menu.active = 0;
                mascota.graph = CG_AISHA;
            END
        END

        // Esperamos a que se suelten todas las teclas (on-release)
        WHILE ((key(_enter) OR key(_space) OR key(_left) OR key(_right) OR key(_up) OR key(_down)))
            FRAME;
        END

        FRAME;
    END
END

//------------------------------------------------------------------------------
// FUNCTION: menu_mover_h
// DESCRIPCIÓN: Mueve el cursor horizontal (delta +1=derecha, -1=izquierda).
//              Hace wrap dentro de la misma fila respetando celdas vacías.
//------------------------------------------------------------------------------
FUNCTION menu_mover_h(INT delta);
PRIVATE
    row = 0;
    col = 0;
    new_col = 0;
    last_col = 0;
BEGIN
    col = menu.selected MOD menu.cols;
    row = menu.selected / menu.cols;

    // Última columna válida de esta fila (la fila inferior puede estar incompleta)
    last_col = menu.count - 1 - row * menu.cols;
    IF (last_col >= menu.cols)
        last_col = menu.cols - 1;
    END

    new_col = col + delta;
    IF (new_col > last_col)
        new_col = 0;        // wrap derecha → primera
    END

    IF (new_col < 0)
        new_col = last_col; // wrap izquierda → última
    END

    menu.selected = row * menu.cols + new_col;
    return(0);
END

//------------------------------------------------------------------------------
// FUNCTION: menu_mover_v
// DESCRIPCIÓN: Mueve el cursor vertical (delta +1=abajo, -1=arriba).
//              Hace wrap entre filas; si la celda destino no existe, va al último ítem válido.
//------------------------------------------------------------------------------
FUNCTION menu_mover_v(INT delta);
PRIVATE
    row = 0;
    col = 0;
    new_row = 0;
    new_idx = 0;
BEGIN
    col = menu.selected MOD menu.cols;
    row = menu.selected / menu.cols;

    new_row = row + delta;
    IF (new_row >= menu.rows)
        new_row = 0;            // wrap abajo → primera fila
    END
    IF (new_row < 0)
        new_row = menu.rows - 1; // wrap arriba → última fila
    END

    new_idx = new_row * menu.cols + col;

    // Si la celda no existe (fila inferior incompleta), va al último ítem válido
    IF (new_idx >= menu.count)
        new_idx = menu.count - 1;
    END

    menu.selected = new_idx;
    return(0);
END

// FUNCTION: cargar_partida
// DESCRIPCIÓN: Lee TAMA.SAV y rellena mascota.stats. Devuelve 1 si OK, 0 si no existe.
//------------------------------------------------------------------------------
FUNCTION cargar_partida();
PRIVATE
    fid = 0;
BEGIN
    fid = fopen(rutas.save, PERMISO_LECTURA);
    IF (fid == 0)
        return(0);  // fichero no existe → primera vez
    END

    fread(OFFSET mascota.stats, 1, fid);

    fclose(fid);
    return(1);
END

//------------------------------------------------------------------------------
// FUNCTION: guardar_partida
// DESCRIPCIÓN: Escribe los stats actuales de mascota en TAMA.SAV.
//------------------------------------------------------------------------------
FUNCTION guardar_partida();
PRIVATE
    fid = 0;
BEGIN
    fid = fopen(rutas.save, PERMISO_ESCRITURA);

    fwrite(OFFSET mascota.stats, 1, fid);

    fclose(fid);
    return(0);
END

//------------------------------------------------------------------------------
// FUNCTION: clamp_stat
// DESCRIPCIÓN: Devuelve `v` acotado al rango [0..10].
//------------------------------------------------------------------------------
FUNCTION clamp_stat(INT v);
BEGIN
    IF (v > 10) return(10); END
    IF (v <  0) return(0);  END
    return(v);
END

//------------------------------------------------------------------------------
// FUNCTION: normalizar_stats
// DESCRIPCIÓN: Clampea todos los stats al rango [0..10].
//------------------------------------------------------------------------------
FUNCTION normalizar_stats();
BEGIN
    mascota.stats.hambre     = clamp_stat(mascota.stats.hambre);
    mascota.stats.felicidad  = clamp_stat(mascota.stats.felicidad);
    mascota.stats.disciplina = clamp_stat(mascota.stats.disciplina);
    mascota.stats.limpieza   = clamp_stat(mascota.stats.limpieza);
    mascota.stats.descanso   = clamp_stat(mascota.stats.descanso);
    mascota.stats.salud      = clamp_stat(mascota.stats.salud);
    return(0);
END

//------------------------------------------------------------------------------
// FUNCTION: aplicar_efecto
// DESCRIPCIÓN: Aplica los cambios de stats correspondientes a la acción `id`.
//              Tras modificar los valores llama a normalizar_stats() y guarda.
//   0 Jugar     → felicidad+2, disciplina-1, limpieza-1, descanso-2
//   1 Alimentar → hambre+2
//   2 Estudiar  → felicidad-1, disciplina+2, descanso-2
//   3 Baño      → limpieza=10, descanso-1
//   4 Curar     → salud=10
//   5 Luces     → descanso=10
//------------------------------------------------------------------------------
FUNCTION aplicar_efecto(INT id_efecto);
BEGIN
    SWITCH (id_efecto)
        CASE 0: // Jugar
            mascota.stats.felicidad  = mascota.stats.felicidad  + 2;
            mascota.stats.disciplina = mascota.stats.disciplina - 1;
            mascota.stats.limpieza   = mascota.stats.limpieza   - 1;
            mascota.stats.descanso   = mascota.stats.descanso   - 2;
        END
        CASE 1: // Alimentar
            mascota.stats.hambre = mascota.stats.hambre + 2;
        END
        CASE 2: // Estudiar
            mascota.stats.felicidad  = mascota.stats.felicidad  - 1;
            mascota.stats.disciplina = mascota.stats.disciplina + 2;
            mascota.stats.descanso   = mascota.stats.descanso   - 2;
        END
        CASE 3: // Baño
            mascota.stats.limpieza = 10;
            mascota.stats.descanso = mascota.stats.descanso - 1;
        END
        CASE 4: // Curar
            mascota.stats.salud = 10;
        END
        CASE 5: // Luces
            mascota.stats.descanso = 10;
        END
    END

    normalizar_stats();
    guardar_partida();
    return(0);
END

//------------------------------------------------------------------------------
// FUNCTION: intro_aisha
// DESCRIPCIÓN: Intenta cargar TAMA.SAV.
//              · Si no existe → presentación de Aisha (primera vez)
//              · Si existe    → saludo al estilo Outlaw Stars
//              Espera a que el jugador pulse ENTER/SPACE y hace on-release.
//              Nota: el proceso main ya tiene asignado el gráfico MARCO_DIALOGO
//              y mostrar_mascota() ya está corriendo; esta función solo escribe
//              texto y llama a FRAME.
//------------------------------------------------------------------------------
FUNCTION intro_aisha();
PRIVATE
    save_existe = 0;
    id_l1 = 0;
    id_l2 = 0;
    cx = 0;
    cy = 0;
BEGIN
    file = fpg.hud;         // Fichero FPG a utilizar
    graph = MARCO_DIALOGO;  // ID del gráfico del marco del cuadro de diálogo

    // Calcular posiciones locales del marco (no forman parte de la STRUCT `menu`)
    x = configuracion.pantalla.ancho / 2;
    y = configuracion.pantalla.alto - configuracion.cuadro_dialogo.alto / 2;

    cx = configuracion.pantalla.ancho / 2;
    cy = configuracion.pantalla.alto - configuracion.cuadro_dialogo.alto / 2;

    save_existe = cargar_partida();

    IF (save_existe == 0)
        // Primera vez — presentación
        id_l1 = write(fuente.fichero, cx, cy - 8, fuente.alineacion.centro,
                      "¡Soy Aisha Clan-Clan, orgullo de");
        id_l2 = write(fuente.fichero, cx, cy + 4, fuente.alineacion.centro,
                      "los Ctarl-Ctarl! ¡Cuídame bien!");
    ELSE
        // Ya existe partida — saludo tsundere de Outlaw Stars
        id_l1 = write(fuente.fichero, cx, cy - 8, fuente.alineacion.centro,
                      "¡Ah, has vuelto! Era hora,");
        id_l2 = write(fuente.fichero, cx, cy + 4, fuente.alineacion.centro,
                      "humano. ¡No me hagas esperar!");
    END

    // Esperamos a que el jugador pulse ENTER/SPACE
    WHILE (NOT (key(_enter) OR key(_space)))
        FRAME;
    END

    // On-release
    WHILE (key(_enter) OR key(_space))
        FRAME;
    END

    delete_text(id_l1);
    delete_text(id_l2);
    return(0);
END
