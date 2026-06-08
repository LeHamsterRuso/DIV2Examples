//------------------------------------------------------------------------------
// TITLE:       MODE9.CPP
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        06/06/2026
// DESCRIPTION: "Modo 9" para DIV Games Studio 2 - escenario 3D navegable (OBJ)
//
// Igual que el modo 8 (mapas .WLD por sectores) pero el ESCENARIO es una malla
// 3D arbitraria cargada desde un fichero .OBJ (paredes, suelos y techos con
// cualquier inclinacion). La camara es un PROCESO de DIV2 (como en el modo 8):
// se mueve en el plano del suelo con advance()/xadvance(), gira con su angle y
// sube/baja con z. Sobre el escenario 3D se dibujan procesos 2D al estilo del
// modo 7 (sprites con escala segun distancia, tipo Doom / Daggerfall).
//
// El renderer reutiliza el rasterizador con textura perspecto-correcto de
// KD3DT y añade: transformacion de camara en primera persona, recorte contra
// el plano cercano (near clipping), color de ambiente, niebla por distancia
// (colormap estilo Doom) y proyeccion de sprites (billboards).
//
// FUNCIONES EXPORTADAS AL PRG (analogas a las del modo 8):
//
//   LOAD_WLD9(obj,tex,scale)  -> tris cargados (0 si fallo). Carga el escenario
//                               en UNA llamada: malla OBJ + textura .MAP + escala
//                               (uds DIV2 por unidad OBJ). tex="" o "0" = sin
//                               textura (flat-shaded). scale<=0 = no cambiar.
//                               Analogo a load_wld(): cambiar de "nivel".
//   MODE9_SETTEX(map)         -> 1/0. Cambiar la textura por separado (opcional).
//   LOAD_SKY9(map)            -> 1/0. Cielo panoramico (.MAP que envuelve 360 en
//                               horizontal). Sustituye el color de fondo plano;
//                               gira con el yaw y se desplaza con el pitch. Misma
//                               paleta que el juego. SKY9_OFF() lo desactiva.
//   SKY9_OFF()                -> 0. Vuelve al fondo plano (SET_ENV_COLOR9).
//   MODE9_LOADFPG(fpg)        -> nº graficos. Carga un FPG EN LA DLL para que
//                               ella misma dibuje los billboards (c_m9) en CADA
//                               viewport (necesario para split-screen). Sin esto
//                               los billboards usan la ruta c_screen (1 vista).
//   START_MODE9(camera,m9,reg)-> 1. Activa el render (firma como start_mode8).
//                               camera=id del proceso camara; m9=&m9 (direccion
//                               del STRUCT, ver nota); reg=region (solo 0).
//                               Integra el BIND: la DLL lee m9.camera/height/
//                               angle de &m9 cada frame.
//   STOP_MODE9()              -> 0. Desactiva el render del escenario.
//   MODE9_SCRW() / MODE9_SCRH() -> ancho / alto de la pantalla actual (px). Para
//                               adaptar raton y viewports a cualquier resolucion.
//   MODE9_SET(height, pitch)  -> 0. Altura del ojo y angulo vertical (pitch) de
//                               la camara. Equivale a m8.height y m8.angle.
//   MODE9_UNITSCALE(n)        -> 0. Unidades DIV2 por unidad OBJ (def 100).
//   MODE9_BIND(&m9.z)         -> 0. (opcional; START_MODE9 ya lo hace) Enlaza el
//                               STRUCT m9 del PRG.
//   MODE9_CULL(modo)          -> 0. 0=sin culling, 1=caras traseras (def), 2=inv.
//   MODE9_FARCLIP(dist)       -> 0. No dibujar mas alla de 'dist' uds DIV2 (0=off).
//                               Con niebla se recorta ademas a fog_far.
//   SET_ENV_COLOR9(r,g,b)     -> 0. Color de fondo/ambiente, 0..100 por canal
//                               (convencion DIV2; 100=blanco).
//   SET_FOG9(near, far)       -> 0. Niebla por distancia (uds DIV2). El COLOR es
//                               el de SET_ENV_COLOR9 (igual que set_fog del m8).
//   MODE9_FOG_OFF()           -> 0. Desactiva la niebla.
//   MODE9_OCCLUDE(on)         -> 0. 1=ocultar billboards tapados por geometria
//                               (z-buffer, def), 0=dibujarlos siempre.
//   MODE9_COLLISION(on)       -> 0. 1=advance/xadvance no atraviesan paredes
//                               (usa el campo 'radius' del proceso camara), 0=off.
//   MODE9_COLLIDE(pid)        -> 1/0. Empuja un proceso CUALQUIERA fuera de las
//                               paredes (sliding) y reescribe su x,y. Para NPCs.
//                               Devuelve 1 si lo movio. Usa su 'radius' (def 30).
//                               Con MODE9_STEP>0 tambien lo apoya en el suelo.
//   MODE9_STEP(altura)        -> 0. Escaleras y rampas: altura max (uds DIV2) que
//                               el jugador sube solo. Los muros mas bajos que eso
//                               no bloquean y se apoya en el suelo de debajo
//                               (peldaños, rampas). 0=off. La GRAVEDAD la pone el
//                               PRG (z-=...); la DLL solo SUBE z al pisar suelo.
//   MODE9_SPLIT(slot,cam,m9,x,y,w,h) -> 1. Define un viewport (split-screen):
//                               hasta 4 camaras, cada una con su m9 y su rect.
//   MODE9_DOWNSCALE(n)        -> 0. Render por debajo de la resolucion nativa
//                               (1=nativa def, 2/3/4 = +rapido, +pixelado).
//   MODE9_PERSPECTIVE(on)     -> 0. Correccion de textura: 0=rendimiento (afin a
//                               16px, def), 1=calidad (1/w exacto por pixel).
//
//   MODE9_BILLBOARD(pid,wx,wy,wz,basesize) -> 1 visible / 0 oculto
//      Coloca el proceso 'pid' como sprite 2D en la posicion de mundo (wx,wy,wz)
//      (unidades DIV2). Ajusta su x,y (pantalla), size (escala por distancia) y
//      z (prioridad de dibujo). Devuelve 0 y pone size=0 si queda tras la camara
//      O si esta tapado por la geometria (oclusion por z-buffer, ver
//      MODE9_OCCLUDE). Es la forma "modo 7" de ver procesos en el escenario 3D.
//      GRAFICOS ANGULARES (como el modo 7): si el proceso tiene 'xgraph' = &tabla
//      (tabla[0]=N graficos, tabla[1..N]=codigos repartidos en 360º) y 'angle' =
//      orientacion del objeto, la DLL elige el grafico segun el angulo desde el
//      que la camara lo ve (igual que start_mode7 + ctype=c_m7 + xgraph).
//
//   MODE9_PROJECT(wx,wy,wz,&sx,&sy,&sz) -> 1 visible / 0 oculto
//      Igual que BILLBOARD pero escribe el resultado en las variables apuntadas
//      en vez de tocar un proceso (para posicionar sprites manualmente).
//
// SISTEMA DE COORDENADAS DEL MUNDO (uds DIV2, se dividen por UNITSCALE -> OBJ):
//   X = proceso.x  (plano del suelo, este/oeste)
//   Z = proceso.y  (plano del suelo, norte/sur)
//   Y (altura)= proceso.z + m9.height   (eje vertical, Y-up como en Blender/OBJ)
//   yaw  = proceso.angle (milesimas de grado: pi = 180000)
//   pitch= m9.angle      (milesimas de grado; 0 = horizonte)
//
// NOTA SOBRE m9 / c_m9:
//   Una DLL no puede crear STRUCTs ni c_types nuevos del lenguaje DIV2 (los
//   genera el compilador). El struct m9 (z,camera,height,angle) y la constante
//   c_m9 se declaran en el PRG (ver MODE9.PRG) y se comunican a esta DLL con
//   START_MODE9 + MODE9_SET. Los procesos-sprite usan ctype=c_screen y se
//   posicionan con MODE9_BILLBOARD; no necesitan un c_type real del motor.
//------------------------------------------------------------------------------

#define GLOBALS
#include "div.h"
#include <math.h>
#include <string.h>

// ---- Limites de la malla (escenarios mas grandes que un modelo suelto) ------
#define MAX_VERTS   4096
#define MAX_UVS     4096
#define MAX_TRIS    8192
#define MAX_WALLS   4096      // segmentos 2D (XZ) para colision con paredes
#define MAX_FLOORS  4096      // triangulos "suelo" (no verticales) para escalones/rampas
#define MAX_VIEWS   4         // viewports simultaneos (split-screen)

// ---- Colision -----------------------------------------------------------
#define WALL_NY     0.5f      // |normal.y|<WALL_NY -> triangulo "pared" (vertical)
#define PLAYER_BODY 1.8f      // alto del cuerpo del jugador (uds OBJ) hacia abajo
#define COLLIDE_DEF 30        // radio de colision por defecto (uds DIV2) si radius<=0

// ---- Paleta de shading flat (tris sin UV) -----------------------------------
#define PAL_BASE    224       // 224..239: rampa de sombreado flat
#define PAL_SHADES   16
#define PAL_ENV     223       // 1 entrada reservada para el color de fondo
#define AMBIENT     0.25f

// ---- Niebla -----------------------------------------------------------------
#define FOG_LEVELS  16        // niveles del colormap de niebla

// ---- Proyeccion -------------------------------------------------------------
#define NEAR_PLANE  0.06f     // plano cercano (uds OBJ)
#define FOCAL_K     0.70f     // focal = ancho * FOCAL_K  (~71 grados de FOV)
#define TEX_SEG     16        // px entre divisiones de perspectiva (correccion afin)

// ---- Toggles de las optimizaciones (para aislar fallos) ----------------------
// 0 = desactivado (comportamiento clasico/seguro). Si algo casca, poner a 0.
#define M9_FAST_FTOL 1        // Tier 1: float->int por "magic number" (version volatile)
#define M9_USE_MIP   1        // Tier 2: mipmap de textura
#define M9_USE_GRID  1        // Tier 3: rejilla espacial de culling

// ---- Offsets de campos dentro de un proceso (en ints, base = id) ------------
// (derivados de _reserved[20] + campos de _process en div.h)
#define P_ID      0
#define P_STATUS  4       // 0=muerto, 2=vivo (ver LTOBJ.DEF reserved.status)
#define P_CTYPE   25
#define P_X       26
#define P_Y       27
#define P_Z       28
#define P_GRAPH   29
#define P_SIZE    31
#define P_ANGLE   32
#define P_XGRAPH  35      // puntero a tabla de graficos angulares (como modo 7)
#define P_HEIGHT  36
#define P_RADIUS  39      // radio de colision del proceso (uds DIV2)

// ctype "logico" del modo 9: un proceso con ctype=c_m9 se dibuja como billboard
// automaticamente (como c_m7 en el modo 7). Valor por defecto 200 (no colisiona
// con c_screen=0/c_scroll=1/c_m7=2); ajustable con MODE9_CTYPE. La constante
// c_m9 del PRG debe valer lo mismo.
#define C_SCREEN  0       // ctype de pantalla de DIV2 (LTOBJ.DEF)
#define MAX_SPR   256     // maximo de billboards c_m9 simultaneos

// ---- Tipos ------------------------------------------------------------------
typedef struct { float x, y, z;               } V3;
typedef struct { float u, v;                  } UV2;
typedef struct { int a,b,c; int ua,ub,uc; unsigned char flat; unsigned char mat; } TriTex;
typedef struct { float depth; int idx; int ci;} TSort;
// Vertice durante el recorte: posicion en espacio camara + UV
typedef struct { float cx,cy,cz,u,v;          } CVert;

// ---- Datos de la malla ------------------------------------------------------
static V3     mesh_v[MAX_VERTS];
static UV2    mesh_uv[MAX_UVS];
static TriTex mesh_t[MAX_TRIS];
static int n_verts=0, n_uvs=0, n_tris=0;
static int mesh_ok=0, has_uvs=0;

// ---- Paredes para colision (footprint 2D en XZ + extension vertical) ---------
typedef struct { float x0,z0,x1,z1, ymin,ymax; } M9Wall;
static M9Wall mesh_walls[MAX_WALLS];
static int    n_walls=0;

// ---- Suelos para escalones y rampas (floor-following) -----------------------
// Indices de los triangulos casi-horizontales (suelo/techo). floor_height() busca
// el suelo MAS ALTO bajo el jugador (<= pies + m9_step) y le sube los pies encima:
// asi sube rampas inclinadas y peldaños, sin hundirse en suelos a distinto nivel.
static int    mesh_floor_idx[MAX_FLOORS];
static int    n_floors=0;
// Altura maxima de escalon/rampa autoescalable (uds OBJ). 0 = desactivado
// (comportamiento clasico: la DLL no toca z, el PRG controla la altura).
static float  m9_step=0.0f;

// ---- Modelos 3D de objeto (LOAD_OBJ9 / DRAW_OBJ9) --------------------------
// Permiten colocar meshes 3D texturados en el mundo como NPCs/props. Cada
// modelo es un OBJ cargado con su propia escala y textura. Las instancias se
// encolan con DRAW_OBJ9 (llamar cada frame) y se renderizan en render_view
// con el mismo z-buffer que la malla del mundo (oclusion correcta).
#define MAX_OBJ9_MODELS  8    // modelos distintos
#define MAX_OBJ9_INST   32    // instancias por frame
#define MAX_OBJ9V      512    // vertices por modelo
#define MAX_OBJ9UV    1024
#define MAX_OBJ9T     1024    // triangulos por modelo
typedef struct {
    V3    *verts;             // div_malloc; = vframes (frame 0). Owner de la memoria.
    V3    *vframes;           // nv*nframes verts contiguos; frame f en vframes+f*nv
    int    nframes;           // fotogramas de animacion (1 = modelo estatico)
    UV2   *uvs;
    TriTex *tris;
    int    nv, nuv, nt;
    char  *tex; int tw, th;  // textura MAP (NULL = flat)
    char  *mip; int mw, mh;  // mipmap 1/2 (LOD/cache)
} Obj9Model;
typedef struct {
    int   midx;              // indice en obj9_models[]
    float ix, iy, iz;        // posicion en espacio mundo (uds OBJ)
    float ysin, ycos;        // rotacion Y precomputada del angulo DIV2
    int   fa, fb;            // fotogramas a interpolar (fa->fb)
    float fblend;            // mezcla 0..1 entre fa y fb (0 = solo fa)
} Obj9Inst;
static Obj9Model obj9_models[MAX_OBJ9_MODELS];
static int       n_obj9_models = 0;
static Obj9Inst  obj9_queue[MAX_OBJ9_INST];
static int       n_obj9_queue  = 0;
// Scratch de transformacion para el modelo en curso (reutilizado por instancia)
static float     obj9cv[MAX_OBJ9V][3];  // espacio camara
static float     obj9px[MAX_OBJ9V];     // pantalla subpixel X
static float     obj9py[MAX_OBJ9V];     // pantalla subpixel Y
static char      obj9bh[MAX_OBJ9V];     // 1 = detras del near plane

// ---- Buffers de render ------------------------------------------------------
static float camv[MAX_VERTS][3];   // vertices en espacio camara
static int   psx[MAX_VERTS], psy[MAX_VERTS];  // proyeccion en pantalla ENTERA (culling)
static float psxf[MAX_VERTS], psyf[MAX_VERTS]; // proyeccion en pantalla SUBPIXEL (rasterizado)
static char  pbehind[MAX_VERTS];   // 1 si el vertice esta tras el plano cercano
static TSort tsort[MAX_TRIS];
// Bucket sort por profundidad (orden front-to-back en O(n))
#define NBUCKETS 256
static int   order[MAX_TRIS];      // indices en tsort[] ordenados cerca->lejos
static int   bcnt[NBUCKETS+1];     // conteos/prefijos del bucket sort

// ---- Materiales (multi-textura) ---------------------------------------------
// Hasta MAX_MATS materiales distintos (por orden de aparicion de 'usemtl' en el
// OBJ). mat_data[0] es el material por defecto (el que se carga con LOAD_WLD9 o
// MODE9_SETTEX). Cada triangulo guarda su indice de material (TriTex.mat) y el
// rasterizador selecciona la textura correcta; si mat_data[mat]==NULL usa mat 0.
// MODE9_MATERIAL(idx,"MAP/x.MAP") asigna una textura a cualquier slot.
#define MAX_MATS 16
static char *mat_data[MAX_MATS];   // pixeles de la textura (NULL = sin asignar)
static int   mat_w[MAX_MATS];
static int   mat_h[MAX_MATS];
static char *mat_mip[MAX_MATS];   // mipmap de nivel 1 (NULL si no hay)
static int   matm_w[MAX_MATS];
static int   matm_h[MAX_MATS];
static int   n_mats = 1;           // nº de materiales distintos en el OBJ actual

// ---- Skybox / cielo panoramico (cilindrico 360º) ----------------------------
// En vez de rellenar el fondo con un color plano, se mapea una textura panoramica:
// la columna de textura sale del yaw de la camara (envuelve 360º) y la fila del
// pitch (mirar arriba/abajo). Es el equivalente eficiente del "sky" de Doom/Build
// (un cubemap de 6 caras seria mucho mas caro por pixel en 486).
#define SKY_MAXDIM 2048
static char *sky_data = NULL;
static int   sky_w = 0, sky_h = 0, sky_on = 0;
static int   sky_coldelta[SKY_MAXDIM];   // columna pantalla -> delta de columna de textura
static int   sky_cd_vw = 0, sky_cd_vh = 0, sky_cd_w = 0; // cache: vw/vh/sky_w para los que estan calculadas las tablas

// ---- Sprites de billboards dibujados por la DLL (multi-vista) ----------------
// La DLL no puede leer los graficos FPG que carga DIV2, asi que parsea el FPG
// ella misma (formato en div.h) y guarda los graficos por codigo. Esto permite
// dibujar los billboards en CADA viewport (split-screen) con oclusion por pixel.
#define MAX_FPGSPR 128
typedef struct { int code,w,h,cx,cy; char *pix; } FpgSpr;
static FpgSpr fspr[MAX_FPGSPR];
static int    n_fpgspr = 0;

// ---- Z-buffer (occlusion) ---------------------------------------------------
// 16 BITS (unsigned short): guarda 1/w en punto fijo (1/w * ZSCALE). Mayor =
// mas cerca. Mitad de memoria y de ancho de banda que un z-buffer de 32 bits
// (mejor uso de cache en DOSBox). Comparacion por pixel en enteros.
// ZSCALE se elige para que 1/NEAR_PLANE * ZSCALE quepa en 16 bits (<=65535):
//   1/0.06 = 16.67  ->  ZSCALE <= 65535*0.06 = 3932  ->  usamos 3900.
#define ZSCALE 3900.0f
static unsigned short *zbuf = NULL;
static int  zbuf_w = 0, zbuf_h = 0;

// ---- Rejilla espacial XZ (culling de triangulos por celdas) -----------------
// El escenario se reparte en una rejilla GRID_DIM x GRID_DIM sobre el plano XZ.
// Cada celda guarda los indices de los triangulos cuyo footprint la solapan. Al
// renderizar solo se consideran los triangulos de las celdas dentro del frustum
// horizontal + far clip, en vez de recorrer los n_tris enteros cada frame.
#define GRID_DIM   16
#define GRID_CELLS (GRID_DIM*GRID_DIM)
static int   grid_start[GRID_CELLS+1];   // prefijos: triangulos de la celda c en [start[c],start[c+1])
static int  *grid_items=NULL;            // (div_malloc) indices de triangulo agrupados por celda
static int   grid_cap=0;                  // capacidad actual de grid_items (en ints)
static int   grid_n=0;                    // 0 = sin rejilla (fallback: recorrer todo)
static float grid_minx=0,grid_minz=0;     // origen de la rejilla (uds OBJ)
static float grid_cw=1,grid_ch=1;         // tamaño de celda (uds OBJ)
static float grid_invcw=1,grid_invch=1;
static float grid_cellrad=1;              // radio (media diagonal) de una celda
static int  *tstamp=NULL;                 // (div_malloc) marca de frame por triangulo
static int   tstamp_cap=0;
static int   frame_stamp=0;

// ---- Transformacion de vertices PEREZOSA (lazy) -----------------------------
// Solo se transforma/proyecta un vertice la primera vez que un triangulo VISIBLE
// lo necesita (marcado con vstamp == frame_stamp). Asi, si la rejilla descarta
// celdas enteras, sus vertices ni se tocan. Los parametros de camara de la vista
// actual se guardan en g_* para que xform_vertex() (llamada desde consider_tri)
// los use sin pasarlos por argumento.
static int   vstamp[MAX_VERTS];           // marca de frame por vertice (transformado ya?)
static float g_Cx,g_Cy,g_Cz,g_ysin,g_ycos,g_psin,g_pcos,g_focal,g_hw,g_hh;

// ---- Tabla trigonometrica (estilo SNES Doom) ---------------------------------
// 4096 entradas de sin/cos evitan las llamadas a sinf/cosf en el bucle de
// renderizado (~40 ciclos en 486 cada una -> 4-8 ciclos con tabla).
#define TRIG_SIZE 4096
#define TRIG_MASK (TRIG_SIZE-1)
#define TRIG_K    651.8986f   // 4096/(2*pi): rad -> indice
static float sin_tab[TRIG_SIZE];
static float cos_tab[TRIG_SIZE];

