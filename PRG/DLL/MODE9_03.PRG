//------------------------------------------------------------------------------
// TITLE:       MODE9.PRG
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        07/06/2026
// DESCRIPTION: Ejemplo del "modo 9": desplazamiento por un escenario 3D (.OBJ)
//              con camara en primera persona (estilo Doom / Elder Scrolls Arena)
//              usando MODE9.DLL. Sobre el escenario se ven objetos 2D como en
//              el modo 7 (sprites con escala segun distancia, aka "billboards").
//              Este RPG es identico al MODE9_02.PRG, pero con un gato 3D en la entrada del castillo.
//
// CONTROLES:
//   W / S         : avanzar / retroceder (SHIFT = correr)
//   A / D         : desplazamiento lateral (strafe)
//   Raton         : girar (horizontal) y mirar (vertical / pitch)
//   ESPACIO       : saltar
//   CTRL          : agacharse
//   ESC           : salir
//
// FICHEROS NECESARIOS:
//   CASTLE.OBJ    : Escenario 3D (castillo + escalera en el patio + lago isla;
//                   3 materiales por 'usemtl': Castle, Stairs, Water).
//   MAP/CASTLE.MAP: Textura del castillo (material 0, por defecto).
//   MAP/STAIRS.MAP: Textura de los peldaños de la escalera (material 1).
//   MAP/WATER.MAP : Textura del lago que rodea la isla (material 2).
//   FPG/MODE9.FPG : Gráficos de los billboards.
//   MAP/SKY.MAP    : Textura del cielo panorámico (skybox).
//
// SOBRE m9 Y c_m9:
//   En DIV/DIV2, una DLL no puede crear STRUCTs ni c_types del lenguaje DIV2,
//   asi que aqui se declaran: el STRUCT m9 (mismos campos que m8: z, camera, height, angle)
//   y la constante c_m9 = 200.
//   La camara se activa con START_MODE9(id,&m9.z,0).
//   Los sprites se ponen con ctype = c_m9 y coordenadas de MUNDO (x,y,z) + size
//   + graph; el modo 9 los dibuja como billboards escalados por distancia SIN
//   llamar a nada cada frame (igual que c_m7 en el modo 7). c_m9 DEBE valer lo
//   mismo en el PRG y en la DLL (200 por defecto; cambiable con MODE9_CTYPE).
//------------------------------------------------------------------------------
PROGRAM MODE9_DEMO;

IMPORT "MODE9.DLL";

CONST
    SCREEN_X   = 320;     // Ancho de la resolucion de la pantalla
    SCREEN_Y   = 200;     // Alto de la resolucion de la pantalla
    GAME_FPS   = 60;      // FPS objetivo
    ADV_UNIT   = 30;      // velocidad de paso (uds DIV2)
    c_m9       = 200;     // c_type "logico" del modo 9 (convencion, ver cabecera)

GLOBAL
    STRUCT m9            // STRUCT de camara del modo 9 (mismos campos que m8). &m9.z = base del struct.
        z;
        camera;
        height;
        angle;
    END
    scr_x;                // resolucion real (la lee la DLL): raton/camara a
    scr_y;                // cualquier resolucion, no solo 320x200
    cat_h;              // handle del modelo 3D del gato (LOAD_OBJ9)
