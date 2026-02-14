//------------------------------------------------------------------------------
// TÍTULO:      TAMA02A.PRG - Versión funcional sin STRUCTs (salvo `reloj`)
// AUTOR:       Sebastian J. MONCHO MAQUET
// FECHA:       13/02/2026
// DESCRIPCIÓN: Segundo ejemplo de un tutorial sobre cómo crear un juego de mascota virtual en MS-DOS.
//              Muestra una interfaz gráfica simple:
//              - HUD superior: stats (Hambre, Felicidad, Disciplina)
//              - CG central: imagen de Aisha
//              - Muestra el texto inferior: "Salir"
//
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
    // Juego a 320x200, 60 FPS, sin frameskip, cuadro de diálogo de 50px de alto
    screen_width = 320;
    screen_height = 200;
    max_fps = 60;
    frameskip = 0;
    cuadro_dialogo_alto = 50;

    // Configuración de los write/write_int para el HUD
    fuente_fichero = 0;
    fuente_izq = 3;
    fuente_centro = 4;

    // ID de los FPG a cargar
    fpg_aisha = 0;
    fpg_hud = 0;

    // Fondo del HUD
    background_tipo = 3;
    background_color = 2;
    background_opacity = 8;
    background_region = 0;
    background_x = 0;
    background_y = 0;
    background_width = 320;
    background_height = 20;

    // Rutas de los assets
    rutas_aisha = "tama/aisha.fpg";
    rutas_hud = "tama/hud.fpg";
    rutas_tmp_nombre = "tm_time.tmp";

    // Stats como variables
    hambre = 2;
    felicidad = 3;
    disciplina = 1;

    // Estructura reloj (fecha/hora)
    STRUCT reloj
        dia = 0;
        mes = 0;
        ano = 0;
        hora = 0;
        minutos = 0;
        segundos = 0;
    END

PRIVATE
    i = 0; // Contador de frames para actualizar reloj cada segundo

BEGIN
    // Configurar modo de video y FPS
    set_mode(screen_width * 1000 + screen_height);
    set_fps(max_fps, 0);

    // Cargamos la paleta y los ficheros FPG
    load_pal(rutas_hud);
    fpg_aisha = load_fpg(rutas_aisha);
    fpg_hud = load_fpg(rutas_hud);

    // Inicializamos el reloj con la hora del sistema
    get_hora();

    // Iniciamos los procesos que correrán en paralelo
    mostrar_mascota();  // El personaje a mostrar
    mostrar_hud();      // Inofrmación en pantalla
    mostrar_comandos(); // La lista de comandos

    // Loop principal
    LOOP
        // Actualizar contador de frames y reloj cada segundo
        i = i + 1;
        IF (i > FPS)   // La constante FPS contiene cuantos frames hubo en el último segundo, más fiable que usar max_fps
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
    tmp_id = fopen(rutas_tmp_nombre, PERMISO_ESCRITURA);
    fwrite(OFFSET tmp_dato, sizeof(tmp_dato), tmp_id);
    fclose(tmp_id);

    get_fileinfo(rutas_tmp_nombre);

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
    file = fpg_aisha;   // Fichero FPG a utilizar
    graph = CG_AISHA;   // ID del gráfico a mostrar

    // X = mitad del ancho de la pantalla, para que quede centrado
    x = screen_width / 2;

    // Y = centro de la pantalla - mitad del alto del cuadro de diálogo para que quede justo encima del texto inferior
    y = screen_height / 2 - cuadro_dialogo_alto / 2;

    LOOP
        FRAME;
    END
END

//------------------------------------------------------------------------------
// PROCESS: mostrar_hud
// DESCRIPCIÓN: Muestra el HUD superior con los stats del personaje y el reloj
//------------------------------------------------------------------------------
FUNCTION mostrar_hud();
BEGIN
    // Dibujamos un fondo semitransparente
    // Uso de draw: draw(<tipo>, <color>, <opacidad>, <región>, <x0>, <y0>, <x1>, <y1>)
    draw(background_tipo, background_color, background_opacity, background_region,
            background_x, background_y,
            background_x + background_width, background_y + background_height);

    // Labels del HUD (coordenadas fijas en esta versión)
    write(fuente_fichero, 8, 5, fuente_izq, "Hambre:");
    write(fuente_fichero, 109, 5, fuente_izq, "Felicidad:");
    write(fuente_fichero, 210, 5, fuente_izq, "Disciplina:");

    // Valores de los stats (OFFSET) en coordenadas fijas
    write_int(fuente_fichero, 64, 5, fuente_izq, OFFSET hambre);
    write_int(fuente_fichero, 181, 5, fuente_izq, OFFSET felicidad);
    write_int(fuente_fichero, 286, 5, fuente_izq, OFFSET disciplina);

    // Labels del reloj (texto) en coordenadas fijas
    write(fuente_fichero, 64, 17, fuente_izq, "Hora:");
    write(fuente_fichero, 120, 17, fuente_izq, ":");
    write(fuente_fichero, 144, 17, fuente_izq, ":");
    write(fuente_fichero, 188, 17, fuente_izq, "Fecha:");
    write(fuente_fichero, 248, 17, fuente_izq, "/");
    write(fuente_fichero, 272, 17, fuente_izq, "/");

    // Valores numéricos del reloj (OFFSET) en coordenadas fijas
    write_int(fuente_fichero, 104, 17, fuente_izq, OFFSET reloj.hora);
    write_int(fuente_fichero, 128, 17, fuente_izq, OFFSET reloj.minutos);
    write_int(fuente_fichero, 152, 17, fuente_izq, OFFSET reloj.segundos);

    write_int(fuente_fichero, 232, 17, fuente_izq, OFFSET reloj.dia);
    write_int(fuente_fichero, 256, 17, fuente_izq, OFFSET reloj.mes);
    write_int(fuente_fichero, 280, 17, fuente_izq, OFFSET reloj.ano);

    return(0);
END

//------------------------------------------------------------------------------
// PROCESS: mostrar_comandos
// DESCRIPCIÓN: Muestra el marco de diálogo y los comandos disponibles (en este caso sólo "Salir") en la parte inferior de la pantalla
//------------------------------------------------------------------------------
PROCESS mostrar_comandos();
BEGIN
    file = fpg_hud;         // Fichero FPG a utilizar
    graph = MARCO_DIALOGO;  // ID del gráfico del marco del cuadro de diálogo

    // Centramos el marco en la parte inferior de la pantalla
    x = screen_width / 2;
    y = screen_height - cuadro_dialogo_alto / 2;

    // Por ahora no hay comandos
    write(fuente_fichero, x, y, fuente_centro, "> Salir");

    LOOP
        // Si se pulsa ESC, SPACE o ENTER, salimos del programa
        IF (key(_esc) OR key(_space) OR key(_enter))
            exit("Hasta pronto.", 0);
        END

        FRAME;
    END
END