// ---- Downscale / line doubler -----------------------------------------------
// 1 = resolucion nativa (def); 2 = mitad de lineas (doblar -> ~2x fill rate);
// 3 = un tercio; 4 = un cuarto. Mismo truco que el SNES Doom: calcular 1 de cada
// N scanlines y duplicarlas. Usar MODE9_DOWNSCALE(n) desde el PRG.
static int m9_downscale = 1;

// ---- Correccion de perspectiva de la textura --------------------------------
// Longitud (px) del tramo afin entre dos divisiones 1/w exactas en hspan_z.
// = TEX_SEG (16): RENDIMIENTO (la textura se interpola lineal dentro del tramo;
//   rapido, pero "ondula" un poco en superficies a angulos pronunciados).
// = 1: CALIDAD (un 1/w exacto por pixel -> perspectiva perfecta, mas lento).
// Por defecto rendimiento. Se cambia con MODE9_PERSPECTIVE(on).
static int m9_texseg = TEX_SEG;
// Segmento EFECTIVO del triangulo actual. raster_tri_z lo baja a 1 (por pixel)
// automaticamente cuando el triangulo tiene perspectiva fuerte (gran ratio de
// profundidad entre sus vertices: geometria que cruza el plano cercano "entrando
// por la camara", o suelos/techos muy inclinados), que es donde la correccion
// afin a 16px deforma la textura. El resto sigue usando m9_texseg (rapido).
static int cur_seg = TEX_SEG;

// ---- Rectangulo de recorte del viewport actual (para split-screen) ----------
// El z-buffer y el buffer de video usan el ancho COMPLETO como stride; el
// dibujo se limita a [clip_x0,clip_x1) x [clip_y0,clip_y1).
static int clip_x0=0, clip_x1=0, clip_y0=0, clip_y1=0;

// ---- Estado de camara / modo ------------------------------------------------
static int   m9_active   = 0;
static int   cull_mode   = 1;      // 0=sin cull, 1=cull caras traseras, 2=cull frontales
static int   m9_camera   = 0;      // id del proceso camara
static int   m9_height   = 0;      // altura del ojo (uds DIV2)
static int   m9_pitch    = 0;      // angulo vertical (milesimas de grado)
static float m9_unitscale= 100.0f; // uds DIV2 por unidad OBJ
static int   m9_bind     = 0;      // offset en mem[] del STRUCT m9 (0=no enlazado)
static int   m9_region   = 0;      // region de pantalla (solo 0=pantalla completa)
static int   m9_occlude  = 1;      // 1=ocultar billboards tras la geometria (z-buffer)
static int   m9_ctype    = 200;    // valor de c_m9 (ctype de billboard automatico)
static int   m9_collision= 0;      // 1=advance/xadvance no atraviesan paredes
static float far_clip    = 0.0f;   // distancia max de dibujo en uds OBJ (0=sin limite)

// ---- Viewports (split-screen): cada vista tiene su camara, su m9 y su rect ---
// vw==0 (o vh==0) significa "pantalla completa" (se resuelve al renderizar).
// lastx/lastz: ultima posicion valida de la camara (para colision con barrido).
typedef struct { int active,cam,bind,vx,vy,vw,vh,haslast; float lastx,lastz; } M9View;
static M9View views[MAX_VIEWS];

// Estado para convertir los procesos c_m9 a c_screen y restaurarlos despues de
// que DIV2 los pinte (asi conservan sus coordenadas de MUNDO en x,y,z).
typedef struct { int base,wx,wy,wz,sz,gr,ct; } M9Spr;
static M9Spr m9spr[MAX_SPR];
static int   n_m9spr = 0;

// ---- Color de ambiente / fondo ----------------------------------------------
static int env_r=0, env_g=0, env_b=0;

// ---- Niebla -----------------------------------------------------------------
static char *fog_map = NULL;       // FOG_LEVELS * 256 bytes (remapeo de color)
static int   fog_on  = 0;
static float fog_near=0.0f, fog_far=1.0f;   // en uds OBJ
// LUT de nivel de niebla indexada por profundidad cuantizada (zfix>>10, 0..63):
// evita la division + comparaciones de fog_level() en el bucle de pixeles.
static unsigned char fog_lvl_lut[64];

// ---- Paleta original (para restaurar en divend) -----------------------------
static char orig_pal[(PAL_SHADES+1) * 3];

// ---- Mensaje de estado ------------------------------------------------------
static char m9_msg[40];

// ---- Punteros al runtime DIV2 -----------------------------------------------
static void *(*g_import)(char *name) = 0;
static void  (*g_export)(char *name, void *p) = 0;

// ============================================================================
// Utilidades de string (sin libc)
// ============================================================================
static void s_cpy(char *d,const char *s){while(*s)*d++=*s++;*d=0;}
static void s_cat(char *d,const char *s){while(*d)d++;while(*s)*d++=*s++;*d=0;}
static void s_itos(int n,char *b){
    char t[12];int i=0,j=0;
    if(!n){b[0]='0';b[1]=0;return;}
    if(n<0){*b++='-';n=-n;}
    while(n){t[i++]=(char)('0'+n%10);n/=10;}
    while(i>0)b[j++]=t[--i];b[j]=0;
}

static void div2c(int off,char *buf,int max){
    int i;char *src=(char*)&mem[off];
    for(i=0;i<max-1&&src[i];i++)buf[i]=src[i];buf[i]=0;
}

static float sc_atof(const char *s){
    float v=0.0f,frac=1.0f;int neg=0;
    while(*s==' '||*s=='\t')s++;
    if(*s=='-'){neg=1;s++;}else if(*s=='+')s++;
    while(*s>='0'&&*s<='9')v=v*10.0f+(float)(*s++-'0');
    if(*s=='.'){s++;while(*s>='0'&&*s<='9'){frac*=0.1f;v+=(float)(*s++-'0')*frac;}}
    return neg?-v:v;
}

static int sc_atoi(const char *s){
    int v=0,neg=0;
    while(*s==' '||*s=='\t')s++;
    if(*s=='-'){neg=1;s++;}
    while(*s>='0'&&*s<='9')v=v*10+(*s++-'0');
    return neg?-v:v;
}

static int read_line(FILE *f,char *buf,int max){
    int c,n=0;
    while(n<max-1){c=fgetc(f);if(c==EOF){buf[n]=0;return n>0;}if(c=='\n')break;if(c!='\r')buf[n++]=(char)c;}
    buf[n]=0;return 1;
}

static char *next_tok(char *s){
    while(*s&&*s!=' '&&*s!='\t'&&*s!='\n')s++;
    while(*s==' '||*s=='\t')s++;
    return s;
}

static char *parse_face_vert(char *s,int *vi,int *uvi){
    *vi=sc_atoi(s)-1; *uvi=-1;
    while(*s&&*s!='/'&&*s!=' '&&*s!='\t'&&*s!='\n')s++;
    if(*s=='/'){
        s++;
        if(*s&&*s!='/'&&*s!=' '&&*s!='\t'&&*s!='\n')
            *uvi=sc_atoi(s)-1;
        while(*s&&*s!='/'&&*s!=' '&&*s!='\t'&&*s!='\n')s++;
        if(*s=='/'){ s++; while(*s&&*s!=' '&&*s!='\t'&&*s!='\n')s++; }
    }
    return s;
}

// ============================================================================
// Raiz cuadrada inversa rapida (Quake's fast inverse sqrt).
// Precision ~0.2% tras 1 iteracion de Newton: suficiente para colision/normal.
// Evita las llamadas a sqrt() en el bucle de colision (O(n_walls)/frame).
// ============================================================================
static float fast_rsqrt(float x){
    union { float f; unsigned long i; } u;
    float xh=0.5f*x;
    u.f=x; u.i=0x5f3759dfUL-(u.i>>1);
    u.f=u.f*(1.5f-xh*u.f*u.f);
    return u.f;
}

// ============================================================================
// Reciproco rapido 1/x (bit-hack + 1 paso de Newton, ~0.05% error). Evita la
// division de la FPU (~73 ciclos en 486) en el rasterizador (1/w por segmento,
// pendientes 1/dy por triangulo). Mismo orden de error que la aproximacion afin.
// ============================================================================
static float fast_recip(float x){
    union { float f; unsigned long i; } u;
    float xx=x;
    u.f=x; u.i=0x7EF127EAUL-u.i;       // aproximacion inicial de 1/x
    u.f=u.f*(2.0f-xx*u.f);            // 1 paso de Newton-Raphson
    return u.f;
}

// ============================================================================
// float -> int rapido (truco del "magic number"). Watcom compila cada (int)float
// como una llamada que guarda/cambia/restaura el control word de la FPU (~50-60
// ciclos); esto lo elimina (redondeo al mas cercano, x86 little-endian, |x|<2^31).
// ============================================================================
// Techo (ceil) entero de un float, sin depender de ceilf (Watcom 10.6). Para el
// rasterizado subpixel: primer centro de pixel (x+0.5) dentro de un borde.
static int iceil(float a){ int i=(int)a; return (a>(float)i)?i+1:i; }

static int fast_ftol(float x){
#if M9_FAST_FTOL
    // 'volatile' OBLIGA a guardar el double en memoria de 64 bits (redondeando
    // desde los 80 bits del registro x87) ANTES de leer el dword bajo. Sin esto
    // Watcom 10.6 dejaba el valor en el registro extendido y la lectura de la
    // union daba basura -> coordenadas locas -> cuelgue. (x86 little-endian.)
    volatile union { double d; int l[2]; } u;
    u.d=(double)x+6755399441055744.0;   // 2^52 + 2^51
    return u.l[0];                       // dword bajo = entero redondeado
#else
    return (int)x;                       // conversion clasica (segura)
#endif
}

// ============================================================================
// Localiza un proceso por su id en mem[]. Devuelve el offset base o -1.
// ============================================================================
static int find_process(int pid){
    int first,last,step,b;
    step = *_process_size;
    if(step<=0) return -1;
    first= *_id_init_offset;
    last = *_id_end_offset;
    for(b=first; b<=last; b+=step){
        if(mem[b+P_ID]==pid) return b;
    }
    return -1;
}

// ============================================================================
// Color de paleta mas cercano (paleta DIV2, valores 6-bit en char*)
// ============================================================================
static int nearest_pal(int r,int g,int b){
    int i,best=0; long bestd=0x7fffffffL;
    for(i=0;i<256;i++){
        int pr=(unsigned char)palette[i*3+0];
        int pg=(unsigned char)palette[i*3+1];
        int pb=(unsigned char)palette[i*3+2];
        long dr=pr-r,dg=pg-g,db=pb-b;
        long d=dr*dr+dg*dg+db*db;
        if(d<bestd){bestd=d;best=i;if(!d)break;}
    }
    return best;
}

// ============================================================================
// Construye el colormap de niebla: para cada nivel t y cada color de origen,
// mezcla hacia (fr,fg,fb) y guarda el indice de paleta mas cercano.
// ============================================================================
static void build_fog_map(int fr,int fg,int fb){
    int lvl,c;
    if(!fog_map){
        fog_map=(char*)div_malloc((size_t)(FOG_LEVELS*256));
        if(!fog_map){fog_on=0;return;}
    }
    for(lvl=0;lvl<FOG_LEVELS;lvl++){
        float t=(float)lvl/(float)(FOG_LEVELS-1);
        for(c=0;c<256;c++){
            int cr=(unsigned char)palette[c*3+0];
            int cg=(unsigned char)palette[c*3+1];
            int cb=(unsigned char)palette[c*3+2];
            int nr=(int)((float)cr*(1.0f-t)+(float)fr*t+0.5f);
            int ng=(int)((float)cg*(1.0f-t)+(float)fg*t+0.5f);
            int nb=(int)((float)cb*(1.0f-t)+(float)fb*t+0.5f);
            fog_map[lvl*256+c]=(char)nearest_pal(nr,ng,nb);
        }
    }
}

// Indice de nivel de niebla para una profundidad dada (uds OBJ)
static int fog_level(float depth){
    float t;
    if(!fog_on) return 0;
    if(fog_far<=fog_near) return 0;
    t=(depth-fog_near)/(fog_far-fog_near);
    if(t<=0.0f) return 0;
    if(t>=1.0f) return FOG_LEVELS-1;
    return (int)(t*(float)(FOG_LEVELS-1)+0.5f);
}

// Precalcula la LUT de niebla: para cada cubeta de profundidad (zfix>>10) guarda
// el nivel de niebla correspondiente. Llamar cuando cambien near/far (set_fog9).
static void build_fog_lut(void){
    int i;
    for(i=0;i<64;i++){
        int zfix=(i<<10)+512;                  // zfix representativo de la cubeta
        float w=(zfix>0)?(ZSCALE/(float)zfix):1e6f;   // w = 1/(zfix/ZSCALE)
        fog_lvl_lut[i]=(unsigned char)fog_level(w);
    }
}

// ============================================================================
// Rasterizador unificado con Z-BUFFER (occlusion) + textura perspecto-correcta
// + niebla por pixel. Pintado FRONT-TO-BACK: el test de profundidad (barato)
// rechaza los pixeles ya tapados ANTES de muestrear la textura (caro).
//   zb almacena 1/w (mayor = mas cerca). tex=NULL -> color plano 'flatcol'.
// ============================================================================
static void hspan_z(char *vid,unsigned short *zb,int W,int H,int y,
                    float xlf,float uwl,float vwl,float iwl,
                    float xrf,float uwr,float vwr,float iwr,
                    char *tex,int tw,int th,int pow2,unsigned char flatcol){
    char *p;unsigned short *zp;float tf;
    float duw,dvw,diw,cuw,cvw,ciw,dx,subx;
    int xStart,xEnd;

    if(y<clip_y0||y>=clip_y1)return;
    // Line doubler: solo renderizar 1 de cada m9_downscale lineas (el resto se
    // duplican tras el render, como en el SNES Doom). Lineas relativas al borde
    // superior del viewport para que el patron empiece siempre en la misma fila.
    if(m9_downscale>1 && ((y-clip_y0)%m9_downscale)!=0)return;
    if(xlf>xrf){
        tf=xlf;xlf=xrf;xrf=tf;
        tf=uwl;uwl=uwr;uwr=tf; tf=vwl;vwl=vwr;vwr=tf; tf=iwl;iwl=iwr;iwr=tf;
    }
    dx=xrf-xlf; if(dx<1e-4f)return;
    {float invdx=fast_recip(dx);
     duw=(uwr-uwl)*invdx; dvw=(vwr-vwl)*invdx; diw=(iwr-iwl)*invdx;}

    // SUBPIXEL: el primer pixel es el de centro (x+0.5) >= xlf; se PRESTEPEAN las
    // coords de textura a ese centro. Asi los vertices NO se "enganchan" a enteros
    // (se acaba el temblor/serpenteo de texturas de la geometria que se mueve).
    xStart=iceil(xlf-0.5f); xEnd=iceil(xrf-0.5f);
    if(xStart<clip_x0)xStart=clip_x0;
    if(xEnd>clip_x1)xEnd=clip_x1;
    if(xStart>=xEnd)return;
    subx=((float)xStart+0.5f)-xlf;
    cuw=uwl+duw*subx; cvw=vwl+dvw*subx; ciw=iwl+diw*subx;

    p=vid+y*W+xStart; zp=zb+y*W+xStart;
    {
        // Profundidad en punto fijo: paso constante en toda la scanline.
        int zstep=fast_ftol(diw*ZSCALE);
        float tuf=(float)tw, tvf=(float)th;
        int twm=tw-1, thm=th-1;       // mascaras (validas solo si pow2)
        int total=xEnd-xStart, xi=0;
        while(xi<total){
            int seg=total-xi; if(seg>cur_seg)seg=cur_seg;
            {
                // Una sola division 1/w en cada extremo del segmento; las coords
                // de textura se interpolan en PUNTO FIJO 16.16 (enteros) dentro.
                float w0=(ciw>1e-6f)?fast_recip(ciw):1e6f;
                float cuw_e=cuw+duw*(float)seg, cvw_e=cvw+dvw*(float)seg, ciw_e=ciw+diw*(float)seg;
                float w1=(ciw_e>1e-6f)?fast_recip(ciw_e):1e6f;
                float invseg=fast_recip((float)seg);
                float tu0=cuw*w0*tuf, tv0=cvw*w0*tvf;     // texel en el extremo izq
                float tu1=cuw_e*w1*tuf, tv1=cvw_e*w1*tvf; // texel en el extremo der
                int tu=fast_ftol(tu0*65536.0f), tv=fast_ftol(tv0*65536.0f);
                int stu=fast_ftol((tu1-tu0)*invseg*65536.0f);
                int stv=fast_ftol((tv1-tv0)*invseg*65536.0f);
                int zfix=fast_ftol(ciw*ZSCALE);            // resync por segmento (sin deriva)
                int lv=fog_on?fog_lvl_lut[(zfix>>10)&63]:0;
                char *fm=(lv>0)?&fog_map[lv*256]:0;
                int k;
                // Las ramas tex/fog/flat se sacan FUERA del bucle de pixeles:
                // dentro solo queda el z-test + muestreo (sin condicionales).
                #define M9_SPAN(SAMPLE) \
                    for(k=0;k<seg;k++){ \
                        if(zfix>*zp){ *p=(SAMPLE); *zp=(unsigned short)zfix; } \
                        p++; zp++; tu+=stu; tv+=stv; zfix+=zstep; }
                if(tex){
                    if(pow2){
                        // Sin clamp: AND con mascara (textura potencia de 2).
                        if(fm){ M9_SPAN(fm[(unsigned char)tex[((tv>>16)&thm)*tw+((tu>>16)&twm)]]) }
                        else  { M9_SPAN(tex[((tv>>16)&thm)*tw+((tu>>16)&twm)]) }
                    } else {
                        // Fallback con clamp (textura no potencia de 2).
                        for(k=0;k<seg;k++){
                            if(zfix>*zp){
                                int tx=tu>>16, ty=tv>>16;
                                char px;
                                if(tx<0)tx=0;else if(tx>=tw)tx=tw-1;
                                if(ty<0)ty=0;else if(ty>=th)ty=th-1;
                                px=tex[ty*tw+tx];
                                if(fm)px=fm[(unsigned char)px];
                                *p=px; *zp=(unsigned short)zfix;
                            }
                            p++; zp++; tu+=stu; tv+=stv; zfix+=zstep;
                        }
                    }
                } else {
                    // Flat: el color (con o sin niebla) es constante en el segmento.
                    unsigned char pxf=fm?(unsigned char)fm[flatcol]:flatcol;
                    M9_SPAN((char)pxf)
                }
                #undef M9_SPAN
                cuw=cuw_e; cvw=cvw_e; ciw=ciw_e;
            }
            xi+=seg;
        }
    }
}

// Evalua un borde (arista) en el CENTRO de scanline cy: posicion x + atributos.
static void edge_at(float cy,float ya,float xa,float uwa,float vwa,float iwa,
                    float gx,float gu,float gv,float gi,
                    float *ox,float *ou,float *ov,float *oi){
    float s=cy-ya; *ox=xa+gx*s; *ou=uwa+gu*s; *ov=vwa+gv*s; *oi=iwa+gi*s;
}

// Rasteriza un triangulo con Z-buffer, coordenadas SUBPIXEL (vertices en float).
// El muestreo es en los centros de pixel (x+0.5, y+0.5) con prestep, de modo que
// los vertices NO se cuantizan a enteros -> sin temblor/serpenteo de texturas al
// mover la geometria (el artefacto "PS1"). tex=NULL -> color plano 'flatcol'.
static void raster_tri_z(char *vid,unsigned short *zb,int W,int H,
    float x0,float y0,float u0,float v0,float w0,
    float x1,float y1,float u1,float v1,float w1,
    float x2,float y2,float u2,float v2,float w2,
    char *tex,int tw,int th,unsigned char flatcol){
    int pow2,y,yA,yB;float tf;
    float iw0,iw1,iw2,uw0,vw0,uw1,vw1,uw2,vw2;

    // w no puede bajar de NEAR_PLANE: garantiza 1/w*ZSCALE <= 65535 (z 16 bits).
    if(w0<NEAR_PLANE)w0=NEAR_PLANE; if(w1<NEAR_PLANE)w1=NEAR_PLANE; if(w2<NEAR_PLANE)w2=NEAR_PLANE;
    cur_seg = m9_texseg;
    pow2=(tex && (tw&(tw-1))==0 && (th&(th-1))==0);
    iw0=1.0f/w0; iw1=1.0f/w1; iw2=1.0f/w2;
    uw0=u0*iw0; vw0=v0*iw0;
    uw1=u1*iw1; vw1=v1*iw1;
    uw2=u2*iw2; vw2=v2*iw2;

    // Ordenar los 3 vertices por Y (float), arrastrando x y atributos u/w,v/w,1/w.
    #define SW(a,b) tf=(a);(a)=(b);(b)=tf;
    #define S2(ya,xa,ua,va,ia, yb,xb,ub,vb,ib) \
        if(ya>yb){SW(ya,yb) SW(xa,xb) SW(ua,ub) SW(va,vb) SW(ia,ib)}
    S2(y0,x0,uw0,vw0,iw0, y1,x1,uw1,vw1,iw1)
    S2(y1,x1,uw1,vw1,iw1, y2,x2,uw2,vw2,iw2)
    S2(y0,x0,uw0,vw0,iw0, y1,x1,uw1,vw1,iw1)
    #undef S2
    #undef SW

    if(y2-y0<1e-4f)return;

    {
    // Pendientes por unidad de Y (no por scanline): el borde se evalua en el
    // CENTRO de cada scanline (cy=y+0.5), con division exacta, sin acumular.
    float gxl=(x2-x0)/(y2-y0), gul=(uw2-uw0)/(y2-y0);   // arista larga 0->2
    float gvl=(vw2-vw0)/(y2-y0), gil=(iw2-iw0)/(y2-y0);

    if(y1-y0>1e-4f){   // mitad superior: arista corta 0->1
        float gxs=(x1-x0)/(y1-y0), gus=(uw1-uw0)/(y1-y0);
        float gvs=(vw1-vw0)/(y1-y0), gis=(iw1-iw0)/(y1-y0);
        yA=iceil(y0-0.5f); yB=iceil(y1-0.5f);
        if(yA<clip_y0)yA=clip_y0; if(yB>clip_y1)yB=clip_y1;
        for(y=yA;y<yB;y++){
            float cy=(float)y+0.5f, xl,ul,vl,il, xs,us,vs,is;
            edge_at(cy,y0,x0,uw0,vw0,iw0,gxl,gul,gvl,gil,&xl,&ul,&vl,&il);
            edge_at(cy,y0,x0,uw0,vw0,iw0,gxs,gus,gvs,gis,&xs,&us,&vs,&is);
            hspan_z(vid,zb,W,H,y,xl,ul,vl,il,xs,us,vs,is,tex,tw,th,pow2,flatcol);
        }
    }
    if(y2-y1>1e-4f){   // mitad inferior: arista corta 1->2 (la larga continua)
        float gxs=(x2-x1)/(y2-y1), gus=(uw2-uw1)/(y2-y1);
        float gvs=(vw2-vw1)/(y2-y1), gis=(iw2-iw1)/(y2-y1);
        yA=iceil(y1-0.5f); yB=iceil(y2-0.5f);
        if(yA<clip_y0)yA=clip_y0; if(yB>clip_y1)yB=clip_y1;
        for(y=yA;y<yB;y++){
            float cy=(float)y+0.5f, xl,ul,vl,il, xs,us,vs,is;
            edge_at(cy,y0,x0,uw0,vw0,iw0,gxl,gul,gvl,gil,&xl,&ul,&vl,&il);
            edge_at(cy,y1,x1,uw1,vw1,iw1,gxs,gus,gvs,gis,&xs,&us,&vs,&is);
            hspan_z(vid,zb,W,H,y,xl,ul,vl,il,xs,us,vs,is,tex,tw,th,pow2,flatcol);
        }
    }
    }
}