BEGIN
    // ignore_error(142); // Descomentar si tarda en arrancar en tu PC

    set_mode(SCREEN_X * 1000 + SCREEN_Y);
    set_fps(GAME_FPS, 0);

    scr_x = MODE9_SCRW();   // MODE9_SCRW() y MODE9_SCRH() se pueden llamar en cualquier momento, no solo al inicio, por si quieres cambiar la resolucion con set_mode durante el juego.
    scr_y = MODE9_SCRH();

    load_fpg("FPG/MODE9.FPG"); // cargar el FPG del juego

    MODE9_LOADFPG("FPG/MODE9.FPG"); // FPG del modo 9 para los billboards

    // --- Cargar el escenario 3D (UNA sola llamada: malla + textura + escala) --
    // LOAD_WLD9(obj, textura, unitscale).  unitscale = 100 uds DIV2 por unidad
    // OBJ. Si la textura no existe (o pones ""), el render cae a flat-shading.
    // La textura de LOAD_WLD9 es el material 0 (POR DEFECTO de todos los materiales).
    LOAD_WLD9("CASTLE.OBJ", "MAP/CASTLE.MAP", 100);

    // --- MULTIMATERIALES -----------------------------------------------------
    // CASTLE.OBJ tiene 3 materiales por 'usemtl' (en orden): 0=Castle, 1=Stairs,
    // 2=Water. MODE9_MATERIAL(idx, map) asigna una textura a cada uno. El 0 ya lo
    // puso LOAD_WLD9 (CASTLE.MAP); aqui ponemos la escalera y el lago. Si un .MAP
    // no existe aun, ese material cae al 0 (CASTLE.MAP) sin fallar.
    MODE9_MATERIAL(1, "MAP/STAIRS.MAP");   // peldanos de la escalera del patio
    MODE9_MATERIAL(2, "MAP/WATER.MAP");    // lago que rodea la isla

    // MODE9_CULL(0); // Desactivar el backface culling (dibujar las caras por ambas caras; mas lento)

    //MODE9_PERSPECTIVE(1);   // <-- Corrige la perspectiva de las texturas (mas lento)

    // Far clip ("flopping"): no dibujar geometria mas alla de N uds DIV2.
    // 0 = sin limite. Con SET_FOG9 activa se recorta automaticamente a fog_far
    // (lo que queda tras la niebla es del color de fondo, no se dibuja).
    MODE9_FARCLIP(0);

    // COLISIONES: con 1, advance/xadvance NO atraviesan las paredes (la distancia
    // minima a la pared es el campo 'radius' del proceso camara). Con 0, libre.
    MODE9_COLLISION(1);

    // ESCALERAS Y RAMPAS: altura max (uds DIV2) que la camara sube sola. Los muros
    // mas bajos que esto NO bloquean (se suben como un peldaño) y la camara se apoya
    // en el suelo que tiene debajo (rampas inclinadas, escalones). 0 = desactivado.
    // La GRAVEDAD la aplica el PRG (ver el bloque de salto/gravedad de 'camara'); la
    // DLL solo SUBE z al pisar un suelo. 50 uds = medio "metro" OBJ (unitscale=100).
    MODE9_STEP(70);

    // --- Ambiente y niebla (color en rango 0..100, convencion DIV2) ----------
    // SET_ENV_COLOR9 fija el color de FONDO y tambien el color de la NIEBLA.
    // 0..100 por canal: 100=blanco, 0=negro. SET_FOG9 solo necesita near/far
    // (igual que set_fog del modo 8): la niebla funde hacia el color de ambiente.
    //SET_ENV_COLOR9(60, 72, 88);        // cielo amarillento, impacta en el color de la niebla
    //SET_FOG9(300, 1400);               // niebla: near=300  far=1400 (uds DIV2)
    MODE9_FOG_OFF();

    // --- Cielo panoramico (skybox) -------------------------------------------
    // LOAD_SKY9(map): textura .MAP que envuelve 360 en horizontal; sustituye el
    // color de fondo plano. Gira con la camara (yaw) y se desplaza con el pitch.
    // Debe usar la MISMA paleta que el juego (SKY.MAP se genero desde CASTLE.MAP
    // con TOOLS/make_sky.py). SKY9_OFF() vuelve al fondo plano de SET_ENV_COLOR9.
    LOAD_SKY9("MAP/SKY.MAP");

    // --- NPC 3D estatico (objeto OBJ texturado en el mundo) ------------------
    // LOAD_OBJ9(obj, textura, unitscale) carga UN modelo 3D estatico: la malla
    // CAT.OBJ con su textura CAT.MAP, escala 50 (uds DIV2 por unidad OBJ). Ocupa
    // un slot de los 8 de la DLL. El gato se vera quieto (sin animacion); para
    // animarlo por vertex morphing se usaria LOAD_OBJ9_ANIM + DRAW_OBJ9_ANIM.
    cat_h = LOAD_OBJ9("CAT.OBJ", "MAP/CAT.MAP", 50);

    // --- Procesos ------------------------------------------------------------
    camara();
    NPC3D(cat_h, 400, -1300, 0);
    NPC(0, 600, 0);          // un sprite angular "modo 7" en el patio del castillo, representa un NPC
    M9TREE(600, -1300, 0);   // un sprite plano, representa un arbol
    M9TREE(-600, -1300, 0);  // un sprite plano, representa un arbol
    M9TREE(1000, -1600, 0);  // un sprite plano, representa un arbol
    M9TREE(-1000, -1600, 0); // un sprite plano, representa un arbol
    M9SIGN(300, -1200, 0);   // un cartel plano con textura

    write(0, 2, scr_y-9, 0, "WASD+RATON mover  ESPACIO salto  ESC salir");
