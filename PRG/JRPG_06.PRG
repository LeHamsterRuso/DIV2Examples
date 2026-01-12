//------------------------------------------------------------------------------
// TITLE:       JRPG with Quest System
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        12/01/2026
// DESCRIPTION: Enhanced JRPG with quest system implementation.
//
// NOTE:        Run MAPGEN03.PRG first to generate MapsV3.dat and ItemsV3.dat files before running this program.
//
//              KEY IMPROVEMENTS OVER JRPG_05:
//              - Quest system: NPCs can offer quests with item collection objectives
//              - Gold/currency system: Track and display player's gold
//              - Quest states: NOT_STARTED, ACTIVE, COMPLETED
//              - Quest rewards: Gold and item rewards upon completion
//              - Dynamic NPC dialogues based on quest state
//              - Inventory item removal system for quest turn-ins
//              - Multiple dialogues per NPC (up to 5 sequential dialogues)
//              - Zoom effect during dialogues (200% with smooth transition)
//------------------------------------------------------------------------------

PROGRAM JRPG;
CONST
    SONG_FILE = "MOD/BULERIA.S3M";
    // Quest states
    QUEST_NOT_STARTED = 0;
    QUEST_ACTIVE = 1;
    QUEST_COMPLETED = 2;
GLOBAL
    STRUCT ItemList[20]
        STRING name[20];
        STRING description[50];
        INT price;
    END
    INT item_list_count = 0;
    offset_x = 0;
    offset_y = 0;
    current_map = 0; // 0 = world, 1 = city1, 2 = city2
    INT player_gold = 0; // Player's gold currency
    STRUCT PlayerData
        INT x = 160;
        INT y = 120;
        INT graph = 2;
        INT direction = 2;
        INT anim_frame = 0;
        INT anim_counter = 0;
    END
    song_id = 0;
    prev_offset_x = -1;
    prev_offset_y = -1;
    prev_map = 0;
    STRUCT Inventory[10]
        STRING item[20];
        INT quantity;
        STRING description[50];
    END
    INT item_count = 0;
    INT inventory_open = 0; // Legacy flag (no longer used for logic)
    INT inventory_active = 0; // True while inventory_screen process is running
    INT submenu_finished = 0; // Flag to signal when submenu has finished
    INT force_redraw = 0; // Force map redraw
    INT dialogue_zoom = 100; // Zoom level during dialogues (100 = normal, 150 = 1.5x)
    STRUCT Controls
        INT left;
        INT right;
        INT up;
        INT down;
        INT talk;
        INT inventory;
        INT exit;
    END
    STRUCT MapData[3]
        INT tiles[32,24];
        INT tilesX;
        INT tilesY;
        STRING fpg_file[30];
        STRUCT TeleportData[50]
            INT tile_i;
            INT tile_j;
            INT target_map;
            INT target_x;
            INT target_y;
        END
        INT teleport_count;
        STRUCT NPCData[10]
            STRING name[20];
            STRUCT dialogues[5]
                STRING dialogue[50];
            END
            INT dialogue_count; // Number of dialogues
            INT x;
            INT y;
            INT color;
            INT gives_item;
            INT item_id;
            INT npc_id;
            INT graph;
            STRING fpg_file[30];
            // Quest data
            INT has_quest;
            STRUCT quest_dialogues[5]
                STRING dialogue[50];
            END
            INT quest_dialogue_count;
            STRUCT quest_accept_texts[5]
                STRING text[50];
            END
            INT quest_accept_count;
            STRUCT quest_progress_texts[5]
                STRING text[50];
            END
            INT quest_progress_count;
            STRUCT quest_complete_texts[5]
                STRING text[50];
            END
            INT quest_complete_count;
            STRUCT quest_reward_texts[5]
                STRING text[50];
            END
            INT quest_reward_count;
            INT quest_item_id;
            INT quest_item_count;
            INT quest_gold_reward;
        END
        INT npc_count;
    END
    // Quest tracking - one per NPC (indexed by npc_id)
    INT quest_states[10];
    // Temporary dialogue storage for passing to dialogue process
    STRUCT temp_dialogues[5]
        STRING dialogue[50];
    END
    INT temp_dialogue_count;
    STRUCT DialogState
        INT process_id;             // Stores the ID of the active dialogue process; used to check if a dialogue is currently running (0 means no dialogue).
        INT closing;                // Boolean flag indicating whether the dialogue is in the process of closing.
        INT close_timer;            // Countdown timer for the dialogue closing animation or delay before fully closing.
        INT open_timer;             // Countdown timer for the dialogue opening delay to prevent immediate interactions.
        INT skip;                   // Boolean flag to skip the letter-by-letter text animation and display the full text instantly.
        INT press_timer;            // Countdown timer to debounce key presses, preventing rapid repeated actions.
        INT complete;               // Boolean flag indicating whether the text animation has finished displaying the full dialogue.
        INT box_id;                 // The draw ID of the dialogue box rectangle; used for deleting the box when closing.
        INT has_options;            // Flag if dialogue has yes/no options
        INT selected_option;        // 0 = yes, 1 = no
        INT item_to_give;           // Item ID to give if yes
        INT is_quest;               // Flag if this is a quest dialogue
        INT quest_npc_id;           // NPC ID for quest tracking
        INT current_dialogue_index; // Current dialogue being shown (for multi-dialogue NPCs)
        INT total_dialogues;        // Total number of dialogues for this NPC
        INT current_npc_index;      // Index of current NPC in MapData array
        INT current_map_index;      // Index of current map
    END
    STRUCT TileTypes
        INT field = 1;
        INT mountain = 2;
        INT river = 3;
        INT bridge = 4;
        INT city = 5;
        INT forest = 6;
    END
    STRUCT ZLevels
        INT map = 100;           // Map at the back
        INT npc = 0;             // NPCs over map
        INT player = -10;        // Player over map
        INT inventory_bg = -150; // Inventory background
        INT dialog = -200;       // Dialogue over everything
    END
    STRUCT ScreenConfig
        INT width = 320;
        INT height = 200;
        INT fps = 30;
    END
    INT fpg_ids[3]; // FPG IDs for each map
    INT npc_fpg_ids[6]; // FPG IDs for each NPC
    INT hud_fpg_id; // FPG ID for HUD elements
    INT player_fpg_id; // FPG ID for player graphics
