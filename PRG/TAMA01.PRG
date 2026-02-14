//------------------------------------------------------------------------------
// TÍTULO:      TAMA01.PRG - Tutorial: Obtener Hora del Sistema
// AUTOR:       Sebastian J. MONCHO MAQUET
// FECHA:       13/02/2026
// DESCRIPCIÓN: Primer ejemplo de un tutorial sobre cómo crear un juego de mascota virtual en MS-DOS.
//              Este ejemplo muestra cómo obtener la hora actual del sistema operativo.
// NOTA:        El programa crea un archivo temporal para obtener la fecha y hora de modificación,
//              que representa la hora actual. Presiona ESC para salir.
//              Código y comentarios en castellano para facilitar la comprensión.
//------------------------------------------------------------------------------

PROGRAM TAMA_WAIFU;
CONST
    nombre_fichero = "test.tmp";
    permisos = "w";
GLOBAL
    id_fichero;
    dato = 0;
BEGIN
    id_fichero = fopen(nombre_fichero, permisos);
    fwrite(OFFSET dato, sizeof(dato), id_fichero);
    fclose(id_fichero);

    get_fileinfo(nombre_fichero);

    // Fecha de última modificación
    write_int(0, 10, 50, 0, &fileinfo.day);      // día
    write_int(0, 50, 50, 0, &fileinfo.month);    // mes
    write_int(0, 90, 50, 0, &fileinfo.year);     // año

    // Hora de última modificación
    write_int(0, 10, 70, 0, &fileinfo.hour);     // hora
    write_int(0, 50, 70, 0, &fileinfo.min);      // minuto
    write_int(0, 90, 70, 0, &fileinfo.sec);      // segundo

    // Bucle para mantener el programa abierto
    LOOP
        IF (key(_ESC))
            exit(0, "Bye");
        END
        FRAME;
    END
END