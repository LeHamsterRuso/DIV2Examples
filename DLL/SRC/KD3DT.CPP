//------------------------------------------------------------------------------
// TITLE:       KD3DT.CPP
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        05/06/2026
// DESCRIPTION: Renderizador 3D con textura para DIV Games Studio 2
//
// Extension de KD3D con mapeo de textura perspecto-correcto (hyperbolic mapping).
// Carga mallas OBJ con coordenadas UV ("vt") y texturas en formato MAP DIV2.
//
// FUNCIONES EXPORTADAS AL PRG:
//
//   KD3DT_LOAD(nombre)                   -> tris cargados, 0 si fallo
//      Igual que KD3D_LOAD pero tambien lee "vt u v" y "f v/vt[/vn]" del OBJ.
//      Si el OBJ no tiene UVs, el render cae a shading plano automaticamente.
//
//   KD3DT_SETTEX(nombre)                 -> 1 si OK, 0 si fallo
//      Carga una textura desde un fichero .MAP de DIV2.
//      Max: 1024x1024. Pixels = indices de paleta del juego (8 bits indexado).
//
//   KD3DT_DRAW(cx, cy, rx, ry, rz, scale) -> siempre 0
//      Igual que KD3D_DRAW.
//
//   KD3DT_SETCOLOR(r, g, b)              -> siempre 0
//      Igual que KD3D_SETCOLOR. Usado en tris sin UV o sin textura cargada.
//
// PALETA: reserva entradas 224-239 (shading de fallback, igual que KD3D).
//
// FORMATO MAP DIV2 (verificado con xxd y tamano de fichero sobre MAPs reales):
//   offset 0   : 8 bytes magic "map\x1a\x0d\x0a\x00\x00"
//   offset 8   : unsigned short wide   (2 bytes LE)
//   offset 10  : unsigned short height (2 bytes LE)
//   offset 12  : DWORD codigo del grafico (4 bytes LE) -- NO es npoints
//   offset 16  : 32 bytes nombre/descripcion
//   offset 48  : 768 bytes paleta (256 colores x 3, valores 6-bit)
//   offset 816 : 576 bytes rangos de color / colorbars
//   offset 1392: unsigned short npoints (2 bytes LE)
//   offset 1394: npoints * 4 bytes puntos de control (2 shorts x,y cada uno)
//   offset 1394+npoints*4: wide*height bytes pixel data (indices de paleta)
//
// EXPORTAR DESDE BLENDER (con UVs):
//   File -> Export -> Wavefront (.obj)
//   Marcar "Triangulate Faces" y "Write UVs".
//   UV fuera de [0,1] se hace clamping (no tiling).
//   V se invierte (1-v): OBJ V=0=inferior; MAP row 0=superior.
//------------------------------------------------------------------------------

#define GLOBALS
#include "div.h"
#include <math.h>

// ---- Limites ----------------------------------------------------------------
#define MAX_VERTS   512
#define MAX_UVS    1024
#define MAX_TRIS   1024

// ---- Paleta de shading (fallback sin textura) --------------------------------
#define PAL_BASE    224
#define PAL_SHADES   16
#define AMBIENT     0.20f

// ---- Camara / luz (igual que KD3D) ------------------------------------------
#define CAM_DIST    6.0f
#define FOV       220.0f
#define LX   0.4082f
#define LY   0.8165f
#define LZ  -0.4082f

// ---- Offsets MAP DIV2 -------------------------------------------------------
#define MAP_HDR_SIZE    8   // magic
#define MAP_W_OFFSET    8   // unsigned short wide
#define MAP_H_OFFSET   10   // unsigned short height
#define MAP_NP_OFFSET 1392  // unsigned short npoints (tras codigo+nombre+paleta+rangos)
#define MAP_PIX_OFFSET 1394 // pixel data si npoints==0

// ---- Tipos ------------------------------------------------------------------
typedef struct { float x, y, z;              } V3;
typedef struct { float u, v;                 } UV2;
typedef struct { int a,b,c; int ua,ub,uc;    } TriTex;
typedef struct { float depth; int idx; int ci; } TSort;