static unsigned char flat_color(int a,int b,int c);   // (definida mas abajo)
static int load_fpg_file(char *fname);                // (definida mas abajo)

// ============================================================================
// Rejilla espacial: rango de celdas (XZ) que solapa el footprint de un triangulo.
// ============================================================================
static void tri_cellrange(int t,int *x0,int *x1,int *z0,int *z1){
    int a=mesh_t[t].a,b=mesh_t[t].b,c=mesh_t[t].c;
    float mnx=mesh_v[a].x,mxx=mnx,mnz=mesh_v[a].z,mxz=mnz,v;
    v=mesh_v[b].x; if(v<mnx)mnx=v; if(v>mxx)mxx=v;
    v=mesh_v[c].x; if(v<mnx)mnx=v; if(v>mxx)mxx=v;
    v=mesh_v[b].z; if(v<mnz)mnz=v; if(v>mxz)mxz=v;
    v=mesh_v[c].z; if(v<mnz)mnz=v; if(v>mxz)mxz=v;
    *x0=(int)((mnx-grid_minx)*grid_invcw); *x1=(int)((mxx-grid_minx)*grid_invcw);
    *z0=(int)((mnz-grid_minz)*grid_invch); *z1=(int)((mxz-grid_minz)*grid_invch);
    if(*x0<0)*x0=0; if(*x1>=GRID_DIM)*x1=GRID_DIM-1; if(*x1<*x0)*x1=*x0;
    if(*z0<0)*z0=0; if(*z1>=GRID_DIM)*z1=GRID_DIM-1; if(*z1<*z0)*z1=*z0;
}

// Construye la rejilla espacial de la malla actual. Devuelve 1 si OK, 0 si no se
// pudo (entonces grid_n=0 y el render recorre todos los triangulos: fallback).
static int build_grid(void){
    int i,gx,gz,t,total=0;
    float minx,minz,maxx,maxz;
    static int cur[GRID_CELLS];
    grid_n=0;
#if !M9_USE_GRID
    return 0;                            // rejilla desactivada (toggle): recorre todo
#endif
    if(n_tris<=0||n_verts<=0) return 0;
    minx=minz=1e30f; maxx=maxz=-1e30f;
    for(i=0;i<n_verts;i++){
        float x=mesh_v[i].x, z=mesh_v[i].z;
        if(x<minx)minx=x; if(x>maxx)maxx=x;
        if(z<minz)minz=z; if(z>maxz)maxz=z;
    }
    if(maxx<=minx)maxx=minx+1.0f; if(maxz<=minz)maxz=minz+1.0f;
    grid_minx=minx; grid_minz=minz;
    grid_cw=(maxx-minx)/(float)GRID_DIM; grid_ch=(maxz-minz)/(float)GRID_DIM;
    // 0.999999 para que el vertice del borde maximo caiga en la celda GRID_DIM-1.
    grid_invcw=(float)GRID_DIM/(maxx-minx)*0.999999f;
    grid_invch=(float)GRID_DIM/(maxz-minz)*0.999999f;
    grid_cellrad=0.5f*(float)sqrt((double)(grid_cw*grid_cw+grid_ch*grid_ch));
    // 1a pasada: contar triangulos por celda (en start[c+1]).
    for(i=0;i<=GRID_CELLS;i++) grid_start[i]=0;
    for(t=0;t<n_tris;t++){
        int x0,x1,z0,z1; tri_cellrange(t,&x0,&x1,&z0,&z1);
        for(gz=z0;gz<=z1;gz++) for(gx=x0;gx<=x1;gx++){ grid_start[gz*GRID_DIM+gx+1]++; total++; }
    }
    // Reservar (div_malloc) grid_items al tamaño exacto y tstamp a n_tris. Si
    // falla la reserva -> grid_n=0 y el render recorre todos los triangulos.
    if(total>grid_cap){
        if(grid_items)div_free(grid_items);
        grid_items=(int*)div_malloc((size_t)total*sizeof(int));
        if(!grid_items){grid_cap=0;return 0;}
        grid_cap=total;
    }
    if(n_tris>tstamp_cap){
        if(tstamp)div_free(tstamp);
        tstamp=(int*)div_malloc((size_t)n_tris*sizeof(int));
        if(!tstamp){tstamp_cap=0;return 0;}
        tstamp_cap=n_tris;
    }
    {int k; for(k=0;k<n_tris;k++) tstamp[k]=0;}   // sin sellos rancios
    for(i=1;i<=GRID_CELLS;i++) grid_start[i]+=grid_start[i-1];
    // 2a pasada: volcar indices de triangulo en su sitio.
    for(i=0;i<GRID_CELLS;i++) cur[i]=grid_start[i];
    for(t=0;t<n_tris;t++){
        int x0,x1,z0,z1; tri_cellrange(t,&x0,&x1,&z0,&z1);
        for(gz=z0;gz<=z1;gz++) for(gx=x0;gx<=x1;gx++){ int c=gz*GRID_DIM+gx; grid_items[cur[c]++]=t; }
    }
    grid_n=1;
    return 1;
}

// ============================================================================
// load_obj_file: carga una malla OBJ (con UVs opcionales). Devuelve nº de tris.
// ============================================================================
static int load_obj_file(char *fname){
    char line[256],*p;
    char mat_names[MAX_MATS][32];   // nombres de material por orden de aparicion
    int n_mat_names=0, cur_mat=0;
    FILE *f;
    int vi[16],uvi[16],nv,i;

    n_verts=0;n_uvs=0;n_tris=0;mesh_ok=0;has_uvs=0;n_mats=1;n_floors=0;

    f=div_fopen(fname,"r");
    if(!f){
        s_cpy(m9_msg,"M9 NO FILE: ");s_cat(m9_msg,fname);
        return 0;
    }

    while(read_line(f,line,sizeof(line))){
        if(line[0]=='v'&&line[1]==' '){
            if(n_verts<MAX_VERTS){
                p=line+2;
                mesh_v[n_verts].x=sc_atof(p);p=next_tok(p);
                mesh_v[n_verts].y=sc_atof(p);p=next_tok(p);
                mesh_v[n_verts].z=sc_atof(p);
                n_verts++;
            }
        } else if(line[0]=='v'&&line[1]=='t'&&line[2]==' '){
            if(n_uvs<MAX_UVS){
                p=line+3;
                mesh_uv[n_uvs].u=sc_atof(p); p=next_tok(p);
                mesh_uv[n_uvs].v=1.0f-sc_atof(p);   // OBJ V=0 abajo, MAP fila0 arriba
                n_uvs++;
            }
        } else if(line[0]=='u'&&line[1]=='s'&&line[2]=='e'&&line[3]=='m'&&
                  line[4]=='t'&&line[5]=='l'&&(line[6]==' '||line[6]=='\t')){
            // usemtl <nombre>: registrar el nombre y obtener su indice (0-based)
            char *mn=line+7; int j,k,found=-1,mlen=0;
            while(*mn==' '||*mn=='\t')mn++;
            while(mn[mlen]&&mn[mlen]!=' '&&mn[mlen]!='\t'&&mlen<31)mlen++;
            for(j=0;j<n_mat_names;j++){
                int eq=1;
                for(k=0;k<mlen;k++){if(mat_names[j][k]!=mn[k]){eq=0;break;}}
                if(eq&&mat_names[j][mlen]==0){found=j;break;}
            }
            if(found<0&&n_mat_names<MAX_MATS){
                for(k=0;k<mlen;k++)mat_names[n_mat_names][k]=mn[k];
                mat_names[n_mat_names][mlen]=0;
                found=n_mat_names++;
            }
            if(found>=0)cur_mat=found;
        } else if(line[0]=='f'&&line[1]==' '){
            p=line+2;nv=0;
            while(*p&&nv<16){
                while(*p==' '||*p=='\t')p++;
                if(!*p||*p=='\n')break;
                p=parse_face_vert(p,&vi[nv],&uvi[nv]);
                nv++;
            }
            for(i=1;i<nv-1&&n_tris<MAX_TRIS;i++){
                if(vi[0]>=0&&vi[0]<n_verts&&vi[i]>=0&&vi[i]<n_verts&&vi[i+1]>=0&&vi[i+1]<n_verts){
                    mesh_t[n_tris].a=vi[0]; mesh_t[n_tris].b=vi[i]; mesh_t[n_tris].c=vi[i+1];
                    mesh_t[n_tris].ua=(uvi[0]  >=0&&uvi[0]  <n_uvs)?uvi[0]  :-1;
                    mesh_t[n_tris].ub=(uvi[i]  >=0&&uvi[i]  <n_uvs)?uvi[i]  :-1;
                    mesh_t[n_tris].uc=(uvi[i+1]>=0&&uvi[i+1]<n_uvs)?uvi[i+1]:-1;
                    mesh_t[n_tris].mat=(unsigned char)cur_mat;
                    n_tris++;
                }
            }
        }
    }
    div_fclose(f);
    n_mats = (n_mat_names>0)?n_mat_names:1;

    has_uvs=(n_uvs>0);
    mesh_ok=(n_tris>0);
    // Precalcular el color de flat-shading de cada triangulo UNA vez (la normal
    // y la luz no cambian): evita un sqrt + normalizacion por triangulo y frame.
    for(i=0;i<n_tris;i++)
        mesh_t[i].flat=flat_color(mesh_t[i].a,mesh_t[i].b,mesh_t[i].c);

    // Precalcular el "footprint" 2D (plano XZ) de las paredes para la colision:
    // un triangulo cuya normal es casi horizontal (|ny|<WALL_NY) es una PARED;
    // su proyeccion en XZ es un segmento (el par de vertices mas separados).
    // Se guarda tambien su extension vertical [ymin,ymax] para no chocar con
    // tejados o dinteles que estan por encima del jugador (p.ej. el porton).
    n_walls=0; n_floors=0;
    for(i=0;i<n_tris;i++){
        int a=mesh_t[i].a,b=mesh_t[i].b,c=mesh_t[i].c;
        float ux=mesh_v[b].x-mesh_v[a].x, uy=mesh_v[b].y-mesh_v[a].y, uz=mesh_v[b].z-mesh_v[a].z;
        float vx=mesh_v[c].x-mesh_v[a].x, vy=mesh_v[c].y-mesh_v[a].y, vz=mesh_v[c].z-mesh_v[a].z;
        float nx=uy*vz-uz*vy, ny=uz*vx-ux*vz, nz=ux*vy-uy*vx;
        float nl=(float)sqrt((double)(nx*nx+ny*ny+nz*nz));
        if(nl<1e-6f)continue;
        if((ny<0?-ny:ny)/nl >= WALL_NY){
            // Casi horizontal -> SUELO/TECHO: candidato de suelo para escalones y
            // rampas (floor-follow). No es una pared, no entra en mesh_walls.
            if(n_floors<MAX_FLOORS) mesh_floor_idx[n_floors++]=i;
            continue;
        }
        if(n_walls>=MAX_WALLS) continue;            // pared (muro casi vertical)
        {
            // par de vertices mas separados en XZ -> extremos del segmento
            float px[3],pz[3],py[3]; int j,e0=0,e1=1; float best=-1.0f;
            px[0]=mesh_v[a].x;pz[0]=mesh_v[a].z;py[0]=mesh_v[a].y;
            px[1]=mesh_v[b].x;pz[1]=mesh_v[b].z;py[1]=mesh_v[b].y;
            px[2]=mesh_v[c].x;pz[2]=mesh_v[c].z;py[2]=mesh_v[c].y;
            for(j=0;j<3;j++){
                int k=(j+1)%3;
                float dxx=px[j]-px[k], dzz=pz[j]-pz[k], d=dxx*dxx+dzz*dzz;
                if(d>best){best=d;e0=j;e1=k;}
            }
            mesh_walls[n_walls].x0=px[e0]; mesh_walls[n_walls].z0=pz[e0];
            mesh_walls[n_walls].x1=px[e1]; mesh_walls[n_walls].z1=pz[e1];
            {float y0=py[0],y1=py[0],t; t=py[1];if(t<y0)y0=t;if(t>y1)y1=t;
             t=py[2];if(t<y0)y0=t;if(t>y1)y1=t;
             mesh_walls[n_walls].ymin=y0; mesh_walls[n_walls].ymax=y1;}
            n_walls++;
        }
    }
    // Rejilla espacial XZ para el culling de triangulos por celdas (Tier 3).
    build_grid();
    {char num[12];
     s_cpy(m9_msg,"M9 ");s_itos(n_tris,num);s_cat(m9_msg,num);
     s_cat(m9_msg,has_uvs?" tri+UV":" tri");}
    return mesh_ok?n_tris:0;
}

// ============================================================================
// build_mip_for: genera el mipmap de 1 nivel (mitad de ancho/alto) para el
// material m. Muestreo de punto (indices de paleta: no se promedian). Mejora la
// coherencia de cache al texturar superficies lejanas.
// ============================================================================
static void build_mip_for(int m){
    int mw,mh,x,y;
    if(mat_mip[m]){div_free(mat_mip[m]);mat_mip[m]=NULL;matm_w[m]=matm_h[m]=0;}
#if !M9_USE_MIP
    return;
#endif
    if(!mat_data[m]||mat_w[m]<2||mat_h[m]<2) return;
    mw=mat_w[m]>>1; mh=mat_h[m]>>1;
    mat_mip[m]=(char*)div_malloc((size_t)(mw*mh));
    if(!mat_mip[m]) return;
    for(y=0;y<mh;y++){
        char *d=mat_mip[m]+(long)y*mw;
        char *s=mat_data[m]+(long)(y<<1)*mat_w[m];
        for(x=0;x<mw;x++) d[x]=s[x<<1];
    }
    matm_w[m]=mw; matm_h[m]=mh;
}

// ============================================================================
// load_material_file: carga una textura .MAP en el slot de material m (0..MAX_MATS-1).
// Libera el buffer anterior de ese slot antes de cargar (sin leaks). Devuelve 1/0.
// ============================================================================
static int load_material_file(int m, char *fname){
    char magic[8];
    FILE *f;
    int w, h, npoints, pix_size;

    if(m<0||m>=MAX_MATS) return 0;
    if(mat_data[m]){div_free(mat_data[m]);mat_data[m]=NULL;mat_w[m]=mat_h[m]=0;}
    if(mat_mip[m]){div_free(mat_mip[m]);mat_mip[m]=NULL;matm_w[m]=matm_h[m]=0;}

    f=div_fopen(fname,"rb");
    if(!f){s_cpy(m9_msg,"TEX NO FILE");return 0;}

    if((int)fread(magic,1,8,f)!=8||magic[0]!='m'||magic[1]!='a'||magic[2]!='p'){
        s_cpy(m9_msg,"TEX no MAP");div_fclose(f);return 0;
    }
    {
        unsigned short sw=0, sh=0, snp=0;
        if((int)fread(&sw,2,1,f)!=1||(int)fread(&sh,2,1,f)!=1){
            s_cpy(m9_msg,"TEX dim err");div_fclose(f);return 0;
        }
        fseek(f,1380L,SEEK_CUR);     // codigo(4)+nombre(32)+paleta(768)+rangos(576)
        if((int)fread(&snp,2,1,f)!=1){
            s_cpy(m9_msg,"TEX npts err");div_fclose(f);return 0;
        }
        w=(int)sw; h=(int)sh; npoints=(int)snp;
    }
    if(w<=0||h<=0||w>1024||h>1024){
        s_cpy(m9_msg,"TEX size err");div_fclose(f);return 0;
    }
    if(npoints>0)fseek(f,(long)npoints*4L,SEEK_CUR);

    pix_size=w*h;
    mat_data[m]=(char*)div_malloc((size_t)pix_size);
    if(!mat_data[m]){s_cpy(m9_msg,"TEX no mem");div_fclose(f);return 0;}
    if((int)fread(mat_data[m],1,(size_t)pix_size,f)!=pix_size){
        s_cpy(m9_msg,"TEX read err");div_free(mat_data[m]);mat_data[m]=NULL;
        div_fclose(f);return 0;
    }
    mat_w[m]=w; mat_h[m]=h;
    div_fclose(f);
    build_mip_for(m);                    // mipmap de 1 nivel para LOD/cache
    {char num[12];s_cpy(m9_msg,"TEX ");s_itos(w,num);s_cat(m9_msg,num);
     s_cat(m9_msg,"x");s_itos(h,num);s_cat(m9_msg,num);}
    return 1;
}

// ============================================================================
// LOAD_WLD9(obj, textura, unitscale): carga el escenario en UNA sola llamada
// (analogo a load_wld del modo 8 pero con textura y escala integradas).
//   obj       : fichero .OBJ del escenario (Y-up, triangulado, con UVs).
//   textura   : fichero .MAP de la textura ("" o "0" = sin textura -> flat).
//   unitscale : uds DIV2 por unidad OBJ (<=0 = no cambiar, def 100).
// Devuelve nº de triangulos cargados (0 si fallo).
// ============================================================================
static void load_wld9_fn(void){
    int scale  =getparm();          // 3er arg: unitscale
    int tex_off=getparm();          // 2do arg: fichero de textura
    int obj_off=getparm();          // 1er arg: fichero OBJ
    char fname[64], tname[64];
    int ntris, m;

    if(scale>0) m9_unitscale=(float)scale;

    div2c(obj_off,fname,sizeof(fname));
    // Liberar TODOS los materiales del nivel anterior antes de cargar el nuevo.
    for(m=0;m<MAX_MATS;m++){
        if(mat_data[m]){div_free(mat_data[m]);mat_data[m]=NULL;mat_w[m]=mat_h[m]=0;}
        if(mat_mip[m]){div_free(mat_mip[m]);mat_mip[m]=NULL;matm_w[m]=matm_h[m]=0;}
    }
    ntris=load_obj_file(fname);

    div2c(tex_off,tname,sizeof(tname));
    if(tname[0] && !(tname[0]=='0'&&tname[1]==0)){
        load_material_file(0,tname);  // textura por defecto en slot 0
    }
    retval(ntris);
}

// MODE9_SETTEX(map): cambia la textura del material 0 (por defecto).
// Equivale a MODE9_MATERIAL(0,"MAP/..."). Devuelve 1/0.
static void mode9_settex_fn(void){
    int str_off=getparm();
    char fname[64];
    div2c(str_off,fname,sizeof(fname));
    retval(load_material_file(0,fname));
}

// MODE9_MATERIAL(idx, map): asigna una textura .MAP al material idx (0..15).
// idx 0 = material por defecto (el que se cargo en LOAD_WLD9).
// Llama despues de LOAD_WLD9, una vez por material que quieras personalizar.
// Si el idx ya tenia textura, la libera antes (sin leaks). Devuelve 1/0.
static void mode9_material_fn(void){
    int str_off=getparm();
    int idx    =getparm();
    char fname[64];
    div2c(str_off,fname,sizeof(fname));
    retval(load_material_file(idx,fname));
}

