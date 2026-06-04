//------------------------------------------------------------------------------
// TITLE:       KD3D.CPP
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        04/06/2026
// DESCRIPTION: Renderizador 3D software para DIV Games Studio 2
//
// Carga mallas en formato OBJ de Blender (ASCII, sin texturas, sin licencia).
// Renderizado software puro: perspectiva + shading plano + backface culling
// + Painter's Algorithm. Sin hardware 3D; funciona en 386/486 a 320x200.
//
// FUNCIONES EXPORTADAS AL PRG:
//
//   KD3D_LOAD(nombre)                   -> tris cargados, 0 si fallo
//      'nombre' es una STRING DIV2 con la ruta del .OBJ (en el dir del juego).
//      Soporta: "v x y z" (vertices) y "f i j k [l]" (caras tri o quad).
//      Caras con UV/normales (f 1/2/3) tambien se aceptan (se ignoran UV/N).
//      Limite: 512 vertices, 1024 triangulos.
//
//   KD3D_DRAW(cx, cy, rx, ry, rz, scale) -> siempre 0
//      cx, cy  : centro de proyeccion en pixels
//      rx,ry,rz: rotacion en grados (0-359), enteros
//      scale   : escala * 100  (100 = tamanyo original, 200 = doble)
//      Dibuja directamente en el buffer de video de DIV2 (buffer actual).
//
//   KD3D_SETCOLOR(r, g, b)              -> siempre 0
//      Establece el color base del objeto (componentes 0-63, formato DIV2).
//      Calcula 16 sombras del color y las carga en paleta[224..239].
//      Llamar antes del primer KD3D_DRAW y cada vez que quieras cambiar color.
//
// PALETA: reserva las entradas 224-239 (16 sombras, de oscuro a brillante).
//         Las restaura al descargar la DLL.
//
//
// EXPORTAR CUBO DESDE BLENDER:
//   File -> Export -> Wavefront (.obj)
//   Marcar "Triangulate Faces" (simplifica el parsing).
//   El fichero resultante debe estar en el directorio del juego.
//------------------------------------------------------------------------------

#define GLOBALS
#include "div.h"
#include <math.h>

// ---- Limites ----------------------------------------------------------------
#define MAX_VERTS    512
#define MAX_TRIS    1024

// ---- Paleta de shading (16 sombras en entradas 224..239) --------------------
#define PAL_BASE     224
#define PAL_SHADES    16
#define AMBIENT      0.20f   // luz ambiente minima (0 = negro puro en sombra)

// ---- Proyeccion (camara en Z=0, objeto en Z=+CAM_DIST) ---------------------
#define CAM_DIST     6.0f
#define FOV        220.0f    // distancia focal en pixels (~320x200)

// ---- Luz fija: vector (0.5, 1.0, -0.5) normalizado -------------------------
#define LX  0.4082f
#define LY  0.8165f
#define LZ -0.4082f

// ---- Tipos ------------------------------------------------------------------
typedef struct { float x, y, z; } V3;
typedef struct { int a, b, c;   } Tri;

// ---- Datos de la malla ------------------------------------------------------
static V3  mesh_v[MAX_VERTS];
static Tri mesh_t[MAX_TRIS];
static int n_verts = 0;
static int n_tris  = 0;
static int mesh_ok = 0;

// ---- Buffers de render (estaticos: evitar desbordamiento de stack en DOS) ---
static float tv[MAX_VERTS][3];  // vertices transformados 3D
static int   sv[MAX_VERTS][2];  // proyeccion en pantalla (px)
static float sv_z[MAX_VERTS];   // profundidad tras proyeccion

typedef struct { float depth; int packed; } TSort; // packed = ti | (ci<<20)
static TSort tsort[MAX_TRIS];

// ---- Paleta original de las entradas reservadas ----------------------------
static char orig_pal[PAL_SHADES * 3];

// ---- Parametros diferidos: KD3D_DRAW los guarda, post_process_buffer los usa
static int draw_active = 0;
static int draw_cx, draw_cy, draw_rx, draw_ry, draw_rz, draw_scale;

// ---- Mensaje de estado (error / info de carga) ------------------------------
static char kd3d_msg[40];
static int  kd3d_msg_frames;   // >0 = mostrar N frames; -1 = mostrar siempre