// ---- Datos de la malla ------------------------------------------------------
static V3     mesh_v[MAX_VERTS];
static UV2    mesh_uv[MAX_UVS];
static TriTex mesh_t[MAX_TRIS];
static int n_verts=0, n_uvs=0, n_tris=0;
static int mesh_ok=0, has_uvs=0;
static int uv_flip_u=0, uv_flip_v=0;  // configurables con KD3DT_UVMODE
static int uv_swap=0;                  // 1 = intercambiar U y V (giro 90 grados)

// ---- Buffers de render ------------------------------------------------------
static float tv[MAX_VERTS][3];
static int   sv[MAX_VERTS][2];
static float sv_z[MAX_VERTS];
static TSort tsort[MAX_TRIS];

// ---- Textura ----------------------------------------------------------------
static char *tex_data = NULL;
static int   tex_w = 0, tex_h = 0;

// ---- Paleta original --------------------------------------------------------
static char orig_pal[PAL_SHADES * 3];

// ---- Estado diferido --------------------------------------------------------
static int draw_active = 0;
static int draw_cx, draw_cy, draw_rx, draw_ry, draw_rz, draw_scale;

// ---- Mensaje de estado ------------------------------------------------------
static char kd3dt_msg[40];
static int  kd3dt_msg_frames;

// ---- Punteros al runtime DIV2 -----------------------------------------------
static void *(*g_import)(char *name) = 0;
static void  (*g_export)(char *name, void *p) = 0;