// ============================================================================
// load_sky_file: carga una textura .MAP panoramica como cielo. Igual formato que
// las texturas (indices contra la paleta DIV2 activa). Devuelve 1/0. La textura
// debe envolver 360º en horizontal (su borde izquierdo y derecho deben casar).
// ============================================================================
static int load_sky_file(char *fname){
    char magic[8]; FILE *f; int w,h,npoints,pix_size;
    if(sky_data){div_free(sky_data);sky_data=NULL;sky_w=sky_h=0;}
    sky_on=0;
    f=div_fopen(fname,"rb");
    if(!f){s_cpy(m9_msg,"SKY NO FILE");return 0;}
    if((int)fread(magic,1,8,f)!=8||magic[0]!='m'||magic[1]!='a'||magic[2]!='p'){
        s_cpy(m9_msg,"SKY no MAP");div_fclose(f);return 0;
    }
    {unsigned short sw=0,sh=0,snp=0;
     if((int)fread(&sw,2,1,f)!=1||(int)fread(&sh,2,1,f)!=1){s_cpy(m9_msg,"SKY dim err");div_fclose(f);return 0;}
     fseek(f,1380L,SEEK_CUR);     // codigo(4)+nombre(32)+paleta(768)+rangos(576)
     if((int)fread(&snp,2,1,f)!=1){s_cpy(m9_msg,"SKY npts err");div_fclose(f);return 0;}
     w=(int)sw;h=(int)sh;npoints=(int)snp;}
    if(w<=0||h<=0||w>SKY_MAXDIM*2||h>SKY_MAXDIM){s_cpy(m9_msg,"SKY size err");div_fclose(f);return 0;}
    if(npoints>0)fseek(f,(long)npoints*4L,SEEK_CUR);
    pix_size=w*h;
    sky_data=(char*)div_malloc((size_t)pix_size);
    if(!sky_data){s_cpy(m9_msg,"SKY no mem");div_fclose(f);return 0;}
    if((int)fread(sky_data,1,(size_t)pix_size,f)!=pix_size){
        s_cpy(m9_msg,"SKY read err");div_free(sky_data);sky_data=NULL;div_fclose(f);return 0;
    }
    sky_w=w;sky_h=h;sky_on=1;sky_cd_vw=0;   // invalidar cache de columnas
    div_fclose(f);
    {char num[12];s_cpy(m9_msg,"SKY ");s_itos(w,num);s_cat(m9_msg,num);
     s_cat(m9_msg,"x");s_itos(h,num);s_cat(m9_msg,num);}
    return 1;
}

// LOAD_SKY9(map): carga un cielo panoramico .MAP. Sustituye el color de fondo
// plano por la textura, orientada segun el yaw (giro) y pitch (mirar arriba/abajo).
static void load_sky9_fn(void){
    int off=getparm(); char fname[64];
    div2c(off,fname,sizeof(fname));
    retval(load_sky_file(fname));
}
// SKY9_OFF(): vuelve al fondo de color plano (SET_ENV_COLOR9).
static void sky9_off_fn(void){ sky_on=0; retval(0); }

// MODE9_LOADFPG(fichero): carga un FPG en la DLL para dibujar los billboards
// (procesos c_m9) ella misma en CADA viewport (necesario para split-screen).
// Sin esto, los billboards usan la ruta c_screen de DIV2 (una sola vista).
// Devuelve nº de graficos cargados. El PRG sigue haciendo su load_fpg aparte.
static void mode9_loadfpg_fn(void){
    int str_off=getparm();
    char fname[64];
    div2c(str_off,fname,sizeof(fname));
    retval(load_fpg_file(fname));
}

// ============================================================================
// START_MODE9 / STOP_MODE9 / MODE9_SET / MODE9_UNITSCALE
// ============================================================================
// START_MODE9(camera, m9, region): igual firma que start_mode8.
//   camera : id del proceso camara (como start_mode8).
//   m9     : el STRUCT m9 a usar. OJO: en modo 8 aqui va el INDICE de m8 (el
//            motor sabe donde vive m8); aqui, al ser m9 un struct del PRG, se
//            pasa su DIRECCION: &m9 (o &m9[n] si usas un array de camaras). La
//            DLL lee m9.camera/height/angle de ahi cada frame (integra el BIND).
//   region : region de pantalla. Esta DLL solo soporta 0 (pantalla completa);
//            no tiene acceso a la tabla de regiones de DIV2.
static void start_mode9_fn(void){
    int region=getparm();    // 3er arg
    int m9off =getparm();    // 2do arg: &m9
    int cam   =getparm();    // 1er arg: id de la camara
    int i;
    m9_camera=cam;
    if(m9off) m9_bind=m9off; // enlaza el struct (no hace falta MODE9_BIND aparte)
    m9_region=region;
    // Vista unica a pantalla completa (view 0); desactivar el resto.
    views[0].active=1; views[0].cam=cam; views[0].bind=m9off;
    views[0].vx=0; views[0].vy=0; views[0].vw=0; views[0].vh=0; views[0].haslast=0;
    for(i=1;i<MAX_VIEWS;i++) views[i].active=0;
    m9_active=1;
    retval(1);
}
// MODE9_SPLIT(slot, camara, m9, x, y, w, h): define un viewport (split-screen).
// slot 0..MAX_VIEWS-1. Cada vista tiene su propia camara y su propio STRUCT m9
// (&m9[n].z). x,y,w,h = rectangulo en pantalla (uds de pantalla). Llama varias
// veces (una por jugador). Tambien activa el modo 9.
static void mode9_split_fn(void){
    int h=getparm(),w=getparm(),y=getparm(),x=getparm();
    int m9off=getparm(),cam=getparm(),slot=getparm();
    if(slot<0||slot>=MAX_VIEWS){retval(0);return;}
    views[slot].active=1; views[slot].cam=cam; views[slot].bind=m9off;
    views[slot].vx=x; views[slot].vy=y; views[slot].vw=w; views[slot].vh=h;
    views[slot].haslast=0;
    if(slot==0){ m9_camera=cam; if(m9off)m9_bind=m9off; }  // primario (billboards)
    m9_active=1;
    retval(1);
}
// MODE9_COLLISION(on): 1=advance/xadvance no atraviesan paredes (usa el campo
// radius del proceso camara como distancia minima a la pared), 0=libre (def).
static void mode9_collision_fn(void){
    m9_collision=getparm()?1:0;
    retval(0);
}
// MODE9_STEP(altura): altura MAXIMA de escalon/rampa (uds DIV2) que se sube de
// forma automatica. >0 activa escaleras y rampas (floor-following): los muros mas
// bajos que 'altura' no bloquean (se suben) y el jugador se apoya en el suelo que
// tiene debajo (peldaños, rampas inclinadas hasta ~60). 0 = desactivado (clasico:
// la DLL no toca z, el PRG controla la altura). Requiere MODE9_COLLISION(1).
// IMPORTANTE: la GRAVEDAD la sigue aplicando el PRG (z = z - algo cada frame); la
// DLL solo SUBE z cuando el jugador se apoya en un suelo/escalon. Llamar DESPUES
// de LOAD_WLD9 (usa la escala de unidades fijada alli).
static void mode9_step_fn(void){
    int d=getparm();
    m9_step=(d>0)?(float)d/m9_unitscale:0.0f;
    retval(0);
}
static void stop_mode9_fn(void){
    m9_active=0;
    retval(0);
}
// MODE9_SCRW()/MODE9_SCRH(): ancho/alto de la pantalla actual (la DLL los conoce
// por _wide/_height). Para que el PRG calcule limites de raton y viewports a
// CUALQUIER resolucion sin hardcodear 320x200. Devuelven 320/200 si no hay modo.
static void mode9_scrw_fn(void){ retval((_wide  && *_wide  >0)?*_wide  :320); }
static void mode9_scrh_fn(void){ retval((_height&& *_height>0)?*_height:200); }
static void mode9_set_fn(void){
    m9_pitch=getparm();      // pitch (ultimo argumento)
    m9_height=getparm();     // height
    retval(0);
}
static void mode9_unitscale_fn(void){
    int n=getparm();
    if(n>0) m9_unitscale=(float)n;
    retval(0);
}
// MODE9_CULL(modo): 0=sin culling, 1=descarta caras traseras (def), 2=invertido.
// Solo usar 1/2 con mallas de volumen cerrado y normales coherentes hacia fuera.
static void mode9_cull_fn(void){
    int m=getparm();
    if(m>=0&&m<=2) cull_mode=m;
    retval(0);
}
// MODE9_FARCLIP(dist): no dibujar geometria mas alla de 'dist' (uds DIV2).
// 0 = sin limite. Si hay niebla activa, ademas se recorta a fog_far (lo que
// queda detras de la niebla es del color de fondo, no hace falta dibujarlo).
static void mode9_farclip_fn(void){
    int d=getparm();
    far_clip=(d>0)?(float)d/m9_unitscale:0.0f;
    retval(0);
}
// MODE9_BIND(&m9): enlaza el STRUCT m9 del PRG (campos z,camera,height,angle).
// La DLL lee camera/height/angle de el cada frame, evitando llamar a MODE9_SET.
static void mode9_bind_fn(void){
    m9_bind=getparm();
    retval(0);
}

// ============================================================================
// SET_ENV_COLOR9 / SET_FOG9 / MODE9_FOG_OFF
// ============================================================================
// DIV2 usa rango 0..100 por canal; la paleta VGA es de 6 bits (0..63). Se
// escala: 100 -> 63 (blanco). (Antes se escribia el valor crudo en la paleta,
// por eso 100 o 255 no daban blanco: se salian del rango de 6 bits.)
static int col100to63(int v){
    if(v<0)v=0; if(v>100)v=100;
    return (v*63+50)/100;
}
static void set_env_color9_fn(void){
    int b=getparm(),g=getparm(),r=getparm();   // 0..100 por canal
    env_r=col100to63(r); env_g=col100to63(g); env_b=col100to63(b);
    palette[PAL_ENV*3+0]=(char)env_r;
    palette[PAL_ENV*3+1]=(char)env_g;
    palette[PAL_ENV*3+2]=(char)env_b;
    set_palette=1;
    // Si la niebla esta activa, su color = color de ambiente: reconstruirla.
    if(fog_on) build_fog_map(env_r,env_g,env_b);
    retval(0);
}
// SET_FOG9(near, far): como set_fog del modo 8, solo near/far (uds DIV2). El
// COLOR de la niebla es el de SET_ENV_COLOR9 (la niebla funde hacia el fondo).
static void set_fog9_fn(void){
    int ffar=getparm(),fnear=getparm();    // rango en uds DIV2
    fog_near=(float)fnear/m9_unitscale;
    fog_far =(float)ffar /m9_unitscale;
    build_fog_map(env_r,env_g,env_b);      // color de niebla = color de ambiente
    fog_on=(fog_map!=NULL && fog_far>fog_near);
    build_fog_lut();                        // LUT por profundidad (fog_on ya fijado)
    retval(0);
}
static void mode9_fog_off_fn(void){
    fog_on=0;
    retval(0);
}

// ============================================================================
// Lee la camara (proceso) y rellena posicion/orientacion. Devuelve 1 si OK.
// ============================================================================
static int get_camera(int cam,int bind,
                      float *cx,float *cy,float *cz,float *yaw,float *pitch,
                      int *outbase){
    int eyeh=m9_height, pitch_i=m9_pitch, base;
    // Si hay STRUCT m9 enlazado, leer camera/height/angle de el (campos
    // consecutivos: z=+0, camera=+1, height=+2, angle=+3). Evita MODE9_SET.
    if(bind){
        cam     =mem[bind+1];
        eyeh    =mem[bind+2];
        pitch_i =mem[bind+3];
    }
    base=find_process(cam);
    if(outbase)*outbase=base;
    if(base<0) return 0;
    *cx   =(float)mem[base+P_X]/m9_unitscale;
    *cz   =(float)mem[base+P_Y]/m9_unitscale;     // proceso.y -> mundo Z
    *cy   =(float)(mem[base+P_Z]+eyeh)/m9_unitscale;   // altura del ojo
    *yaw  =(float)mem[base+P_ANGLE]*(3.14159265f/180000.0f);
    *pitch=(float)pitch_i*(3.14159265f/180000.0f);
    return 1;
}

// ============================================================================
// floor_height: altura del suelo bajo el punto (px,pz) en uds OBJ. Recorre los
// triangulos de suelo, hace el test punto-en-triangulo en XZ (coordenadas
// baricentricas) e interpola la Y del plano. Devuelve el suelo MAS ALTO cuya
// altura no supere ceil_y (asi en un edificio de 2 plantas no te sube al techo).
// Devuelve 1 y escribe *fy si encuentra suelo; 0 si no hay suelo bajo el punto.
// ============================================================================
static int floor_height(float px,float pz,float ceil_y,float *fy){
    int i,found=0; float best=-1e30f;
    for(i=0;i<n_floors;i++){
        int t=mesh_floor_idx[i];
        int a=mesh_t[t].a,b=mesh_t[t].b,c=mesh_t[t].c;
        float x0=mesh_v[a].x,z0=mesh_v[a].z,y0=mesh_v[a].y;
        float x1=mesh_v[b].x,z1=mesh_v[b].z,y1=mesh_v[b].y;
        float x2=mesh_v[c].x,z2=mesh_v[c].z,y2=mesh_v[c].y;
        float d=(z1-z2)*(x0-x2)+(x2-x1)*(z0-z2);    // 2*area en XZ (≠0 = no vertical)
        float l0,l1,l2,y,inv;
        if(d<1e-6f&&d>-1e-6f)continue;
        inv=1.0f/d;
        l0=((z1-z2)*(px-x2)+(x2-x1)*(pz-z2))*inv;
        l1=((z2-z0)*(px-x2)+(x0-x2)*(pz-z2))*inv;
        l2=1.0f-l0-l1;
        if(l0<-0.001f||l1<-0.001f||l2<-0.001f)continue;   // (px,pz) fuera del triangulo
        y=l0*y0+l1*y1+l2*y2;
        if(y<=ceil_y+0.05f && y>best){best=y;found=1;}
    }
    if(found)*fy=best;
    return found;
}

// ============================================================================
// Colision 2D (plano XZ) de un circulo (camara, radio r en uds OBJ) contra los
// segmentos de pared. Empuja la camara fuera de las paredes que coincidan con
// su altura (sliding: solo se corrige la componente perpendicular, asi se
// "desliza" a lo largo de la pared). Modifica *cx,*cz. Las paredes cuya cima
// este a <= 'step' sobre los pies (feet) NO bloquean: son escalones que el
// floor-follow sube (asi se puede entrar en una escalera).
// ============================================================================
static void collide_xz(float *cx,float *cz,float cy,float r,float feet,float step){
    float ylo=cy-PLAYER_BODY, yhi=cy+0.3f;   // franja vertical del jugador (OBJ)
    float r2=r*r;
    int pass,w;
    for(pass=0;pass<2;pass++){               // 2 pasadas: resuelve esquinas
        for(w=0;w<n_walls;w++){
            float ax,az,bx,bz,dx,dz,len2,t,px,pz,ox,oz,d2;
            if(mesh_walls[w].ymax<ylo || mesh_walls[w].ymin>yhi) continue;
            if(step>0.0f && mesh_walls[w].ymax<=feet+step) continue;  // escalon: no bloquea
            ax=mesh_walls[w].x0; az=mesh_walls[w].z0;
            bx=mesh_walls[w].x1; bz=mesh_walls[w].z1;
            dx=bx-ax; dz=bz-az; len2=dx*dx+dz*dz;
            t = (len2>1e-9f) ? (((*cx-ax)*dx+(*cz-az)*dz)/len2) : 0.0f;
            if(t<0.0f)t=0.0f; else if(t>1.0f)t=1.0f;
            px=ax+dx*t; pz=az+dz*t;          // punto mas cercano del segmento
            ox=*cx-px; oz=*cz-pz; d2=ox*ox+oz*oz;
            if(d2<r2){
                if(d2>1e-10f){
                    float inv=fast_rsqrt(d2); float push=(r-1.0f/inv)*inv;
                    *cx+=ox*push; *cz+=oz*push;
                } else {                      // justo encima: empujar por la normal
                    float nx=-dz, nz2=dx, nl2=nx*nx+nz2*nz2;
                    if(nl2>1e-10f){ float inv=fast_rsqrt(nl2); *cx+=nx*inv*r; *cz+=nz2*inv*r; }
                }
            }
        }
    }
}

// Colision con BARRIDO (swept): evita el "tunneling" cuando la camara se mueve
// mas rapido que su radio. Si el segmento de movimiento (lx,lz)->(cx,cz) cruza
// el plano de una pared a distancia < r, detiene la camara a distancia r del
// plano por el lado del que venia. collide_xz refina luego el deslizamiento.
static void collide_swept(float lx,float lz,float *cx,float *cz,float cy,float r,
                          float feet,float step){
    float ylo=cy-PLAYER_BODY, yhi=cy+0.3f;
    int w;
    for(w=0;w<n_walls;w++){
        float ax,az,ex,ez,el2,nx,nz,nl,dl,dc,t,ix,iz,st,target,denom;
        if(mesh_walls[w].ymax<ylo||mesh_walls[w].ymin>yhi)continue;
        if(step>0.0f && mesh_walls[w].ymax<=feet+step)continue;   // escalon: no bloquea
        ax=mesh_walls[w].x0; az=mesh_walls[w].z0;
        ex=mesh_walls[w].x1-ax; ez=mesh_walls[w].z1-az; el2=ex*ex+ez*ez;
        if(el2<1e-9f)continue;
        nx=-ez; nz=ex; {float nl2=nx*nx+nz*nz; if(nl2<1e-12f)continue;
        {float inv=fast_rsqrt(nl2); nx*=inv; nz*=inv;}}
        dl=(lx-ax)*nx+(lz-az)*nz;        // distancia perpendicular del origen
        dc=(*cx-ax)*nx+(*cz-az)*nz;      // distancia perpendicular del destino
        // ¿cruza la "banda" de radio r del plano viniendo de fuera?
        if(dl>=r && dc<r)      target= r;
        else if(dl<=-r && dc>-r) target=-r;
        else continue;
        denom=dl-dc; if(denom>-1e-6f&&denom<1e-6f)continue;
        t=(dl-target)/denom; if(t<0.0f)t=0.0f; else if(t>1.0f)t=1.0f;
        ix=lx+(*cx-lx)*t; iz=lz+(*cz-lz)*t;
        st=((ix-ax)*ex+(iz-az)*ez)/el2;  // ¿el cruce cae dentro del segmento?
        if(st>=-0.15f&&st<=1.15f){ *cx=ix; *cz=iz; }
    }
}

// ============================================================================
// MODE9_COLLIDE(pid): empuja un proceso CUALQUIERA fuera de las paredes (sliding),
// no solo la camara. Lee su x,y (suelo), z (altura) y radius del proceso; corrige
// x,y y los reescribe. Devuelve 1 si lo movio (estaba dentro de un muro), 0 si no.
// Es deslizamiento puro (sin barrido anti-tunneling): pensado para NPCs a
// velocidad normal; para algo muy rapido, llamalo varias veces o reduce su paso.
// Se trata z (P_Z) como la altura de los PIES; el cuerpo sube PLAYER_BODY.
// ============================================================================
static void mode9_collide_fn(void){
    int pid=getparm();
    int base=find_process(pid);
    float cx,cz,cy,r,ox,oz;
    if(base<0 || n_walls<=0){ retval(0); return; }
    cx=(float)mem[base+P_X]/m9_unitscale;
    cz=(float)mem[base+P_Y]/m9_unitscale;
    cy=(float)mem[base+P_Z]/m9_unitscale + PLAYER_BODY;   // banda vertical del cuerpo
    r =(float)mem[base+P_RADIUS]/m9_unitscale;
    if(r<=0.0f) r=(float)COLLIDE_DEF/m9_unitscale;
    ox=cx; oz=cz;
    {
        float feet=(float)mem[base+P_Z]/m9_unitscale;
        collide_xz(&cx,&cz,cy,r,feet,m9_step);
        // Escalones/rampas: subir los pies del proceso al suelo bajo el (<= m9_step).
        if(m9_step>0.0f && n_floors>0){
            float fy;
            if(floor_height(cx,cz,feet+m9_step,&fy) && feet<fy){
                float fz=fy*m9_unitscale;
                mem[base+P_Z]=(int)(fz>=0?fz+0.5f:fz-0.5f);
            }
        }
    }
    {float fx=cx*m9_unitscale, fz=cz*m9_unitscale;
     mem[base+P_X]=(int)(fx>=0?fx+0.5f:fx-0.5f);
     mem[base+P_Y]=(int)(fz>=0?fz+0.5f:fz-0.5f);}
    retval((ox!=cx||oz!=cz)?1:0);
}

