//------------------------------------------------------------------------------
// TITLE:       MINDLL.CPP
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        03/06/2026
// DESCRIPTION: Esta DLL no hace nada util, solo sirve para comprobar que el sistema de DLLs funciona.
// post_process_buffer escribe UNA sola linea de pixels (color 2 de la paleta cargada)
// en la fila 10 del buffer. Si se ve esa linea, la DLL funciona.
// No usa div_rand, no usa ghost, no usa malloc. Solo accede a buffer/wide.
//------------------------------------------------------------------------------

#define GLOBALS
#include "div.h"

static int mindll_ok = 0;
static void *(*g_import)(char *name) = 0;
static void  (*g_export)(char *name, void *obj) = 0;

// Escribe una línea de píxeles (color 2 de la paleta cargada) en la fila 10 del buffer,
void post_process_buffer(void) {
    int x;
    char *row;
    if (!mindll_ok) return;
    if (wide <= 0 || height <= 10) return;
    row = buffer + 10 * wide;
    for (x = 0; x < wide; x++) row[x] = 2;
}

// No hace nada, sólo devuelve 0
void __export divlibrary(LIBRARY_PARAMS) {}

// Exporta post_process_buffer para que DIV2 lo llame después de cada frame
void __export divmain(COMMON_PARAMS) {
    g_import = DIV_import;
    g_export = DIV_export;
    #define DIV_import g_import
    #define DIV_export g_export
    AutoLoad();
    GLOBAL_IMPORT();
    mindll_ok = 1;
    DIV_export("post_process_buffer", post_process_buffer);
    #undef DIV_import
    #undef DIV_export
}

// No hace nada, sólo devuelve 0
void __export divend(COMMON_PARAMS) {
    mindll_ok = 0;
}