// ============================================================================
// Utilidades de string (sin libc)
// ============================================================================
static void s_cpy(char *d,const char *s){while(*s)*d++=*s++;*d=0;}
static void s_cat(char *d,const char *s){while(*d)d++;while(*s)*d++=*s++;*d=0;}
static void s_itos(int n,char *b){
    char t[8];int i=0,j=0;
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

// Parsea un vertice de cara OBJ: "v", "v/vt", "v//vn", "v/vt/vn"
// Devuelve puntero al siguiente caracter tras el token.
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
// Rasterizador flat (fallback sin textura, igual que KD3D)
// ============================================================================
static void hspan(char *vid,int W,int H,int y,int x0,int x1,char col){
    char *p;int tmp;
    if(y<0||y>=H)return;
    if(x0>x1){tmp=x0;x0=x1;x1=tmp;}
    if(x0<0)x0=0;if(x1>=W)x1=W-1;if(x0>x1)return;
    p=vid+y*W+x0;tmp=x1-x0+1;while(tmp-->0)*p++=col;
}

static void fill_tri(char *vid,int W,int H,
                     int x0,int y0,int x1,int y1,int x2,int y2,char col){
    int tmp,y;float t,xl,xs;
    if(y0>y1){tmp=y0;y0=y1;y1=tmp;tmp=x0;x0=x1;x1=tmp;}
    if(y1>y2){tmp=y1;y1=y2;y2=tmp;tmp=x1;x1=x2;x2=tmp;}
    if(y0>y1){tmp=y0;y0=y1;y1=tmp;tmp=x0;x0=x1;x1=tmp;}
    if(y0==y2){hspan(vid,W,H,y0,x0,x2,col);return;}
    for(y=y0;y<=y2;y++){
        t=(float)(y-y0)/(float)(y2-y0);
        xl=(float)x0+(float)(x2-x0)*t;
        if(y<=y1){t=(y1>y0)?(float)(y-y0)/(float)(y1-y0):0.0f;xs=(float)x0+(float)(x1-x0)*t;}
        else{t=(y2>y1)?(float)(y-y1)/(float)(y2-y1):1.0f;xs=(float)x1+(float)(x2-x1)*t;}
        hspan(vid,W,H,y,(int)xl,(int)xs,col);
    }
}

// ============================================================================
// Rasterizador con textura perspecto-correcto.
// Recibe u/w, v/w y 1/w en los extremos del span; interpola linealmente
// esas tres magnitudes y divide en cada pixel: u = (u/w)/(1/w).
// ============================================================================
static void hspan_tex(char *vid,int W,int H,int y,
                      int xl,float uwl,float vwl,float iwl,
                      int xr,float uwr,float vwr,float iwr,
                      char *tex,int tw,int th){
    int tmp,x,len;char *p;float tf;
    float duw,dvw,diw,cuw,cvw,ciw;
    int tx,ty;

    if(y<0||y>=H)return;
    if(xl>xr){
        tmp=xl;xl=xr;xr=tmp;
        tf=uwl;uwl=uwr;uwr=tf; tf=vwl;vwl=vwr;vwr=tf; tf=iwl;iwl=iwr;iwr=tf;
    }
    len=xr-xl;
    if(len<0)return;

    {float flen=len>0?(float)len:1.0f;
     duw=(uwr-uwl)/flen; dvw=(vwr-vwl)/flen; diw=(iwr-iwl)/flen;}
    cuw=uwl; cvw=vwl; ciw=iwl;

    // Clip izquierdo
    if(xl<0){float clip=(float)(-xl);cuw+=clip*duw;cvw+=clip*dvw;ciw+=clip*diw;xl=0;}
    if(xr>=W)xr=W-1;
    if(xl>xr)return;

    p=vid+y*W+xl;
    for(x=xl;x<=xr;x++){
        // Division perspecto-correcta: u = (u/w) / (1/w)
        float w=(ciw>1e-6f)?1.0f/ciw:1e6f;
        float fu=uv_swap?cvw:cuw, fv=uv_swap?cuw:cvw;
        tx=(int)(fu*w*(float)tw); if(tx<0)tx=0;else if(tx>=tw)tx=tw-1;
        ty=(int)(fv*w*(float)th); if(ty<0)ty=0;else if(ty>=th)ty=th-1;
        if(uv_flip_u)tx=tw-1-tx;
        if(uv_flip_v)ty=th-1-ty;
        *p++=tex[ty*tw+tx];
        cuw+=duw; cvw+=dvw; ciw+=diw;
    }
}

// fill_tri_tex recibe ademas la profundidad perspectiva (pz) de cada vertice.
static void fill_tri_tex(char *vid,int W,int H,
    int x0,int y0,float u0,float v0,float w0,
    int x1,int y1,float u1,float v1,float w1,
    int x2,int y2,float u2,float v2,float w2,
    char *tex,int tw,int th){
    int tmp,y;float t,xl,xs,tf;
    // Precalcular u/w, v/w, 1/w en cada vertice
    float iw0,iw1,iw2,uw0,vw0,uw1,vw1,uw2,vw2;
    float uwl,vwl,iwl,uws,vws,iws;

    if(w0<0.01f)w0=0.01f; if(w1<0.01f)w1=0.01f; if(w2<0.01f)w2=0.01f;
    iw0=1.0f/w0; iw1=1.0f/w1; iw2=1.0f/w2;
    uw0=u0*iw0; vw0=v0*iw0;
    uw1=u1*iw1; vw1=v1*iw1;
    uw2=u2*iw2; vw2=v2*iw2;

    // Ordenar por Y (burbuja de 3 elementos)
    #define SWAPV(a,b) tf=(a);(a)=(b);(b)=tf;
    #define SWAPI(a,b) tmp=(a);(a)=(b);(b)=tmp;
    #define SORT2(ya,xa,ua,va,ia, yb,xb,ub,vb,ib) \
        if(ya>yb){SWAPI(ya,yb) SWAPI(xa,xb) SWAPV(ua,ub) SWAPV(va,vb) SWAPV(ia,ib)}
    SORT2(y0,x0,uw0,vw0,iw0, y1,x1,uw1,vw1,iw1)
    SORT2(y1,x1,uw1,vw1,iw1, y2,x2,uw2,vw2,iw2)
    SORT2(y0,x0,uw0,vw0,iw0, y1,x1,uw1,vw1,iw1)
    #undef SORT2
    #undef SWAPI
    #undef SWAPV

    if(y0==y2)return;

    for(y=y0;y<=y2;y++){
        t=(float)(y-y0)/(float)(y2-y0);
        xl=(float)x0+(float)(x2-x0)*t;
        uwl=uw0+(uw2-uw0)*t; vwl=vw0+(vw2-vw0)*t; iwl=iw0+(iw2-iw0)*t;

        if(y<=y1){
            t=(y1>y0)?(float)(y-y0)/(float)(y1-y0):0.0f;
            xs=(float)x0+(float)(x1-x0)*t;
            uws=uw0+(uw1-uw0)*t; vws=vw0+(vw1-vw0)*t; iws=iw0+(iw1-iw0)*t;
        } else {
            t=(y2>y1)?(float)(y-y1)/(float)(y2-y1):1.0f;
            xs=(float)x1+(float)(x2-x1)*t;
            uws=uw1+(uw2-uw1)*t; vws=vw1+(vw2-vw1)*t; iws=iw1+(iw2-iw1)*t;
        }
        hspan_tex(vid,W,H,y,(int)xl,uwl,vwl,iwl,(int)xs,uws,vws,iws,tex,tw,th);
    }
}

// ============================================================================
// KD3DT_LOAD: parsea OBJ con coordenadas UV
// ============================================================================
static void kd3dt_load_fn(void){
    int str_off=getparm();
    char fname[64],line[256],*p;
    FILE *f;
    int vi[8],uvi[8],nv,i;

    div2c(str_off,fname,sizeof(fname));
    n_verts=0;n_uvs=0;n_tris=0;mesh_ok=0;has_uvs=0;

    f=div_fopen(fname,"r");
    if(!f){
        s_cpy(kd3dt_msg,"NO FILE: ");s_cat(kd3dt_msg,fname);
        kd3dt_msg_frames=-1;retval(0);return;
    }

    while(read_line(f,line,sizeof(line))){
        if(line[0]=='v'&&line[1]==' '){
            if(n_verts<MAX_VERTS){
                p=line+2;
                mesh_v[n_verts].x=-sc_atof(p);p=next_tok(p); // negado: corrige espejo del +180 en Y
                mesh_v[n_verts].y=sc_atof(p);p=next_tok(p);
                mesh_v[n_verts].z=sc_atof(p);
                n_verts++;
            }
        } else if(line[0]=='v'&&line[1]=='t'&&line[2]==' '){
            if(n_uvs<MAX_UVS){
                p=line+3;
                mesh_uv[n_uvs].u=sc_atof(p); p=next_tok(p);
                // OBJ: V=0 es la fila inferior; MAP DIV2: fila 0 es la superior.
                mesh_uv[n_uvs].v=1.0f-sc_atof(p);
                n_uvs++;
            }
        } else if(line[0]=='f'&&line[1]==' '){
            p=line+2;nv=0;
            while(*p&&nv<8){
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
                    n_tris++;
                }
            }
        }
    }

    div_fclose(f);

    has_uvs=(n_uvs>0);
    mesh_ok=(n_tris>0);

    if(mesh_ok){
        char num[8];
        s_cpy(kd3dt_msg,"KD3DT ");s_itos(n_tris,num);s_cat(kd3dt_msg,num);
        s_cat(kd3dt_msg,has_uvs?" tri+UV":" tri");
        kd3dt_msg_frames=-1;
    } else {
        s_cpy(kd3dt_msg,"KD3DT ERR: ");s_cat(kd3dt_msg,fname);
        kd3dt_msg_frames=-1;
    }
    retval(mesh_ok?n_tris:0);
}