BEGIN
    set_mode(ScreenConfig.width * 1000 + ScreenConfig.height);
    set_fps(ScreenConfig.fps, 0);

    // Load palette
    load_pal("DIV2.PAL");

    // Load HUD graphics
    hud_fpg_id = load_fpg("DIABLO/HUD.FPG");

    // Load player graphics
    player_fpg_id = load_fpg("DIABLO/PLAYER.FPG");

    // Load and play background music
    song_id = load_song(SONG_FILE, 1); // 1 for indefinite loop
    song(song_id);

    // Initialize controls
    InitControls();

    // Initialize quest states
    InitQuestStates();

    // Load item database from file
    LoadItemsData();

    // Load map data from file (maps, NPCs, teleports)
    LoadMapsData();

    // Load FPG files dynamically from map data
    LoadMapFPGs();

    // Create processes
    map_drawer();
    player();
    hud_display();
    LOOP
        FRAME;
    END
END

// Initialize all quest states to NOT_STARTED
PROCESS InitQuestStates()
PRIVATE
    i;
BEGIN
    FROM i = 0 TO 9;
        quest_states[i] = QUEST_NOT_STARTED;
    END
END

// Loads item database from ItemsV3.dat file.
// Reads all available items with their descriptions and prices.
PROCESS LoadItemsData()
PRIVATE
    file_handle;
    data_size;
BEGIN
    // Open the items data file for reading
    file_handle = fopen("ItemsV3.dat", "r");

    IF (file_handle == 0)
        // File doesn't exist - show error
        write(0, 10, 10, 0, "ERROR: ItemsV3.dat not found! Please run MAPGEN04.PRG first.");
        EXIT("ItemsV3.dat missing", 1);
    END

    // Read item_list_count first
    fread(OFFSET item_list_count, 1, file_handle);

    // Read entire ItemList structure
    data_size = sizeof(ItemList);
    fread(OFFSET ItemList, data_size, file_handle);

    // Close the file
    fclose(file_handle);
END

// Loads all map data from MapsV3.dat file.
// Reads map tiles, NPCs, teleports, and quest data for all maps from external file.
PROCESS LoadMapsData()
PRIVATE
    file_handle;
    data_size;
BEGIN
    // Open the maps data file for reading
    file_handle = fopen("MapsV3.dat", "r");

    IF (file_handle == 0)
        // File doesn't exist - show error
        write(0, 10, 10, 0, "ERROR: MapsV3.dat not found! Please run MAPGEN04.PRG first.");
        EXIT("MapsV3.dat missing", 1);
    END

    // Get size of MapData structure
    data_size = sizeof(MapData);

    // Read entire MapData structure from file
    IF (fread(OFFSET MapData, data_size, file_handle) == 0)
        // Error reading file
        write(0, 10, 10, 0, "Error loading MapsV3.dat!");
    END

    // Close the file
    fclose(file_handle);
END

// Loads FPG files dynamically from map data.
PROCESS LoadMapFPGs()
PRIVATE
    i, j, k;
    STRING loaded_npcs[6];
    INT loaded_count = 0;
    INT already_loaded;
BEGIN
    // Load map FPGs
    i = 0;
    WHILE (i < 3)
        fpg_ids[i] = load_fpg(MapData[i].fpg_file);
        i++;
    END

    // Load NPC FPGs (avoiding duplicates)
    i = 0;
    WHILE (i < 3) // For each map
        j = 0;
        WHILE (j < MapData[i].npc_count) // For each NPC in map
            // Check if this FPG is already loaded
            already_loaded = 0;
            FOR (k = 0; k < loaded_count; k++)
                IF (strcmp(loaded_npcs[k], MapData[i].NPCData[j].fpg_file) == 0)
                    already_loaded = 1;
                    BREAK;
                END
            END

            // If not loaded yet, load it
            IF (already_loaded == 0)
                npc_fpg_ids[MapData[i].NPCData[j].npc_id] = load_fpg(MapData[i].NPCData[j].fpg_file);
                loaded_npcs[loaded_count] = MapData[i].NPCData[j].fpg_file;
                loaded_count++;
            END
            j++;
        END
        i++;
    END
END

// Initializes the Controls struct with keyboard bindings.
PROCESS InitControls()
BEGIN
    Controls.left = _LEFT;
    Controls.right = _RIGHT;
    Controls.up = _UP;
    Controls.down = _DOWN;
    Controls.talk = _ENTER;
    Controls.inventory = _ESC;
    Controls.exit = _F10;
END

// Displays HUD information (gold count).
PROCESS hud_display()
PRIVATE
    gold_text_id = 0;
    STRING gold_str;
BEGIN
    LOOP
        IF (inventory_active == 0)
            // Display gold
            IF (gold_text_id != 0)
                delete_text(gold_text_id);
            END
            gold_str = "Gold: " + itoa(player_gold);
            gold_text_id = write(0, 10, 10, 0, gold_str);
        ELSE
            // Hide gold during inventory
            IF (gold_text_id != 0)
                delete_text(gold_text_id);
                gold_text_id = 0;
            END
        END
        FRAME;
    END
END

// Central rendering process.
PROCESS map_drawer()
PRIVATE
    i, j, color, x1, y1, x2, y2;
    dist_x, dist_y;
    i_min, i_max, j_min, j_max;
    map_width, map_height;
    dirty;
    last_inventory_state;
    tile_code;