// ============================================================================
// Sprites de billboards: parseo de FPG + dibujo (blit) escalado con oclusion.
// ============================================================================
static void free_sprites(void){
    int i;
    for(i=0;i<n_fpgspr;i++){ if(fspr[i].pix){div_free(fspr[i].pix);fspr[i].pix=NULL;} }
    n_fpgspr=0;
}
// load_fpg_file: parsea un .FPG de DIV2 (formato FPGHEADER/FPGBODY de div.h) y
// guarda cada grafico (codigo, w, h, punto de control, pixels). Devuelve nº de
// graficos. Habilita el dibujo de billboards por la DLL (multi-vista).
static int load_fpg_file(char *fname){
    FILE *f; char magic[8]; int count=0;
    free_sprites();
    f=div_fopen(fname,"rb");
    if(!f){s_cpy(m9_msg,"FPG NO FILE");return 0;}
    if((int)fread(magic,1,8,f)!=8||magic[0]!='f'||magic[1]!='p'||magic[2]!='g'){
        s_cpy(m9_msg,"FPG bad");div_fclose(f);return 0;
    }
    fseek(f,768L+576L,SEEK_CUR);          // saltar paleta(768)+colorbars(16*36)
    while(n_fpgspr<MAX_FPGSPR){
        int code,length,wide,height,npoints,psz,cx,cy;
        char desc[32],fn2[12];
        unsigned short pt[2];
        if((int)fread(&code,4,1,f)!=1) break;
        if((int)fread(&length,4,1,f)!=1) break;
        if((int)fread(desc,1,32,f)!=32) break;
        if((int)fread(fn2,1,12,f)!=12) break;
        if((int)fread(&wide,4,1,f)!=1) break;
        if((int)fread(&height,4,1,f)!=1) break;
        if((int)fread(&npoints,4,1,f)!=1) break;
        if(wide<=0||height<=0||wide>2048||height>2048||npoints<0) break;
        cx=wide/2; cy=height/2;
        if(npoints>0){
            if((int)fread(pt,2,2,f)!=2) break;
            if((short)pt[0]>=0&&(short)pt[1]>=0){cx=(short)pt[0];cy=(short)pt[1];}
            if(npoints>1) fseek(f,(long)(npoints-1)*4L,SEEK_CUR);
        }
        psz=wide*height;
        {char *pix=(char*)div_malloc((size_t)psz);
         if(!pix) break;
         if((int)fread(pix,1,(size_t)psz,f)!=psz){div_free(pix);break;}
         fspr[n_fpgspr].code=code; fspr[n_fpgspr].w=wide; fspr[n_fpgspr].h=height;
         fspr[n_fpgspr].cx=cx; fspr[n_fpgspr].cy=cy; fspr[n_fpgspr].pix=pix;
         n_fpgspr++; count++;}
    }
    div_fclose(f);
    {char num[12];s_cpy(m9_msg,"FPG ");s_itos(count,num);s_cat(m9_msg,num);s_cat(m9_msg," gr");}
    return count;
}
static int find_sprite(int code){
    int i; for(i=0;i<n_fpgspr;i++) if(fspr[i].code==code) return i; return -1;
}
// Dibuja el sprite 'idx' centrado en su punto de control en (scx,scy) de
// pantalla, escalado a sizepct%, recortado al viewport (clip_*), con color 0
// transparente y test/escritura de z-buffer (zfix) para oclusion por pixel.
// fogmap: remapeo de color de niebla para ESTE sprite (segun su distancia), o
// NULL si no hay niebla. Se aplica al pixel antes de escribirlo (igual que la
// geometria), asi los billboards lejanos se funden con la niebla en vez de saltar.
static void blit_sprite(int idx,int scx,int scy,int sizepct,int zfix,char *vid,int W,char *fogmap){
    FpgSpr *s=&fspr[idx];
    int dw=s->w*sizepct/100, dh=s->h*sizepct/100;
    int x0,y0,sxstep,systep,cx0,cy0,cx1,cy1,su0,sv,x,y;
    if(dw<1||dh<1||dw>4000||dh>4000)return;
    x0=scx-(s->cx*sizepct/100); y0=scy-(s->cy*sizepct/100);
    sxstep=(s->w<<16)/dw; systep=(s->h<<16)/dh;
    cx0=x0; cy0=y0; cx1=x0+dw; cy1=y0+dh; su0=0; sv=0;
    if(cx0<clip_x0){su0=(clip_x0-x0)*sxstep; cx0=clip_x0;}
    if(cy0<clip_y0){sv =(clip_y0-y0)*systep; cy0=clip_y0;}
    if(cx1>clip_x1)cx1=clip_x1;
    if(cy1>clip_y1)cy1=clip_y1;
    if(cx0>=cx1||cy0>=cy1)return;
    for(y=cy0;y<cy1;y++){
        char *prow=vid + (long)y*W;
        unsigned short *zrow=zbuf + (long)y*W;
        char *srow=s->pix + (long)(sv>>16)*s->w;
        int su=su0;
        if(fogmap){
            for(x=cx0;x<cx1;x++){
                char px=srow[su>>16];
                if(px!=0 && zfix>(int)zrow[x]){ prow[x]=fogmap[(unsigned char)px]; zrow[x]=(unsigned short)zfix; }
                su+=sxstep;
            }
        } else {
            for(x=cx0;x<cx1;x++){
                char px=srow[su>>16];
                if(px!=0 && zfix>(int)zrow[x]){ prow[x]=px; zrow[x]=(unsigned short)zfix; }
                su+=sxstep;
            }
        }
        sv+=systep;
    }
}

// Transforma un punto de mundo (uds OBJ) a espacio camara. Devuelve cx,cy,cz.
static void world_to_cam(float Px,float Py,float Pz,
                         float Cx,float Cy,float Cz,
                         float ysin,float ycos,float psin,float pcos,
                         float *ocx,float *ocy,float *ocz){
    float dx=Px-Cx, dy=Py-Cy, dz=Pz-Cz;
    // Yaw alrededor de Y. Eje X de camara = F x up (handedness igual que el
    // modo 8: el giro horizontal NO queda espejado).
    float rx = dx*ysin + dz*ycos;
    float rz = dx*ycos + dz*(-ysin);
    float ry = dy;
    // Pitch alrededor del eje X de camara
    float y2 = ry*pcos - rz*psin;
    float z2 = ry*psin + rz*pcos;
    *ocx=rx; *ocy=y2; *ocz=z2;
}

// ============================================================================
// do_render: nucleo del modo 9 (camara primera persona + recorte near + niebla)
// ============================================================================
// Color de flat-shading de un triangulo (normal en uds OBJ contra la luz).
static unsigned char flat_color(int a,int b,int c){
    float ex1=mesh_v[b].x-mesh_v[a].x,ey1=mesh_v[b].y-mesh_v[a].y,ez1=mesh_v[b].z-mesh_v[a].z;
    float ex2=mesh_v[c].x-mesh_v[a].x,ey2=mesh_v[c].y-mesh_v[a].y,ez2=mesh_v[c].z-mesh_v[a].z;
    float nx=ey1*ez2-ez1*ey2,ny=ez1*ex2-ex1*ez2,nz=ex1*ey2-ey1*ex2;
    float nlen=(float)sqrt((double)(nx*nx+ny*ny+nz*nz));
    float sh; int ci;
    if(nlen>1e-6f){nx/=nlen;ny/=nlen;nz/=nlen;}
    sh=nx*0.4082f+ny*0.8165f+nz*(-0.4082f);
    if(sh<0.0f)sh=-sh;
    sh=AMBIENT+(1.0f-AMBIENT)*sh;
    ci=(int)(sh*(float)(PAL_SHADES-1)+0.5f);
    if(ci<0)ci=0;if(ci>=PAL_SHADES)ci=PAL_SHADES-1;
    return (unsigned char)(PAL_BASE+ci);
}

// flat_color_v: igual que flat_color pero recibe V3* en vez de indices globales.
// Usada por load_obj9_model para precalcular el color de flat-shading de cada
// triangulo del modelo (la normal del tri contra la misma luz que el mundo).
static unsigned char flat_color_v(V3 *va,V3 *vb,V3 *vc){
    float ex1=vb->x-va->x,ey1=vb->y-va->y,ez1=vb->z-va->z;
    float ex2=vc->x-va->x,ey2=vc->y-va->y,ez2=vc->z-va->z;
    float nx=ey1*ez2-ez1*ey2,ny=ez1*ex2-ex1*ez2,nz=ex1*ey2-ey1*ex2;
    float nlen=(float)sqrt((double)(nx*nx+ny*ny+nz*nz));
    float sh; int ci;
    if(nlen>1e-6f){nx/=nlen;ny/=nlen;nz/=nlen;}
    sh=nx*0.4082f+ny*0.8165f+nz*(-0.4082f);
    if(sh<0.0f)sh=-sh;
    sh=AMBIENT+(1.0f-AMBIENT)*sh;
    ci=(int)(sh*(float)(PAL_SHADES-1)+0.5f);
    if(ci<0)ci=0;if(ci>=PAL_SHADES)ci=PAL_SHADES-1;
    return (unsigned char)(PAL_BASE+ci);
}

// build_frame_name: construye "<base><n>.OBJ" (ej. base="CAT",n=3 -> "CAT3.OBJ").
// Soporta n multidigito por si en el futuro se usan >10 fotogramas.
static void build_frame_name(char *dst,const char *base,int n){
    char tmp[12]; int k=0;
    strcpy(dst,base);
    if(n<=0){ tmp[k++]='0'; }
    else { int t=n; char rev[12]; int r=0;
           while(t>0){rev[r++]=(char)('0'+(t%10));t/=10;}
           while(r>0)tmp[k++]=rev[--r]; }
    tmp[k]=0;
    strcat(dst,tmp);
    strcat(dst,".OBJ");
}

// load_obj9_verts_only: parsea SOLO las posiciones 'v' de un OBJ en dst (escaladas
// por sfac). Para fotogramas de animacion >0, que comparten topologia (vt/f) con
// el frame 0. Devuelve el numero de vertices leidos.
static int load_obj9_verts_only(char *fname,V3 *dst,int maxv,float sfac){
    FILE *f; int nv=0; char line[256];
    f=div_fopen(fname,"r");
    if(!f) return 0;
    while(read_line(f,line,sizeof(line))){
        char *p=line;
        while(*p==' '||*p=='\t')p++;
        if(p[0]=='v'&&p[1]==' '){
            float x,y,z; p+=2;
            x=sc_atof(p);p=next_tok(p);y=sc_atof(p);p=next_tok(p);z=sc_atof(p);
            if(nv<maxv){dst[nv].x=x*sfac;dst[nv].y=y*sfac;dst[nv].z=z*sfac;nv++;}
        }
    }
    div_fclose(f);
    return nv;
}

// load_obj9_model: parsea un OBJ en un Obj9Model. sfac = factor de escala
// (model_unitscale / m9_unitscale) para convertir verts OBJ -> espacio mundo.
// Usa div_malloc para los temporales y para las arrays finales del modelo.
static int load_obj9_model(Obj9Model *mdl,char *fname,float sfac){
    FILE *f;
    V3    *tv;
    UV2   *tuv;
    TriTex *ttr;
    int nv=0,nuv=0,nt=0,i,has_uv=0;
    char line[256];
    f=div_fopen(fname,"r");
    if(!f) return 0;
    tv =(V3*   )div_malloc(MAX_OBJ9V *sizeof(V3));
    tuv=(UV2*  )div_malloc(MAX_OBJ9UV*sizeof(UV2));
    ttr=(TriTex*)div_malloc(MAX_OBJ9T *sizeof(TriTex));
    if(!tv||!tuv||!ttr){
        if(tv)div_free(tv);if(tuv)div_free(tuv);if(ttr)div_free(ttr);
        div_fclose(f);return 0;
    }
    while(read_line(f,line,sizeof(line))){
        char *p=line;
        while(*p==' '||*p=='\t')p++;
        if(p[0]=='v'&&p[1]==' '){
            float x,y,z; p+=2;
            x=sc_atof(p);p=next_tok(p);y=sc_atof(p);p=next_tok(p);z=sc_atof(p);
            if(nv<MAX_OBJ9V){tv[nv].x=x*sfac;tv[nv].y=y*sfac;tv[nv].z=z*sfac;nv++;}
        } else if(p[0]=='v'&&p[1]=='t'){
            float u,v; p+=3;
            u=sc_atof(p);p=next_tok(p);v=sc_atof(p);
            if(nuv<MAX_OBJ9UV){tuv[nuv].u=u;tuv[nuv].v=1.0f-v;nuv++;has_uv=1;}
        } else if(p[0]=='f'&&p[1]==' '){
            int vi[8],uvi[8],nf=0; p+=2;
            while(*p&&*p!='\n'&&nf<8){
                while(*p==' '||*p=='\t')p++;
                if(!*p||*p=='\n')break;
                p=parse_face_vert(p,&vi[nf],&uvi[nf]);
                nf++;
            }
            for(i=1;i<nf-1&&nt<MAX_OBJ9T;i++){
                int ia=vi[0],ib=vi[i],ic=vi[i+1];
                if(ia<0||ia>=nv||ib<0||ib>=nv||ic<0||ic>=nv) continue;
                ttr[nt].a=ia;ttr[nt].b=ib;ttr[nt].c=ic;
                ttr[nt].ua=(uvi[0]  >=0&&uvi[0]  <nuv)?uvi[0]  :-1;
                ttr[nt].ub=(uvi[i]  >=0&&uvi[i]  <nuv)?uvi[i]  :-1;
                ttr[nt].uc=(uvi[i+1]>=0&&uvi[i+1]<nuv)?uvi[i+1]:-1;
                ttr[nt].mat=0;
                ttr[nt].flat=flat_color_v(&tv[ia],&tv[ib],&tv[ic]);
                nt++;
            }
        }
    }
    div_fclose(f);
    if(nv==0||nt==0){div_free(tv);div_free(tuv);div_free(ttr);return 0;}
    mdl->verts=(V3*   )div_malloc((size_t)(nv *sizeof(V3)));
    mdl->uvs  =(UV2*  )div_malloc((size_t)((nuv>0?nuv:1)*sizeof(UV2)));
    mdl->tris =(TriTex*)div_malloc((size_t)(nt *sizeof(TriTex)));
    if(!mdl->verts||!mdl->uvs||!mdl->tris){
        if(mdl->verts)div_free(mdl->verts);
        if(mdl->uvs)  div_free(mdl->uvs);
        if(mdl->tris) div_free(mdl->tris);
        mdl->verts=NULL;mdl->uvs=NULL;mdl->tris=NULL;
        div_free(tv);div_free(tuv);div_free(ttr);return 0;
    }
    for(i=0;i<nv;i++) mdl->verts[i]=tv[i];
    for(i=0;i<nuv;i++)mdl->uvs[i]  =tuv[i];
    for(i=0;i<nt;i++) mdl->tris[i] =ttr[i];
    mdl->nv=nv;mdl->nuv=(has_uv?nuv:0);mdl->nt=nt;
    mdl->vframes=mdl->verts;mdl->nframes=1;   // estatico por defecto
    div_free(tv);div_free(tuv);div_free(ttr);
    return nt;
}

// Transforma y proyecta un vertice a espacio camara SOLO si no se hizo ya en este
// frame (vstamp). Usa los parametros de camara de la vista actual (g_*). Rellena
// camv/psx/psy/pbehind como antes hacia el bucle que recorria todos los vertices.
static void xform_vertex(int i){
    float dx,dy,dz,rx,rz,ocx,ocy,ocz;
    if(vstamp[i]==frame_stamp) return;
    vstamp[i]=frame_stamp;
    dx=mesh_v[i].x-g_Cx; dy=mesh_v[i].y-g_Cy; dz=mesh_v[i].z-g_Cz;
    rx=dx*g_ysin+dz*g_ycos;
    rz=dx*g_ycos-dz*g_ysin;
    ocx=rx;
    ocy=dy*g_pcos-rz*g_psin;
    ocz=dy*g_psin+rz*g_pcos;
    camv[i][0]=ocx;camv[i][1]=ocy;camv[i][2]=ocz;
    if(ocz>=NEAR_PLANE){
        float inv=fast_recip(ocz);
        float fx=g_hw+ocx*g_focal*inv, fy=g_hh-ocy*g_focal*inv;
        psxf[i]=fx; psyf[i]=fy;                 // subpixel (para el rasterizado)
        psx[i]=fast_ftol(fx); psy[i]=fast_ftol(fy); // entero (para culling)
        pbehind[i]=0;
    } else pbehind[i]=1;
}

// Criba de un triangulo (near cull + far clip + backface + frustum) y, si pasa,
// lo añade a tsort[] para el bucket sort. Transforma sus vertices de forma
// perezosa (xform_vertex). Comun a la ruta de rejilla y al fallback.
static void consider_tri(int i,float fcull,int *pndraw){
    int a=mesh_t[i].a,b=mesh_t[i].b,c=mesh_t[i].c;
    float za,zb,zc,depth,zmin; int nd;
    xform_vertex(a); xform_vertex(b); xform_vertex(c);
    za=camv[a][2]; zb=camv[b][2]; zc=camv[c][2];
    if(za<NEAR_PLANE&&zb<NEAR_PLANE&&zc<NEAR_PLANE)return;
    if(fcull>0.0f){
        zmin=za; if(zb<zmin)zmin=zb; if(zc<zmin)zmin=zc;
        if(zmin>fcull)return;
    }
    nd=*pndraw;
    if(!pbehind[a]&&!pbehind[b]&&!pbehind[c]){
        // Triangulo entero delante del near: usar la proyeccion ya hecha.
        int ax=psx[a],ay=psy[a],bx=psx[b],by=psy[b],cx2=psx[c],cy2=psy[c];
        if(cull_mode){
            long area=(long)(bx-ax)*(long)(cy2-ay)-(long)(cx2-ax)*(long)(by-ay);
            if(cull_mode==1&&area>=0)return;   // descartar caras traseras
            if(cull_mode==2&&area<=0)return;   // (winding invertido)
        }
        {   // frustum (rect del viewport): los 3 fuera por el mismo lado
            int o0=0,o1=0,o2=0;
            if(ax<clip_x0)o0|=1; else if(ax>=clip_x1)o0|=2; if(ay<clip_y0)o0|=4; else if(ay>=clip_y1)o0|=8;
            if(bx<clip_x0)o1|=1; else if(bx>=clip_x1)o1|=2; if(by<clip_y0)o1|=4; else if(by>=clip_y1)o1|=8;
            if(cx2<clip_x0)o2|=1;else if(cx2>=clip_x1)o2|=2;if(cy2<clip_y0)o2|=4;else if(cy2>=clip_y1)o2|=8;
            if(o0&o1&o2)return;
        }
        tsort[nd].ci=0;   // no necesita recorte
    } else {
        tsort[nd].ci=1;   // cruza el near: recorte en el rasterizado
    }
    depth=(za+zb+zc)*(1.0f/3.0f);
    tsort[nd].depth=depth;
    tsort[nd].idx=i;
    *pndraw=nd+1;
}

// ============================================================================
// render_sky: rellena el fondo del viewport con el cielo panoramico cilindrico,
// tratado como geometria infinitamente lejana: cada pixel depende SOLO de la
// direccion del rayo (azimut/elevacion), no de la posicion. Asi queda "clavado"
// al mundo y se mueve de forma natural al girar (yaw) y mirar arriba/abajo (pitch).
//   azimut(x)    = -yaw + atan((x-cx)/focal)          -> columna de textura (envuelve 360)
//   elevacion(y) =  pitch + atan((cy-y)/focal)        -> fila de textura
// Ambos ejes usan la MISMA escala px-textura/radian (sky_w/2pi) para no deformar.
// Se dibuja SIN z-buffer (la geometria se rasteriza encima). Respeta el 'step'
// del line doubler. El signo de 'base' coincide con la handedness del motor
// (rz=dx*cos-dz*sin); si el cielo girara al reves, cambia -yaw por +yaw.
// ============================================================================
static void render_sky(int vx,int vy,int vw,int vh,float focal,float hh,
                       float yaw,float pitch,char *vid,int W,int step){
    static int   skycol[SKY_MAXDIM];
    static int   skyrow[SKY_MAXDIM];
    static int   skyhz[SKY_MAXDIM];      // nivel de niebla/bruma por fila (si hay niebla)
    static float rowang[SKY_MAXDIM];     // atan((centro-y)/focal) por fila de pantalla
    int x,y,base, dofog=(fog_on&&fog_map!=NULL);
    float k=(float)sky_w/6.2831853f;     // px de textura por radian (igual en H y V)
    float hazespan=0.35f;                // rad (~20): bajo esta elevacion el cielo se funde con la niebla
    if(vw>SKY_MAXDIM||vh>SKY_MAXDIM||sky_w<=0||sky_h<=0) return;
    // Tablas de angulo por columna/fila (atan). Solo se recalculan si cambia el
    // tamaño del viewport o de la textura (no cada frame).
    if(sky_cd_vw!=vw || sky_cd_vh!=vh || sky_cd_w!=sky_w){
        float half=(float)vw*0.5f, hrel=hh-(float)vy;
        for(x=0;x<vw;x++)
            sky_coldelta[x]=(int)((float)atan((double)(((float)x-half)/focal))*k);
        for(y=0;y<vh;y++)
            rowang[y]=(float)atan((double)((hrel-(float)y)/focal));
        sky_cd_vw=vw; sky_cd_vh=vh; sky_cd_w=sky_w;
    }
    // Columna de textura por columna de pantalla (azimut, envuelto a [0,sky_w)).
    base=(int)(-yaw*k);
    for(x=0;x<vw;x++){
        int c=base+sky_coldelta[x]; c%=sky_w; if(c<0)c+=sky_w;
        skycol[x]=c;
    }
    // Fila de textura por fila de pantalla (elevacion). Fila sky_h-1 = horizonte
    // (elevacion 0), fila 0 = cenit. Bajo el horizonte se clampa (lo tapa el suelo).
    // Si hay niebla: nivel de bruma por fila segun elevacion (horizonte->maximo,
    // cenit->0) para que el cielo se funda con la niebla SIN costura.
    for(y=0;y<vh;y++){
        float el=pitch+rowang[y];
        int ty=(sky_h-1)-(int)(el*k);
        if(ty<0)ty=0; else if(ty>=sky_h)ty=sky_h-1;
        skyrow[y]=ty*sky_w;
        if(dofog){
            int lv;
            if(el<=0.0f) lv=FOG_LEVELS-1;
            else if(el>=hazespan) lv=0;
            else lv=(int)((1.0f-el/hazespan)*(float)(FOG_LEVELS-1)+0.5f);
            skyhz[y]=lv;
        }
    }
    for(y=0;y<vh;y+=step){
        char *p=vid+(long)(vy+y)*W+vx;
        int row=skyrow[y];
        if(dofog && skyhz[y]>0){
            char *fm=&fog_map[skyhz[y]*256];
            for(x=0;x<vw;x++) p[x]=fm[(unsigned char)sky_data[row+skycol[x]]];
        } else {
            for(x=0;x<vw;x++) p[x]=sky_data[row+skycol[x]];
        }
    }
}

