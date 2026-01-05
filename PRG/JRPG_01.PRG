//------------------------------------------------------------------------------
// TITLE:       JRPG with graphic primitives
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        04/01/2026
// DESCRIPTION: Basic JRPG with characters as circles, tile-based scenario,
//              2 NPCs with dialogue.
//------------------------------------------------------------------------------

PROGRAM JRPG;
CONST MAX_NPC = 2;
GLOBAL
    offset_x = 0;
    offset_y = 0;
    player_x = 160;
    player_y = 120;
    STRUCT Controls
        INT left;
        INT right;
        INT up;
        INT down;
        INT talk;
        INT exit;
    END
    STRUCT Map
        INT tiles[32,24];
    END
    STRUCT DialogState
        INT process_id;     // Stores the ID of the active dialogue process; used to check if a dialogue is currently running (0 means no dialogue).
        INT closing;        // Boolean flag indicating whether the dialogue is in the process of closing.
        INT close_timer;    // Countdown timer for the dialogue closing animation or delay before fully closing.
        INT open_timer;     // Countdown timer for the dialogue opening delay to prevent immediate interactions.
        INT skip;           // Boolean flag to skip the letter-by-letter text animation and display the full text instantly.
        INT press_timer;    // Countdown timer to debounce key presses, preventing rapid repeated actions.
        INT complete;       // Boolean flag indicating whether the text animation has finished displaying the full dialogue.
        INT box_id;         // The draw ID of the dialogue box rectangle; used for deleting the box when closing.
    END
    STRUCT NPCData[MAX_NPC]
        STRING name;
        STRING dialogue;
        INT x;
        INT y;
        INT color;
    END
    STRUCT Colors
        INT field = 38;     // Green field
        INT mountain = 117; // Brown mountains
        INT river = 57;     // Blue river
        INT bridge = 8;     // Brown bridge
        INT city = 235;     // Yellow cities
        INT forest = 34;    // Dark green forest
    END
    STRUCT ZLevels
        INT map = 100;      // Map at the back
        INT npc = 0;        // NPCs over map
        INT player = -10;   // Player over map
        INT dialog = -200;  // Dialogue over everything
    END
    STRUCT ScreenConfig
        INT width = 320;
        INT height = 240;
        INT fps = 30;
    END
BEGIN
    set_mode(ScreenConfig.width * 1000 + ScreenConfig.height);
    set_fps(ScreenConfig.fps, 0);

    // Initialize controls
    InitControls();

    // Initialize the map
    InitMap();

    // Initialize NPC data
    InitNPCData();

    // Create processes
    map_drawer();
    npc(0);
    npc(1);
    player();
END

// Initializes the NPC data array.
// Sets predefined names, dialogues, positions, and colors for each NPC.
PROCESS InitNPCData()
PRIVATE
    i;
BEGIN
    NPCData[0].name = "NPC 1";
    NPCData[0].dialogue = "Hello, I am NPC 1. Welcome to the JRPG!";
    NPCData[0].x = 50;
    NPCData[0].y = 50;
    NPCData[0].color = 12;
    NPCData[1].name = "NPC 2";
    NPCData[1].dialogue = "Hello, I am NPC 2. Have a good day!";
    NPCData[1].x = 250;
    NPCData[1].y = 150;
    NPCData[1].color = 14;
END

// Generates the tile-based map.
// Assigns color values to each tile in the Map.tiles array,
// creating terrains like fields, mountains, rivers, bridges, forests, and cities
// based on position conditions.
PROCESS InitMap()
PRIVATE
    i, j;