// ============================================================================
// KD3DT_SETTEX: carga textura desde fichero MAP de DIV2
// ============================================================================
static void kd3dt_settex_fn(void){
    int str_off=getparm();
    char fname[64], magic[8];
    FILE *f;
    int w, h, npoints, pix_size;

    div2c(str_off,fname,sizeof(fname));

    if(tex_data){div_free(tex_data);tex_data=NULL;tex_w=tex_h=0;}

    f=div_fopen(fname,"rb");
    if(!f){
        s_cpy(kd3dt_msg,"TEX NO FILE: ");s_cat(kd3dt_msg,fname);
        kd3dt_msg_frames=-1;retval(0);return;
    }

    if((int)fread(magic,1,8,f)!=8||magic[0]!='m'||magic[1]!='a'||magic[2]!='p'){
        s_cpy(kd3dt_msg,"TEX: no es MAP DIV2");kd3dt_msg_frames=-1;
        div_fclose(f);retval(0);return;
    }

    // Estructura real del MAP DIV2 (verificado con xxd y tamano de fichero):
    //   offset 8 : width  (unsigned short, 2 bytes LE)
    //   offset 10: height (unsigned short, 2 bytes LE)
    //   offset 12: codigo del grafico (DWORD, 4 bytes) -- NO es npoints
    //   offset 16: nombre/descripcion (32 bytes)
    //   offset 48: paleta (256*3 = 768 bytes)
    //   offset 816: rangos de color / colorbars (576 bytes)
    //   offset 1392: npoints (WORD, 2 bytes)
    //   offset 1394: npoints*4 bytes de puntos de control
    //   offset 1394 + npoints*4: width*height bytes de pixels
    {
        unsigned short sw=0, sh=0, snp=0;
        if((int)fread(&sw,2,1,f)!=1||(int)fread(&sh,2,1,f)!=1){
            s_cpy(kd3dt_msg,"TEX: error leyendo dim");kd3dt_msg_frames=-1;
            div_fclose(f);retval(0);return;
        }
        // Saltar codigo(4) + nombre(32) + paleta(768) + rangos(576) = 1380 bytes,
        // pasando de offset 12 hasta offset 1392 (el WORD npoints).
        fseek(f,1380L,SEEK_CUR);
        if((int)fread(&snp,2,1,f)!=1){
            s_cpy(kd3dt_msg,"TEX: error leyendo npts");kd3dt_msg_frames=-1;
            div_fclose(f);retval(0);return;
        }
        w=(int)sw; h=(int)sh; npoints=(int)snp;
    }
    if(w<=0||h<=0||w>1024||h>1024){
        s_cpy(kd3dt_msg,"TEX: tamano invalido");kd3dt_msg_frames=-1;
        div_fclose(f);retval(0);return;
    }

    // Saltar puntos de control (2 shorts = 4 bytes por punto)
    if(npoints>0)fseek(f,(long)npoints*4L,SEEK_CUR);

    pix_size=w*h;
    tex_data=(char*)div_malloc((size_t)pix_size);
    if(!tex_data){
        s_cpy(kd3dt_msg,"TEX: sin memoria");kd3dt_msg_frames=-1;
        div_fclose(f);retval(0);return;
    }

    if((int)fread(tex_data,1,(size_t)pix_size,f)!=pix_size){
        s_cpy(kd3dt_msg,"TEX: error lectura");kd3dt_msg_frames=-1;
        div_free(tex_data);tex_data=NULL;
        div_fclose(f);retval(0);return;
    }

    tex_w=w;tex_h=h;
    div_fclose(f);

    {char num[8];
     s_cpy(kd3dt_msg,"TEX ");s_itos(w,num);s_cat(kd3dt_msg,num);
     s_cat(kd3dt_msg,"x");s_itos(h,num);s_cat(kd3dt_msg,num);
     kd3dt_msg_frames=-1;}
    retval(1);
}

