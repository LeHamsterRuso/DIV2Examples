//------------------------------------------------------------------------------
// TITLE:       MODE9_2P.PRG
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        07/06/2026
// DESCRIPTION: Ejemplo del "modo 9" a DOS JUGADORES con PANTALLA PARTIDA
//              (split-screen) usando MODE9.DLL. Dos camaras independientes, cada
//              una con su STRUCT m9 y su viewport (mitad superior / inferior).
//
//   JUGADOR 1 (mitad superior):  W/S avanzar-retroceder   A/D girar   ESPACIO saltar
//   JUGADOR 2 (mitad inferior):  CURSORES arr/abj avanzar   izq/der girar   CTRL saltar
//   ESC: salir
//
//   GRAVEDAD + ESCALERAS/RAMPAS: cada camara cae por gravedad (la integra el PRG)
//   y la DLL la apoya en el suelo, sube peldaños/rampas (MODE9_STEP). En el patio
//   hay una pequena escalera (material Stairs) y el mapa lo rodea un lago (Water).
//
//   Ninguno usa xadvance (no hay strafe): izquierda/derecha GIRAN la camara,
//   como en un FPS clasico.
//
//   COLISIONES: MODE9_COLLISION(1) hace que advance NO atraviese las paredes;
//   la distancia minima a la pared es el campo 'radius' de cada camara.
//
// FICHEROS: CASTLE.OBJ + MAP/CASTLE.MAP (como en MODE9.PRG).
//------------------------------------------------------------------------------
PROGRAM MODE9_2P;

IMPORT "MODE9.DLL";

CONST
    SCREEN_X = 320;
    SCREEN_Y = 200;
    GAME_FPS = 30;
    ADV_UNIT = 28;        // velocidad de paso (uds DIV2)
        TURN     = 7000;      // velocidad de giro (milesimas de grado por frame)
    c_m9     = 200;       // ctype de billboard del modo 9 (igual que en la DLL)

GLOBAL
    // Array de dos camaras m9 (mismos campos que m8). &m9[n].z = base del n.
    STRUCT m9[2]
        z;
        camera;
        height;
        angle;
    END

PRIVATE
    c1; c2;               // ids de los procesos camara
    scrw; scrh;           // resolucion real (viewports a cualquier resolucion)