BEGIN
    FROM i = 0 TO 31;
        FROM j = 0 TO 23;
            // Green field by default
            Map.tiles[i,j] = Colors.field;
            // Gray mountains on the edges
            IF (i < 4 OR i > 27 OR j < 3)
                Map.tiles[i,j] = Colors.mountain;
            END
            // Blue sea at the bottom
            IF (j > 20)
                Map.tiles[i,j] = Colors.river;
            END
            // Horizontal blue river in the middle
            IF (j == 12 OR j == 13)
                Map.tiles[i,j] = Colors.river;
            END
            // Brown bridge over the river in the center
            IF (i == 16 AND (j == 12 OR j == 13))
                Map.tiles[i,j] = Colors.bridge;
            END
            // Dark green forest in central areas
            IF ((i >= 8 AND i <= 15 AND j >= 6 AND j <= 11) OR (i >= 18 AND i <= 25 AND j >= 14 AND j <= 19))
                Map.tiles[i,j] = Colors.forest;
            END
            // Yellow cities
            IF ((i >= 6 AND i <= 9 AND j >= 5 AND j <= 8) OR (i >= 20 AND i <= 23 AND j >= 15 AND j <= 18))
                Map.tiles[i,j] = Colors.city;
            END
            // Path connecting the two cities via the bridge
            // Vertical path from first city to above river
            IF (i == 7 AND j >= 6 AND j <= 11)
                Map.tiles[i,j] = Colors.bridge;
            END
            // Horizontal path above river to bridge column
            IF (j == 11 AND i >= 7 AND i <= 16)
                Map.tiles[i,j] = Colors.bridge;
            END
            // Vertical path from above river down to second city level
            IF (i == 16 AND j >= 11 AND j <= 15)
                Map.tiles[i,j] = Colors.bridge;
            END
            // Horizontal path to second city
            IF (j == 15 AND i >= 16 AND i <= 21)
                Map.tiles[i,j] = Colors.bridge;
            END
        END
    END
END

// Assigns key constants to the Controls struct.
// Sets values for player input: left, right, up, down, talk, and exit.
PROCESS InitControls()
BEGIN
    Controls.left = _LEFT;
    Controls.right = _RIGHT;
    Controls.up = _UP;
    Controls.down = _DOWN;
    Controls.talk = _ENTER;
    Controls.exit = _ESC;
END

// Continuously renders the visible portion of the map.
// Calculates the range of tiles on screen, draws filled rectangles
// for each tile with the appropriate color, and manages draw IDs for cleanup.
PROCESS map_drawer()
PRIVATE
    i, j, color, x1, y1, x2, y2;
    i_min, i_max, j_min, j_max;
    draw_ids[256]; // array for draw IDs (maximum safe)
    draw_counter = 0;
BEGIN
    LOOP
        // Delete previous draws
        FOR (i = 0; i < draw_counter; i++)
            delete_draw(draw_ids[i]);
        END
        draw_counter = 0;

        // Calculate visible tile range
        IF (((-offset_x + 31) / 32) - 1 > 0) i_min = ((-offset_x + 31) / 32) - 1; ELSE i_min = 0; END
        IF (31 < ((ScreenConfig.width - offset_x) / 32) + 1) i_max = 31; ELSE i_max = ((ScreenConfig.width - offset_x) / 32) + 1; END
        IF (((-offset_y + 31) / 32) - 1 > 0) j_min = ((-offset_y + 31) / 32) - 1; ELSE j_min = 0; END
        IF (23 < ((ScreenConfig.height - offset_y) / 32) + 1) j_max = 23; ELSE j_max = ((ScreenConfig.height - offset_y) / 32) + 1; END
        i = i_min;
        WHILE (i <= i_max)
            j = j_min;
            WHILE (j <= j_max)
                x1 = i * 32 + offset_x;
                y1 = j * 32 + offset_y;
                x2 = x1 + 32;
                y2 = y1 + 32;
                // Use map color
                color = Map.tiles[i,j];
                // Draw filled rectangle
                draw_z = ZLevels.map;
                draw_ids[draw_counter] = draw(3, color, 15, 0, x1, y1, x2, y2);
                draw_counter++;
                j++;
            END
            i++;
        END

        FRAME;
    END