// Helpers de string (sin libc)
static void s_cpy(char *d, const char *s){ while(*s)*d++=*s++; *d=0; }
static void s_cat(char *d, const char *s){ while(*d)d++; while(*s)*d++=*s++; *d=0; }
static void s_itos(int n, char *b){
    char t[8]; int i=0,j=0;
    if(!n){b[0]='0';b[1]=0;return;}
    if(n<0){*b++='-';n=-n;}
    while(n){t[i++]=(char)('0'+n%10);n/=10;}
    while(i>0)b[j++]=t[--i]; b[j]=0;
}

static void *(*g_import)(char *name) = 0;
static void  (*g_export)(char *name, void *p) = 0;

// ============================================================================
// Utilidades
// ============================================================================

// Convierte STRING DIV2 a C string.
// Las strings en DIV2 se almacenan como bytes normales empaquetados en mem[].
// off es el indice en unidades de int; los bytes reales estan en &mem[off].
static void div2c(int off, char *buf, int max) {
    int i;
    char *src = (char*)&mem[off];
    for (i = 0; i < max - 1 && src[i]; i++)
        buf[i] = src[i];
    buf[i] = 0;
}

// atof minimo: "1.234", "-0.5", etc. (no necesita exponent para OBJ basico)
static float sc_atof(const char *s) {
    float v = 0.0f, frac = 1.0f;
    int neg = 0;
    while (*s == ' ' || *s == '\t') s++;
    if (*s == '-') { neg = 1; s++; } else if (*s == '+') s++;
    while (*s >= '0' && *s <= '9') v = v * 10.0f + (float)(*s++ - '0');
    if (*s == '.') { s++; while (*s >= '0' && *s <= '9') { frac *= 0.1f; v += (float)(*s++ - '0') * frac; } }
    return neg ? -v : v;
}

// atoi minimo (puede tener signo negativo)
static int sc_atoi(const char *s) {
    int v = 0, neg = 0;
    while (*s == ' ' || *s == '\t') s++;
    if (*s == '-') { neg = 1; s++; }
    while (*s >= '0' && *s <= '9') v = v * 10 + (*s++ - '0');
    return neg ? -v : v;
}

// Lee una linea del archivo (elimina \r, termina en \n o EOF)
static int read_line(FILE *f, char *buf, int max) {
    int c, n = 0;
    while (n < max - 1) {
        c = fgetc(f);
        if (c == EOF) { buf[n] = 0; return n > 0; }
        if (c == '\n') break;
        if (c != '\r') buf[n++] = (char)c;
    }
    buf[n] = 0;
    return 1;
}

// Salta al siguiente token en la cadena (espacio como separador)
static char *next_tok(char *s) {
    while (*s && *s != ' ' && *s != '\t' && *s != '\n') s++;
    while (*s == ' ' || *s == '\t') s++;
    return s;
}

// ============================================================================
// Rasterizador de triangulos (scanline, punto flotante)
// ============================================================================

static void hspan(char *vid, int W, int H, int y, int x0, int x1, char col) {
    char *p;
    int tmp;
    if (y < 0 || y >= H) return;
    if (x0 > x1) { tmp = x0; x0 = x1; x1 = tmp; }
    if (x0 < 0) x0 = 0;
    if (x1 >= W) x1 = W - 1;
    if (x0 > x1) return;
    p = vid + y * W + x0;
    tmp = x1 - x0 + 1;
    while (tmp-- > 0) *p++ = col;
}

static void fill_tri(char *vid, int W, int H,
                     int x0, int y0, int x1, int y1, int x2, int y2, char col) {
    int tmp, y;
    float t, x_long, x_short;

    // Ordenar por Y (y0 <= y1 <= y2)
    if (y0 > y1) { tmp=y0;y0=y1;y1=tmp; tmp=x0;x0=x1;x1=tmp; }
    if (y1 > y2) { tmp=y1;y1=y2;y2=tmp; tmp=x1;x1=x2;x2=tmp; }
    if (y0 > y1) { tmp=y0;y0=y1;y1=tmp; tmp=x0;x0=x1;x1=tmp; }

    if (y0 == y2) { hspan(vid, W, H, y0, x0, x2, col); return; }

    for (y = y0; y <= y2; y++) {
        // Arista larga: v0 -> v2 (cubre todo el rango vertical)
        t = (float)(y - y0) / (float)(y2 - y0);
        x_long = (float)x0 + (float)(x2 - x0) * t;

        // Arista corta: v0->v1 (parte superior) o v1->v2 (parte inferior)
        if (y <= y1) {
            t = (y1 > y0) ? (float)(y - y0) / (float)(y1 - y0) : 0.0f;
            x_short = (float)x0 + (float)(x1 - x0) * t;
        } else {
            t = (y2 > y1) ? (float)(y - y1) / (float)(y2 - y1) : 1.0f;
            x_short = (float)x1 + (float)(x2 - x1) * t;
        }

        hspan(vid, W, H, y, (int)x_long, (int)x_short, col);
    }
}

