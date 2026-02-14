//------------------------------------------------------------------------------
// TÍTULO:      TAMA03.PRG - Menú navegable simple (entregable 3)
// AUTOR:       Sebastian J. MONCHO MAQUET
// FECHA:       14/02/2026
// DESCRIPCIÓN: Reutiliza el esqueleto visual de TAMA02B.PRG y añade un menú
//              navegable con opciones: "Jugar", "Alimentar", "Disciplinar", "Baño", "Curar", "Luces" y "Salir".
//              - Navegación: flechas ARRIBA/ABAJO o IZQUIERDA/DERECHA
//              - Selección: ENTER / SPACE
//              - "Salir" termina la ejecución; seleccionar una acción muestra una CG y texto
//                (ENTER/SPACE vuelve al menú de comandos).
//
// Nota: Cabecera ampliada con los comentarios de TAMA02B.PRG para facilitar la comparación/diff.
// (A continuación se incluye la cabecera original de TAMA02B.PRG)
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// TÍTULO:      TAMA02.PRG - Esqueleto UI básico
// AUTOR:       Sebastian J. MONCHO MAQUET
// FECHA:       14/02/2026
// DESCRIPCIÓN: Segundo ejemplo de un tutorial sobre cómo crear un juego de mascota virtual en MS-DOS.
//              Muestra una interfaz gráfica simple:
//              - HUD superior: stats (Hambre, Felicidad, Disciplina)
//              - CG central: imagen de Aisha
//              - Muestra el texto inferior: "Salir"
//
// Nota: Esta versión (TAMA02B.PRG) es funcionalmente idéntica a TAMA02A.PRG,
//       pero organiza los datos usando STRUCTs en lugar de variables/arrays.
//------------------------------------------------------------------------------

PROGRAM TAMA_WAIFU;

CONST
    PERMISO_ESCRITURA = "w";    // w = escritura, r = lectura, a = append (añadir al final)

    // ID de los gráficos
    CG_AISHA = 4;         // ID del gráfico que muestra a Aisha
    MARCO_DIALOGO = 16;   // ID del marco del cuadro de dilálogo

    // Índices para HUD, recorremos un bucle para mostrar los textos en pantalla
    HUD_HAMBRE = 0;     // Índice para el texto "Hambre:" y su valor
    HUD_FELICIDAD = 1;  // Índice para el texto "Felicidad:" y su valor
    HUD_DISCIPLINA = 2; // Índice para el texto "Disc:" y su valor
    HUD_COUNT = 3;      // Número total de labels del HUD (fin del bucle)

    // Índices para los textos del reloj,  recorremos un bucle para mostrar los textos en pantalla
    RL_HORA_LABEL = 0;  // 'Hora:' antes de la hora
    RL_SEP_T1 = 1;      // ':' entre horas y minutos
    RL_SEP_T2 = 2;      // ':' entre minutos y segundos
    RL_FECHA_LABEL = 3; // 'Fecha:' antes de la fecha
    RL_SEP_D_M = 4;     // '/' entre día y mes
    RL_SEP_M_Y = 5;     // '/' entre mes y año
    RL_COUNT = 6;       // Número total de labels del reloj (fin del bucle)

    // Indice para los valoress del reloj, recorremos un bucle para mostrar los valores en pantalla
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
        STRUCT label[HUD_COUNT] // Lista de labels ("Hambre:", "Felicidad:", "Disc:")
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
            height = 20;  // alto del rectángulo
        END
    END

    // Estructura de rutas de assets
    STRUCT rutas
        aisha = "tama/aisha.fpg";    // Fichero con los gráficos de la chica mascota
        hud = "tama/hud.fpg";        // Fichero con los gráficos de la interfaz
        tmp_nombre = "tm_time.tmp";  // Fichero temporal para obtener la hora del sistema
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

        // Stats de la mascota — movidos aquí para encapsular el estado
        STRUCT stats
            hambre = 2;
            felicidad = 3;
            disciplina = 1;
        END
    END

    // Estructura del menú de comandos
    STRUCT menu
        spacing = 72;        // separación horizontal entre opciones (incrementada para evitar solapamientos)
        selected = 0;        // índice seleccionado
        active = 0;          // 1 = acción activa (modal)
        accion_id = -1;      // id de la acción activa (campo renombrado)
        count = 7;           // número de comandos

        STRUCT comando[7]    // Lista de 7 comandos (Jugar, Alimentar, Disciplinar, Baño, Curar, Luces, Salir)
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

    // Carganmos la paleta
    load_pal(rutas.hud);

    // Carganis kis archivos FPG
    fpg.aisha = load_fpg(rutas.aisha);
    fpg.hud = load_fpg(rutas.hud);

    // Inicializamos el reloj con la hora del sistema
    get_hora();
    // Inicializamos el menu
    init_menu();

    // Iniciamos los procesos que correrán en paralelo
    mostrar_mascota();  // El personaje a mostrar
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
// PROCESS: get_hora
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
    file = fpg.aisha;   // Fichero FPG a utiiizar
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
// PROCESS: init_hud
// DESCRIPCIÓN: Inicializa las posiciones y textos de los labels del HUD
// que luego serán usados en el proceso `mostrar_hud`
//------------------------------------------------------------------------------
FUNCTION init_hud();
BEGIN
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

    // Labels del reloj
    hud.reloj.labels[RL_HORA_LABEL].pos.x = 64;
    hud.reloj.labels[RL_HORA_LABEL].pos.y = 17;
    hud.reloj.labels[RL_HORA_LABEL].text.label = "Hora:";

    hud.reloj.values[RV_HORA].pos.x = 104; // hora (2 dígitos)
    hud.reloj.values[RV_HORA].pos.y = 17;

    hud.reloj.labels[RL_SEP_T1].pos.x = 120; // ':'
    hud.reloj.labels[RL_SEP_T1].pos.y = 17;
    hud.reloj.labels[RL_SEP_T1].text.label = ":";

    hud.reloj.values[RV_MIN].pos.x = 128; // minutos
    hud.reloj.values[RV_MIN].pos.y = 17;

    hud.reloj.labels[RL_SEP_T2].pos.x = 144; // ':'
    hud.reloj.labels[RL_SEP_T2].pos.y = 17;
    hud.reloj.labels[RL_SEP_T2].text.label = ":";

    hud.reloj.values[RV_SEG].pos.x = 152; // segundos
    hud.reloj.values[RV_SEG].pos.y = 17;

    // Fecha
    hud.reloj.labels[RL_FECHA_LABEL].pos.x = 188;
    hud.reloj.labels[RL_FECHA_LABEL].pos.y = 17;
    hud.reloj.labels[RL_FECHA_LABEL].text.label = "Fecha:";

    hud.reloj.values[RV_DIA].pos.x = 232; // día
    hud.reloj.values[RV_DIA].pos.y = 17;

    hud.reloj.labels[RL_SEP_D_M].pos.x = 248; // '/'
    hud.reloj.labels[RL_SEP_D_M].pos.y = 17;
    hud.reloj.labels[RL_SEP_D_M].text.label = "/";

    hud.reloj.values[RV_MES].pos.x = 256; // mes
    hud.reloj.values[RV_MES].pos.y = 17;

    hud.reloj.labels[RL_SEP_M_Y].pos.x = 272; // '/'
    hud.reloj.labels[RL_SEP_M_Y].pos.y = 17;
    hud.reloj.labels[RL_SEP_M_Y].text.label = "/";

    hud.reloj.values[RV_ANO].pos.x = 280; // año (4 dígitos)
    hud.reloj.values[RV_ANO].pos.y = 17;

    // Ajustamos el ancho del fondo del HUD al ancho de la pantalla
    hud.background.width = configuracion.pantalla.ancho;

    return(0);