END

// Handles player movement, camera centering, interaction with NPCs,
// dialogue management, and rendering the player as a circle.
// Includes terrain-based speed adjustments and collision detection for water.
PROCESS player()
PRIVATE
    draw_id = 0;
    screen_x, screen_y;
    tile_i, tile_j, speed;
    new_x, new_y;
    closest_npc = -1;
    temp_dist;
    min_dist;
    i;
BEGIN
    x = player_x;
    y = player_y;
    LOOP
        // Calculate current tile and speed
        tile_i = player_x / 32;
        tile_j = player_y / 32;
        speed = 5;
        IF (Map.tiles[tile_i, tile_j] == Colors.forest OR Map.tiles[tile_i, tile_j] == Colors.mountain)
            speed = 2;
        END

        // Movement only if no dialogue
        IF (DialogState.process_id == 0)
            IF (KEY(Controls.left))
                new_x = player_x - speed;
                tile_i = new_x / 32;
                tile_j = player_y / 32;
                IF (Map.tiles[tile_i, tile_j] != Colors.river)
                    player_x = new_x;
                END
            END
            IF (KEY(Controls.right))
                new_x = player_x + speed;
                tile_i = new_x / 32;
                tile_j = player_y / 32;
                IF (Map.tiles[tile_i, tile_j] != Colors.river)
                    player_x = new_x;
                END
            END
            IF (KEY(Controls.up))
                new_y = player_y - speed;
                tile_i = player_x / 32;
                tile_j = new_y / 32;
                IF (Map.tiles[tile_i, tile_j] != Colors.river)
                    player_y = new_y;
                END
            END
            IF (KEY(Controls.down))
                new_y = player_y + speed;
                tile_i = player_x / 32;
                tile_j = new_y / 32;
                IF (Map.tiles[tile_i, tile_j] != Colors.river)
                    player_y = new_y;
                END
            END
        END

        // Center camera on player
        offset_x = ScreenConfig.width / 2 - player_x;
        offset_y = ScreenConfig.height / 2 - player_y;
        screen_x = ScreenConfig.width / 2;
        screen_y = ScreenConfig.height / 2;

        IF (KEY(Controls.exit))
            EXIT("Goodbye", 0);
        END

        x = player_x;
        y = player_y;

        // Draw player circle
        IF (draw_id != 0)
            delete_draw(draw_id);
        END
        draw_z = ZLevels.player;
        draw_id = draw(5, 15, 15, 0, screen_x - 10, screen_y - 10, screen_x + 10, screen_y + 10);

        // Calculate distances for interaction
        closest_npc = -1;
        min_dist = 51; // greater than 50
        FROM i = 0 TO MAX_NPC - 1:
            temp_dist = sqrt((player_x - NPCData[i].x) * (player_x - NPCData[i].x) + (player_y - NPCData[i].y) * (player_y - NPCData[i].y));
            IF (temp_dist < 50 AND temp_dist < min_dist)
                closest_npc = i;
                min_dist = temp_dist;
            END
        END

        // Check interaction with NPCs
        IF (closest_npc != -1 AND KEY(Controls.talk))
            IF (DialogState.press_timer == 0)
                DialogState.press_timer = ScreenConfig.fps / 3;
                IF (DialogState.process_id == 0)
                    DialogState.process_id = dialogue(NPCData[closest_npc].name, NPCData[closest_npc].dialogue);
                ELSE
                    IF (DialogState.open_timer == 0)
                        IF (DialogState.complete == 1)
                            DialogState.closing = 1;
                        ELSE
                            DialogState.skip = 1;
                        END
                    END
                END
            END
        END

        // Decrement press timer
        IF (DialogState.press_timer > 0)
            DialogState.press_timer--;
        END

        FRAME;
    END
END