// ============================================================================
// KD3DT_DRAW / KD3DT_SETCOLOR
// ============================================================================
static void kd3dt_draw_fn(void){
    draw_scale=getparm();draw_rz=getparm();draw_ry=getparm();
    draw_rx=getparm();draw_cy=getparm();draw_cx=getparm();
    draw_active=1;retval(0);
}

static void kd3dt_setcolor_fn(void){
    int b=getparm(),g=getparm(),r=getparm(),i;
    for(i=0;i<PAL_SHADES;i++){
        float t=AMBIENT+(1.0f-AMBIENT)*(float)i/(float)(PAL_SHADES-1);
        palette[(PAL_BASE+i)*3+0]=(char)((int)((float)r*t+0.5f));
        palette[(PAL_BASE+i)*3+1]=(char)((int)((float)g*t+0.5f));
        palette[(PAL_BASE+i)*3+2]=(char)((int)((float)b*t+0.5f));
    }
    set_palette=1;retval(0);
}

// ============================================================================
// do_render: nucleo 3D (igual que KD3D pero con rasterizado textured/flat)
// ============================================================================
static void do_render(int cx,int cy,int rx_d,int ry_d,int rz_d,int scale_p){
    float scale=(float)scale_p*0.01f;
    float PI=3.14159265f;
    float rx=(float)rx_d*(PI/180.0f);
    // +180 gira el modelo para que la cara frontal de Blender (Forward=-Z Up=Y)
    // quede cara a la camara. Equivalente a invertir el winding pero sin tocarlo.
    float ry=(float)(ry_d+180)*(PI/180.0f);
    float rz=(float)rz_d*(PI/180.0f);
    float cxr=(float)cos(rx),sxr=(float)sin(rx);
    float cyr=(float)cos(ry),syr=(float)sin(ry);
    float czr=(float)cos(rz),szr=(float)sin(rz);
    int W,H,i,ndraw;
    char *vid;

    if(!mesh_ok||!_buffer||!_wide||!_height)return;
    vid=(char*)(*((unsigned long*)_buffer));
    if(!vid)return;
    W=*_wide;H=*_height;

    // 1. Transformar vertices
    for(i=0;i<n_verts;i++){
        float x=mesh_v[i].x*scale,y=mesh_v[i].y*scale,z=mesh_v[i].z*scale,t;
        t=y*cxr-z*sxr;z=y*sxr+z*cxr;y=t;
        t=x*cyr+z*syr;z=-x*syr+z*cyr;x=t;
        t=x*czr-y*szr;y=x*szr+y*czr;x=t;
        tv[i][0]=x;tv[i][1]=y;tv[i][2]=z;
        float pz=z+CAM_DIST;if(pz<0.01f)pz=0.01f;
        sv[i][0]=cx+(int)(x*FOV/pz);
        sv[i][1]=cy-(int)(y*FOV/pz);
        sv_z[i]=pz;
    }

    // 2. Backface cull + calcular shade + preparar sort
    ndraw=0;
    for(i=0;i<n_tris;i++){
        int a=mesh_t[i].a,b=mesh_t[i].b,c=mesh_t[i].c;
        int sx0=sv[a][0],sy0=sv[a][1],sx1=sv[b][0],sy1=sv[b][1],sx2=sv[c][0],sy2=sv[c][1];
        // X se cargo negado, lo que invierte el winding: caras frontales tienen area2 < 0.
        int area2=(sx1-sx0)*(sy2-sy0)-(sx2-sx0)*(sy1-sy0);
        if(area2>=0)continue;

        float ex1=tv[b][0]-tv[a][0],ey1=tv[b][1]-tv[a][1],ez1=tv[b][2]-tv[a][2];
        float ex2=tv[c][0]-tv[a][0],ey2=tv[c][1]-tv[a][1],ez2=tv[c][2]-tv[a][2];
        float nx=ey1*ez2-ez1*ey2,ny=ez1*ex2-ex1*ez2,nz=ex1*ey2-ey1*ex2;
        float nlen=(float)sqrt((double)(nx*nx+ny*ny+nz*nz));
        if(nlen>1e-6f){nx/=nlen;ny/=nlen;nz/=nlen;}

        float shade=nx*LX+ny*LY+nz*LZ;
        if(shade<0.0f)shade=0.0f;
        shade=AMBIENT+(1.0f-AMBIENT)*shade;
        int ci=(int)(shade*(float)(PAL_SHADES-1)+0.5f);
        if(ci<0)ci=0;if(ci>=PAL_SHADES)ci=PAL_SHADES-1;

        float depth=(sv_z[a]+sv_z[b]+sv_z[c])*(1.0f/3.0f);
        tsort[ndraw].depth=depth;
        tsort[ndraw].idx=i;
        tsort[ndraw].ci=ci;
        ndraw++;
    }

    // 3. Insertion sort back-to-front
    {int j;TSort tmp;
     for(j=1;j<ndraw;j++){
         tmp=tsort[j];int k=j-1;
         while(k>=0&&tsort[k].depth<tmp.depth){tsort[k+1]=tsort[k];k--;}
         tsort[k+1]=tmp;
     }}

    // 4. Rasterizar: textura si disponible, flat shading en caso contrario
    for(i=0;i<ndraw;i++){
        int ti=tsort[i].idx,ci=tsort[i].ci;
        int a=mesh_t[ti].a,b=mesh_t[ti].b,c=mesh_t[ti].c;

        if(tex_data&&has_uvs&&mesh_t[ti].ua>=0&&mesh_t[ti].ub>=0&&mesh_t[ti].uc>=0){
            fill_tri_tex(vid,W,H,
                sv[a][0],sv[a][1],mesh_uv[mesh_t[ti].ua].u,mesh_uv[mesh_t[ti].ua].v,sv_z[a],
                sv[b][0],sv[b][1],mesh_uv[mesh_t[ti].ub].u,mesh_uv[mesh_t[ti].ub].v,sv_z[b],
                sv[c][0],sv[c][1],mesh_uv[mesh_t[ti].uc].u,mesh_uv[mesh_t[ti].uc].v,sv_z[c],
                tex_data,tex_w,tex_h);
        } else {
            fill_tri(vid,W,H,
                sv[a][0],sv[a][1],
                sv[b][0],sv[b][1],
                sv[c][0],sv[c][1],(char)(PAL_BASE+ci));
        }
    }
    set_palette=1;
}