BEGIN
    force_redraw = 1;
    last_inventory_state = inventory_active;
    LOOP
        IF (inventory_active == 0)
            // Detect inventory state change to force redraw when closing
            IF (inventory_active != last_inventory_state)
                IF (inventory_active == 0)
                    force_redraw = 1;
                END
                last_inventory_state = inventory_active;
            END

            // Dirty rectangle: only redraw if map or camera changes
            dirty = 0;
            IF (offset_x != prev_offset_x OR offset_y != prev_offset_y OR current_map != prev_map OR force_redraw == 1)
                dirty = 1;
            END

            // Always clear screen to prevent sprite accumulation from put()
            clear_screen();

            // Current map dimensions
            map_width = MapData[current_map].tilesX;
            map_height = MapData[current_map].tilesY;

            // Visible tile range
            IF (((-offset_x + 31) / 32) - 1 > 0) i_min = ((-offset_x + 31) / 32) - 1; ELSE i_min = 0; END
            IF (map_width - 1 < ((ScreenConfig.width - offset_x) / 32) + 1) i_max = map_width - 1; ELSE i_max = ((ScreenConfig.width - offset_x) / 32) + 1; END
            IF (((-offset_y + 31) / 32) - 1 > 0) j_min = ((-offset_y + 31) / 32) - 1; ELSE j_min = 0; END
            IF (map_height - 1 < ((ScreenConfig.height - offset_y) / 32) + 1) j_max = map_height - 1; ELSE j_max = ((ScreenConfig.height - offset_y) / 32) + 1; END

            // Apply zoom effect during dialogues
            draw_z = ZLevels.map;

            i = i_min;
            WHILE (i <= i_max)
                j = j_min;
                WHILE (j <= j_max)
                    x1 = i * 32 + offset_x;
                    y1 = j * 32 + offset_y;

                    // Apply zoom transformation centered on player (screen center)
                    x1 = ScreenConfig.width / 2 + ((x1 - ScreenConfig.width / 2) * dialogue_zoom) / 100;
                    y1 = ScreenConfig.height / 2 + ((y1 - ScreenConfig.height / 2) * dialogue_zoom) / 100;

                    // Get tile code
                    tile_code = MapData[current_map].tiles[i,j];
                    // Draw sprite with zoom - xput handles the scaling
                    xput(fpg_ids[current_map], tile_code, x1 + 16, y1 + 16, 0, dialogue_zoom, 0, 0);
                    j++;
                END
                i++;
            END

            // Update previous values
            prev_offset_x = offset_x;
            prev_offset_y = offset_y;
            prev_map = current_map;
            force_redraw = 0;

            // Draw NPCs
            draw_z = ZLevels.npc;
            i = 0;
            WHILE (i < MapData[current_map].npc_count)
                // Calculate screen position
                x1 = MapData[current_map].NPCData[i].x + offset_x;
                y1 = MapData[current_map].NPCData[i].y + offset_y;

                // Apply zoom transformation centered on player (screen center)
                x1 = ScreenConfig.width / 2 + ((x1 - ScreenConfig.width / 2) * dialogue_zoom) / 100;
                y1 = ScreenConfig.height / 2 + ((y1 - ScreenConfig.height / 2) * dialogue_zoom) / 100;

                // Check if visible on screen
                IF (x1 + 16 > 0 AND x1 - 16 < ScreenConfig.width AND y1 + 16 > 0 AND y1 - 16 < ScreenConfig.height)
                    // Update NPC direction to face player
                    dist_x = abs(PlayerData.x - MapData[current_map].NPCData[i].x);
                    dist_y = abs(PlayerData.y - MapData[current_map].NPCData[i].y);

                    IF (dist_x > dist_y)
                        IF (PlayerData.x > MapData[current_map].NPCData[i].x)
                            MapData[current_map].NPCData[i].graph = 2; // Look right
                        ELSE
                            MapData[current_map].NPCData[i].graph = 4; // Look left
                        END
                    ELSE
                        IF (PlayerData.y < MapData[current_map].NPCData[i].y)
                            MapData[current_map].NPCData[i].graph = 1; // Look up
                        ELSE
                            MapData[current_map].NPCData[i].graph = 3; // Look down
                        END
                    END
                    // Draw NPC shadow
                    xput(hud_fpg_id, 3, x1, y1, 0, dialogue_zoom, 4, 0);
                    // Draw NPC sprite
                    xput(npc_fpg_ids[MapData[current_map].NPCData[i].npc_id], MapData[current_map].NPCData[i].graph, x1, y1 - 24, 0, dialogue_zoom, 0, 0);
                END
                i++;
            END

            // Draw player shadow
            xput(hud_fpg_id, 3, ScreenConfig.width / 2, ScreenConfig.height / 2, 0, dialogue_zoom, 4, 0);
            // Draw player sprite
            draw_z = ZLevels.player;
            xput(player_fpg_id, PlayerData.graph, ScreenConfig.width / 2, ScreenConfig.height / 2 - 24, 0, dialogue_zoom, 0, 0);
        END

        FRAME;
    END
END

// Handles all player logic and interactions.
PROCESS player()
PRIVATE
    screen_x, screen_y;
    tile_i, tile_j, speed;
    new_x, new_y;
    closest_npc = -1;
    temp_dist;
    min_dist;
    i;
    npc_map;
    exit_direction;
    INT enter_pressed = 0;
    INT inventory_close_timer = 0;
    INT k;
    INT moving = 0;
    INT new_direction = 0;
    INT npc_id;
    STRING dialogue_text;