BEGIN
    //ignore_error(142); <- Descomentar en ordenadores donde tarde mucho en cargar

    set_mode(SCREEN_X * 1000 + SCREEN_Y);   // set_mode a la resolucion que quieras (320x200, 640x480, 800x600...)
    set_fps(GAME_FPS, 0);
    load_pal("div2.pal");                       // paleta base ANTES de los setters
    load_fpg("FPG/MODE9.FPG");

    // Escenario 3D (malla + textura + escala) en una sola llamada. La textura es
    // el material 0 (por defecto de todos los materiales del OBJ).
    LOAD_WLD9("CASTLE.OBJ", "MAP/CASTLE.MAP", 100);
    MODE9_CULL(1);

    // MULTIMATERIALES: CASTLE.OBJ define 0=Castle, 1=Stairs, 2=Water (por 'usemtl').
    MODE9_MATERIAL(1, "MAP/STAIRS.MAP");   // peldanos de la escalera del patio
    MODE9_MATERIAL(2, "MAP/WATER.MAP");    // lago que rodea la isla

    // Cargar el MISMO FPG en la DLL: asi puede dibujar los billboards (c_m9) en
    // CADA viewport (necesario en split-screen; DIV2 solo pinta un sprite una vez).
    MODE9_LOADFPG("FPG/MODE9.FPG");

    // Ambiente + niebla (color 0..100; la niebla funde hacia el color de fondo)
    //SET_ENV_COLOR9(60, 72, 88);
    //SET_FOG9(300, 1400);

    // PAREDES SOLIDAS: advance no las atraviesa (usa 'radius' de cada camara)
    MODE9_COLLISION(1);

    // ESCALERAS Y RAMPAS: cada camara sube sola los desniveles <= 50 uds DIV2 y se
    // apoya en el suelo (la gravedad la aplica cada player_cam, ver mas abajo).
    MODE9_STEP(50);

    // Crear las dos camaras (devuelven su id de proceso)
    c1 = player_cam(0,   0,   -1500, -90000);     // jugador 1: fuera, mirando al porton
    c2 = player_cam(1,   100, -1500, -90000);     // jugador 2: fuera, mirando al porton

    // Resolucion REAL (la sabe la DLL): los viewports se adaptan a cualquier
    // modo (320x200, 640x480, 800x600...), no solo a 320x200.
    scrw = MODE9_SCRW();
    scrh = MODE9_SCRH();
    // --- Cielo panoramico (skybox) -------------------------------------------
    // LOAD_SKY9(map): textura .MAP que envuelve 360 en horizontal; sustituye el
    // color de fondo plano. Gira con la camara (yaw) y se desplaza con el pitch.
    // Debe usar la MISMA paleta que el juego (SKY.MAP se genero desde CASTLE.MAP
    // con TOOLS/make_sky.py). SKY9_OFF() vuelve al fondo plano de SET_ENV_COLOR9.
    LOAD_SKY9("MAP/SKY.MAP");

    // Definir los dos viewports (split-screen horizontal: arriba / abajo)
    MODE9_SPLIT(0, c1, &m9[0].z, 0,        0, scrw, scrh/2);   // arriba
    MODE9_SPLIT(1, c2, &m9[1].z, 0, scrh/2, scrw, scrh/2);   // abajo
    //MODE9_DOWNSCALE(2);   // Si va lento: render a menor resolucion (2/3/4) duplicando lineas
    //MODE9_PERSPECTIVE(1);  // Texturas perfectas (1/w por pixel) en vez de afin a 16px (mas lento)

    NPC(0, 600, 0);          // un sprite angular "modo 7" en el patio del castillo, representa un NPC
    M9TREE(600, -1300, 0);   // un sprite plano, representa un arbol
    M9TREE(-600, -1300, 0);  // un sprite plano, representa un arbol
    M9TREE(1000, -1600, 0);  // un sprite plano, representa un arbol
    M9TREE(-1000, -1600, 0); // un sprite plano, representa un arbol
    M9SIGN(300, -1200, 0);   // un cartel plano con textura


    LOOP
        if (key(_esc)) STOP_MODE9(); exit("Bye", 0); end
        FRAME;
    END
END


//------------------------------------------------------------------------------
// PROCESO camara de un jugador.
//   pl    : indice del jugador (0 = teclas WASD, 1 = cursores)
//   sx,sy : posicion inicial en el suelo (uds DIV2: x=mundo X, y=mundo Z)
//   sang  : angulo inicial
//------------------------------------------------------------------------------
PROCESS player_cam(pl, sx, sy, sang)
PRIVATE
    npc_gr[] = 8, 8,1,2,3,4,5,6,7;   // N=8 graficos en 360º
    fall_v;        // velocidad de caida (la gravedad la integra el PRG)
    grounded;      // 1 si la DLL nos sostiene en un suelo/escalon/rampa
    z_fell;        // z tras la gravedad, ANTES de que la DLL ajuste
    jumpk;         // tecla de salto de este jugador