// Renderiza todas las instancias de objetos 3D encoladas con DRAW_OBJ9 en la
// vista actual. Usa los parametros de camara globales (g_*) ya establecidos
// por render_view. Reutiliza tsort[]/order[]/bcnt[] (el sort del mundo ya
// termino) y el z-buffer existente -> oclusion correcta con la geometria estatica.
static void render_obj9_instances(char *vid,int W,int H){
    int qi;
    (void)H;
    if(!n_obj9_queue) return;
    for(qi=0;qi<n_obj9_queue;qi++){
        Obj9Inst  *inst=&obj9_queue[qi];
        Obj9Model *mdl =&obj9_models[inst->midx];
        int i,ti,ndraw=0;
        float iys=inst->ysin,iyc=inst->ycos;
        float ix=inst->ix,iy=inst->iy,iz=inst->iz;
        char *mtex=mdl->tex;
        int   mtw=mdl->tw,mth=mdl->th;
        char *mmip=mdl->mip;
        int   mmw=mdl->mw,mmh=mdl->mh;
        int has_tex=(mtex!=NULL&&mdl->nuv>0);
        // Fotogramas de animacion a mezclar (vertex morphing). Para modelos
        // estaticos fr0==fr1 y blend=0, asi que es lectura directa sin coste.
        V3   *fr0=mdl->vframes+(long)inst->fa*mdl->nv;
        V3   *fr1=mdl->vframes+(long)inst->fb*mdl->nv;
        float blend=inst->fblend;
        int   morph=(mdl->nframes>1&&blend>0.0f);
        // Transformar cada vertice: local (rotacion Y + traslacion) -> camara
        for(i=0;i<mdl->nv;i++){
            float vx,vy,vz;
            if(morph){
                vx=fr0[i].x+(fr1[i].x-fr0[i].x)*blend;
                vy=fr0[i].y+(fr1[i].y-fr0[i].y)*blend;
                vz=fr0[i].z+(fr1[i].z-fr0[i].z)*blend;
            } else {
                vx=fr0[i].x;vy=fr0[i].y;vz=fr0[i].z;
            }
            float wx=vx*iyc-vz*iys+ix;
            float wz=vx*iys+vz*iyc+iz;
            float wy=vy+iy;
            float dx=wx-g_Cx,dy=wy-g_Cy,dz=wz-g_Cz;
            float rx=dx*g_ysin+dz*g_ycos;
            float rz=dx*g_ycos-dz*g_ysin;
            float ocx=rx;
            float ocy=dy*g_pcos-rz*g_psin;
            float ocz=dy*g_psin+rz*g_pcos;
            obj9cv[i][0]=ocx;obj9cv[i][1]=ocy;obj9cv[i][2]=ocz;
            if(ocz>=NEAR_PLANE){
                float inv=fast_recip(ocz);
                obj9px[i]=g_hw+ocx*g_focal*inv;
                obj9py[i]=g_hh-ocy*g_focal*inv;
                obj9bh[i]=0;
            } else obj9bh[i]=1;
        }
        // Cribar y preparar el sort (near cull + backface)
        for(ti=0;ti<mdl->nt&&ndraw<MAX_TRIS;ti++){
            int a=mdl->tris[ti].a,b=mdl->tris[ti].b,c=mdl->tris[ti].c;
            float za=obj9cv[a][2],zb=obj9cv[b][2],zc=obj9cv[c][2];
            if(za<NEAR_PLANE&&zb<NEAR_PLANE&&zc<NEAR_PLANE) continue;
            if(!obj9bh[a]&&!obj9bh[b]&&!obj9bh[c]){
                if(cull_mode){
                    float area=(obj9px[b]-obj9px[a])*(obj9py[c]-obj9py[a])
                              -(obj9px[c]-obj9px[a])*(obj9py[b]-obj9py[a]);
                    if(cull_mode==1&&area>=0.0f) continue;
                    if(cull_mode==2&&area<=0.0f) continue;
                }
                tsort[ndraw].ci=0;
            } else tsort[ndraw].ci=1;
            tsort[ndraw].depth=(za+zb+zc)*(1.0f/3.0f);
            tsort[ndraw].idx=ti;
            ndraw++;
        }
        if(!ndraw) continue;
        // Bucket sort front-to-back (reutiliza bcnt[]/order[])
        {
            int j,bk; float dmin=1e30f,dmax=-1e30f,inv;
            for(j=0;j<ndraw;j++){float d=tsort[j].depth;if(d<dmin)dmin=d;if(d>dmax)dmax=d;}
            if(dmax<=dmin){ for(j=0;j<ndraw;j++)order[j]=j; }
            else {
                inv=(float)(NBUCKETS-1)/(dmax-dmin);
                for(j=0;j<=NBUCKETS;j++)bcnt[j]=0;
                for(j=0;j<ndraw;j++){
                    bk=(int)((tsort[j].depth-dmin)*inv);
                    if(bk<0)bk=0;else if(bk>=NBUCKETS)bk=NBUCKETS-1;
                    bcnt[bk+1]++;
                }
                for(j=1;j<=NBUCKETS;j++)bcnt[j]+=bcnt[j-1];
                for(j=0;j<ndraw;j++){
                    bk=(int)((tsort[j].depth-dmin)*inv);
                    if(bk<0)bk=0;else if(bk>=NBUCKETS)bk=NBUCKETS-1;
                    order[bcnt[bk]++]=j;
                }
            }
        }
        // Rasterizar (via rapida + via de recorte, identicas al mundo)
        for(i=0;i<ndraw;i++){
            int oi=order[i],ti2=tsort[oi].idx;
            int a=mdl->tris[ti2].a,b=mdl->tris[ti2].b,c=mdl->tris[ti2].c;
            int textured=has_tex&&(mdl->tris[ti2].ua>=0);
            unsigned char flatcol=textured?0:mdl->tris[ti2].flat;
            if(tsort[oi].ci==0){
                // ---- Via rapida: tri entero delante del near ----
                float u0=0,v0=0,u1=0,v1=0,u2=0,v2=0;
                char *utex=mtex;int utw=mtw,uth=mth;
                float ax=obj9px[a],ay=obj9py[a],bx=obj9px[b],by=obj9py[b],cx2=obj9px[c],cy2=obj9py[c];
                {int mnx=(int)ax,mxx=(int)ax,mny=(int)ay,mxy=(int)ay;
                 if((int)bx<mnx)mnx=(int)bx;if((int)bx>mxx)mxx=(int)bx;
                 if((int)cx2<mnx)mnx=(int)cx2;if((int)cx2>mxx)mxx=(int)cx2;
                 if((int)by<mny)mny=(int)by;if((int)by>mxy)mxy=(int)by;
                 if((int)cy2<mny)mny=(int)cy2;if((int)cy2>mxy)mxy=(int)cy2;
                 if(mxx<clip_x0||mnx>=clip_x1||mxy<clip_y0||mny>=clip_y1) continue;}
                if(textured){
                    u0=mdl->uvs[mdl->tris[ti2].ua].u;v0=mdl->uvs[mdl->tris[ti2].ua].v;
                    u1=mdl->uvs[mdl->tris[ti2].ub].u;v1=mdl->uvs[mdl->tris[ti2].ub].v;
                    u2=mdl->uvs[mdl->tris[ti2].uc].u;v2=mdl->uvs[mdl->tris[ti2].uc].v;
                    if(mmip){
                        long sa=(long)((bx-ax)*(cy2-ay)-(cx2-ax)*(by-ay));
                        float uvx=(u1-u0)*(v2-v0)-(u2-u0)*(v1-v0);
                        float texA,scrA;
                        if(sa<0)sa=-sa;if(uvx<0.0f)uvx=-uvx;
                        texA=uvx*(float)mtw*(float)mth;
                        scrA=(float)sa*0.5f;if(scrA<1.0f)scrA=1.0f;
                        if(texA>scrA*4.0f){utex=mmip;utw=mmw;uth=mmh;}
                    }
                }
                raster_tri_z(vid,zbuf,W,H,
                    ax,ay,u0,v0,obj9cv[a][2],
                    bx,by,u1,v1,obj9cv[b][2],
                    cx2,cy2,u2,v2,obj9cv[c][2],
                    textured?utex:NULL,utw,uth,flatcol);
            } else {
                // ---- Via de recorte: cruza el near plane ----
                CVert in[8],out[10];
                int nin=3,nout=0,k;
                float sxf[10],syf[10],sw[10];
                int mnx=999999,mxx=-999999,mny=999999,mxy=-999999;
                in[0].cx=obj9cv[a][0];in[0].cy=obj9cv[a][1];in[0].cz=obj9cv[a][2];
                in[1].cx=obj9cv[b][0];in[1].cy=obj9cv[b][1];in[1].cz=obj9cv[b][2];
                in[2].cx=obj9cv[c][0];in[2].cy=obj9cv[c][1];in[2].cz=obj9cv[c][2];
                if(textured){
                    in[0].u=mdl->uvs[mdl->tris[ti2].ua].u;in[0].v=mdl->uvs[mdl->tris[ti2].ua].v;
                    in[1].u=mdl->uvs[mdl->tris[ti2].ub].u;in[1].v=mdl->uvs[mdl->tris[ti2].ub].v;
                    in[2].u=mdl->uvs[mdl->tris[ti2].uc].u;in[2].v=mdl->uvs[mdl->tris[ti2].uc].v;
                } else {
                    in[0].u=in[0].v=in[1].u=in[1].v=in[2].u=in[2].v=0.0f;
                }
                for(k=0;k<nin;k++){
                    CVert *cur=&in[k],*nxt=&in[(k+1)%nin];
                    int curIn=(cur->cz>=NEAR_PLANE),nxtIn=(nxt->cz>=NEAR_PLANE);
                    if(curIn)out[nout++]=*cur;
                    if(curIn!=nxtIn&&nout<10){
                        float t=(NEAR_PLANE-cur->cz)/(nxt->cz-cur->cz);
                        out[nout].cx=cur->cx+(nxt->cx-cur->cx)*t;
                        out[nout].cy=cur->cy+(nxt->cy-cur->cy)*t;
                        out[nout].cz=NEAR_PLANE;
                        out[nout].u =cur->u +(nxt->u -cur->u )*t;
                        out[nout].v =cur->v +(nxt->v -cur->v )*t;
                        nout++;
                    }
                }
                if(nout<3)continue;
                for(k=0;k<nout;k++){
                    float w=out[k].cz;if(w<NEAR_PLANE)w=NEAR_PLANE;
                    float inv=fast_recip(w);
                    int ix2,iy2;
                    sxf[k]=g_hw+out[k].cx*g_focal*inv;
                    syf[k]=g_hh-out[k].cy*g_focal*inv;
                    sw[k]=w;
                    ix2=fast_ftol(sxf[k]);iy2=fast_ftol(syf[k]);
                    if(ix2<mnx)mnx=ix2;if(ix2>mxx)mxx=ix2;
                    if(iy2<mny)mny=iy2;if(iy2>mxy)mxy=iy2;
                }
                if(mxx<clip_x0||mnx>=clip_x1||mxy<clip_y0||mny>=clip_y1)continue;
                for(k=1;k<nout-1;k++){
                    raster_tri_z(vid,zbuf,W,H,
                        sxf[0],syf[0],out[0].u,out[0].v,sw[0],
                        sxf[k],syf[k],out[k].u,out[k].v,sw[k],
                        sxf[k+1],syf[k+1],out[k+1].u,out[k+1].v,sw[k+1],
                        textured?mtex:NULL,mtw,mth,flatcol);
                }
            }
        }
    }
}

