PROGRAM VISUAL_NOVEL_EXAMPLE;
GLOBAL
    STRUCT Dialog[4]
        STRING Background;
        STRING Character;
        STRING Text;
    END
    file_fnt;
    file_bg;
    file_dialog_text_bg;
    file_dialog_name_bg;
    dialog_text[5];
PRIVATE
    INT scene = 0;
    INT second = 0;
    INT complete = 0;
BEGIN
    SET_MODE(m640x480);
    SET_FPS(30, 0);
    LoadStaticResources();
    LoadData();
    LoadScene(scene);
    LOOP
        if (second < strlen(Dialog[scene].Text))
            PrintDialog(Dialog[scene].Text, second);
            second++;
        ELSE
            complete = 1;
        END
        IF (key(_esc)) exit("Bye", 0); end
        IF (scan_code != 0)
            IF (complete == 1)
                scene++;
                IF (scene >= 4)
                    scene = 0;
                END
                LoadScene(scene);
                second = 0;
                complete = 0;
            ELSE
                second = strlen(Dialog[scene].Text) - 1;
                PrintDialog(Dialog[scene].Text, second);
            END
        END
        FRAME;
    END;
END

process LoadStaticResources()
BEGIN
   file_fnt=load_fnt("VNEXAMPL.FNT");
   file_dialog_name_bg=load_map("ASSETS/BG/DIALOGCH.MAP");
   file_dialog_text_bg=load_map("ASSETS/BG/DIALOG.MAP");
END

process LoadScene(INT scene)
BEGIN
    delete_text(all_text);
    delete_draw(all_drawing);
    clear_screen();
    unload_map(file_bg);
    file_bg=load_map(Dialog[scene].Background);
    put_screen(0, file_bg);
    xput(0, file_dialog_text_bg, 15, 375, 0, 100, 4, 0);
    xput(0, file_dialog_name_bg, 15, 355, 0, 100, 4, 0);
    write(file_fnt, 127, 365, 4, Dialog[scene].Character);
END

process LoadData()
BEGIN
    MockData();
END

process MockData()
BEGIN
    SetDialog(0, "ASSETS/BG/001.MAP", "Narrator",
        "It was a sweet summer day in this Isekai-style universe.");
    SetDialog(1, "ASSETS/BG/001.MAP", "Narrator",
        "And then she appeared, a sweet green elf...");
    SetDialog(2, "ASSETS/BG/002.MAP", "Gidna",
        "Excuse me, good sir...\nWould you happen to have a few coins for a little beer?");
    SetDialog(3, "ASSETS/BG/003.MAP", "Gidna",
        "Believe it or not,\nI'm allergic to water.");
END

process SetDialog(INT element, STRING Background, STRING Character, STRING Text)
BEGIN
    Dialog[element].Background = Background;
    Dialog[element].Character = Character;
    Dialog[element].Text = Text;
END

/*
    Prints the dialogs in the scene in multiple lines
    @Text: Full dialog
    @second: Position where cut the lines drawing
*/
process PrintDialog(STRING text, int second)
PRIVATE
    INT i, j;
    INT pos;
    INT prev;
    STRING temp;
    INT line_count;
    INT dialog_y;
    INT copied_last;
    STRUCT Lines[5]
        STRING Text;
    END
BEGIN
    if (second > strlen(text) - 1)
        second = strlen(text) - 1;
    END

    prev = 0;
    line_count = 0;
    copied_last = 0;

    while (line_count < 5)
        // Gets the next line break (if any)
        pos = strstr(text, "\n");

        if (pos == -1 OR pos > second)
            // No more breaks found or it's beyong second
            j = 0;
            for(i = prev; i <= second; i++)
                temp[j] = text[i];
                j++;
            END
            temp[j] = 0;
            strcpy(Lines[line_count].Text, temp);
            line_count++;
            copied_last = 1; // Mark that we already copied the remaining text
            break;
        END

        // Copy from prev to just before the line break
        j = 0;
        for(i = prev; i < pos; i++)
            temp[j] = text[i];
            j++;
        END
        temp[j] = 0;
        strcpy(Lines[line_count].Text, temp);
        line_count++;

        /* Replace the "\n" in the original string
         to avoid matching it again*/
        text[pos] = ' ';
        text[pos + 1] = ' ';

        prev = pos + 2;
    END

    /* If there's still remaining text
     amd we haven't copied it yet */
    if (copied_last == 0 AND prev <= second AND line_count < 5)
        j = 0;
        for(i = prev; i <= second; i++)
            temp[j] = text[i];
            j++;
        END
        temp[j] = 0;
        strcpy(Lines[line_count].Text, temp);
        line_count++;
    END

    // Clear previous dialog lines
    for(i = 0; i < 5; i++)
        if (dialog_text[i] != 0)
            delete_text(dialog_text[i]);
        END
    END

    // Draw the new dialog lines
    dialog_y = 380;
    for(i = 0; i < line_count; i++)
        dialog_text[i] = write(file_fnt, 30, dialog_y, 0, Lines[i].Text);
        dialog_y += 20;
    END
END