END

//------------------------------------------------------------------------------
// FUNCTION: init_menu
// DESCRIPCIÓN: Inicializa labels, CGs y posición del menú de comandos
//------------------------------------------------------------------------------
FUNCTION init_menu();
BEGIN
    menu.spacing = 72;  // más separación para que no se solapen los textos
    menu.selected = 0;
    menu.active = 0;
    menu.accion_id = -1;
    menu.count = 7;

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
// PROCESS: mostrar_hud
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

    // Escribimos los labels dek HUD uno a uno
    FOR (idx = 0; idx < HUD_COUNT; idx++)
        write(fuente.fichero, hud.label[idx].pos.x, hud.label[idx].pos.y, fuente.alineacion.izq, hud.label[idx].text.label);
    END

    // Escribimos los valores de los stats (OFFSET)
    write_int(fuente.fichero, hud.label[HUD_HAMBRE].value_pos.x, hud.label[HUD_HAMBRE].value_pos.y, fuente.alineacion.izq, OFFSET mascota.stats.hambre);
    write_int(fuente.fichero, hud.label[HUD_FELICIDAD].value_pos.x, hud.label[HUD_FELICIDAD].value_pos.y, fuente.alineacion.izq, OFFSET mascota.stats.felicidad);
    write_int(fuente.fichero, hud.label[HUD_DISCIPLINA].value_pos.x, hud.label[HUD_DISCIPLINA].value_pos.y, fuente.alineacion.izq, OFFSET mascota.stats.disciplina);

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

    // write_int actualiza los valores en pantalla en tiempo real, no necesitamos ningún bucle o reescribir etos textos
    return(0);
END