BEGIN
    x = sx; y = sy; z = 0;
    angle  = sang;
    radius = 40;              // distancia minima a la pared (uds DIV2)
    ctype  = c_m9;            // marcador visible para el OTRO jugador (billboard)
    //graph = 8;            // grafico de MODE9.FPG
    xgraph = &npc_gr[0];
    size   = 100;             // escala base (%); el modo 9 la modula por distancia

    // Estado del modo 9 de ESTE jugador (su propio m9[pl])
    m9[pl].camera = id;
    m9[pl].height = 160;     // altura del ojo
    m9[pl].angle  = 0;       // pitch (0 = horizonte)

    fall_v   = 0;
    grounded = 1;
    if (pl == 0) jumpk = _space; else jumpk = _control; end   // salto por jugador

    LOOP
        if (pl == 0)
            // --- Jugador 1: WASD (+ESPACIO salto) ---
            if (key(_w)) advance(ADV_UNIT);  end
            if (key(_s)) advance(-ADV_UNIT); end
            if (key(_a)) angle += TURN;      end    // girar a la izquierda
            if (key(_d)) angle -= TURN;      end    // girar a la derecha
        else
            // --- Jugador 2: cursores (+CTRL salto) ---
            if (key(_up))    advance(ADV_UNIT);  end
            if (key(_down))  advance(-ADV_UNIT); end
            if (key(_left))  angle += TURN;      end
            if (key(_right)) angle -= TURN;      end
        end

        // --- Gravedad (en el PRG) + suelo/escalon/rampa (lo pone la DLL) -------
        // Mismo patron que MODE9.PRG: integramos la gravedad (z baja); tras el
        // FRAME la DLL puede SUBIR z si nos apoyamos en algo (ver MODE9_STEP).
        if (key(jumpk) and grounded)
            fall_v   = -60;        // impulso de salto (negativo = hacia arriba)
            grounded = 0;
        end
        fall_v = fall_v + 6;                              // gravedad (subida)
        if (fall_v > 0) fall_v = fall_v + 8; end         // caida mas rapida (game feel)
        z = z - fall_v;            // caer (o subir, si fall_v<0 por el salto)
        if (z < 0) z = 0; end       // suelo de seguridad en y=0
        z_fell = z;                // z tras la gravedad, antes de que la DLL ajuste

        FRAME;

        // Si la DLL nos dejo por encima de lo que dejo la gravedad y caiamos,
        // tocamos suelo: grounded y paramos la caida.
        if (z > z_fell - 1 and fall_v > 0)
            grounded = 1;
            fall_v   = 0;
        else
            grounded = 0;
        end
    END
END

//------------------------------------------------------------------------------
// Procesos de SPRITE billboard (estilo modo 7): basta con ponerle ctype = c_m9 y
// sus coordenadas de MUNDO (x,y = suelo, z = altura), graph y size. El modo 9
// lo dibuja automaticamente como sprite 2D escalado segun la distancia, SIN
// llamar a nada cada frame (igual que un proceso c_m7 en el modo 7).
//   - x, y : posicion en el plano del suelo (uds DIV2)
//   - z    : altura (uds DIV2)
//   - size : escala base en % (la distancia la aplica el modo 9 encima)
//
// OCLUSION: el modo 9 oculta el sprite si queda tapado por la geometria (test
// de z-buffer). Se puede desactivar con MODE9_OCCLUDE(0).
//------------------------------------------------------------------------------
PROCESS NPC(wx, wy, wz)
PRIVATE
    npc_gr[] = 8, 8,1,2,3,4,5,6,7;   // N=8 graficos en 360º

BEGIN
    ctype = c_m9;         // <-- el modo 9 lo pinta como billboard automaticamente
    //graph = 8;          // grafico de MODE9.FPG, billboard plano (1 cara)
    xgraph = &npc_gr[0];  // grafico de MODE9.FPG, billboard con multiples caras, en funcion del angulo de vision
    size  = 100;          // escala base (%); el modo 9 la modula por distancia
    angle = 0;
    x = wx; y = wy; z = wz;   // posicion en el MUNDO (el proceso la conserva)
    LOOP
        FRAME;
    END
END

PROCESS M9TREE(wx, wy, wz)
BEGIN
    ctype = c_m9;         // <-- el modo 9 lo pinta como billboard automaticamente
    graph = 9;          // grafico de MODE9.FPG, billboard plano (1 cara)
    size  = 100;          // escala base (%); el modo 9 la modula por distancia
    angle = 0;
    x = wx; y = wy; z = wz;   // posicion en el MUNDO (el proceso la conserva)
    LOOP
        FRAME;
    END
END

PROCESS M9SIGN(wx, wy, wz)
BEGIN
    ctype = c_m9;         // <-- el modo 9 lo pinta como billboard automaticamente
    graph = 10;          // grafico de MODE9.FPG, billboard plano (1 cara)
    size  = 100;          // escala base (%); el modo 9 la modula por distancia
    angle = 0;
    x = wx; y = wy; z = wz;   // posicion en el MUNDO (el proceso la conserva)
    LOOP
        FRAME;
    END
END