// ============================================================================
// post_process_buffer: callback de DIV2 (post-sprites, pre-flip)
// ============================================================================
void post_process_buffer(void){
    if(!_wide||!_height||*_wide<=0||*_height<=0||!_buffer)return;
    if(div_text_out)div_text_out("KD3DT",2,2);
    if(kd3dt_msg_frames!=0&&div_text_out){
        div_text_out(kd3dt_msg,2,12);
        if(kd3dt_msg_frames>0)kd3dt_msg_frames--;
    }
    if(!draw_active)return;
    do_render(draw_cx,draw_cy,draw_rx,draw_ry,draw_rz,draw_scale);
}

// ============================================================================
// KD3DT_UVMODE(flip_u, flip_v)  ->  siempre 0
//   Controla el espejado de las coordenadas UV al muestrear la textura.
//   flip_u=1 -> invierte U (espejo horizontal de la textura)
//   flip_v=1 -> invierte V adicional (la correccion OBJ->MAP ya se aplica
//               automaticamente al cargar: V_cargado = 1 - V_obj)
//
//   Para exportacion estandar de Blender (Forward=-Z Up=Y, Triangulate+UVs):
//     KD3DT_UVMODE(0, 0);   <- correcto si la orientacion es simetrica
//     KD3DT_UVMODE(1, 0);   <- correcto en la mayoria de modelos
//                              (el giro +180 en Y invierte el eje X proyectado,
//                               lo que espeja la textura horizontalmente)
// ============================================================================
static void kd3dt_uvmode_fn(void){
    int fv=getparm(), fu=getparm();
    uv_flip_u = (fu != 0);
    uv_flip_v = (fv != 0);
    retval(0);
}