// ============================================================================
// KD3D_LOAD: parsea un OBJ y carga la malla
// ============================================================================
static void kd3d_load_fn(void) {
    int str_off = getparm();
    char fname[64], line[256], *p;
    FILE *f;
    int i, vi[8], nv;

    div2c(str_off, fname, sizeof(fname));

    n_verts = 0; n_tris = 0; mesh_ok = 0;

    f = div_fopen(fname, "r");
    if (!f) {
        s_cpy(kd3d_msg, "NO FILE: ");
        s_cat(kd3d_msg, fname);
        kd3d_msg_frames = -1;
        retval(0); return;
    }

    while (read_line(f, line, sizeof(line))) {
        if (line[0] == 'v' && line[1] == ' ') {
            // Vertice
            if (n_verts < MAX_VERTS) {
                p = line + 2;
                mesh_v[n_verts].x =  sc_atof(p); p = next_tok(p);
                mesh_v[n_verts].y =  sc_atof(p); p = next_tok(p);
                mesh_v[n_verts].z =  sc_atof(p);
                n_verts++;
            }
        } else if (line[0] == 'f' && line[1] == ' ') {
            // Cara: extraer indices de vertice (antes de '/')
            p = line + 2; nv = 0;
            while (*p && nv < 8) {
                while (*p == ' ' || *p == '\t') p++;
                if (*p == 0 || *p == '\n') break;
                vi[nv++] = sc_atoi(p) - 1;  // OBJ es 1-based
                while (*p && *p != ' ' && *p != '\t' && *p != '\n') p++;
            }
            // Triangular (fan desde v0): quad -> 2 tris, pentagono -> 3 tris, etc.
            for (i = 1; i < nv - 1 && n_tris < MAX_TRIS; i++) {
                if (vi[0]   >= 0 && vi[0]   < n_verts &&
                    vi[i]   >= 0 && vi[i]   < n_verts &&
                    vi[i+1] >= 0 && vi[i+1] < n_verts) {
                    mesh_t[n_tris].a = vi[0];
                    mesh_t[n_tris].b = vi[i];
                    mesh_t[n_tris].c = vi[i+1];
                    n_tris++;
                }
            }
        }
        // El resto (vn, vt, s, o, g, #, mtllib...) se ignoran
    }

    div_fclose(f);
    mesh_ok = (n_tris > 0);

    if (mesh_ok) {
        char num[8];
        s_cpy(kd3d_msg, "KD3D OK ");
        s_itos(n_tris, num); s_cat(kd3d_msg, num);
        s_cat(kd3d_msg, " tri");
        kd3d_msg_frames = -1;   // permanente
    } else {
        s_cpy(kd3d_msg, "KD3D ERR: ");
        s_cat(kd3d_msg, fname);
        kd3d_msg_frames = -1;   // mostrar siempre hasta nuevo load
    }

    retval(mesh_ok ? n_tris : 0);
}

