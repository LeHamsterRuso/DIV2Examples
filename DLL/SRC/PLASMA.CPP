//------------------------------------------------------------------------------
// TITLE:       PLASMA.CPP
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        03/06/2026
// DESCRIPTION: Efecto plasma clasico de demoscene
// Autoload: llena toda la pantalla con plasma de colores cada frame.
// Usa tabla de senos precalculada (enteros) para maxima velocidad.
// Reserva indices de paleta 128-199 para el arco iris.
// Funciones exportadas al lenguaje:
//   PLASMA_SET_SPEED(s)   1-16, velocidad de animacion (defecto 2)
// Nota: sin FPU — usa aproximacion entera de Bhaskara para evitar
// dependencias del runtime de punto flotante (noemu387/ppfltused).
//------------------------------------------------------------------------------

#include <stdio.h>
#include <mem.h>

#define GLOBALS
#include "div.h"

#define PAL_PLASMA_START  128
#define PAL_PLASMA_COUNT   72   // indices 128..199
#define SIN_SIZE          512

static void *(*g_import)(char *name) = 0;
static void  (*g_export)(char *name, void *obj) = 0;
static void  (*g_com)(char *name, void *obj, int n) = 0;
static unsigned char sintab[SIN_SIZE];
static unsigned char pal_map[256];       // pal_map[v] = indice de paleta para valor v
static int           plasma_t     = 0;
static int           plasma_speed = 2;
static int           plasma_init  = 0;   // flag: tablas ya inicializadas

// Paleta arco iris ciclica (HSV saturado a V=63)
static void setup_plasma_palette(void) {
    int i, h6, f, r, g, b;
    for (i = 0; i < PAL_PLASMA_COUNT; i++) {
        h6 = (i * 6) / PAL_PLASMA_COUNT;
        f  = (i * 6 % PAL_PLASMA_COUNT) * 63 / PAL_PLASMA_COUNT;
        switch (h6) {
            case 0: r=63; g=f;    b=0;  break;
            case 1: r=63-f; g=63; b=0;  break;
            case 2: r=0;  g=63;   b=f;  break;
            case 3: r=0;  g=63-f; b=63; break;
            case 4: r=f;  g=0;    b=63; break;
            default:r=63; g=0;    b=63-f; break;
        }
        palette[(PAL_PLASMA_START+i)*3+0] = (char)r;
        palette[(PAL_PLASMA_START+i)*3+1] = (char)g;
        palette[(PAL_PLASMA_START+i)*3+2] = (char)b;
    }
    set_palette = 1;
}

// Aproximacion entera de Bhaskara I (siglo VII) para sin en grados:
//   sin(d) ≈ 4*d*(180-d) / (40500 - d*(180-d))   para 0 <= d <= 180
// Error maximo: ~0.17%. Mapea i(0..511) → sintab(0..255). Sin FPU.
static void setup_sintable(void) {
    int i, d, t, v;
    for (i = 0; i < SIN_SIZE; i++) {
        d = (i * 360) / SIN_SIZE;   // grados 0..359
        if (d > 180) { d -= 180; v = -1; } else { v = 1; }
        t = d * (180 - d);
        // Bhaskara: resultado en rango [0, ~16384] para semiperiodo positivo
        // denominador minimo 32400 (en d=90), numerador max 4*8100=32400
        // escalamos: (4*t << 13) / (40500 - t) da ~16384 en pico
        t = (4 * t * 16384) / (40500 - d * (180 - d));
        t = (t * 127) / 16384;          // normalizar a [0..127]
        sintab[i] = (unsigned char)(128 + v * t);
    }
    for (i = 0; i < 256; i++)
        pal_map[i] = (unsigned char)(PAL_PLASMA_START + i * (PAL_PLASMA_COUNT - 1) / 255);
}

// Después de cada frame, dibuja el efecto plasma en el buffer usando la tabla de senos
void post_process_buffer(void) {
    int x, y, v;
    int t1, t2, t3;
    char *row;

    // Init diferida: tablas y paleta cuando palette y wide ya estan listos
    if (!plasma_init) { setup_sintable(); setup_plasma_palette(); plasma_init = 1; }

    plasma_t = (plasma_t + plasma_speed) & (SIN_SIZE - 1);

    {
        int pt2 = (plasma_t * 2) & (SIN_SIZE - 1);
        for (y = 0; y < height; y++) {
            row = buffer + y * wide;
            t2  = (y * 2 + plasma_t) & (SIN_SIZE - 1);
            for (x = 0; x < wide; x++) {
                t1 = (x * 2 + plasma_t) & (SIN_SIZE - 1);
                t3 = ((x + y) + pt2)    & (SIN_SIZE - 1);
                v  = ((int)sintab[t1] + (int)sintab[t2] + (int)sintab[t3]) / 3;
                row[x] = (char)pal_map[v];
            }
        }
    }
}

// Cambia la velocidad de animacion del plasma (1-16)
void plasma_set_speed(void) {
    int s = getparm();
    if (s < 1)  s = 1;
    if (s > 16) s = 16;
    plasma_speed = s;
    retval(0);
}

// Exporta la función plasma_set_speed para que DIV2 la llame
void __export divlibrary(LIBRARY_PARAMS) {
    g_com = COM_export;
    #define COM_export g_com
    COM_export("PLASMA_SET_SPEED", plasma_set_speed, 1);
    #undef COM_export
}

// Exporta la función divmain para que DIV2 la llame
void __export divmain(COMMON_PARAMS) {
    g_import = DIV_import;
    g_export = DIV_export;
    #define DIV_import g_import
    #define DIV_export g_export
    AutoLoad();
    GLOBAL_IMPORT();
    DIV_export("post_process_buffer", post_process_buffer);
    #undef DIV_import
    #undef DIV_export
}

// No hace nada, sólo devuelve 0
void __export divend(COMMON_PARAMS) {}