BEGIN
    x = PlayerData.x;
    y = PlayerData.y;
    LOOP
        moving = 0;
        new_direction = PlayerData.direction;

        // Calculate current tile and speed
        tile_i = PlayerData.x / 32;
        tile_j = PlayerData.y / 32;
        IF (current_map == 0)
            speed = 5;
            IF (MapData[current_map].tiles[tile_i, tile_j] == TileTypes.forest OR MapData[current_map].tiles[tile_i, tile_j] == TileTypes.mountain)
                speed = 2;
            END
        ELSE
            speed = 5;
        END

        // Movement
        IF (DialogState.process_id == 0 AND inventory_active == 0)
            IF (KEY(Controls.left))
                new_x = PlayerData.x - speed;
                tile_i = new_x / 32;
                tile_j = PlayerData.y / 32;
                IF (current_map == 0)
                    IF (MapData[current_map].tiles[tile_i, tile_j] != TileTypes.river)
                        PlayerData.x = new_x;
                        moving = 1;
                        new_direction = 4;
                    END
                ELSE
                    PlayerData.x = new_x;
                    moving = 1;
                    new_direction = 4;
                END
            END
            IF (KEY(Controls.right))
                new_x = PlayerData.x + speed;
                tile_i = new_x / 32;
                tile_j = PlayerData.y / 32;
                IF (current_map == 0)
                    IF (MapData[current_map].tiles[tile_i, tile_j] != TileTypes.river)
                        PlayerData.x = new_x;
                        moving = 1;
                        new_direction = 2;
                    END
                ELSE
                    PlayerData.x = new_x;
                    moving = 1;
                    new_direction = 2;
                END
            END
            IF (KEY(Controls.up))
                new_y = PlayerData.y - speed;
                tile_i = PlayerData.x / 32;
                tile_j = new_y / 32;
                IF (current_map == 0)
                    IF (MapData[current_map].tiles[tile_i, tile_j] != TileTypes.river)
                        PlayerData.y = new_y;
                        moving = 1;
                        new_direction = 1;
                    END
                ELSE
                    PlayerData.y = new_y;
                    moving = 1;
                    new_direction = 1;
                END
            END
            IF (KEY(Controls.down))
                new_y = PlayerData.y + speed;
                tile_i = PlayerData.x / 32;
                tile_j = new_y / 32;
                IF (current_map == 0)
                    IF (MapData[current_map].tiles[tile_i, tile_j] != TileTypes.river)
                        PlayerData.y = new_y;
                        moving = 1;
                        new_direction = 3;
                    END
                ELSE
                    PlayerData.y = new_y;
                    moving = 1;
                    new_direction = 3;
                END
            END
        END

        // Update player animation
        PlayerData.direction = new_direction;

        IF (moving)
            PlayerData.anim_counter++;
            IF (PlayerData.anim_counter >= 5)
                PlayerData.anim_counter = 0;
                PlayerData.anim_frame = (PlayerData.anim_frame + 1) % 6;
            END

            IF (PlayerData.direction == 1)
                PlayerData.graph = 5 + PlayerData.anim_frame;
            ELSE
                IF (PlayerData.direction == 2)
                    PlayerData.graph = 11 + PlayerData.anim_frame;
                ELSE
                    IF (PlayerData.direction == 3)
                        PlayerData.graph = 17 + PlayerData.anim_frame;
                    ELSE
                        PlayerData.graph = 23 + PlayerData.anim_frame;
                    END
                END
            END
        ELSE
            PlayerData.anim_frame = 0;
            PlayerData.anim_counter = 0;

            IF (PlayerData.direction == 1)
                PlayerData.graph = 1;
            ELSE
                IF (PlayerData.direction == 2)
                    PlayerData.graph = 2;
                ELSE
                    IF (PlayerData.direction == 3)
                        PlayerData.graph = 3;
                    ELSE
                        PlayerData.graph = 4;
                    END
                END
            END
        END

        // Check for exiting city boundaries
        IF (current_map != 0 AND (PlayerData.x < 0 OR PlayerData.x >= 256 OR PlayerData.y < 0 OR PlayerData.y >= 256))
            prev_map = -1;
            prev_offset_x = -9999;
            prev_offset_y = -9999;
            fade_off();
            exit_direction = 0;
            IF (PlayerData.y < 0)
                exit_direction = 0;
            ELSE
                IF (PlayerData.y >= 256)
                    exit_direction = 1;
                ELSE
                    IF (PlayerData.x < 0)
                        exit_direction = 2;
                    ELSE
                        exit_direction = 3;
                    END
                END
            END
            IF (current_map == 1)
                current_map = 0;
                IF (exit_direction == 0)
                    PlayerData.x = 7 * 32;
                    PlayerData.y = 4 * 32;
                ELSE
                    IF (exit_direction == 1)
                        PlayerData.x = 7 * 32;
                        PlayerData.y = 9 * 32;
                    ELSE
                        IF (exit_direction == 2)
                            PlayerData.x = 5 * 32;
                            PlayerData.y = 6 * 32;
                        ELSE
                            PlayerData.x = 10 * 32;
                            PlayerData.y = 6 * 32;
                        END
                    END
                END
            ELSE
                IF (current_map == 2)
                    current_map = 0;
                    IF (exit_direction == 0)
                        PlayerData.x = 21 * 32;
                        PlayerData.y = 14 * 32;
                    ELSE
                        IF (exit_direction == 1)
                            PlayerData.x = 21 * 32;
                            PlayerData.y = 19 * 32;
                        ELSE
                            IF (exit_direction == 2)
                                PlayerData.x = 19 * 32;
                                PlayerData.y = 16 * 32;
                            ELSE
                                PlayerData.x = 24 * 32;
                                PlayerData.y = 16 * 32;
                            END
                        END
                    END
                END
            END
            fade_on();
            force_redraw = 1;
        END

        // Center camera on player
        offset_x = ScreenConfig.width / 2 - PlayerData.x;
        offset_y = ScreenConfig.height / 2 - PlayerData.y;
        screen_x = ScreenConfig.width / 2;
        screen_y = ScreenConfig.height / 2;

        IF (KEY(Controls.inventory))
            IF (DialogState.press_timer == 0 AND inventory_close_timer == 0 AND inventory_active == 0)
                DialogState.press_timer = ScreenConfig.fps / 2;
                inventory_screen();
                inventory_close_timer = ScreenConfig.fps;
            END
        END

        IF (KEY(Controls.exit))
            unload_song(song_id);
            EXIT("Goodbye", 0);
        END

        x = PlayerData.x;
        y = PlayerData.y;

        // Calculate distances for interaction
        closest_npc = -1;
        min_dist = 51;
        i = 0;
        WHILE (i < MapData[current_map].npc_count)
            temp_dist = sqrt((PlayerData.x - MapData[current_map].NPCData[i].x) * (PlayerData.x - MapData[current_map].NPCData[i].x) + (PlayerData.y - MapData[current_map].NPCData[i].y) * (PlayerData.y - MapData[current_map].NPCData[i].y));
            IF (temp_dist < 50 AND temp_dist < min_dist)
                closest_npc = i;
                min_dist = temp_dist;
            END
            i++;
        END

        // Check interaction with NPCs
        IF (KEY(Controls.talk))
            IF (enter_pressed == 0 AND closest_npc != -1 AND inventory_active == 0 AND inventory_close_timer == 0)
                IF (DialogState.press_timer == 0)
                    DialogState.press_timer = ScreenConfig.fps / 3;
                    IF (DialogState.process_id == 0)
                        npc_id = MapData[current_map].NPCData[closest_npc].npc_id;

                        // Check if NPC has a quest
                        IF (MapData[current_map].NPCData[closest_npc].has_quest == 1)
                            // Quest NPC - determine dialogue based on quest state
                            IF (quest_states[npc_id] == QUEST_NOT_STARTED)
                                // Offer quest
                                i = 0;
                                WHILE (i < MapData[current_map].NPCData[closest_npc].quest_dialogue_count)
                                    temp_dialogues[i].dialogue = MapData[current_map].NPCData[closest_npc].quest_dialogues[i].dialogue;
                                    i++;
                                END
                                temp_dialogue_count = MapData[current_map].NPCData[closest_npc].quest_dialogue_count;
                                DialogState.process_id = dialogue(MapData[current_map].NPCData[closest_npc].name, 1, 0);
                                DialogState.is_quest = 1;
                                DialogState.quest_npc_id = npc_id;
                                DialogState.current_npc_index = closest_npc;
                                DialogState.current_map_index = current_map;
                            ELSE
                                IF (quest_states[npc_id] == QUEST_ACTIVE)
                                    // Check if quest can be completed
                                    IF (HasItems(MapData[current_map].NPCData[closest_npc].quest_item_id, MapData[current_map].NPCData[closest_npc].quest_item_count))
                                        // Can complete quest
                                        i = 0;
                                        WHILE (i < MapData[current_map].NPCData[closest_npc].quest_complete_count)
                                            temp_dialogues[i].dialogue = MapData[current_map].NPCData[closest_npc].quest_complete_texts[i].text;
                                            i++;
                                        END
                                        temp_dialogue_count = MapData[current_map].NPCData[closest_npc].quest_complete_count;
                                        DialogState.process_id = dialogue(MapData[current_map].NPCData[closest_npc].name, 0, 0);
                                        // Complete quest
                                        RemoveItems(MapData[current_map].NPCData[closest_npc].quest_item_id, MapData[current_map].NPCData[closest_npc].quest_item_count);
                                        player_gold = player_gold + MapData[current_map].NPCData[closest_npc].quest_gold_reward;
                                        quest_states[npc_id] = QUEST_COMPLETED;
                                    ELSE
                                        // Quest in progress
                                        i = 0;
                                        WHILE (i < MapData[current_map].NPCData[closest_npc].quest_progress_count)
                                            temp_dialogues[i].dialogue = MapData[current_map].NPCData[closest_npc].quest_progress_texts[i].text;
                                            i++;
                                        END
                                        temp_dialogue_count = MapData[current_map].NPCData[closest_npc].quest_progress_count;
                                        DialogState.process_id = dialogue(MapData[current_map].NPCData[closest_npc].name, 0, 0);
                                    END
                                ELSE
                                    // Quest completed
                                    i = 0;
                                    WHILE (i < MapData[current_map].NPCData[closest_npc].quest_reward_count)
                                        temp_dialogues[i].dialogue = MapData[current_map].NPCData[closest_npc].quest_reward_texts[i].text;
                                        i++;
                                    END
                                    temp_dialogue_count = MapData[current_map].NPCData[closest_npc].quest_reward_count;
                                    DialogState.process_id = dialogue(MapData[current_map].NPCData[closest_npc].name, 0, 0);
                                END
                            END
                        ELSE
                            // Regular NPC dialogue - copy to temp storage
                            i = 0;
                            WHILE (i < MapData[current_map].NPCData[closest_npc].dialogue_count)
                                temp_dialogues[i].dialogue = MapData[current_map].NPCData[closest_npc].dialogues[i].dialogue;
                                i++;
                            END
                            temp_dialogue_count = MapData[current_map].NPCData[closest_npc].dialogue_count;
                            DialogState.process_id = dialogue(MapData[current_map].NPCData[closest_npc].name, MapData[current_map].NPCData[closest_npc].gives_item, MapData[current_map].NPCData[closest_npc].item_id);
                        END
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
                enter_pressed = 1;
            END
        ELSE
            enter_pressed = 0;
        END

        // Decrement timers
        IF (DialogState.press_timer > 0)
            DialogState.press_timer--;
        END
        IF (inventory_close_timer > 0)
            inventory_close_timer--;
        END

        // Check for map transitions
        IF (current_map == 0)
            tile_i = PlayerData.x / 32;
            tile_j = PlayerData.y / 32;
            k = 0;
            WHILE (k < MapData[0].teleport_count)
                IF (tile_i == MapData[0].TeleportData[k].tile_i AND tile_j == MapData[0].TeleportData[k].tile_j)
                    prev_map = -1;
                    prev_offset_x = -9999;
                    prev_offset_y = -9999;
                    fade_off();
                    current_map = MapData[0].TeleportData[k].target_map;
                    PlayerData.x = MapData[0].TeleportData[k].target_x;
                    PlayerData.y = MapData[0].TeleportData[k].target_y;
                    fade_on();
                    BREAK;
                END
                k++;
            END
        END

        FRAME;
    END