// Renders the specified NPC as a circle on screen if visible.
// Calculates screen position and manages draw IDs.
PROCESS npc(id_char)
PRIVATE
    draw_id = 0;
    screen_x, screen_y;
    color = 0;
BEGIN
    x = NPCData[id_char].x;
    y = NPCData[id_char].y;
    LOOP
        // Calculate screen position
        screen_x = x + offset_x;
        screen_y = y + offset_y;

        // Cleanup
        IF (draw_id != 0)
            delete_draw(draw_id);
            draw_id = 0;
        END
        // Draw NPC circle only if visible on screen
        IF (screen_x + 10 > 0 AND screen_x - 10 < ScreenConfig.width AND screen_y + 10 > 0 AND screen_y - 10 < ScreenConfig.height)
            color = NPCData[id_char].color;
            draw_z = ZLevels.npc;
            draw_id = draw(5, color, 15, 0, screen_x - 10, screen_y - 10, screen_x + 10, screen_y + 10);
        END

        FRAME;
    END
END

// Manages the dialogue system.
// Displays the speaker's name and animates text letter-by-letter.
// Handles user input to skip or close, draws the dialogue box,
// name, and text, and controls timers for opening and closing.
PROCESS dialogue(STRING name, STRING text)
PRIVATE
    STRING temp; // temporary string to build the text
    index = 0;
    letter_delay = 0;
    text_id = 0;
    name_id = 0;
    i;
    len;
    complete = 0;
BEGIN
    DialogState.closing = 0;
    DialogState.close_timer = 0;
    DialogState.open_timer = ScreenConfig.fps / 3; // delay to avoid immediate closing
    DialogState.skip = 0;
    DialogState.complete = 0;
    len = strlen(text);
    
    // Draw dialogue box
    draw_z = ZLevels.dialog;
    DialogState.box_id = draw(3, 0, 15, 0, 20, ScreenConfig.height - 70, ScreenConfig.width - 20, ScreenConfig.height - 20); // black rectangle

    // Write speaker name
    name_id = write(0, 30, ScreenConfig.height - 65, 0, name);
    LOOP

        // Decrement open timer
        IF (DialogState.open_timer > 0)
            DialogState.open_timer--;
        END

        // Animate text letter by letter
        IF (DialogState.skip)
            index = len;
            DialogState.skip = 0;
            // Build temp with the full text
            i = 0;
            WHILE (i < index)
                temp[i] = text[i];
                i++;
            END
            temp[index] = 0;
            complete = 1;
            DialogState.complete = 1;
        END
        IF (index < len)
            IF (letter_delay == 0)
                index++;
                // Build temp with the first index letters
                i = 0;
                WHILE (i < index)
                    temp[i] = text[i]; // 0-based
                    i++;
                END
                temp[index] = 0; // null-terminate
                letter_delay = ScreenConfig.fps / 15; // delay between letters
            ELSE
                letter_delay--;
            END
        ELSE
            complete = 1;
            DialogState.complete = 1;
        END

        // Write current text
        IF (text_id != 0)
            delete_text(text_id);
        END
        text_id = write(0, 30, ScreenConfig.height - 45, 0, temp);

        // Check closing
        IF (DialogState.closing)
            IF (complete == 0)
                // Skip to end
                index = len;
                i = 0;
                WHILE (i < len)
                    temp[i] = text[i];
                    i++;
                END
                temp[len] = 0;
                complete = 1;
            ELSE
                // Close with delay
                IF (DialogState.close_timer == 0)
                    DialogState.close_timer = ScreenConfig.fps / 3; // closing delay
                END
                DialogState.close_timer--;
                IF (DialogState.close_timer == 0)
                    delete_draw(DialogState.box_id);
                    DialogState.box_id = 0;
                    delete_text(text_id);
                    delete_text(name_id);
                    DialogState.closing = 0;
                    DialogState.process_id = 0;
                    RETURN;
                END
            END
        END

        FRAME;
    END
END
