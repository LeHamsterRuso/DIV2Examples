//------------------------------------------------------------------------------
// TITLE:       CRT.CPP
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        03/06/2026
// DESCRIPTION: Efecto monitor CRT con lineas de escaner (scanlines)
// Autoload: oscurece filas alternas del buffer usando la tabla ghost de DIV2
// para simular el aspecto de un monitor de fosforo.
// Funciones exportadas al lenguaje:
//   CRT_SET_INTENSITY(v)   0=desactivado  1=ghost blend 50%  2=negro puro
//------------------------------------------------------------------------------

#include <stdio.h>
#include <mem.h>

#define GLOBALS
#include "div.h"

static void *(*g_import)(char *name) = 0;
static void  (*g_export)(char *name, void *obj) = 0;
static void  (*g_com)(char *name, void *obj, int n) = 0;
static int crt_intensity = 1;

// Después de cada frame, dibuja en negro las filas impares y oscurece el resto
void post_process_buffer(void) {
    int x, y;
    char *row;

    if (crt_intensity == 0) return;

    for (y = 1; y < height; y += 2) {
        row = buffer + y * wide;
        if (crt_intensity == 2) {
            // Linea de escaner pura: negro absoluto en filas impares
            for (x = 0; x < wide; x++) row[x] = 0;
        } else {
            // ghost[c*256+0] = mezcla 50% del color c con el color 0 (negro)
            // Esto oscurece el pixel a la mitad sin perder el color base
            for (x = 0; x < wide; x++)
                row[x] = ghost[((unsigned char)row[x]) * 256];
        }
    }
}

// Cambia la intensidad del efecto CRT
void crt_set_intensity(void) {
    int v = getparm();
    if (v < 0) v = 0;
    if (v > 2) v = 2;
    crt_intensity = v;
    retval(0);
}

// Exporta la función crt_set_intensity para que DIV2 la llame
void __export divlibrary(LIBRARY_PARAMS) {
    g_com = COM_export;
    #define COM_export g_com
    COM_export("CRT_SET_INTENSITY", crt_set_intensity, 1);
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