// ============================================================================
// do_render: nucleo del renderizador 3D (llamado desde post_process_buffer)
// ============================================================================
static void do_render(int cx, int cy, int rx_d, int ry_d, int rz_d, int scale_p) {
    float scale = (float)scale_p * 0.01f;
    float PI = 3.14159265f;
    float rx = (float)rx_d * (PI / 180.0f);
    float ry = (float)ry_d * (PI / 180.0f);
    float rz = (float)rz_d * (PI / 180.0f);

    float cxr=(float)cos(rx), sxr=(float)sin(rx);
    float cyr=(float)cos(ry), syr=(float)sin(ry);
    float czr=(float)cos(rz), szr=(float)sin(rz);

    int W, H, i, ndraw;
    char *vid;

    if (!mesh_ok || !_buffer || !_wide || !_height) return;
    vid = (char*)(*((unsigned long*)_buffer));
    if (!vid) return;
    W = *_wide; H = *_height;

    // ---- 1. Transformar vertices -------------------------------------------
    for (i = 0; i < n_verts; i++) {
        float x = mesh_v[i].x * scale;
        float y = mesh_v[i].y * scale;
        float z = mesh_v[i].z * scale;
        float t;

        // Rx
        t = y*cxr - z*sxr; z = y*sxr + z*cxr; y = t;
        // Ry
        t = x*cyr + z*syr; z = -x*syr + z*cyr; x = t;
        // Rz
        t = x*czr - y*szr; y = x*szr + y*czr; x = t;

        tv[i][0] = x; tv[i][1] = y; tv[i][2] = z;

        // Proyeccion perspectiva: camara en origen, objeto en +Z
        float pz = z + CAM_DIST;
        if (pz < 0.01f) pz = 0.01f;
        sv[i][0] = cx + (int)(x * FOV / pz);
        sv[i][1] = cy - (int)(y * FOV / pz);  // Y invertida en pantalla
        sv_z[i]  = pz;
    }

    // ---- 2. Backface cull + calcular shade + preparar sort -----------------
    ndraw = 0;
    for (i = 0; i < n_tris; i++) {
        int a = mesh_t[i].a, b = mesh_t[i].b, c = mesh_t[i].c;
        int sx0=sv[a][0], sy0=sv[a][1];
        int sx1=sv[b][0], sy1=sv[b][1];
        int sx2=sv[c][0], sy2=sv[c][1];

        // Area con signo en espacio pantalla (Y invertida en DIV2).
        // OBJ usa winding CCW visto desde fuera. Con Y invertida, las caras
        // frontales quedan con area2 POSITIVA. Cullar area2 <= 0 (traseras).
        int area2 = (sx1-sx0)*(sy2-sy0) - (sx2-sx0)*(sy1-sy0);
        if (area2 <= 0) continue;  // cara trasera: descartar

        // Normal del triangulo en espacio 3D transformado
        float ex1=tv[b][0]-tv[a][0], ey1=tv[b][1]-tv[a][1], ez1=tv[b][2]-tv[a][2];
        float ex2=tv[c][0]-tv[a][0], ey2=tv[c][1]-tv[a][1], ez2=tv[c][2]-tv[a][2];
        float nx = ey1*ez2 - ez1*ey2;
        float ny = ez1*ex2 - ex1*ez2;
        float nz = ex1*ey2 - ey1*ex2;
        float nlen = (float)sqrt((double)(nx*nx + ny*ny + nz*nz));
        if (nlen > 1e-6f) { nx/=nlen; ny/=nlen; nz/=nlen; }

        // Shading: luz fija + luz ambiente
        float shade = nx*LX + ny*LY + nz*LZ;
        if (shade < 0.0f) shade = 0.0f;
        shade = AMBIENT + (1.0f - AMBIENT) * shade;

        // Mapear shade al indice de paleta (0..PAL_SHADES-1)
        int ci = (int)(shade * (float)(PAL_SHADES - 1) + 0.5f);
        if (ci < 0) ci = 0;
        if (ci >= PAL_SHADES) ci = PAL_SHADES - 1;

        // Profundidad media del triangulo
        float depth = (sv_z[a] + sv_z[b] + sv_z[c]) * (1.0f / 3.0f);

        tsort[ndraw].depth  = depth;
        tsort[ndraw].packed = i | (ci << 20);  // tri index (bits 0-19) + color (bits 20-23)
        ndraw++;
    }

    // ---- 3. Ordenar back-to-front (insertion sort: rapido para <200 tris) --
    {
        int j;
        TSort tmp;
        for (j = 1; j < ndraw; j++) {
            tmp = tsort[j];
            int k = j - 1;
            while (k >= 0 && tsort[k].depth < tmp.depth) {
                tsort[k+1] = tsort[k];
                k--;
            }
            tsort[k+1] = tmp;
        }
    }

    // ---- 4. Rasterizar (Painter's Algorithm: lejos primero) ----------------
    for (i = 0; i < ndraw; i++) {
        int ti = tsort[i].packed & 0xFFFFF;     // indice de triangulo
        int ci = (tsort[i].packed >> 20) & 0xF; // indice de color
        char col = (char)(PAL_BASE + ci);

        int a = mesh_t[ti].a, b = mesh_t[ti].b, c = mesh_t[ti].c;
        fill_tri(vid, W, H,
                 sv[a][0], sv[a][1],
                 sv[b][0], sv[b][1],
                 sv[c][0], sv[c][1], col);
    }

    set_palette = 1;
}