END

// Check if player has specified number of items.
PROCESS HasItems(INT item_id, INT count_needed)
PRIVATE
    i;
BEGIN
    i = 0;
    WHILE (i < item_count)
        IF (strcmp(inventory[i].item, ItemList[item_id].name) == 0)
            IF (inventory[i].quantity >= count_needed)
                RETURN(1); // Has enough items
            ELSE
                RETURN(0); // Not enough items
            END
        END
        i++;
    END
    RETURN(0); // Item not found
END

// Remove specified number of items from inventory.
PROCESS RemoveItems(INT item_id, INT count_to_remove)
PRIVATE
    i;
BEGIN
    i = 0;
    WHILE (i < item_count)
        IF (strcmp(inventory[i].item, ItemList[item_id].name) == 0)
            inventory[i].quantity = inventory[i].quantity - count_to_remove;
            IF (inventory[i].quantity <= 0)
                // Remove item from inventory by shifting array
                WHILE (i < item_count - 1)
                    inventory[i].item = inventory[i + 1].item;
                    inventory[i].quantity = inventory[i + 1].quantity;
                    inventory[i].description = inventory[i + 1].description;
                    i++;
                END
                item_count--;
            END
            RETURN;
        END
        i++;
    END
END

// Manages the interactive dialogue system with multiple dialogues support.
// Uses global temp_dialogues and temp_dialogue_count instead of parameters
PROCESS dialogue(STRING name, INT has_options, INT item_id)
PRIVATE
    STRING temp;
    STRING text[50];
    index = 0;
    letter_delay = 0;
    text_id = 0;
    name_id = 0;
    indicator_id = 0;
    options_text_ids[2];
    options_box_id = 0;
    selected_option = 0;
    showing_options = 0;
    STRUCT OptionStrings[2]
        STRING normal;
        STRING selected;
    END
    i;
    len;
    complete = 0;
    INT input_timer = 0;
    INT enter_pressed = 0;
    INT frame_counter = 0;
    INT j;
    INT found;
