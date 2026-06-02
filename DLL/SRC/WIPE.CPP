//------------------------------------------------------------------------------
// TITLE:       WIPE.CPP
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        03/06/2026
// DESCRIPTION: Transiciones de pantalla cinematograficas
// Autoload: aplica la transicion activa en post_process_buffer (DESPUES
// de que DIV2 renderiza el frame, antes de mostrarlo en pantalla).
// Funciones exportadas al lenguaje:
//   WIPE_START(tipo)      inicia transicion: 0=cortina_arriba  1=cortina_abajo
//                                            2=disolver         3=persianas
//   WIPE_ADVANCE(paso)    avanza progreso en 'paso' unidades (0-100)
//                         devuelve el progreso actual
//   WIPE_STOP()           desactiva la transicion
//------------------------------------------------------------------------------

#include <stdio.h>
#include <mem.h>

#define GLOBALS
#include "div.h"

static void *(*g_import)(char *name) = 0;
static void  (*g_export)(char *name, void *obj) = 0;
static void  (*g_com)(char *name, void *obj, int n) = 0;
static int wipe_type     = -1;   // -1 = inactivo
static int wipe_progress =  0;   // 0..100

// Después de cada frame, dibuja la transición activa en el buffer
void post_process_buffer(void) {
    int x, y, rows, start_y;
    int black_h;
    char *row;
    unsigned int h;

    if (wipe_type < 0 || wipe_progress <= 0) return;

    switch (wipe_type) {

        case 0:  // Cortina de arriba hacia abajo
            rows = height * wipe_progress / 100;
            for (y = 0; y < rows; y++) {
                row = buffer + y * wide;
                for (x = 0; x < wide; x++) row[x] = 0;
            }
            break;

        case 1:  // Cortina de abajo hacia arriba
            rows    = height * wipe_progress / 100;
            start_y = height - rows;
            if (start_y < 0) start_y = 0;
            for (y = start_y; y < height; y++) {
                row = buffer + y * wide;
                for (x = 0; x < wide; x++) row[x] = 0;
            }
            break;

        case 2:  // Disolucion aleatoria determinista
            // Hash de Knuth: cada pixel tiene un umbral fijo 0-255.
            // Cuando progress*256/100 supera el umbral, el pixel se pone a negro.
            {
                int threshold = wipe_progress * 256 / 100;
                for (y = 0; y < height; y++) {
                    unsigned int yh = (unsigned int)y * 12347u;
                    row = buffer + y * wide;
                    for (x = 0; x < wide; x++) {
                        h = (unsigned int)x * 31337u + yh;
                        h = (h ^ (h >> 8)) & 0xFF;
                        if ((int)h < threshold) row[x] = 0;
                    }
                }
            }
            break;

        case 3:  // Persianas horizontales (8 tiras)
            black_h = 8 * wipe_progress / 100;
            if (black_h < 1 && wipe_progress > 0) black_h = 1;
            for (y = 0; y < height; y++) {
                if (y % 8 < black_h) {
                    row = buffer + y * wide;
                    for (x = 0; x < wide; x++) row[x] = 0;
                }
            }
            break;
    }
}

// Inicia una transición de pantalla
void wipe_start(void) {
    int t = getparm();
    if (t < 0) t = 0;
    if (t > 3) t = 3;
    wipe_type     = t;
    wipe_progress = 0;
    retval(0);
}

// Avanza el progreso de la transición en 'step' unidades (0-100)
void wipe_advance(void) {
    int step = getparm();
    wipe_progress += step;
    if (wipe_progress > 100) wipe_progress = 100;
    if (wipe_progress < 0)   wipe_progress = 0;
    retval(wipe_progress);
}

// Detiene la transición y limpia el efecto 
void wipe_stop(void) {
    wipe_type     = -1;
    wipe_progress =  0;
    retval(0);
}

// Exporta las funciones de control de la transición para que DIV2 las llame
void __export divlibrary(LIBRARY_PARAMS) {
    g_com = COM_export;
    #define COM_export g_com
    COM_export("WIPE_START",   wipe_start,   1);
    COM_export("WIPE_ADVANCE", wipe_advance, 1);
    COM_export("WIPE_STOP",    wipe_stop,    0);
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