END


//------------------------------------------------------------------------------
// Proceso CAMARA: se mueve por el escenario como en el modo 8.
//------------------------------------------------------------------------------
PROCESS camara()
PRIVATE
    mouse_x_prev;
    eye_base;
    fall_v;        // velocidad de caida (la gravedad la integra el PRG)
    grounded;      // 1 si la DLL nos sostiene en un suelo/escalon/rampa
    z_fell;        // z tras aplicar la gravedad, ANTES de que la DLL ajuste
BEGIN
    // Posicion inicial (uds DIV2): x,y = plano del suelo; z = altura
    x = 0;                // frente al porton (el porton esta en z=-1000)
    y = -1500;            // fuera de la muralla, mirando hacia el castillo
    z = 0;
    angle = -90000;       // mirando hacia +Z (hacia el porton)

    // Estado del modo 9
    m9.camera = id;
    m9.height = 160;      // altura del ojo (1.6 uds OBJ; muralla de 4 de alto)
    m9.angle  = 0;        // pitch (0 = horizonte)
    eye_base  = m9.height;
    radius    = 40;       // distancia minima a la pared (para MODE9_COLLISION)

    // START_MODE9(camara, m9, region) -- misma firma que start_mode8.
    //   camara = id del proceso camara.
    //   m9     = &m9.z (la DIRECCION del STRUCT; en modo 8 aqui iria el indice
    //            de m8, pero al ser m9 un struct del PRG hay que pasar su
    //            direccion. &m9.z = base del struct; usa &m9[n].z para un array
    //            de camaras). La DLL lee m9.camera/height/angle de ahi cada
    //            frame (no hace falta MODE9_SET ni MODE9_BIND aparte).
    //   region = 0 (pantalla completa; unica region soportada por la DLL).
    START_MODE9(id, &m9.z, 0);

    //MODE9_DOWNSCALE(2); // Si va lento: render a menor resolucion (2/3/4) duplicando lineas (mas FPS, mas pixelado)
    // Cada valor de downscale reduce la resolucion a 1/2, 1/3 o 1/4 (y duplica lineas para llenar la pantalla).
    // 1 = resolucion completa (sin downscale); 2 = render a la mitad de resolucion (160x100 en vez de 320x200); 3 = un tercio; 4 = un cuarto.
    // Es un truco empleado en juegos first person shooter de consolas de 16 bits

    mouse_x_prev = mouse.x;
    fall_v   = 0;
    grounded = 1;


    load_pal("div2.pal");
    LOOP
        if (key(_esc)) STOP_MODE9(); exit("Bye", 0); end

        // --- Movimiento lateral (strafe) ---
        if (key(_d)) xadvance(angle - 90000, ADV_UNIT); end
        if (key(_a)) xadvance(angle + 90000, ADV_UNIT); end

        // --- Avanzar / retroceder ---
        if (key(_w))
            if (key(_l_shift) or key(_r_shift)) advance(ADV_UNIT*2);
            else advance(ADV_UNIT); end
        end
        if (key(_s)) advance(-ADV_UNIT); end

        // --- Salto y gravedad (LA GRAVEDAD VIVE EN EL PRG) -------------------
        // El PRG integra la gravedad (z baja cada frame). El SUELO -incluidos
        // escalones y rampas- lo pone la DLL TRAS el FRAME: si el jugador se apoya
        // en algo, la DLL le SUBE z (ver MODE9_STEP). Por eso despues del FRAME
        // comprobamos si z subio respecto a lo que dejo la gravedad: si subio y
        // estabamos cayendo, es que tocamos suelo (grounded) y paramos la caida.
        if (key(_space) and grounded)
            fall_v   = -60;        // impulso de salto (negativo = hacia arriba)
            grounded = 0;
        end
        fall_v = fall_v + 6;                              // gravedad (subida)
        if (fall_v > 0) fall_v = fall_v + 8; end         // caida mas rapida (game feel)
        z = z - fall_v;            // caer (o subir, si fall_v<0 por el salto)
        if (z < 0) z = 0; end       // suelo de seguridad en y=0 (por si no hay malla)
        z_fell = z;                // z tras la gravedad, antes de que la DLL ajuste

        // --- Agacharse ---
        if (key(_control)) m9.height = eye_base * 2 / 3;
        else m9.height = eye_base; end

        // --- Raton: giro horizontal y pitch vertical (adaptado a la resolucion) -
        // Yaw: sensibilidad ~constante en cualquier modo (256000/scr_x = 800 @320).
        angle = angle - (mouse.x - mouse_x_prev) * 256000 / scr_x;
        // Pitch: mapeo ABSOLUTO de mouse.y. Centro = scr_y/2 (horizonte real);
        // factor 120000/scr_y para que toda la altura cubra +-60000 (=600 @200).
        m9.angle = (scr_y/2 - mouse.y) * 120000 / scr_y;
        if (m9.angle >  60000) m9.angle =  60000; end
        if (m9.angle < -60000) m9.angle = -60000; end

        if (mouse.x <= 0 or mouse.x >= scr_x-1) mouse.x = scr_x/2; end
        mouse_x_prev = mouse.x;

        FRAME;

        // Tras el FRAME la DLL ya pudo SUBIR z (escalon/rampa/apoyo en el suelo).
        // Si z quedo por encima de lo que dejo la gravedad y veniamos cayendo,
        // hemos tocado suelo: marcamos grounded y anulamos la velocidad de caida.
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

//------------------------------------------------------------------------------
// NPC3D: objeto 3D texturado en el mundo. Usa DRAW_OBJ9 cada frame para que la
// DLL lo renderice como malla 3D (con z-buffer respecto al escenario).
//   handle : devuelto por LOAD_OBJ9 (0 = modelo no cargado -> no dibuja nada)
//   wx, wy : posicion inicial en el plano del suelo (uds DIV2)
//   wz     : altura inicial (uds DIV2; 0 = al nivel del suelo)
//
// El proceso mantiene sus coordenadas (x,y,z,angle) como cualquier proceso DIV2:
// puedes moverlo con advance(), cambiar angle, etc. en subclases.
// DRAW_OBJ9(handle, x, y, z, angle) se llama antes de cada FRAME y dibuja el
// modelo estatico (sin animacion: el gato se queda quieto).
//------------------------------------------------------------------------------
PROCESS NPC3D(handle, wx, wy, wz)
BEGIN
    x = wx; y = wy; z = wz;
    angle = pi;    
    LOOP
        if (handle > 0)
            DRAW_OBJ9(handle, x, y, z, angle);
        end
        FRAME;
    END
END