BEGIN
    // Initialize options
    OptionStrings[0].normal = "  Yes";
    OptionStrings[0].selected = "> Yes";
    OptionStrings[1].normal = "  No";
    OptionStrings[1].selected = "> No";
    DialogState.closing = 0;
    DialogState.close_timer = 0;
    DialogState.open_timer = 5;
    DialogState.skip = 0;
    DialogState.complete = 0;
    DialogState.has_options = has_options;
    DialogState.item_to_give = item_id;
    DialogState.current_dialogue_index = 0;
    DialogState.total_dialogues = temp_dialogue_count;

    // Get first dialogue text
    text = temp_dialogues[0].dialogue;
    len = strlen(text);

    name_id = write(0, 30, ScreenConfig.height - 45, 0, name);
    LOOP
        // Verificar si los menús están activos - cerrar diálogo si es así
        IF (inventory_active == 1)
            DialogState.closing = 1;
        END

        // Smooth zoom transition
        IF (dialogue_zoom < 200)
            dialogue_zoom = dialogue_zoom + 10;
            IF (dialogue_zoom > 200)
                dialogue_zoom = 200;
            END
        END

        // Draw dialogue box
        draw_z = ZLevels.dialog;
        put(hud_fpg_id, 1, ScreenConfig.width / 2, ScreenConfig.height - 25);

        IF (DialogState.open_timer > 0)
            DialogState.open_timer--;
        END

        IF (input_timer > 0)
            input_timer--;
        END

        // Animate text letter by letter
        IF (DialogState.skip AND index < len)
            index = len;
            DialogState.skip = 0;
            i = 0;
            WHILE (i < index)
                temp[i] = text[i];
                i++;
            END
            temp[index] = 0;
            complete = 1;
            DialogState.complete = 1;
            letter_delay = 0;
        END
        IF (index < len AND DialogState.skip == 0)
            IF (letter_delay == 0)
                index++;
                i = 0;
                WHILE (i < index)
                    temp[i] = text[i];
                    i++;
                END
                temp[index] = 0;
                letter_delay = ScreenConfig.fps / 15;
            ELSE
                letter_delay--;
            END
        ELSE
            IF (complete == 0)
                complete = 1;
                DialogState.complete = 1;
                i = 0;
                WHILE (i < len)
                    temp[i] = text[i];
                    i++;
                END
                temp[len] = 0;
            END
        END

        // Write current text
        IF (text_id != 0)
            delete_text(text_id);
        END
        text_id = write(0, 30, ScreenConfig.height - 30, 0, temp);

        // Show indicator
        IF (indicator_id != 0)
            delete_text(indicator_id);
            indicator_id = 0;
        END
        IF (complete == 1 AND DialogState.has_options == 0 AND DialogState.open_timer == 0)
            IF ((frame_counter / 15) % 2 == 0)
                indicator_id = write(0, ScreenConfig.width - 80, ScreenConfig.height - 20, 0, "[ENTER]");
            END
        END

        // Show options if complete
        IF (complete == 1 AND DialogState.has_options == 1)
            IF (showing_options == 0)
                showing_options = 1;
                input_timer = ScreenConfig.fps / 6;
                enter_pressed = 1;
            END
        END

        // Handle options menu
        IF (showing_options)
            i = 0;
            WHILE (i < 2)
                IF (options_text_ids[i] != 0)
                    delete_text(options_text_ids[i]);
                    options_text_ids[i] = 0;
                END
                i++;
            END

            IF (KEY(Controls.up) AND input_timer == 0)
                selected_option = (selected_option - 1 + 2) % 2;
                input_timer = 5;
            END
            IF (KEY(Controls.down) AND input_timer == 0)
                selected_option = (selected_option + 1) % 2;
                input_timer = 5;
            END
            IF (KEY(Controls.talk))
                IF (enter_pressed == 0)
                    // Handle quest acceptance
                    IF (DialogState.is_quest == 1)
                        IF (selected_option == 0)
                            // Accept quest - show acceptance text(s) if available
                            IF (MapData[DialogState.current_map_index].NPCData[DialogState.current_npc_index].quest_accept_count > 0)
                                // Close current dialogue and show accept texts
                                DialogState.current_dialogue_index = 0;
                                DialogState.total_dialogues = MapData[DialogState.current_map_index].NPCData[DialogState.current_npc_index].quest_accept_count;
                                j = 0;
                                WHILE (j < MapData[DialogState.current_map_index].NPCData[DialogState.current_npc_index].quest_accept_count)
                                    temp_dialogues[j].dialogue = MapData[DialogState.current_map_index].NPCData[DialogState.current_npc_index].quest_accept_texts[j].text;
                                    j++;
                                END
                                // Reset to show first accept text
                                text = temp_dialogues[0].dialogue;
                                len = strlen(text);
                                index = 0;
                                complete = 0;
                                DialogState.complete = 0;
                                DialogState.open_timer = 5;
                                temp[0] = 0;
                            END
                            quest_states[DialogState.quest_npc_id] = QUEST_ACTIVE;
                        END
                        // Reset quest flag
                        DialogState.is_quest = 0;
                    ELSE
                        // Regular item giving
                        IF (selected_option == 0)
                            found = -1;
                            FOR (j = 0; j < item_count; j++)
                                IF (strcmp(inventory[j].item, ItemList[DialogState.item_to_give].name) == 0)
                                    found = j;
                                    BREAK;
                                END
                            END
                            IF (found != -1)
                                inventory[found].quantity++;
                            ELSE
                                IF (item_count < 10)
                                    inventory[item_count].item = ItemList[DialogState.item_to_give].name;
                                    inventory[item_count].quantity = 1;
                                    inventory[item_count].description = ItemList[DialogState.item_to_give].description;
                                    item_count++;
                                END
                            END
                        END
                    END
                    DialogState.closing = 1;
                    showing_options = 0;
                    enter_pressed = 1;
                    input_timer = 10;
                END
            ELSE
                enter_pressed = 0;
            END

            // Draw options
            i = 0;
            WHILE (i < 2)
                IF (i == selected_option)
                    options_text_ids[i] = write(0, 240, ScreenConfig.height - 20 + i * 10, 0, OptionStrings[i].selected);
                ELSE
                    options_text_ids[i] = write(0, 240, ScreenConfig.height - 20 + i * 10, 0, OptionStrings[i].normal);
                END
                i++;
            END
        END

        // Check closing
        IF (DialogState.closing)
            IF (complete == 0)
                index = len;
                i = 0;
                WHILE (i < len)
                    temp[i] = text[i];
                    i++;
                END
                temp[len] = 0;
                complete = 1;
            ELSE
                // Check if there are more dialogues to show
                IF (DialogState.current_dialogue_index < DialogState.total_dialogues - 1)
                    // Move to next dialogue
                    DialogState.current_dialogue_index++;
                    text = temp_dialogues[DialogState.current_dialogue_index].dialogue;
                    len = strlen(text);
                    index = 0;
                    complete = 0;
                    DialogState.complete = 0;
                    DialogState.closing = 0;
                    DialogState.open_timer = 5;
                    temp[0] = 0; // Clear temp
                    IF (indicator_id != 0)
                        delete_text(indicator_id);
                        indicator_id = 0;
                    END
                ELSE
                    // Last dialogue - proceed to close
                    IF (DialogState.close_timer == 0)
                        DialogState.close_timer = ScreenConfig.fps / 3;
                    END
                    DialogState.close_timer--;

                    // Smooth zoom transition back to normal
                    IF (dialogue_zoom > 100)
                        dialogue_zoom = dialogue_zoom - 10;
                        IF (dialogue_zoom < 100)
                            dialogue_zoom = 100;
                        END
                    END

                    IF (DialogState.close_timer == 0)
                        DialogState.box_id = 0;
                        force_redraw = 1;

                        // Ensure zoom is fully reset
                        dialogue_zoom = 100;

                        IF (options_box_id != 0)
                            delete_draw(options_box_id);
                            options_box_id = 0;
                        END
                        delete_text(text_id);
                        delete_text(name_id);
                        IF (indicator_id != 0)
                            delete_text(indicator_id);
                        END
                        IF (showing_options)
                            i = 0;
                            WHILE (i < 2)
                                IF (options_text_ids[i] != 0)
                                    delete_text(options_text_ids[i]);
                                END
                                i++;
                            END
                        END
                        DialogState.closing = 0;
                        DialogState.process_id = 0;
                        RETURN;
                    END
                END
            END
        END
        frame_counter++;

        FRAME;
    END
END