// KD3DT_UVSWAP(on_off) -> 0
//   on_off=1: intercambia U y V al muestrear (prueba giro 90 grados de la textura)
//   on_off=0: comportamiento normal
static void kd3dt_uvswap_fn(void){
    uv_swap = (getparm() != 0);
    retval(0);
}

// ============================================================================
// Puntos de entrada de la DLL
// ============================================================================
void __export divlibrary(LIBRARY_PARAMS){
    COM_export("KD3DT_LOAD",     kd3dt_load_fn,     1);
    COM_export("KD3DT_SETTEX",   kd3dt_settex_fn,   1);
    COM_export("KD3DT_DRAW",     kd3dt_draw_fn,     6);
    COM_export("KD3DT_SETCOLOR", kd3dt_setcolor_fn, 3);
    COM_export("KD3DT_UVMODE",   kd3dt_uvmode_fn,   2);
    COM_export("KD3DT_UVSWAP",   kd3dt_uvswap_fn,   1);
}

void __export divmain(COMMON_PARAMS){
    int i;
    g_import=DIV_import;g_export=DIV_export;
    #define DIV_import g_import
    #define DIV_export g_export

    AutoLoad();
    GLOBAL_IMPORT();

    draw_active=0;kd3dt_msg[0]=0;kd3dt_msg_frames=0;
    tex_data=NULL;tex_w=0;tex_h=0;
    DIV_export("post_process_buffer",post_process_buffer);

    for(i=0;i<PAL_SHADES*3;i++)
        orig_pal[i]=palette[PAL_BASE*3+i];

    // Color inicial: blanco (fallback mientras no se llame KD3DT_SETCOLOR)
    {int j;
     for(j=0;j<PAL_SHADES;j++){
         float t=AMBIENT+(1.0f-AMBIENT)*(float)j/(float)(PAL_SHADES-1);
         palette[(PAL_BASE+j)*3+0]=(char)((int)(63.0f*t+0.5f));
         palette[(PAL_BASE+j)*3+1]=(char)((int)(63.0f*t+0.5f));
         palette[(PAL_BASE+j)*3+2]=(char)((int)(63.0f*t+0.5f));
     }
     set_palette=1;}

    #undef DIV_import
    #undef DIV_export
}

void __export divend(COMMON_PARAMS){
    int i;
    (void)DIV_import;(void)DIV_export;
    if(tex_data){div_free(tex_data);tex_data=NULL;}
    mesh_ok=0;
    for(i=0;i<PAL_SHADES*3;i++)
        palette[PAL_BASE*3+i]=orig_pal[i];
    set_palette=1;
}
