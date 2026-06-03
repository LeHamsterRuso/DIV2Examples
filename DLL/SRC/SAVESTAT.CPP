//------------------------------------------------------------------------------
// TITLE:       SAVESTAT.CPP
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        03/06/2026
// DESCRIPTION: DLL de savestates en memoria para DIV Games Studio 2
//
// AutoLoad: funciona con cualquier juego sin modificarlo.
//
// Controles:
//   F1-F5  : Guardar ranura 1-5
//   F6-F10 : Cargar ranura 1-5
//
// Funciones opcionales exportadas al PRG:
//   SS_SAVE(slot)  -> 1 si OK  (slot 1-5)
//   SS_LOAD(slot)  -> 1 si OK  (slot 1-5)
//
// QUE SE GUARDA (volcado plano, estilo emulador):
//
//   mem[long_header .. id_end_offset + process_size)
//
//   Cubre en un solo bloque contiguo:
//     - Estructuras de sistema: SCROLL, MOUSE, M7, JOY... (posicion del scroll, camara)
//     - Globales de sistema (timer, fps, restore_type...)
//     - Globales de usuario (score, hp, nivel...)
//     - Bloque completo de cada proceso: _reserved (ip, sp, status, x0/y0/x1/y1...),
//       campos _process (x, y, graph, angle...) y variables locales.
//
//   ip y sp SE RESTAURAN intencionadamente: en el momento del guardado los
//   procesos estan suspendidos en FRAME con la pila limpia, asi que restaurar
//   ip/sp hace que cada proceso retome exactamente donde se guardo.
//
//   Los campos id e idscan (identidad del proceso, gestionados internamente
//   por el motor) NO se restauran: se guardan antes del volcado y se reescriben
//   despues para no desincronizar la tabla interna de IDs del motor.
//
//   palette[0..767]
//
// Refresco visual: flag clear_pending consumido en post_process_buffer.
//------------------------------------------------------------------------------

#define GLOBALS
#include "div.h"

#define MAX_SLOTS       5
#define SC_F1           59   // F1..F5  = scan codes 59..63  (guardar)
#define SC_F6           64   // F6..F10 = scan codes 64..68  (cargar)
#define MSG_FRAMES      60   // ~2 s a 30fps

// Limite de slots de proceso que preservamos (id, idscan) al cargar.
// 512 es mas que suficiente para cualquier juego DIV2.
#define MAX_PROC_SLOTS  512

static void *(*g_import)(char *name)          = 0;
static void  (*g_export)(char *name, void *p) = 0;

static int  ss_ok         = 0;
static int  clear_pending = 0;
static char prev_fkey[10];
static int  msg_timer     = 0;
static char msg_buf[24];

// Buffers por ranura
static int  *save_buf[MAX_SLOTS];   // volcado plano de mem[]
static char *save_pal[MAX_SLOTS];   // paleta
static int   save_total[MAX_SLOTS]; // ints en save_buf
static int   save_last[MAX_SLOTS];  // id_end_offset+process_size al guardar
static int   save_ps[MAX_SLOTS];    // process_size al guardar
static int   save_np[MAX_SLOTS];    // num procesos al guardar
static int   save_valid[MAX_SLOTS];

// ---- String helpers ----
static void sc_cpy(char *d, const char *s) { while (*s) *d++ = *s++; *d = 0; }
static void sc_cat(char *d, const char *s) { while (*d) d++; while (*s) *d++ = *s++; *d = 0; }
static void sc_itoa(int n, char *buf) {
    char tmp[8]; int i=0,j=0;
    if (n==0){buf[0]='0';buf[1]=0;return;}
    while(n>0){tmp[i++]=(char)('0'+n%10);n/=10;}
    while(i>0)buf[j++]=tmp[--i]; buf[j]=0;
}

// ---- Guardar ----
// Vuelca mem[long_header .. last) en un solo bloque plano.
static int do_save(int slot) {
    int idx = slot - 1;
    int first, last, total, i;

    if (!ss_ok || slot < 1 || slot > MAX_SLOTS) return 0;
    if (process_size <= 0) return 0;

    first = long_header;
    last  = id_end_offset + process_size;   // exclusivo: primer int fuera del rango
    total = last - first;
    if (total <= 0) return 0;

    // Reasignar buffer si el layout cambio
    if (save_total[idx] != total) {
        if (save_buf[idx]) div_free(save_buf[idx]);
        save_buf[idx]   = (int *)div_malloc(total * 4);
        save_total[idx] = total;
    }
    if (!save_pal[idx]) save_pal[idx] = (char *)div_malloc(768);
    if (!save_buf[idx] || !save_pal[idx]) return 0;

    // Volcado plano
    for (i = 0; i < total; i++) save_buf[idx][i] = mem[first + i];

    // Paleta
    for (i = 0; i < 768; i++) save_pal[idx][i] = palette[i];

    save_last[idx]  = last;
    save_ps[idx]    = process_size;
    save_np[idx]    = (id_end_offset - id_init_offset) / process_size + 1;
    save_valid[idx] = 1;
    return 1;
}