// Displays the pause/main menu screen.
PROCESS inventory_screen()
PRIVATE
    bg_id = 0, title_id = 0;
    STRUCT MenuOption[4]
        STRING text;
        INT text_id;
    END
    INT selected = 0;
    INT i;
    INT input_timer = 0;
    INT open_timer = 0;
    INT exit_menu = 0;
    INT do_exit_game = 0;
    INT submenu_result = 0;
    INT in_submenu = 0;
BEGIN
    inventory_active = 1;
    clear_screen();

    open_timer = 20;

    draw_z = ZLevels.inventory_bg;
    put(hud_fpg_id, 2, ScreenConfig.width / 2, ScreenConfig.height / 2);

    title_id = write(0, ScreenConfig.width / 2, 10, 4, "Pause Menu");

    LOOP
        IF (input_timer > 0)
            input_timer--;
        END
        IF (open_timer > 0)
            open_timer--;
        END

        // Clear previous menu options
        i = 0;
        WHILE (i < 4)
            IF (MenuOption[i].text_id != 0)
                delete_text(MenuOption[i].text_id);
                MenuOption[i].text_id = 0;
            END
            i++;
        END

        IF (KEY(Controls.up) AND input_timer == 0 AND in_submenu == 0)
            selected = (selected - 1 + 4) % 4;
            input_timer = 5;
        END
        IF (KEY(Controls.down) AND input_timer == 0 AND in_submenu == 0)
            selected = (selected + 1) % 4;
            input_timer = 5;
        END
        IF (KEY(Controls.talk) AND input_timer == 0 AND in_submenu == 0)
            IF (selected == 0)
                // Quests
                in_submenu = 1;
                delete_text(title_id);
                i = 0;
                WHILE (i < 4)
                    IF (MenuOption[i].text_id != 0)
                        delete_text(MenuOption[i].text_id);
                    END
                    i++;
                END
                submenu_finished = 0;
                quests_screen();
                // Esperar a que el submenú termine completamente
                WHILE (submenu_finished == 0)
                    FRAME;
                END
                clear_screen();
                draw_z = ZLevels.inventory_bg;
                put(hud_fpg_id, 2, ScreenConfig.width / 2, ScreenConfig.height / 2);
                title_id = write(0, ScreenConfig.width / 2, 10, 4, "Pause Menu");
                input_timer = 5;
                open_timer = 5;
                in_submenu = 0;
            ELSE
                IF (selected == 1)
                    // Items
                    delete_text(title_id);
                    i = 0;
                    WHILE (i < 4)
                        IF (MenuOption[i].text_id != 0)
                            delete_text(MenuOption[i].text_id);
                        END
                        i++;
                    END
                    submenu_finished = 0;
                    items_screen();
                    // Esperar a que el submenú termine completamente
                    WHILE (submenu_finished == 0)
                        FRAME;
                    END
                    clear_screen();
                    draw_z = ZLevels.inventory_bg;
                    put(hud_fpg_id, 2, ScreenConfig.width / 2, ScreenConfig.height / 2);
                    title_id = write(0, ScreenConfig.width / 2, 10, 4, "Pause Menu");
                    input_timer = 20;
                    open_timer = 20;
                    in_submenu = 0;
                ELSE
                    IF (selected == 2)
                        // Back
                        exit_menu = 1;
                    ELSE
                        // Exit Game
                        exit_menu = 1;
                        do_exit_game = 1;
                    END
                END
            END
        END
        IF (KEY(Controls.inventory) AND open_timer == 0)
            exit_menu = 1;
        END

        IF (exit_menu)
            force_redraw = 1;
            BREAK;
        END

        // Draw menu options only if not in submenu
        IF (in_submenu == 0)
            IF (selected == 0)
                MenuOption[0].text = "> Quests";
            ELSE
                MenuOption[0].text = "  Quests";
            END
            IF (selected == 1)
                MenuOption[1].text = "> Items";
            ELSE
                MenuOption[1].text = "  Items";
            END
            IF (selected == 2)
                MenuOption[2].text = "> Back";
            ELSE
                MenuOption[2].text = "  Back";
            END
            IF (selected == 3)
                MenuOption[3].text = "> Exit Game";
            ELSE
                MenuOption[3].text = "  Exit Game";
            END

            MenuOption[0].text_id = write(0, ScreenConfig.width / 2, 50, 4, MenuOption[0].text);
            MenuOption[1].text_id = write(0, ScreenConfig.width / 2, 70, 4, MenuOption[1].text);
            MenuOption[2].text_id = write(0, ScreenConfig.width / 2, 90, 4, MenuOption[2].text);
            MenuOption[3].text_id = write(0, ScreenConfig.width / 2, 110, 4, MenuOption[3].text);
        END

        FRAME;
    END

    delete_text(title_id);
    i = 0;
    WHILE (i < 4)
        IF (MenuOption[i].text_id != 0)
            delete_text(MenuOption[i].text_id);
        END
        i++;
    END
    inventory_active = 0;

    IF (do_exit_game)
        unload_song(song_id);
        EXIT("Goodbye", 0);
    END
END

// Displays the quests screen.
PROCESS quests_screen()
PRIVATE
    title_id = 0;
    STRUCT MenuOption[12]
        STRING text;
        INT text_id;
        INT desc_id;
    END
    INT menu_count = 0;
    INT selected = 0;
    INT i, j;
    INT input_timer = 0;
    INT open_timer = 0;
    INT exit_screen = 0;
    STRING quest_status;
    INT active_quests = 0;
