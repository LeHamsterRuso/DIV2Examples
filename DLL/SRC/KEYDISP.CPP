//------------------------------------------------------------------------------
// TITLE:       KEYDISP.CPP
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        03/06/2026
// DESCRIPTION: DLL de visualizacion de teclado para DIV Games Studio 2
//
// Muestra en pantalla un teclado QWERTY completo con las teclas actualmente
// pulsadas resaltadas en amarillo. AutoLoad: no requiere modificar el juego.
//
// Teclas mostradas:
//   ESC, F1-F12, fila de numeros, QWERTY, ASDF, ZXCV, modificadores
//   (Shift/Ctrl/Alt/Caps), Space, Enter, Backspace, Tab, barra invertida,
//   flechas y bloque de navegacion (Ins/Del/Home/End/PgUp/PgDn).
//
// Colores:
//   Reserva paleta[253] (gris oscuro = no pulsada)
//   y     paleta[254] (amarillo    = pulsada).
//   Restaura los valores originales al descargar la DLL.
//
// Geometria:
//   Cada "semiunidad" = 4 px. Tecla normal = 2 su = 7x7 px (1px de hueco).
//   El teclado se pinta en la esquina inferior izquierda de la pantalla.
//------------------------------------------------------------------------------

#define GLOBALS
#include "div.h"

// ---- Colores ----------------------------------------------------------------
#define COL_OFF     253     // gris oscuro: tecla no pulsada
#define COL_ON      254     // amarillo:    tecla pulsada

// ---- Geometria --------------------------------------------------------------
#define KH          7       // alto de cada tecla en px  (fila 8px - 1 hueco)
#define KBX         2       // margen izquierdo del teclado en px
#define KBY_MARGIN  52      // px desde el borde inferior de pantalla

// ---- Definicion de teclas ---------------------------------------------------
// { scancode, col (su), row, cw (su) }
// px = KBX + col*4,   py = kby + row*8
// pw = cw*4 - 1,      ph = KH
typedef struct { unsigned char scan, col, row, cw; } KKey;

static KKey kkeys[] = {
    /* Fila 0 - ESC + grupos F1-F4 / F5-F8 / F9-F12 (gap visual entre grupos) */
    { 1,  0, 0, 2},
    {59,  4, 0, 2}, {60,  6, 0, 2}, {61,  8, 0, 2}, {62, 10, 0, 2},
    {63, 14, 0, 2}, {64, 16, 0, 2}, {65, 18, 0, 2}, {66, 20, 0, 2},
    {67, 24, 0, 2}, {68, 26, 0, 2}, {87, 28, 0, 2}, {88, 30, 0, 2},

    /* Fila 1 - ` 1 2 3 4 5 6 7 8 9 0 - = BKSP */
    {41,  0, 1, 2},
    { 2,  2, 1, 2}, { 3,  4, 1, 2}, { 4,  6, 1, 2}, { 5,  8, 1, 2},
    { 6, 10, 1, 2}, { 7, 12, 1, 2}, { 8, 14, 1, 2}, { 9, 16, 1, 2},
    {10, 18, 1, 2}, {11, 20, 1, 2}, {12, 22, 1, 2}, {13, 24, 1, 2},
    {14, 26, 1, 4},

    /* Fila 2 - TAB Q W E R T Y U I O P [ ] \ */
    {15,  0, 2, 3},
    {16,  3, 2, 2}, {17,  5, 2, 2}, {18,  7, 2, 2}, {19,  9, 2, 2},
    {20, 11, 2, 2}, {21, 13, 2, 2}, {22, 15, 2, 2}, {23, 17, 2, 2},
    {24, 19, 2, 2}, {25, 21, 2, 2}, {26, 23, 2, 2}, {27, 25, 2, 2},
    {43, 27, 2, 3},

    /* Fila 3 - CAPS A S D F G H J K L ; ' ENTER */
    {58,  0, 3, 3},
    {30,  3, 3, 2}, {31,  5, 3, 2}, {32,  7, 3, 2}, {33,  9, 3, 2},
    {34, 11, 3, 2}, {35, 13, 3, 2}, {36, 15, 3, 2}, {37, 17, 3, 2},
    {38, 19, 3, 2}, {39, 21, 3, 2}, {40, 23, 3, 2},
    {28, 25, 3, 5},

    /* Fila 4 - LSHIFT Z X C V B N M , . / RSHIFT */
    {42,  0, 4, 4},
    {44,  4, 4, 2}, {45,  6, 4, 2}, {46,  8, 4, 2}, {47, 10, 4, 2},
    {48, 12, 4, 2}, {49, 14, 4, 2}, {50, 16, 4, 2}, {51, 18, 4, 2},
    {52, 20, 4, 2}, {53, 22, 4, 2},
    {54, 24, 4, 6},

    /* Fila 5 - CTRL ALT SPACE  ALT CTRL                                    */
    /* DIV2 no distingue izq/dcha: ambos lados muestran el mismo scancode   */
    {29,  0, 5, 3}, {56,  3, 5, 3}, {57,  6, 5,14}, {56, 20, 5, 3}, {29, 23, 5, 3},

    /* Flechas (col 32-37) */
    {72, 34, 3, 2},                                   /* UP            */
    {75, 32, 4, 2}, {80, 34, 4, 2}, {77, 36, 4, 2},  /* LEFT DOWN RIGHT */

    /* Bloque de navegacion (col 38-41) */
    {82, 38, 2, 2}, {83, 40, 2, 2},   /* INS  DEL  */
    {71, 38, 3, 2}, {73, 40, 3, 2},   /* HOME PGUP */
    {79, 38, 4, 2}, {81, 40, 4, 2},   /* END  PGDN */

    {0, 0, 0, 0}    /* centinela */
};