//------------------------------------------------------------------------------
// PROCESS: mostrar_comandos
// DESCRIPCIÓN: Renderiza el marco de diálogo y las opciones del menú inferior.
//              Utiliza la `STRUCT menu` y los `menu.comando[]` para ser totalmente data-driven.
//------------------------------------------------------------------------------
PROCESS mostrar_comandos();
PRIVATE
    leftOffset = 0;          // desplazamiento horizontal para centrar cada fila según su número de elementos
    idx = 0;                 // índice para la fila superior
    sub = 0;                 // índice auxiliar para la segunda fila
    row_gap = 12;            // separación vertical entre filas
    top_count = 0;           // elementos en fila superior
    bottom_count = 0;        // elementos en fila inferior
    action_text = "";        // texto de la acción activa (si hay alguna)
    action_graph = CG_AISHA; // gráfico de la acción activa (si hay alguna)
    px = 0;                  // posición X para dibujar cada comando (se recalcula para cada opción)
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

        // Calculamos y dibujamos en 2 filas (cada fila centrada según su número de elementos)
        top_count = (menu.count + 1) / 2;                  // p. ej. 7 -> 4 arriba, 3 abajo
        bottom_count = menu.count - top_count;

        // Si la acción está activa, NO dibujamos los comandos; mostramos solo el texto dentro del marco.
        IF (menu.active == 1)
            IF (menu.accion_id >= 0 AND menu.accion_id < menu.count)
                action_graph = menu.comando[menu.accion_id].cg;
                action_text = menu.comando[menu.accion_id].action_text;
            ELSE
                action_graph = CG_AISHA;
                action_text = "";
            END

            // Cambiamos el gráfico de la mascota (mostrar_mascota lo renderiza) y mostramos el texto DENTRO del marco
            mascota.graph = action_graph;
            id_action_text = write(fuente.fichero, x, y, fuente.alineacion.centro, action_text);
        ELSE
            // --- fila superior ---
            leftOffset = (top_count - 1) * menu.spacing / 2;
            px = x - leftOffset;
            FOR (idx = 0; idx < top_count; idx++)
                IF (menu.selected == idx)
                    texto_seleccionado = "> " + menu.comando[idx].label.text;
                    id_menu_textos[idx] = write(fuente.fichero, px, y - row_gap / 2, fuente.alineacion.centro, texto_seleccionado);
                ELSE
                    id_menu_textos[idx] = write(fuente.fichero, px, y - row_gap / 2, fuente.alineacion.centro, menu.comando[idx].label.text);
                END

                px = px + menu.spacing;
            END

            // --- fila inferior (si existe) ---
            IF (bottom_count > 0)
                leftOffset = (bottom_count - 1) * menu.spacing / 2;
                px = x - leftOffset;

                FOR (sub = 0; sub < bottom_count; sub++)
                    idx = top_count + sub;
                    IF (menu.selected == idx)
                        texto_seleccionado = "> " + menu.comando[idx].label.text;
                        id_menu_textos[idx] = write(fuente.fichero, px, y + row_gap / 2, fuente.alineacion.centro, texto_seleccionado);
                    ELSE
                        id_menu_textos[idx] = write(fuente.fichero, px, y + row_gap / 2, fuente.alineacion.centro, menu.comando[idx].label.text);
                    END

                    px = px + menu.spacing;
                END
            END
        END

        FRAME;
    END
END

//------------------------------------------------------------------------------
// PROCESS: controlar_menu
// DESCRIPCIÓN: Gestiona la entrada del menú (navegación y selección). Usa la STRUCT `menu`.
//------------------------------------------------------------------------------
PROCESS controlar_menu();
PRIVATE
BEGIN
    LOOP
        IF (NOT menu.active)
            // Navegación: flechas ARRIBA/ABAJO o IZQUIERDA/DERECHA
            IF (key(_left) OR key(_up))
                menu.selected = menu.selected - 1;

                // Si bajamos de 0, volvemos al último elemento (wrap-around)
                IF (menu.selected < 0)
                    menu.selected = menu.count - 1;
                END
            END
            IF (key(_right) OR key(_down))
                menu.selected = menu.selected + 1;

                // Si superamos el último elemento, volvemos al primero (wrap-around)
                IF (menu.selected > menu.count - 1)
                    menu.selected = 0;
                END
            END

            // Selecciamos una acción con: ENTER / SPACE
            IF (key(_enter) OR key(_space))
                IF (menu.selected == menu.count - 1)
                    // Comando de "Salir"
                    exit("Hasta pronto.", 0);
                ELSE
                    // Activamos la acción seleccionada
                    menu.active = 1;
                    menu.accion_id = menu.selected;
                END
            END
        ELSE
            // Si una acción está seleccionada, permitir cerrarla con ENTER/SPACE/ESC
            IF (key(_enter) OR key(_space) OR key(_esc))
                menu.active = 0;            // Ninguna acción está activa
                mascota.graph = CG_AISHA;   // Gráfico por defecto
            END
        END

        // Esperamos a que se suelten las teclas (simulamos el on-release)
        WHILE ((key(_enter) OR key(_space) OR key(_left) OR key(_right) OR key(_up) OR key(_down)))
            FRAME;
        END

        FRAME;
    END
END
