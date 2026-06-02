//------------------------------------------------------------------------------
// TITLE:       HUD.CPP
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        03/06/2026
// DESCRIPTION: Overlay HUD DLL para DIV Games Studio 2
// Muestra por pantalla: FPS (actual/min/max), resolucion, RAM usada/libre,
// y una marca de agua en la esquina inferior derecha.
//
// Funciones exportadas al PRG:
//   HUD_SET_MEM_FREE(kb)    - llamar cada frame con memory_free()
//   HUD_SET_MEM_TOTAL(kb)   - llamar una vez con total RAM en KB
//   HUD_TOGGLE()            - alterna visibilidad, devuelve 0/1
//   HUD_SHOW()              - fuerza HUD visible
//   HUD_HIDE()              - fuerza HUD oculto
//   HUD_RESET_FPS()         - resetea contadores min/max FPS
//------------------------------------------------------------------------------

#define GLOBALS
#include "div.h"

static int hud_ok        = 0;
static int hud_visible   = 1;
static int hud_fps_min   = 9999;
static int hud_fps_max   = 0;
static int hud_mem_free  = -1;
static int hud_mem_total = -1;


// ---- Helpers de cadena ----
static void hud_itoa(int n, char *buf) {
    char tmp[12];
    int i = 0, j = 0;
    if (n < 0) { buf[j++] = '-'; n = -n; }
    if (n == 0) { buf[j++] = '0'; buf[j] = 0; return; }
    while (n > 0) { tmp[i++] = (char)('0' + n % 10); n /= 10; }
    while (i > 0) buf[j++] = tmp[--i];
    buf[j] = 0;
}

// Devuelve puntero al nuevo terminador nulo (permite encadenar llamadas).
static char *hud_append(char *dst, const char *src) {
    while (*dst) dst++;
    while (*src) *dst++ = *src++;
    *dst = 0;
    return dst;
}

// Igual que hud_append pero con un entero convertido a string.
static char *hud_append_int(char *dst, int val) {
    char num[12];
    hud_itoa(val, num);
    return hud_append(dst, num);
}


// ---- Callback post_process_buffer ----
static void hud_draw(void) {
    char line[80];
    char *p;
    int   cur_fps;

    if (!hud_ok || !hud_visible) return;
    if (!div_text_out) return;

    cur_fps = fps;                                      // macro: mem[end_struct+20]
    if (cur_fps < hud_fps_min) hud_fps_min = cur_fps;
    if (cur_fps > hud_fps_max) hud_fps_max = cur_fps;

    // --- Linea 0 @ y=2: FPS actual / min / max ---
    p = line; p[0] = 0;
    p = hud_append(p,     "FPS:");
    p = hud_append_int(p, cur_fps);
    p = hud_append(p,     " mn:");
    p = hud_append_int(p, hud_fps_min);
    p = hud_append(p,     " mx:");
    p = hud_append_int(p, hud_fps_max);
    div_text_out(line, 2, 2);

    // --- Linea 1 @ y=12: resolucion ---
    p = line; p[0] = 0;
    p = hud_append(p,     "RES:");
    p = hud_append_int(p, wide);
    p = hud_append(p,     "x");
    p = hud_append_int(p, height);
    div_text_out(line, 2, 12);

    // --- Lineas 2-3 @ y=22,32: memoria (solo si fue informada por el PRG) ---
    if (hud_mem_total > 0 && hud_mem_free >= 0) {
        int used = hud_mem_total - hud_mem_free;

        p = line; p[0] = 0;
        p = hud_append(p,     "RAM:");
        p = hud_append_int(p, used);
        p = hud_append(p,     "KB");
        div_text_out(line, 2, 22);

        p = line; p[0] = 0;
        p = hud_append(p,     "LIB:");
        p = hud_append_int(p, hud_mem_free);
        p = hud_append(p,     "KB");
        div_text_out(line, 2, 32);
    }

    // --- Marca de agua: esquina inferior derecha ---
    // "Hamster_ruso, WIP" son 18 chars; fuente DIV ~6px/char = ~108px.
    // Margen derecho: 120px. Margen inferior: 10px.
    {
        int wx = wide - 120;
        int wy = height - 10;
        char wm[] = "Hamster_ruso, WIP";
        if (wx < 2)  wx = 2;
        if (wy < 40) wy = 40;
        div_text_out(wm, wx, wy);
    }
}


// ---- Funciones exportadas al PRG ----

// HUD_SET_MEM_FREE(kb) - kb libres (pasar memory_free() cada frame)
static void hud_set_mem_free(void) {
    hud_mem_free = getparm();
    retval(0);
}

// HUD_SET_MEM_TOTAL(kb) - kb totales (llamar una vez en BEGIN del PRG)
static void hud_set_mem_total(void) {
    hud_mem_total = getparm();
    retval(0);
}

// HUD_TOGGLE() - alterna visibilidad; devuelve 1=visible 0=oculto
static void hud_toggle(void) {
    hud_visible = !hud_visible;
    retval(hud_visible);
}

static void hud_show(void) { hud_visible = 1; retval(0); }
static void hud_hide(void) { hud_visible = 0; retval(0); }

// HUD_RESET_FPS() - reinicia estadisticas min/max
static void hud_reset_fps(void) {
    hud_fps_min = 9999;
    hud_fps_max = 0;
    retval(0);
}


// ---- Puntos de entrada obligatorios de la DLL ----
// Registrar funciones exportadas al PRG
void __export divlibrary(LIBRARY_PARAMS) {
    COM_export("HUD_SET_MEM_FREE",  hud_set_mem_free,  1);
    COM_export("HUD_SET_MEM_TOTAL", hud_set_mem_total, 1);
    COM_export("HUD_TOGGLE",        hud_toggle,        0);
    COM_export("HUD_SHOW",          hud_show,          0);
    COM_export("HUD_HIDE",          hud_hide,          0);
    COM_export("HUD_RESET_FPS",     hud_reset_fps,     0);
}

// Inicializar estado, registrar callback de dibujo
void __export divmain(COMMON_PARAMS) {
    AutoLoad();
    GLOBAL_IMPORT();
    hud_ok      = 1;
    hud_fps_min = 9999;
    hud_fps_max = 0;
    DIV_export("post_process_buffer", hud_draw);
}

// Limpiar estado, desregistrar callback
void __export divend(COMMON_PARAMS) {
    hud_ok = 0;
}