BEGIN
    clear_screen();

    open_timer = 10;

    draw_z = ZLevels.inventory_bg;
    put(hud_fpg_id, 2, ScreenConfig.width / 2, ScreenConfig.height / 2);

    title_id = write(0, ScreenConfig.width / 2, 10, 4, "Quests");

    // Count active/completed quests
    FOR (i = 0; i < 3; i++)
        FOR (j = 0; j < MapData[i].npc_count; j++)
            IF (MapData[i].NPCData[j].has_quest == 1)
                IF (quest_states[MapData[i].NPCData[j].npc_id] != QUEST_NOT_STARTED)
                    active_quests++;
                END
            END
        END
    END

    menu_count = active_quests + 1; // +1 for Back option

    // Wait for key release
    WHILE (KEY(Controls.up) OR KEY(Controls.down) OR KEY(Controls.talk) OR KEY(Controls.inventory))
        FRAME;
    END

    LOOP
        IF (input_timer > 0)
            input_timer--;
        END
        IF (open_timer > 0)
            open_timer--;
        END

        // Clear previous menu options
        i = 0;
        WHILE (i < 12)
            IF (MenuOption[i].text_id != 0)
                delete_text(MenuOption[i].text_id);
                MenuOption[i].text_id = 0;
            END
            IF (MenuOption[i].desc_id != 0)
                delete_text(MenuOption[i].desc_id);
                MenuOption[i].desc_id = 0;
            END
            i++;
        END

        IF (KEY(Controls.up) AND input_timer == 0)
            selected = (selected - 1 + menu_count) % menu_count;
            input_timer = 5;
        END
        IF (KEY(Controls.down) AND input_timer == 0)
            selected = (selected + 1) % menu_count;
            input_timer = 5;
        END
        IF (KEY(Controls.talk) AND input_timer == 0)
            IF (selected == active_quests)
                exit_screen = 1;
            END
        END
        IF (KEY(Controls.inventory) AND open_timer == 0)
            exit_screen = 1;
        END

        IF (exit_screen)
            BREAK;
        END

        // Draw quest list
        menu_count = 0;
        FOR (i = 0; i < 3; i++)
            FOR (j = 0; j < MapData[i].npc_count; j++)
                IF (MapData[i].NPCData[j].has_quest == 1)
                    IF (quest_states[MapData[i].NPCData[j].npc_id] == QUEST_ACTIVE)
                        quest_status = " [Active]";
                        IF (menu_count == selected)
                            MenuOption[menu_count].text = "> " + MapData[i].NPCData[j].name + ": " + MapData[i].NPCData[j].quest_dialogues[0].dialogue;
                        ELSE
                            MenuOption[menu_count].text = "  " + MapData[i].NPCData[j].name + ": " + MapData[i].NPCData[j].quest_dialogues[0].dialogue;
                        END
                        MenuOption[menu_count].text_id = write(0, 30, 30 + menu_count * 20, 0, MenuOption[menu_count].text);
                        MenuOption[menu_count].desc_id = write(0, 30, 40 + menu_count * 20, 0, quest_status);
                        menu_count++;
                    ELSE
                        IF (quest_states[MapData[i].NPCData[j].npc_id] == QUEST_COMPLETED)
                            quest_status = " [Completed]";
                            IF (menu_count == selected)
                                MenuOption[menu_count].text = "> " + MapData[i].NPCData[j].name + ": " + MapData[i].NPCData[j].quest_dialogues[0].dialogue;
                            ELSE
                                MenuOption[menu_count].text = "  " + MapData[i].NPCData[j].name + ": " + MapData[i].NPCData[j].quest_dialogues[0].dialogue;
                            END
                            MenuOption[menu_count].text_id = write(0, 30, 30 + menu_count * 20, 0, MenuOption[menu_count].text);
                            MenuOption[menu_count].desc_id = write(0, 30, 40 + menu_count * 20, 0, quest_status);
                            menu_count++;
                        END
                    END
                END
            END
        END

        // Draw Back option
        IF (menu_count == selected)
            MenuOption[menu_count].text = "> Back";
        ELSE
            MenuOption[menu_count].text = "  Back";
        END
        MenuOption[menu_count].text_id = write(0, ScreenConfig.width / 2, 30 + menu_count * 20, 4, MenuOption[menu_count].text);
        
        menu_count++;

        FRAME;
    END
    
    delete_text(title_id);
    i = 0;
    WHILE (i < 12)
        IF (MenuOption[i].text_id != 0)
            delete_text(MenuOption[i].text_id);
        END
        IF (MenuOption[i].desc_id != 0)
            delete_text(MenuOption[i].desc_id);
        END
        i++;
    END
    submenu_finished = 1;
END

// Displays the items screen.
PROCESS items_screen()
PRIVATE
    title_id = 0;
    STRUCT MenuOption[12]
        STRING text;
        INT text_id;
        INT desc_id;
    END
    INT menu_count;
    INT selected = 0;
    INT i;
    STRING current_item;
    INT num_items_to_show;
    INT input_timer = 0;
    INT open_timer = 0;
    INT exit_screen = 0;
    STRING qty_str;
BEGIN
    clear_screen();
    
    open_timer = 10;
    num_items_to_show = item_count;
    IF (num_items_to_show > 8)
        num_items_to_show = 8;
    END
    menu_count = item_count + 1; // +1 for Back option

    draw_z = ZLevels.inventory_bg;
    put(hud_fpg_id, 2, ScreenConfig.width / 2, ScreenConfig.height / 2);

    title_id = write(0, ScreenConfig.width / 2, 10, 4, "Items");

    // Wait for key release
    WHILE (KEY(Controls.up) OR KEY(Controls.down) OR KEY(Controls.talk) OR KEY(Controls.inventory))
        FRAME;
    END

    LOOP
        IF (input_timer > 0)
            input_timer--;
        END
        IF (open_timer > 0)
            open_timer--;
        END
        
        // Clear previous menu options
        i = 0;
        WHILE (i < 12)
            IF (MenuOption[i].text_id != 0)
                delete_text(MenuOption[i].text_id);
                MenuOption[i].text_id = 0;
            END
            IF (MenuOption[i].desc_id != 0)
                delete_text(MenuOption[i].desc_id);
                MenuOption[i].desc_id = 0;
            END
            i++;
        END

        IF (KEY(Controls.up) AND input_timer == 0)
            selected = (selected - 1 + menu_count) % menu_count;
            input_timer = 5;
        END
        IF (KEY(Controls.down) AND input_timer == 0)
            selected = (selected + 1) % menu_count;
            input_timer = 5;
        END
        IF (KEY(Controls.talk) AND input_timer == 0)
            IF (selected == item_count)
                exit_screen = 1;
            END
        END
        IF (KEY(Controls.inventory) AND open_timer == 0)
            exit_screen = 1;
        END
        
        IF (exit_screen)
            BREAK;
        END

        // Draw item list
        i = 0;
        WHILE (i < item_count)
            qty_str = itoa(inventory[i].quantity);
            current_item = inventory[i].item + " x" + qty_str;
            IF (i == selected)
                MenuOption[i].text = "> " + current_item;
            ELSE
                MenuOption[i].text = "  " + current_item;
            END
            MenuOption[i].text_id = write(0, 30, 30 + i * 20, 0, MenuOption[i].text);
            MenuOption[i].desc_id = write(0, 200, 30 + i * 20, 0, inventory[i].description);
            i++;
        END

        // Draw Back option
        IF (item_count == selected)
            MenuOption[item_count].text = "> Back";
        ELSE
            MenuOption[item_count].text = "  Back";
        END
        MenuOption[item_count].text_id = write(0, ScreenConfig.width / 2, 30 + item_count * 20, 4, MenuOption[item_count].text);

        FRAME;
    END
    
    delete_text(title_id);
    i = 0;
    WHILE (i < 12)
        IF (MenuOption[i].text_id != 0)
            delete_text(MenuOption[i].text_id);
        END
        IF (MenuOption[i].desc_id != 0)
            delete_text(MenuOption[i].desc_id);
        END
        i++;
    END
    submenu_finished = 1;
END