// Renderiza UNA vista (viewport) en el buffer. El z-buffer/buffer usan el ancho
// completo W como stride; el dibujo se limita al rect del viewport (clip_*).
static void render_view(M9View *v,char *vid,int W,int H){
    float Cx,Cy,Cz,yaw,pitch,ysin,ycos,psin,pcos;
    float focal,hw,hh,fcull;
    int i,ndraw,cbase;
    int vx,vy,vw,vh;

    // Resolver el rect del viewport (vw/vh==0 -> pantalla completa)
    vx=v->vx; vy=v->vy; vw=v->vw; vh=v->vh;
    if(vw<=0){vx=0;vw=W;} if(vh<=0){vy=0;vh=H;}
    if(vx<0){vw+=vx;vx=0;} if(vy<0){vh+=vy;vy=0;}
    if(vx+vw>W)vw=W-vx; if(vy+vh>H)vh=H-vy;
    if(vw<=0||vh<=0)return;
    clip_x0=vx; clip_x1=vx+vw; clip_y0=vy; clip_y1=vy+vh;

    if(!get_camera(v->cam,v->bind,&Cx,&Cy,&Cz,&yaw,&pitch,&cbase))return;

    // --- Colision: empujar la camara fuera de las paredes y reescribir su
    //     posicion en el proceso (asi advance/xadvance "no atraviesan" muros) --
    if(m9_collision && cbase>=0 && (n_walls>0 || (m9_step>0.0f && n_floors>0))){
        float r=(float)mem[cbase+P_RADIUS]/m9_unitscale;
        float feet=(float)mem[cbase+P_Z]/m9_unitscale;   // pies del jugador (uds OBJ)
        float eyeoff=Cy-feet;                             // ojo por encima de los pies
        if(r<=0.0f) r=(float)COLLIDE_DEF/m9_unitscale;
        // Paredes: deslizamiento (las <= m9_step de alto no bloquean: son escalones
        // que el floor-follow sube). Barrido anti-tunneling antes del deslizamiento.
        if(n_walls>0){
            if(v->haslast) collide_swept(v->lastx,v->lastz,&Cx,&Cz,Cy,r,feet,m9_step);
            collide_xz(&Cx,&Cz,Cy,r,feet,m9_step);
            v->lastx=Cx; v->lastz=Cz; v->haslast=1;
        }
        // Escalones y rampas (floor-follow): subir los pies al suelo que hay debajo,
        // siempre que el desnivel sea <= m9_step. NO baja los pies (eso lo hace la
        // gravedad del PRG). El ojo (Cy) sube con los pies para este mismo frame.
        if(m9_step>0.0f && n_floors>0){
            float fy;
            if(floor_height(Cx,Cz,feet+m9_step,&fy) && feet<fy) feet=fy;
            Cy=feet+eyeoff;
            {float fz=feet*m9_unitscale; mem[cbase+P_Z]=(int)(fz>=0?fz+0.5f:fz-0.5f);}
        }
        {float fx=Cx*m9_unitscale, fz=Cz*m9_unitscale;
         mem[cbase+P_X]=(int)(fx>=0?fx+0.5f:fx-0.5f);
         mem[cbase+P_Y]=(int)(fz>=0?fz+0.5f:fz-0.5f);}
    }

    {int yi=(int)(yaw*TRIG_K)&TRIG_MASK; ysin=sin_tab[yi]; ycos=cos_tab[yi];}
    {int pi2=(int)(pitch*TRIG_K)&TRIG_MASK; psin=sin_tab[pi2]; pcos=cos_tab[pi2];}
    focal=(float)vw*FOCAL_K; hw=(float)vx+(float)vw*0.5f; hh=(float)vy+(float)vh*0.5f;

    // Distancia de corte (far clip): far_clip y, si hay niebla, fog_far (lo que
    // queda detras de la niebla es color de fondo, no hace falta dibujarlo).
    fcull=far_clip;
    if(fog_on&&fog_far>0.0f){ if(fcull<=0.0f||fog_far<fcull) fcull=fog_far; }

    // --- Fondo (color de ambiente) limitado al rect del viewport ------------
    // Con line doubler: solo limpiar las lineas que se van a renderizar; el
    // resto se duplican luego. Usamos memset (mas rapido que el bucle manual).
    {
        int step=m9_downscale>1?m9_downscale:1;
        if(sky_on && sky_data && vw<=SKY_MAXDIM && vh<=SKY_MAXDIM){
            render_sky(vx,vy,vw,vh,focal,hh,yaw,pitch,vid,W,step);   // cielo panoramico
        } else {
            unsigned char bg=(unsigned char)PAL_ENV;
            int yy;
            for(yy=vy; yy<vy+vh; yy+=step)
                memset((unsigned char*)vid+(long)yy*W+vx, (int)bg, (size_t)vw);  // fondo plano
        }
    }

    // Z-buffer limitado al rect del viewport (limpiar a 0 = lejos)
    {int yy, step=m9_downscale>1?m9_downscale:1;
     for(yy=vy; yy<vy+vh; yy+=step)
         memset(zbuf+(long)yy*W+vx, 0, (size_t)vw*2);
    }

    // 1. Guardar los parametros de camara de esta vista (g_*) para la
    //    transformacion PEREZOSA de vertices, e incrementar el sello de frame
    //    (vstamp y tstamp). Cada vertice se transforma bajo demanda la primera vez
    //    que un triangulo visible lo necesita (xform_vertex desde consider_tri),
    //    asi los vertices de celdas descartadas por la rejilla ni se tocan.
    g_Cx=Cx;g_Cy=Cy;g_Cz=Cz; g_ysin=ysin;g_ycos=ycos;g_psin=psin;g_pcos=pcos;
    g_focal=focal;g_hw=hw;g_hh=hh;
    frame_stamp++;

    // 2. Sort: near cull + far clip + backface + FRUSTUM culling. tsort.ci marca
    //    si el triangulo cruza el near (needs_clip) para el rasterizado.
    //    Con rejilla (grid_n): solo se consideran los triangulos de las celdas
    //    dentro del frustum horizontal + far clip (Tier 3). Sin rejilla: todos.
    ndraw=0;
    if(grid_n){
        int gx,gz;
        float fk=0.5f/FOCAL_K;        // tan(medio FOV horizontal)
        for(gz=0;gz<GRID_DIM;gz++){
            float ccz=grid_minz+((float)gz+0.5f)*grid_ch;
            for(gx=0;gx<GRID_DIM;gx++){
                int cell=gz*GRID_DIM+gx, s=grid_start[cell], e=grid_start[cell+1], k;
                float ccx,dx,dz,rx,rz,lim;
                if(s>=e) continue;                 // celda vacia
                ccx=grid_minx+((float)gx+0.5f)*grid_cw;
                dx=ccx-Cx; dz=ccz-Cz;
                rx=dx*ysin+dz*ycos;                // eje X de camara (yaw, sin pitch)
                rz=dx*ycos-dz*ysin;                // hacia delante (el pitch no afecta a XZ)
                if(rz < -grid_cellrad) continue;   // celda enteramente detras
                if(fcull>0.0f && rz-grid_cellrad>fcull) continue;   // mas alla del far clip
                lim=fk*(rz+grid_cellrad)+grid_cellrad;              // frustum horizontal
                if(rx>lim||-rx>lim) continue;
                for(k=s;k<e;k++){
                    int t=grid_items[k];
                    if(tstamp[t]==frame_stamp) continue;   // ya procesado (otra celda)
                    tstamp[t]=frame_stamp;
                    consider_tri(t,fcull,&ndraw);
                }
            }
        }
    } else {
        for(i=0;i<n_tris;i++) consider_tri(i,fcull,&ndraw);
    }

    // 3. BUCKET SORT front-to-back en O(n): cuantiza la profundidad en NBUCKETS
    //    cubetas y ordena por conteo (no comparaciones). Con z-buffer el orden
    //    EXACTO dentro de una cubeta es irrelevante (el z-buffer decide la
    //    oclusion); basta el orden grueso cerca->lejos para que el z-test
    //    rechace pronto lo tapado. Escala O(n) frente al O(n^2) del insertion.
    {
        int j,bk;
        float dmin=1e30f,dmax=-1e30f,inv;
        for(j=0;j<ndraw;j++){
            float d=tsort[j].depth;
            if(d<dmin)dmin=d; if(d>dmax)dmax=d;
        }
        if(dmax<=dmin){
            for(j=0;j<ndraw;j++)order[j]=j;
        } else {
            inv=(float)(NBUCKETS-1)/(dmax-dmin);
            for(j=0;j<=NBUCKETS;j++)bcnt[j]=0;
            for(j=0;j<ndraw;j++){
                bk=(int)((tsort[j].depth-dmin)*inv);
                if(bk<0)bk=0; else if(bk>=NBUCKETS)bk=NBUCKETS-1;
                bcnt[bk+1]++;
            }
            for(j=1;j<=NBUCKETS;j++)bcnt[j]+=bcnt[j-1];   // prefijo -> inicio de cada cubeta
            for(j=0;j<ndraw;j++){
                bk=(int)((tsort[j].depth-dmin)*inv);
                if(bk<0)bk=0; else if(bk>=NBUCKETS)bk=NBUCKETS-1;
                order[bcnt[bk]++]=j;
            }
        }
    }

    // 4. Rasterizar. Via RAPIDA si el tri no cruza el near (mayoria): usa la
    //    proyeccion ya calculada, sin recorte. Si cruza, recorte Sutherland-H.
    for(i=0;i<ndraw;i++){
        int oi=order[i];
        int ti=tsort[oi].idx;
        int a=mesh_t[ti].a,b=mesh_t[ti].b,c=mesh_t[ti].c;
        // Seleccion de textura por material: si el slot del tri no tiene textura,
        // cae al slot 0 (textura por defecto cargada en LOAD_WLD9). Costo: 1 check
        // por triangulo, fuera del bucle de pixels (impacto en rendimiento nulo).
        {int mat=(int)mesh_t[ti].mat;
        char *mtex=mat_data[mat]?mat_data[mat]:mat_data[0];
        int   mtw =mat_data[mat]?mat_w[mat]:mat_w[0];
        int   mth =mat_data[mat]?mat_h[mat]:mat_h[0];
        char *mmip=mat_data[mat]?mat_mip[mat]:mat_mip[0];
        int   mmw =mat_data[mat]?matm_w[mat]:matm_w[0];
        int   mmh =mat_data[mat]?matm_h[mat]:matm_h[0];
        int textured=(mtex&&has_uvs&&mesh_t[ti].ua>=0&&mesh_t[ti].ub>=0&&mesh_t[ti].uc>=0);
        unsigned char flatcol = textured?0:mesh_t[ti].flat;

        if(tsort[oi].ci==0){
            // ---- Via rapida: triangulo entero delante del near ----
            int ax=psx[a],ay=psy[a],bx=psx[b],by=psy[b],cx2=psx[c],cy2=psy[c];
            int mnx,mxx,mny,mxy;
            float u0=0,v0=0,u1=0,v1=0,u2=0,v2=0;
            mnx=ax; if(bx<mnx)mnx=bx; if(cx2<mnx)mnx=cx2;
            mxx=ax; if(bx>mxx)mxx=bx; if(cx2>mxx)mxx=cx2;
            mny=ay; if(by<mny)mny=by; if(cy2<mny)mny=cy2;
            mxy=ay; if(by>mxy)mxy=by; if(cy2>mxy)mxy=cy2;
            if(mxx<clip_x0||mnx>=clip_x1||mxy<clip_y0||mny>=clip_y1){continue;}
            {
            char *utex=mtex; int utw=mtw,uth=mth;
            if(textured){
                u0=mesh_uv[mesh_t[ti].ua].u; v0=mesh_uv[mesh_t[ti].ua].v;
                u1=mesh_uv[mesh_t[ti].ub].u; v1=mesh_uv[mesh_t[ti].ub].v;
                u2=mesh_uv[mesh_t[ti].uc].u; v2=mesh_uv[mesh_t[ti].uc].v;
                // LOD: si el triangulo minifica mucho la textura usar el mipmap.
                if(mmip){
                    long sa=(long)(bx-ax)*(long)(cy2-ay)-(long)(cx2-ax)*(long)(by-ay);
                    float uvx=(u1-u0)*(v2-v0)-(u2-u0)*(v1-v0);
                    float texA,scrA;
                    if(sa<0)sa=-sa; if(uvx<0.0f)uvx=-uvx;
                    texA=uvx*(float)mtw*(float)mth;
                    scrA=(float)sa*0.5f; if(scrA<1.0f)scrA=1.0f;
                    if(texA>scrA*4.0f){utex=mmip;utw=mmw;uth=mmh;}
                }
            }
            raster_tri_z(vid,zbuf,W,H,
                psxf[a],psyf[a],u0,v0,camv[a][2],
                psxf[b],psyf[b],u1,v1,camv[b][2],
                psxf[c],psyf[c],u2,v2,camv[c][2],
                textured?utex:0, utw, uth, flatcol);
            }
            continue;
        }

        // ---- Via de recorte: el triangulo cruza el plano cercano ----
        {
        CVert in[8],out[10];
        int nin=3,nout=0,k;
        float sxf[10],syf[10],sw[10];   // pantalla SUBPIXEL (para el rasterizado)
        int mnx=999999,mxx=-999999,mny=999999,mxy=-999999;
        in[0].cx=camv[a][0];in[0].cy=camv[a][1];in[0].cz=camv[a][2];
        in[1].cx=camv[b][0];in[1].cy=camv[b][1];in[1].cz=camv[b][2];
        in[2].cx=camv[c][0];in[2].cy=camv[c][1];in[2].cz=camv[c][2];
        if(textured){
            in[0].u=mesh_uv[mesh_t[ti].ua].u; in[0].v=mesh_uv[mesh_t[ti].ua].v;
            in[1].u=mesh_uv[mesh_t[ti].ub].u; in[1].v=mesh_uv[mesh_t[ti].ub].v;
            in[2].u=mesh_uv[mesh_t[ti].uc].u; in[2].v=mesh_uv[mesh_t[ti].uc].v;
        }else{
            in[0].u=in[0].v=in[1].u=in[1].v=in[2].u=in[2].v=0.0f;
        }
        for(k=0;k<nin;k++){
            CVert *cur=&in[k], *nxt=&in[(k+1)%nin];
            int curIn=(cur->cz>=NEAR_PLANE), nxtIn=(nxt->cz>=NEAR_PLANE);
            if(curIn) out[nout++]=*cur;
            if(curIn!=nxtIn && nout<10){
                float t=(NEAR_PLANE-cur->cz)/(nxt->cz-cur->cz);
                out[nout].cx=cur->cx+(nxt->cx-cur->cx)*t;
                out[nout].cy=cur->cy+(nxt->cy-cur->cy)*t;
                out[nout].cz=NEAR_PLANE;
                out[nout].u =cur->u +(nxt->u -cur->u )*t;
                out[nout].v =cur->v +(nxt->v -cur->v )*t;
                nout++;
            }
        }
        if(nout<3)continue;
        for(k=0;k<nout;k++){
            float w=out[k].cz; if(w<NEAR_PLANE)w=NEAR_PLANE;
            float inv=fast_recip(w);
            int ix,iy;
            sxf[k]=hw + out[k].cx*focal*inv;     // subpixel (float)
            syf[k]=hh - out[k].cy*focal*inv;
            sw[k] =w;
            ix=fast_ftol(sxf[k]); iy=fast_ftol(syf[k]);   // entero solo para el bbox
            if(ix<mnx)mnx=ix; if(ix>mxx)mxx=ix;
            if(iy<mny)mny=iy; if(iy>mxy)mxy=iy;
        }
        if(mxx<clip_x0||mnx>=clip_x1||mxy<clip_y0||mny>=clip_y1)continue;
        for(k=1;k<nout-1;k++){
            raster_tri_z(vid,zbuf,W,H,
                sxf[0],syf[0],out[0].u,out[0].v,sw[0],
                sxf[k],syf[k],out[k].u,out[k].v,sw[k],
                sxf[k+1],syf[k+1],out[k+1].u,out[k+1].v,sw[k+1],
                textured?mtex:0, mtw, mth, flatcol);
        }
        }
        }   // cierre del bloque {int mat=...}
    }

    // --- Objetos 3D (DRAW_OBJ9): renderizar despues del mundo para que el
    //     z-buffer ya tenga la geometria estatica y la oclusion sea correcta. ---
    render_obj9_instances(vid,W,H);

    // --- Billboards dibujados por la DLL en ESTE viewport (multi-vista) -------
    // Solo si hay un FPG cargado en la DLL (MODE9_LOADFPG). Cada proceso c_m9 se
    // proyecta con la camara de ESTA vista y se dibuja con oclusion por pixel.
    // No se dibuja el marcador de la propia camara de la vista.
    if(n_fpgspr>0){
        int camid = v->bind ? mem[v->bind+1] : v->cam;
        int first=*_id_init_offset, last=*_id_end_offset, step=*_process_size, b;
        if(step>0) for(b=first;b<=last;b+=step){
            int gr,si;
            float Px,Py,Pz,ocx,ocy,ocz,inv;
            if(mem[b+P_CTYPE]!=m9_ctype) continue;
            if(mem[b+P_ID]==0||mem[b+P_STATUS]==0||mem[b+P_ID]==camid) continue;
            Px=(float)mem[b+P_X]/m9_unitscale; Pz=(float)mem[b+P_Y]/m9_unitscale;
            Py=(float)mem[b+P_Z]/m9_unitscale;
            world_to_cam(Px,Py,Pz,Cx,Cy,Cz,ysin,ycos,psin,pcos,&ocx,&ocy,&ocz);
            if(ocz<NEAR_PLANE) continue;
            // grafico: angular (xgraph) segun ESTA vista, o el graph del proceso
            {int xg=mem[b+P_XGRAPH];
             if(xg&&mem[xg]>0){
                 int n=mem[xg],sector; float oa,va,rel,tp=6.2831853f;
                 oa=(float)mem[b+P_ANGLE]*(3.14159265f/180000.0f);
                 va=(float)atan2((double)(Pz-Cz),(double)(Cx-Px));
                 rel=va-oa; rel=rel-tp*(float)floor((double)(rel/tp));
                 sector=(int)(rel/tp*(float)n+0.5f);
                 if(sector>=n)sector-=n; if(sector<0)sector+=n;
                 gr=mem[xg+1+sector];
             } else gr=mem[b+P_GRAPH];
            }
            si=find_sprite(gr); if(si<0) continue;
            inv=fast_recip(ocz);
            {int scx=fast_ftol(hw+ocx*focal*inv), scy=fast_ftol(hh-ocy*focal*inv);
             // El tamaño debe escalar con la resolucion igual que la geometria
             // (que proyecta con focal=vw*FOCAL_K). 320 = ancho de referencia
             // donde size=100 esta calibrado. Sin esto, los billboards encogen
             // (en pixeles fijos) al subir la resolucion.
             int sp9=fast_ftol(100.0f*inv*((float)vw/320.0f)); int fin,zfix;
             int basesize=mem[b+P_SIZE];
             int flv; char *fm;
             if(sp9<1)sp9=1;
             fin=(sp9*basesize)/100; if(fin<1)fin=1;
             zfix=fast_ftol(inv*ZSCALE); if(zfix<0)zfix=0; else if(zfix>65535)zfix=65535;
             // Niebla del sprite segun su distancia (ocz), igual que la geometria.
             flv=fog_on?fog_level(ocz):0;
             fm=(flv>0)?&fog_map[flv*256]:0;
             blit_sprite(si,scx,scy,fin,zfix,vid,W,fm);
            }
        }
    }
    // --- Line doubler: copiar cada linea renderizada a las q-1 siguientes -----
    // Se hace DESPUES de los billboards (que ya escriben con z-test correcto en
    // las lineas pares). Solo el buffer de video; el z-buffer queda con huecos
    // pero se limpia al inicio del siguiente frame, no importa.
    if(m9_downscale>1){
        int yy,qq;
        for(yy=vy; yy<vy+vh; yy+=m9_downscale){
            unsigned char *src=(unsigned char*)vid+(long)yy*W+vx;
            for(qq=1; qq<m9_downscale && yy+qq<vy+vh; qq++)
                memcpy((unsigned char*)vid+(long)(yy+qq)*W+vx, src, (size_t)vw);
        }
    }
    // Nota: la paleta NO se reenvia cada frame (set_palette solo en los setters).
}

// do_render: prepara el buffer y el z-buffer y renderiza todas las vistas
// activas (1 = pantalla completa; >1 = split-screen).
static void do_render(void){
    int W,H,vi;
    char *vid;
    if(!m9_active||!mesh_ok||!_buffer||!_wide||!_height)return;
    vid=(char*)(*((unsigned long*)_buffer));
    if(!vid)return;
    W=*_wide;H=*_height;
    if(W<=0||H<=0)return;

    // Z-buffer (16 bits) a tamaño de pantalla completa; cada vista limpia su rect.
    if(!zbuf||zbuf_w!=W||zbuf_h!=H){
        if(zbuf)div_free(zbuf);
        zbuf=(unsigned short*)div_malloc((size_t)((long)W*(long)H*(long)sizeof(unsigned short)));
        zbuf_w=W;zbuf_h=H;
    }
    if(!zbuf)return;

    for(vi=0; vi<MAX_VIEWS; vi++)
        if(views[vi].active) render_view(&views[vi],vid,W,H);
    n_obj9_queue=0;   // limpiar cola tras renderizar todos los viewports
}

// ============================================================================
// MODE9_BILLBOARD / MODE9_PROJECT
// ============================================================================
// Proyecta (wx,wy,wz) uds DIV2 a pantalla. Devuelve 1 visible (escribe sx,sy y
// sz=profundidad en uds DIV2, szpct=escala%) o 0 si tras la camara.
static int project_world(int wx,int wy,int wz,int *sx,int *sy,int *depthu,int *sizepct){
    float Cx,Cy,Cz,yaw,pitch,ysin,ycos,psin,pcos;
    float Px,Py,Pz,ocx,ocy,ocz,focal,hw,hh,w;
    int W,H;
    if(!m9_active||!_wide||!_height)return 0;
    W=*_wide;H=*_height;
    if(!get_camera(m9_camera,m9_bind,&Cx,&Cy,&Cz,&yaw,&pitch,0))return 0;
    {int yi=(int)(yaw*TRIG_K)&TRIG_MASK; ysin=sin_tab[yi]; ycos=cos_tab[yi];}
    {int pi2=(int)(pitch*TRIG_K)&TRIG_MASK; psin=sin_tab[pi2]; pcos=cos_tab[pi2];}
    Px=(float)wx/m9_unitscale; Pz=(float)wy/m9_unitscale; Py=(float)wz/m9_unitscale;
    world_to_cam(Px,Py,Pz,Cx,Cy,Cz,ysin,ycos,psin,pcos,&ocx,&ocy,&ocz);
    if(ocz<NEAR_PLANE)return 0;
    focal=(float)W*FOCAL_K; hw=(float)W*0.5f; hh=(float)H*0.5f;
    w=ocz;
    *sx=(int)(hw+ocx*focal/w);
    *sy=(int)(hh-ocy*focal/w);
    *depthu=(int)(w*m9_unitscale);
    // escala: 100% a 1 unidad OBJ de distancia (ajustable con basesize). Escala
    // con la resolucion (320 = ancho de referencia) para no encoger a mas res.
    {int s=(int)(100.0f/w*((float)W/320.0f)+0.5f); if(s<1)s=1; if(s>2000)s=2000; *sizepct=s;}

    // OCLUSION contra el z-buffer: si en el pixel del sprite hay geometria mas
    // cercana, el sprite esta detras de una pared -> oculto (estilo modo 7/Doom).
    // Usa el z-buffer del frame ANTERIOR (se rellena en do_render, que corre
    // despues de la logica de procesos): 1 frame de desfase, imperceptible.
    if(m9_occlude && zbuf && zbuf_w==W && zbuf_h==H){
        int ix=*sx, iy=*sy;
        if(ix>=0&&ix<W&&iy>=0&&iy<H){
            int zspr=(int)((1.0f/w)*ZSCALE);
            int zgeo=(int)zbuf[iy*W+ix];
            // bias ~3% para que un sprite pegado a una superficie no parpadee
            if(zgeo > zspr + (zspr>>5)) return 0;
        }
    }
    return 1;
}

// Si el proceso tiene xgraph (tabla de graficos angulares, como en el modo 7),
// elige el grafico segun el angulo desde el que la camara ve al sprite.
// Tabla: mem[xg]=N (nº de graficos), mem[xg+1..xg+N]=codigos repartidos en 360º.
static void pick_angular_graph(int base,int wx,int wy){
    int xg=mem[base+P_XGRAPH];
    int n,sector;
    float Cx,Cy,Cz,yaw,pitch,Pxw,Pzw,objang,viewang,rel,twopi;
    if(!xg)return;
    n=mem[xg];
    if(n<=0)return;
    if(!get_camera(m9_camera,m9_bind,&Cx,&Cy,&Cz,&yaw,&pitch,0))return;
    Pxw=(float)wx/m9_unitscale; Pzw=(float)wy/m9_unitscale;
    objang =(float)mem[base+P_ANGLE]*(3.14159265f/180000.0f);
    // angulo (convencion DIV2) de la direccion sprite->camara
    viewang=(float)atan2((double)(Pzw-Cz),(double)(Cx-Pxw));
    rel=viewang-objang;
    twopi=6.2831853f;
    rel=rel-twopi*(float)floor((double)(rel/twopi));   // normalizar a [0,2pi)
    sector=(int)(rel/twopi*(float)n+0.5f);
    if(sector>=n)sector-=n; if(sector<0)sector+=n;
    mem[base+P_GRAPH]=mem[xg+1+sector];
}

static void mode9_billboard_fn(void){
    int basesize=getparm(),wz=getparm(),wy=getparm(),wx=getparm(),pid=getparm();
    int sx,sy,depthu,sizepct,base;
    base=find_process(pid);
    if(base<0){retval(0);return;}
    if(!project_world(wx,wy,wz,&sx,&sy,&depthu,&sizepct)){
        mem[base+P_SIZE]=0;          // tras la camara u oculto por geometria
        retval(0);return;
    }
    mem[base+P_X]=sx;
    mem[base+P_Y]=sy;
    mem[base+P_SIZE]=(sizepct*basesize)/100;
    if(mem[base+P_SIZE]<1)mem[base+P_SIZE]=1;
    mem[base+P_Z]=depthu;            // mayor profundidad -> dibujado detras
    pick_angular_graph(base,wx,wy);  // grafico segun angulo (si hay xgraph)
    retval(1);
}

// MODE9_OCCLUDE(on): 1=ocultar billboards tapados por geometria (def), 0=off.
static void mode9_occlude_fn(void){
    m9_occlude=getparm()?1:0;
    retval(0);
}
// MODE9_CTYPE(n): valor de la constante c_m9 (ctype de billboard automatico).
// Debe coincidir con CONST c_m9 del PRG. Por defecto 200.
static void mode9_ctype_fn(void){
    int n=getparm();
    if(n>2) m9_ctype=n;   // no permitir colisionar con c_screen/scroll/m7
    retval(0);
}

// ============================================================================
// Billboards automaticos (ctype = c_m9), al estilo c_m7 del modo 7:
// el usuario solo pone ctype=c_m9 y x,y,z (MUNDO), size (escala %), graph y
// angle en el proceso; NO llama a nada cada frame. Tras pintar el escenario 3D
// se recorren todos los procesos c_m9, se proyectan y se convierten a c_screen
// (con x,y de pantalla, size escalado por distancia y z=profundidad) para que
// DIV2 los dibuje con su propio escalador. Despues del pintado se restauran sus
// coordenadas de mundo y su ctype c_m9 (restore_m9_sprites en post_process_buffer).
// ============================================================================
static void process_m9_sprites(void){
    int first,last,step,b;
    n_m9spr=0;
    if(!m9_active) return;
    step=*_process_size; if(step<=0) return;
    first=*_id_init_offset; last=*_id_end_offset;
    for(b=first; b<=last; b+=step){
        if(mem[b+P_CTYPE]!=m9_ctype) continue;
        if(mem[b+P_ID]==0 || mem[b+P_STATUS]==0) continue;   // slot libre/muerto
        if(n_m9spr>=MAX_SPR) break;
        {
            int wx=mem[b+P_X], wy=mem[b+P_Y], wz=mem[b+P_Z];
            int basesize=mem[b+P_SIZE];
            int sx,sy,depthu,sizepct;
            // guardar el estado de mundo para restaurarlo tras el pintado
            m9spr[n_m9spr].base=b;
            m9spr[n_m9spr].wx=wx; m9spr[n_m9spr].wy=wy; m9spr[n_m9spr].wz=wz;
            m9spr[n_m9spr].sz=basesize; m9spr[n_m9spr].gr=mem[b+P_GRAPH];
            m9spr[n_m9spr].ct=mem[b+P_CTYPE];
            n_m9spr++;
            // convertir a c_screen para que DIV2 lo pinte como sprite 2D
            mem[b+P_CTYPE]=C_SCREEN;
            if(!project_world(wx,wy,wz,&sx,&sy,&depthu,&sizepct)){
                mem[b+P_SIZE]=0;            // tras la camara u oculto -> no pintar
            } else {
                int s=(sizepct*basesize)/100;   // escala = distancia * size_base%
                if(s<1)s=1;
                mem[b+P_X]=sx; mem[b+P_Y]=sy;
                mem[b+P_SIZE]=s;
                mem[b+P_Z]=depthu;          // mayor profundidad -> pintado detras
                pick_angular_graph(b,wx,wy);// grafico segun angulo (si hay xgraph)
            }
        }
    }
}
static void restore_m9_sprites(void){
    int i;
    for(i=0;i<n_m9spr;i++){
        int b=m9spr[i].base;
        mem[b+P_X]=m9spr[i].wx; mem[b+P_Y]=m9spr[i].wy; mem[b+P_Z]=m9spr[i].wz;
        mem[b+P_SIZE]=m9spr[i].sz; mem[b+P_GRAPH]=m9spr[i].gr;
        mem[b+P_CTYPE]=m9spr[i].ct;
    }
    n_m9spr=0;
}

static void mode9_project_fn(void){
    int osz=getparm(),osy=getparm(),osx=getparm();
    int wz=getparm(),wy=getparm(),wx=getparm();
    int sx,sy,depthu,sizepct;
    if(!project_world(wx,wy,wz,&sx,&sy,&depthu,&sizepct)){
        mem[osx]=0;mem[osy]=0;mem[osz]=0;retval(0);return;
    }
    mem[osx]=sx;mem[osy]=sy;mem[osz]=depthu;
    retval(1);
}