// ============================================================================
// KD3D_DRAW: guarda parametros; el renderizado ocurre en post_process_buffer
// (despues de que DIV2 termine su propio rendering, antes del flip a pantalla)
// ============================================================================
static void kd3d_draw_fn(void) {
    draw_scale  = getparm();
    draw_rz     = getparm();
    draw_ry     = getparm();
    draw_rx     = getparm();
    draw_cy     = getparm();
    draw_cx     = getparm();
    draw_active = 1;
    retval(0);
}

// ============================================================================
// KD3D_SETCOLOR: crea gradiente de 16 sombras en paleta[224..239]
// r, g, b en formato DIV2 (0-63)
// ============================================================================
static void kd3d_setcolor_fn(void) {
    int b = getparm();
    int g = getparm();
    int r = getparm();
    int i;

    for (i = 0; i < PAL_SHADES; i++) {
        // t va de AMBIENT (sombra) a 1.0 (luz plena)
        float t = AMBIENT + (1.0f - AMBIENT) * (float)i / (float)(PAL_SHADES - 1);
        palette[(PAL_BASE + i) * 3 + 0] = (char)((int)((float)r * t + 0.5f));
        palette[(PAL_BASE + i) * 3 + 1] = (char)((int)((float)g * t + 0.5f));
        palette[(PAL_BASE + i) * 3 + 2] = (char)((int)((float)b * t + 0.5f));
    }
    set_palette = 1;
    retval(0);
}

// ============================================================================
// post_process_buffer: DIV2 lo llama tras renderizar todos los sprites,
// justo antes del flip. Aqui dibujamos el 3D encima sin que se borre.
// ============================================================================
void post_process_buffer(void) {
    if (!_wide || !_height || *_wide <= 0 || *_height <= 0 || !_buffer) return;

    // Siempre mostramos "KD3D" en la esquina para confirmar que el callback
    // esta activo (desaparece si algo falla antes de llegar aqui)
    if (div_text_out) div_text_out("KD3D", 2, 2);

    // Mensaje de estado (error de carga o confirmacion de exito)
    if (kd3d_msg_frames != 0 && div_text_out) {
        div_text_out(kd3d_msg, 2, 12);
        if (kd3d_msg_frames > 0) kd3d_msg_frames--;
    }

    if (!draw_active) return;
    do_render(draw_cx, draw_cy, draw_rx, draw_ry, draw_rz, draw_scale);
}

// ============================================================================
// Puntos de entrada de la DLL
// ============================================================================
void __export divlibrary(LIBRARY_PARAMS) {
    COM_export("KD3D_LOAD",     kd3d_load_fn,     1);
    COM_export("KD3D_DRAW",     kd3d_draw_fn,     6);
    COM_export("KD3D_SETCOLOR", kd3d_setcolor_fn, 3);
}

void __export divmain(COMMON_PARAMS) {
    int i;
    g_import = DIV_import;
    g_export = DIV_export;
    #define DIV_import g_import
    #define DIV_export g_export

    AutoLoad();
    GLOBAL_IMPORT();

    draw_active = 0;
    kd3d_msg[0] = 0;
    kd3d_msg_frames = 0;
    DIV_export("post_process_buffer", post_process_buffer);

    // Guardar palette original de las 16 entradas reservadas
    for (i = 0; i < PAL_SHADES * 3; i++)
        orig_pal[i] = palette[PAL_BASE * 3 + i];

    // Color inicial: blanco
    {
        int j;
        for (j = 0; j < PAL_SHADES; j++) {
            float t = AMBIENT + (1.0f - AMBIENT) * (float)j / (float)(PAL_SHADES - 1);
            palette[(PAL_BASE + j) * 3 + 0] = (char)((int)(63.0f * t + 0.5f));
            palette[(PAL_BASE + j) * 3 + 1] = (char)((int)(63.0f * t + 0.5f));
            palette[(PAL_BASE + j) * 3 + 2] = (char)((int)(63.0f * t + 0.5f));
        }
        set_palette = 1;
    }

    #undef DIV_import
    #undef DIV_export
}

void __export divend(COMMON_PARAMS) {
    int i;
    (void)DIV_import; (void)DIV_export;
    mesh_ok = 0;
    // Restaurar palette
    for (i = 0; i < PAL_SHADES * 3; i++)
        palette[PAL_BASE * 3 + i] = orig_pal[i];
    set_palette = 1;
}