// ---- Estado de la DLL -------------------------------------------------------
static char orig_pal[6];   // paleta[253..254] original (3 componentes cada uno)
static void *(*g_import)(char *name) = 0;
static void  (*g_export)(char *name, void *p) = 0;
static int kd_ok = 0;

// ---- Dibujar una tecla en el buffer de video --------------------------------
static void draw_key(char *vid, int stride, int kby, KKey *k) {
    int px = KBX + (int)k->col * 4;
    int py = kby + (int)k->row * 8;
    int pw = (int)k->cw * 4 - 1;
    int r, c, x, y;
    char col;

    // Bounds en scan: key[] tiene 128 entradas
    if (k->scan == 0 || k->scan >= 128) return;
    col = (_key && _key[k->scan]) ? (char)COL_ON : (char)COL_OFF;

    for (r = 0; r < KH; r++) {
        y = py + r;
        if (y < 0 || y >= *_height) continue;
        for (c = 0; c < pw; c++) {
            x = px + c;
            if (x >= 0 && x < *_wide)
                vid[y * stride + x] = col;
        }
    }
}

// ---- Callback del motor: se llama tras renderizar, antes del flip ----------
void post_process_buffer(void) {
    char *vid;
    int kby, i;

    if (!kd_ok) return;
    if (!_wide || !_height || *_wide <= 0 || *_height <= 0 || !_buffer) return;
    vid = (char*)(*((unsigned long*)_buffer));
    if (!vid) return;

    // Fijar nuestros colores cada frame (un fade del juego podria resetearlos)
    palette[COL_OFF * 3 + 0] =  6;  palette[COL_OFF * 3 + 1] =  6;  palette[COL_OFF * 3 + 2] =  6;
    palette[COL_ON  * 3 + 0] = 63;  palette[COL_ON  * 3 + 1] = 63;  palette[COL_ON  * 3 + 2] = 10;
    set_palette = 1;

    kby = *_height - KBY_MARGIN;
    if (kby < 0) kby = 0;

    for (i = 0; kkeys[i].cw != 0; i++)
        draw_key(vid, *_wide, kby, &kkeys[i]);
}

// ---- Puntos de entrada de la DLL -------------------------------------------
void __export divlibrary(LIBRARY_PARAMS) { (void)COM_export; }

void __export divmain(COMMON_PARAMS) {
    g_import = DIV_import;
    g_export = DIV_export;
    #define DIV_import g_import
    #define DIV_export g_export

    AutoLoad();
    GLOBAL_IMPORT();

    // Guardar valores originales de las dos entradas de paleta que usaremos
    orig_pal[0] = palette[COL_OFF * 3];
    orig_pal[1] = palette[COL_OFF * 3 + 1];
    orig_pal[2] = palette[COL_OFF * 3 + 2];
    orig_pal[3] = palette[COL_ON  * 3];
    orig_pal[4] = palette[COL_ON  * 3 + 1];
    orig_pal[5] = palette[COL_ON  * 3 + 2];

    kd_ok = 1;
    DIV_export("post_process_buffer", post_process_buffer);

    #undef DIV_import
    #undef DIV_export
}

void __export divend(COMMON_PARAMS) {
    (void)DIV_import; (void)DIV_export;
    kd_ok = 0;
    // Restaurar palette original antes de salir
    palette[COL_OFF * 3]     = orig_pal[0];
    palette[COL_OFF * 3 + 1] = orig_pal[1];
    palette[COL_OFF * 3 + 2] = orig_pal[2];
    palette[COL_ON  * 3]     = orig_pal[3];
    palette[COL_ON  * 3 + 1] = orig_pal[4];
    palette[COL_ON  * 3 + 2] = orig_pal[5];
    set_palette = 1;
}