// ---- Cargar ----
// Restaura el volcado plano, preservando id e idscan de cada proceso
// para no desincronizar la tabla interna de IDs del motor DIV2.
static int do_load(int slot) {
    int idx = slot - 1;
    int first, last, restore_end, total, cur_np, np, p, i;

    if (!ss_ok || slot < 1 || slot > MAX_SLOTS) return 0;
    if (!save_valid[idx] || save_ps[idx] != process_size) return 0;
    if (!save_buf[idx]   || !save_pal[idx]) return 0;

    first = long_header;
    last  = save_last[idx];
    np    = save_np[idx];

    // No escribir mas alla del bloque de procesos actual
    cur_np      = (id_end_offset - id_init_offset) / process_size + 1;
    restore_end = id_end_offset + process_size;
    if (last > restore_end) last = restore_end;

    total = last - first;
    if (total <= 0) return 0;

    // Preservar id (offset 0) e idscan (offset 1) de cada slot actual,
    // para no romper la tabla interna de IDs del motor.
    int slots_to_keep = (cur_np < np) ? cur_np : np;
    if (slots_to_keep > MAX_PROC_SLOTS) slots_to_keep = MAX_PROC_SLOTS;

    static int kept_id[MAX_PROC_SLOTS];
    static int kept_idscan[MAX_PROC_SLOTS];
    for (p = 0; p < slots_to_keep; p++) {
        int base = id_init_offset + p * process_size;
        kept_id[p]     = mem[base + 0];
        kept_idscan[p] = mem[base + 1];
    }

    // Restaurar volcado plano
    for (i = 0; i < total; i++) mem[first + i] = save_buf[idx][i];

    // Volver a poner los id/idscan actuales
    for (p = 0; p < slots_to_keep; p++) {
        int base = id_init_offset + p * process_size;
        mem[base + 0] = kept_id[p];
        mem[base + 1] = kept_idscan[p];
    }

    // Restaurar paleta
    for (i = 0; i < 768; i++) palette[i] = save_pal[idx][i];

    set_palette   = 1;
    restore_type  = 1;
    clear_pending = 1;
    return 1;
}

// ---- Callback post_process_buffer ----
void post_process_buffer(void) {
    if (!_wide || !_height || *_wide <= 0 || *_height <= 0 || !_buffer) return;

    // Deteccion de teclas F1-F10 via key[] (estado fisico, valido aqui)
    if (ss_ok && _key) {
        int i;
        char num[4], txt[20];

        for (i = 0; i < 5; i++) {
            char cur = _key[SC_F1 + i];
            if (cur && !prev_fkey[i]) {
                if (do_save(i + 1)) {
                    sc_cpy(txt, "SAVE "); sc_itoa(i+1, num); sc_cat(txt, num);
                    sc_cpy(msg_buf, txt); msg_timer = MSG_FRAMES;
                }
            }
            prev_fkey[i] = cur;
        }
        for (i = 0; i < 5; i++) {
            char cur = _key[SC_F6 + i];
            if (cur && !prev_fkey[5+i]) {
                int ok = do_load(i + 1);
                sc_cpy(txt, ok ? "LOAD " : "EMPTY "); sc_itoa(i+1, num); sc_cat(txt, num);
                sc_cpy(msg_buf, txt); msg_timer = MSG_FRAMES;
            }
            prev_fkey[5+i] = cur;
        }
    }

    {
        char *vid = (char*)(*((unsigned long *)_buffer));
        if (!vid) return;

        // Borrar buffer tras carga
        if (clear_pending) {
            int i, sz = *_wide * *_height;
            for (i = 0; i < sz; i++) vid[i] = 0;
            clear_pending = 0;
        }

        // Mensaje de estado
        if (msg_timer > 0 && div_text_out) {
            msg_timer--;
            div_text_out(msg_buf, 2, *_height - 10);
        }
    }
}

// ---- Funciones exportadas al PRG ----
static void ss_save_fn(void) {
    int s = getparm();
    if (s<1) s=1; if (s>MAX_SLOTS) s=MAX_SLOTS;
    retval(do_save(s));
}
static void ss_load_fn(void) {
    int s = getparm();
    if (s<1) s=1; if (s>MAX_SLOTS) s=MAX_SLOTS;
    retval(do_load(s));
}

// ---- Puntos de entrada ----
void __export divlibrary(LIBRARY_PARAMS) {
    COM_export("SS_SAVE", ss_save_fn, 1);
    COM_export("SS_LOAD", ss_load_fn, 1);
}

void __export divmain(COMMON_PARAMS) {
    int i;
    g_import = DIV_import;
    g_export = DIV_export;
    #define DIV_import g_import
    #define DIV_export g_export

    AutoLoad();
    GLOBAL_IMPORT();

    for (i=0;i<MAX_SLOTS;i++){
        save_buf[i]=0; save_pal[i]=0;
        save_total[i]=0; save_last[i]=0;
        save_ps[i]=0; save_np[i]=0;
        save_valid[i]=0;
    }
    for (i=0;i<10;i++) prev_fkey[i]=0;
    ss_ok=1; clear_pending=0; msg_timer=0;

    DIV_export("post_process_buffer", post_process_buffer);

    #undef DIV_import
    #undef DIV_export
}

void __export divend(COMMON_PARAMS) {
    int i; ss_ok=0;
    for (i=0;i<MAX_SLOTS;i++){
        if (save_buf[i]){div_free(save_buf[i]);save_buf[i]=0;}
        if (save_pal[i]){div_free(save_pal[i]);save_pal[i]=0;}
        save_valid[i]=0;
    }
}