// ============================================================================
// Callbacks de DIV2
// ============================================================================
// El escenario 3D se dibuja como FONDO: DIV2 pinta los sprites/procesos encima
// (estilo modo 7). Asi los billboards quedan delante del escenario.
// Tras pintar el escenario (y rellenar el z-buffer), se preparan los billboards
// c_m9: se proyectan y se convierten a c_screen para que DIV2 los pinte.
void background_to_buffer(void){
    do_render();
    // Si hay un FPG cargado en la DLL, los billboards los dibuja la propia DLL
    // en cada viewport (multi-vista, ver render_view). Si no, se usa la ruta
    // "c_screen" de DIV2 (1 sola vista) convirtiendo los procesos c_m9.
    if(n_fpgspr==0) process_m9_sprites();
}

// Tras pintar los sprites, restaurar las coordenadas de mundo y el ctype c_m9
// de los billboards (asi el PRG los maneja con coordenadas de mundo).
void post_process_buffer(void){
    restore_m9_sprites();
}


// MODE9_DOWNSCALE(n): renderiza por debajo de la resolucion nativa duplicando
// lineas, al estilo SNES Doom (antes MODE9_QUALITY).
//   1 = resolucion nativa (def)
//   2 = 1 de cada 2 lineas -> la otra se duplica (~2x velocidad de fill)
//   3 = 1 de cada 3 lineas (~3x)
//   4 = 1 de cada 4 lineas (~4x, pixel art muy gordo)
// La ganancia real depende del fill rate (numero de pixels escritos/frame).
// En escenas con muchos triangulos y pocos pixels tapados, x2 casi dobla los FPS.
static void mode9_downscale_fn(void){
    int q=getparm();
    if(q>=1&&q<=4) m9_downscale=q;
    retval(0);
}

// MODE9_PERSPECTIVE(on): correccion de perspectiva de la textura.
//   0 = RENDIMIENTO (def): correccion afin a tramos de 16 px (rapido; la textura
//       puede "ondular" levemente en superficies muy inclinadas).
//   1 = CALIDAD: un 1/w exacto por pixel -> texturas perfectas, mas lento.
// Por defecto siempre rendimiento; el usuario activa la calidad si la quiere.
static void mode9_perspective_fn(void){
    int on=getparm();
    m9_texseg = on ? 1 : TEX_SEG;
    if(m9_texseg<1) m9_texseg=1;
    retval(0);
}

// ============================================================================
// Puntos de entrada de la DLL
// ============================================================================
// load_obj9_texture: carga la textura MAP del modelo (opcional). tname=="" o "0"
// deja el modelo en flat-shading. Igual logica que load_material_file pero para
// un Obj9Model. Compartida por LOAD_OBJ9 y LOAD_OBJ9_ANIM.
static void load_obj9_texture(Obj9Model *mdl,char *tname){
    if(tname[0]&&tname[0]!='0'){
        char magic[8]; FILE *f; int w,h,npoints;
        f=div_fopen(tname,"rb");
        if(f){
            if((int)fread(magic,1,8,f)==8&&magic[0]=='m'&&magic[1]=='a'&&magic[2]=='p'){
                unsigned short sw=0,sh=0,snp=0;
                if(fread(&sw,2,1,f)==1&&fread(&sh,2,1,f)==1){
                    fseek(f,1380L,SEEK_CUR);
                    if(fread(&snp,2,1,f)==1){
                        w=(int)sw;h=(int)sh;npoints=(int)snp;
                        if(w>0&&h>0&&w<=1024&&h<=1024){
                            if(npoints>0)fseek(f,(long)npoints*4L,SEEK_CUR);
                            mdl->tex=(char*)div_malloc((size_t)(w*h));
                            if(mdl->tex&&(int)fread(mdl->tex,1,(size_t)(w*h),f)==w*h){
                                int mx,my;
                                mdl->tw=w;mdl->th=h;
                                if(w>=2&&h>=2){
                                    int mw=w>>1,mh=h>>1;
                                    mdl->mip=(char*)div_malloc((size_t)(mw*mh));
                                    if(mdl->mip){
                                        for(my=0;my<mh;my++){
                                            char *d=mdl->mip+(long)my*mw;
                                            char *s=mdl->tex+(long)(my<<1)*w;
                                            for(mx=0;mx<mw;mx++)d[mx]=s[mx<<1];
                                        }
                                        mdl->mw=mw;mdl->mh=mh;
                                    }
                                }
                            } else {
                                if(mdl->tex){div_free(mdl->tex);mdl->tex=NULL;}
                            }
                        }
                    }
                }
            }
            div_fclose(f);
        }
    }
}

// ============================================================================
// LOAD_OBJ9(obj, tex, scale): carga un modelo 3D de objeto (NPC/prop 3D).
//   obj   : fichero .OBJ del modelo (Y-up, triangulado; UVs opcionales).
//   tex   : textura .MAP ("" = flat-shading con la rampa de sombreado del mundo).
//   scale : uds DIV2 por unidad OBJ del modelo (igual que unitscale en LOAD_WLD9).
// Devuelve handle 1..MAX_OBJ9_MODELS (0 si fallo o sin slots libres).
// Los modelos se conservan hasta STOP_MODE9/divend; no hace falta recargar
// en cada frame.
// ============================================================================
static void load_obj9_fn(void){
    int scale  =getparm();
    int tex_off=getparm();
    int obj_off=getparm();
    char oname[64],tname[64];
    Obj9Model *mdl;
    float sfac;
    div2c(obj_off,oname,sizeof(oname));
    div2c(tex_off,tname,sizeof(tname));
    if(n_obj9_models>=MAX_OBJ9_MODELS){retval(0);return;}
    mdl=&obj9_models[n_obj9_models];
    mdl->verts=NULL;mdl->vframes=NULL;mdl->nframes=1;mdl->uvs=NULL;mdl->tris=NULL;
    mdl->nv=mdl->nuv=mdl->nt=0;
    mdl->tex=NULL;mdl->tw=mdl->th=0;
    mdl->mip=NULL;mdl->mw=mdl->mh=0;
    sfac=(scale>0)?((float)scale/m9_unitscale):1.0f;
    if(!load_obj9_model(mdl,oname,sfac)){retval(0);return;}
    load_obj9_texture(mdl,tname);
    n_obj9_models++;
    retval(n_obj9_models);   // handle 1-based; 0 = error
}

// ============================================================================
// LOAD_OBJ9_ANIM(base, tex, scale, nframes): igual que LOAD_OBJ9 pero carga una
// animacion por vertex morphing. Los fotogramas son ficheros "<base><n>.OBJ":
// base="CAT", nframes=10 -> CAT0.OBJ..CAT9.OBJ. Todos deben compartir topologia
// (mismos triangulos/UVs y mismo numero de vertices); solo cambian las posiciones.
// La animacion ocupa UN SOLO slot de los MAX_OBJ9_MODELS, sin importar nframes.
// Devuelve handle 1..MAX_OBJ9_MODELS (0 si fallo). Animar con DRAW_OBJ9_ANIM.
// ============================================================================
static void load_obj9_anim_fn(void){
    int nframes=getparm();
    int scale  =getparm();
    int tex_off=getparm();
    int base_off=getparm();
    char base[64],tname[64],fname[80];
    Obj9Model *mdl;
    float sfac;
    V3 *block; int f,nv;
    div2c(base_off,base,sizeof(base));
    div2c(tex_off,tname,sizeof(tname));
    if(nframes<1) nframes=1;
    if(n_obj9_models>=MAX_OBJ9_MODELS){retval(0);return;}
    mdl=&obj9_models[n_obj9_models];
    mdl->verts=NULL;mdl->vframes=NULL;mdl->nframes=1;mdl->uvs=NULL;mdl->tris=NULL;
    mdl->nv=mdl->nuv=mdl->nt=0;
    mdl->tex=NULL;mdl->tw=mdl->th=0;
    mdl->mip=NULL;mdl->mw=mdl->mh=0;
    sfac=(scale>0)?((float)scale/m9_unitscale):1.0f;
    // Frame 0: parseo completo (topologia + frame 0 de vertices).
    build_frame_name(fname,base,0);
    if(!load_obj9_model(mdl,fname,sfac)){retval(0);return;}
    nv=mdl->nv;
    if(nframes>1){
        // Reservar el bloque de todos los fotogramas y copiar el frame 0.
        block=(V3*)div_malloc((size_t)((long)nv*nframes*sizeof(V3)));
        if(block){
            for(f=0;f<nv;f++) block[f]=mdl->verts[f];
            div_free(mdl->verts);          // libera la copia de 1 frame
            mdl->verts=block;mdl->vframes=block;mdl->nframes=nframes;
            // Frames 1..nframes-1: solo posiciones, en su offset del bloque.
            for(f=1;f<nframes;f++){
                int got;
                build_frame_name(fname,base,f);
                got=load_obj9_verts_only(fname,block+(long)f*nv,nv,sfac);
                // Si un frame falta o no cuadra en topologia, duplicar el frame 0
                // (degrada a "sin movimiento" en vez de mostrar basura/crashear).
                if(got!=nv){
                    int j; V3 *dst=block+(long)f*nv;
                    for(j=0;j<nv;j++) dst[j]=block[j];
                }
            }
            // NOTA: cargar N frames en una sola llamada es lento en MS-DOS real;
            // el PRG debe desactivar el watchdog (max_process_time=0) alrededor de
            // esta llamada para evitar el error 142. No se puede ceder a FRAME
            // desde dentro de un builtin.
        }
        // Si block==NULL nos quedamos con 1 frame: el modelo sigue siendo valido.
    }
    load_obj9_texture(mdl,tname);
    n_obj9_models++;
    retval(n_obj9_models);
}

// ============================================================================
// DRAW_OBJ9(handle, x, y, z, angle): encola una instancia del modelo 'handle'
// (devuelto por LOAD_OBJ9) en la posicion de mundo (x,y,z) uds DIV2 con la
// orientacion indicada (milesimas de grado, convencion DIV2). Llamar CADA FRAME
// antes de FRAME (igual que DRAW_OBJ en KD3DT). La cola se vacia automaticamente
// despues de que todas las vistas se rendericen.
// ============================================================================
static void draw_obj9_fn(void){
    int angle =getparm();
    int pz    =getparm();
    int py    =getparm();
    int px    =getparm();
    int handle=getparm();
    Obj9Inst *inst; float ar; int ai;
    if(handle<1||handle>n_obj9_models||n_obj9_queue>=MAX_OBJ9_INST){retval(0);return;}
    inst=&obj9_queue[n_obj9_queue];
    inst->midx=handle-1;
    inst->ix=(float)px/m9_unitscale;   // DIV2.x -> OBJ.x
    inst->iz=(float)py/m9_unitscale;   // DIV2.y -> OBJ.z
    inst->iy=(float)pz/m9_unitscale;   // DIV2.z -> OBJ.y (altura)
    ar=(float)angle*(6.2831853f/360000.0f);
    ai=(int)(ar*TRIG_K)&TRIG_MASK;
    inst->ysin=sin_tab[ai];inst->ycos=cos_tab[ai];
    inst->fa=0;inst->fb=0;inst->fblend=0.0f;   // sin animacion (frame 0)
    n_obj9_queue++;
    retval(0);
}

// ============================================================================
// DRAW_OBJ9_ANIM(handle, x, y, z, angle, fpos): como DRAW_OBJ9 pero para modelos
// cargados con LOAD_OBJ9_ANIM. 'fpos' es la posicion de la animacion en 1/256 de
// fotograma: parte entera (fpos>>8) = fotograma, parte baja (fpos&255) = mezcla
// hacia el siguiente. El recorrido es 0..nframes*256 y hace bucle automatico, de
// modo que se interpola suavemente entre keyframes con muy pocos OBJ.
// Ejemplo (10 frames, bucle de 3 s usando timer): ver MODE9.PRG.
// ============================================================================
static void draw_obj9_anim_fn(void){
    int fpos  =getparm();
    int angle =getparm();
    int pz    =getparm();
    int py    =getparm();
    int px    =getparm();
    int handle=getparm();
    Obj9Inst *inst; Obj9Model *mdl; float ar; int ai,nf,fi;
    if(handle<1||handle>n_obj9_models||n_obj9_queue>=MAX_OBJ9_INST){retval(0);return;}
    mdl=&obj9_models[handle-1];
    nf=mdl->nframes; if(nf<1) nf=1;
    inst=&obj9_queue[n_obj9_queue];
    inst->midx=handle-1;
    inst->ix=(float)px/m9_unitscale;
    inst->iz=(float)py/m9_unitscale;
    inst->iy=(float)pz/m9_unitscale;
    ar=(float)angle*(6.2831853f/360000.0f);
    ai=(int)(ar*TRIG_K)&TRIG_MASK;
    inst->ysin=sin_tab[ai];inst->ycos=cos_tab[ai];
    // Descomponer fpos (1/256 de frame) en frame base + mezcla, con bucle.
    if(fpos<0) fpos=0;
    fi=(fpos>>8)%nf;
    inst->fa=fi;
    inst->fb=(fi+1)%nf;                 // bucle: tras el ultimo vuelve al 0
    inst->fblend=(float)(fpos&255)*(1.0f/255.0f);
    n_obj9_queue++;
    retval(0);
}

void __export divlibrary(LIBRARY_PARAMS){
    COM_export("LOAD_WLD9",       load_wld9_fn,       3);
    COM_export("MODE9_SETTEX",    mode9_settex_fn,    1);
    COM_export("MODE9_MATERIAL",  mode9_material_fn,  2);
    COM_export("LOAD_SKY9",       load_sky9_fn,       1);
    COM_export("SKY9_OFF",        sky9_off_fn,        0);
    COM_export("MODE9_LOADFPG",   mode9_loadfpg_fn,   1);
    COM_export("START_MODE9",     start_mode9_fn,     3);
    COM_export("STOP_MODE9",      stop_mode9_fn,      0);
    COM_export("MODE9_SCRW",      mode9_scrw_fn,      0);
    COM_export("MODE9_SCRH",      mode9_scrh_fn,      0);
    COM_export("MODE9_SET",       mode9_set_fn,       2);
    COM_export("MODE9_UNITSCALE", mode9_unitscale_fn, 1);
    COM_export("MODE9_CULL",      mode9_cull_fn,      1);
    COM_export("MODE9_FARCLIP",   mode9_farclip_fn,   1);
    COM_export("MODE9_BIND",      mode9_bind_fn,      1);
    COM_export("SET_ENV_COLOR9",  set_env_color9_fn,  3);
    COM_export("SET_FOG9",        set_fog9_fn,        2);
    COM_export("MODE9_FOG_OFF",   mode9_fog_off_fn,   0);
    COM_export("MODE9_OCCLUDE",   mode9_occlude_fn,   1);
    COM_export("MODE9_CTYPE",     mode9_ctype_fn,     1);
    COM_export("MODE9_COLLISION", mode9_collision_fn, 1);
    COM_export("MODE9_COLLIDE",   mode9_collide_fn,   1);
    COM_export("MODE9_STEP",      mode9_step_fn,      1);
    COM_export("MODE9_DOWNSCALE",  mode9_downscale_fn,  1);
    COM_export("MODE9_PERSPECTIVE", mode9_perspective_fn, 1);
    COM_export("MODE9_SPLIT",     mode9_split_fn,     7);
    COM_export("MODE9_BILLBOARD", mode9_billboard_fn, 5);
    COM_export("MODE9_PROJECT",   mode9_project_fn,   6);
    COM_export("LOAD_OBJ9",       load_obj9_fn,       3);
    COM_export("DRAW_OBJ9",       draw_obj9_fn,       5);
    COM_export("LOAD_OBJ9_ANIM",  load_obj9_anim_fn,  4);
    COM_export("DRAW_OBJ9_ANIM",  draw_obj9_anim_fn,  6);
}

void __export divmain(COMMON_PARAMS){
    int i;
    g_import=DIV_import;g_export=DIV_export;
    #define DIV_import g_import
    #define DIV_export g_export

    AutoLoad();
    GLOBAL_IMPORT();

    // Construir tablas trigonometricas (una sola vez al cargar la DLL).
    // 4096 entradas = resolucion de 0.088 grados, mucho mas fina que la
    // granularidad del angulo DIV2 (1 milesima de grado = 0.001 grados).
    {int i; for(i=0;i<TRIG_SIZE;i++){
        float a=(float)i*(6.2831853f/(float)TRIG_SIZE);
        sin_tab[i]=(float)sin(a); cos_tab[i]=(float)cos(a);
    }}

    m9_active=0;m9_camera=0;m9_height=0;m9_pitch=0;m9_unitscale=100.0f;
    m9_bind=0;m9_region=0;m9_occlude=1;m9_ctype=200;far_clip=0.0f;cull_mode=1;
    m9_collision=0;n_walls=0;m9_downscale=1;m9_texseg=TEX_SEG;
    m9_step=0.0f;n_floors=0;
    grid_n=0;frame_stamp=0;
    grid_items=NULL;grid_cap=0;tstamp=NULL;tstamp_cap=0;
    for(i=0;i<MAX_VERTS;i++) vstamp[i]=0;   // sin sellos rancios entre ejecuciones
    for(i=0;i<MAX_VIEWS;i++){views[i].active=0;views[i].haslast=0;}
    n_m9spr=0;n_fpgspr=0;
    {int m; for(m=0;m<MAX_MATS;m++){mat_data[m]=NULL;mat_w[m]=mat_h[m]=0;mat_mip[m]=NULL;matm_w[m]=matm_h[m]=0;}}
    n_mats=1;
    {int m; for(m=0;m<MAX_OBJ9_MODELS;m++){
        obj9_models[m].verts=NULL;obj9_models[m].vframes=NULL;obj9_models[m].nframes=1;
        obj9_models[m].uvs=NULL;obj9_models[m].tris=NULL;
        obj9_models[m].nv=obj9_models[m].nuv=obj9_models[m].nt=0;
        obj9_models[m].tex=NULL;obj9_models[m].tw=obj9_models[m].th=0;
        obj9_models[m].mip=NULL;obj9_models[m].mw=obj9_models[m].mh=0;
    }}
    n_obj9_models=0;n_obj9_queue=0;
    sky_data=NULL;sky_w=0;sky_h=0;sky_on=0;sky_cd_vw=0;sky_cd_w=0;
    fog_map=NULL;fog_on=0;
    env_r=env_g=env_b=0;
    m9_msg[0]=0;

    DIV_export("background_to_buffer",background_to_buffer);
    DIV_export("post_process_buffer", post_process_buffer);

    // Guardar paleta reservada (rampa flat + entrada de fondo)
    for(i=0;i<PAL_SHADES*3;i++) orig_pal[i]=palette[PAL_BASE*3+i];
    for(i=0;i<3;i++) orig_pal[PAL_SHADES*3+i]=palette[PAL_ENV*3+i];

    // Rampa flat por defecto: gris
    {int j;
     for(j=0;j<PAL_SHADES;j++){
         float t=AMBIENT+(1.0f-AMBIENT)*(float)j/(float)(PAL_SHADES-1);
         palette[(PAL_BASE+j)*3+0]=(char)((int)(50.0f*t+0.5f));
         palette[(PAL_BASE+j)*3+1]=(char)((int)(50.0f*t+0.5f));
         palette[(PAL_BASE+j)*3+2]=(char)((int)(50.0f*t+0.5f));
     }}
    // Fondo por defecto: negro
    palette[PAL_ENV*3+0]=0;palette[PAL_ENV*3+1]=0;palette[PAL_ENV*3+2]=0;
    set_palette=1;

    #undef DIV_import
    #undef DIV_export
}

void __export divend(COMMON_PARAMS){
    int i;
    (void)DIV_import;(void)DIV_export;
    {int m; for(m=0;m<MAX_MATS;m++){
        if(mat_data[m]){div_free(mat_data[m]);mat_data[m]=NULL;mat_w[m]=mat_h[m]=0;}
        if(mat_mip[m]){div_free(mat_mip[m]);mat_mip[m]=NULL;matm_w[m]=matm_h[m]=0;}
    }}
    {int m; for(m=0;m<n_obj9_models;m++){
        // verts == vframes (mismo bloque); liberar una vez y anular ambos.
        if(obj9_models[m].verts){div_free(obj9_models[m].verts);obj9_models[m].verts=NULL;}
        obj9_models[m].vframes=NULL;obj9_models[m].nframes=1;
        if(obj9_models[m].uvs)  {div_free(obj9_models[m].uvs);  obj9_models[m].uvs=NULL;}
        if(obj9_models[m].tris) {div_free(obj9_models[m].tris); obj9_models[m].tris=NULL;}
        if(obj9_models[m].tex)  {div_free(obj9_models[m].tex);  obj9_models[m].tex=NULL;}
        if(obj9_models[m].mip)  {div_free(obj9_models[m].mip);  obj9_models[m].mip=NULL;}
    }}
    n_obj9_models=0;n_obj9_queue=0;
    if(sky_data){div_free(sky_data);sky_data=NULL;sky_w=sky_h=0;sky_on=0;}
    if(grid_items){div_free(grid_items);grid_items=NULL;grid_cap=0;}
    if(tstamp){div_free(tstamp);tstamp=NULL;tstamp_cap=0;}
    if(fog_map){div_free(fog_map);fog_map=NULL;}
    if(zbuf){div_free(zbuf);zbuf=NULL;zbuf_w=zbuf_h=0;}
    free_sprites();
    mesh_ok=0;m9_active=0;
    for(i=0;i<PAL_SHADES*3;i++) palette[PAL_BASE*3+i]=orig_pal[i];
    for(i=0;i<3;i++) palette[PAL_ENV*3+i]=orig_pal[PAL_SHADES*3+i];
    set_palette=1;
}
