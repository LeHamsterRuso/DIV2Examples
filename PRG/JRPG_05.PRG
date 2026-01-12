//------------------------------------------------------------------------------
// TITLE:       JRPG with FPG sprites - Sprite-based edition with animations
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        11/01/2026
// DESCRIPTION: Enhanced JRPG with complete sprite conversion from primitives, featuring player animations, NPC directional sprites, and HUD elements.
//
// NOTE:        Run MAPGEN02.PRG first to generate MapsV2.dat and ItemsV2.dat files before running this program.
//
//              KEY IMPROVEMENTS OVER JRPG_04:
//              - Complete sprite conversion: All graphics now use FPG sprites instead of draw() primitives
//              - Player animation system: 6-frame walk cycles in 4 directions + idle states
//              - NPC directional sprites: NPCs face player based on distance (horizontal/vertical priority)
//              - HUD sprite elements: Dialogue boxes, inventory backgrounds, and transparent shadows
//              - Data-driven FPG loading: FPG filenames loaded from MapsV2.dat for flexible asset management
//              - PlayerData struct: Renamed from Player to avoid naming conflicts, includes animation state
//              - TileTypes struct: Replaced Colors for better terrain type management
//              - Rendering optimizations: clear_screen() every frame for put() sprites, xput() for transparency
//------------------------------------------------------------------------------

PROGRAM JRPG;
CONST
    SONG_FILE = "MOD/BULERIA.S3M";
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
    INT force_redraw = 0; // Force map redraw
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
            STRING dialogue[50];
            INT x;
            INT y;
            INT color;
            INT gives_item;
            INT item_id;
            INT npc_id;
            INT graph;
            STRING fpg_file[30];
        END
        INT npc_count;
    END
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

    // Load item database from file
    LoadItemsData();

    // Load map data from file (maps, NPCs, teleports)
    LoadMapsData();

    // Load FPG files dynamically from map data
    LoadMapFPGs();

    // Create processes
    map_drawer();
    player();
    LOOP
        FRAME;
    END
END

// Loads item database from ItemsV2.dat file.
// Reads all available items with their descriptions and prices.
PROCESS LoadItemsData()
PRIVATE
    file_handle;
    data_size;
BEGIN
    // Open the items data file for reading
    file_handle = fopen("ItemsV2.dat", "r");

    IF (file_handle == 0)
        // File doesn't exist - show error
        write(0, 10, 10, 0, "ERROR: ItemsV2.dat not found! Please run MAPGEN.PRG first.");
        EXIT("ItemsV2.dat missing", 1);
    END

    // Read item_list_count first
    fread(OFFSET item_list_count, 1, file_handle);

    // Read entire ItemList structure
    data_size = sizeof(ItemList);
    fread(OFFSET ItemList, data_size, file_handle);

    // Close the file
    fclose(file_handle);
END

// Loads all map data from MapsV2.dat file.
// Reads map tiles, NPCs, and teleport data for all maps from external file.
// This data-driven approach allows map editing without recompiling the game.
PROCESS LoadMapsData()
PRIVATE
    file_handle;
    data_size;
BEGIN
    // Open the maps data file for reading
    file_handle = fopen("MapsV2.dat", "r");

    IF (file_handle == 0)
        // File doesn't exist - show error
        write(0, 10, 10, 0, "ERROR: MapsV2.dat not found! Please run MAPGEN.PRG first.");
        EXIT("MapsV2.dat missing", 1);
    END

    // Get size of MapData structure
    data_size = sizeof(MapData);

    // Read entire MapData structure from file
    IF (fread(OFFSET MapData, data_size, file_handle) == 0)
        // Error reading file
        write(0, 10, 10, 0, "Error loading MapsV2.dat!");
    END

    // Close the file
    fclose(file_handle);
END

// Loads FPG files dynamically from map data.
// NEW IMPROVEMENT OVER JRPG_04: Enables data-driven FPG loading from MapsV2.dat,
// allowing flexible asset management without recompiling. Loads map tiles, NPC sprites,
// HUD elements, and player graphics based on configurable filenames in data structures.
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
// Maps arrow keys for movement, ENTER for NPC interaction,
// ESC for inventory screen, and F10 for game exit.
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

// Central rendering process - MAIN IMPROVEMENT OVER JRPG_04: Complete sprite conversion.
// Uses dirty rectangle optimization with sprite-based rendering: only redraws map tiles when camera/map changes,
// but clears screen every frame for put() sprites. Renders sprites for map tiles, NPCs with directional facing,
// player with animations, and transparent shadows using xput().
//
// Renders in order:
// 1. Map tiles (only if dirty) - uses put() with FPG sprites instead of draw() primitives
// 2. NPCs (every frame) - directional sprites facing player, with transparent shadows
// 3. Player (every frame) - animated sprite always centered on screen
//
// All drawing consolidated here eliminates separate NPC processes,
// improving performance and simplifying draw ID management.
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

                i = i_min;
                WHILE (i <= i_max)
                    j = j_min;
                    WHILE (j <= j_max)
                        x1 = i * 32 + offset_x;
                        y1 = j * 32 + offset_y;
                        x2 = x1 + 32;
                        y2 = y1 + 32;
                        // Get tile code
                        tile_code = MapData[current_map].tiles[i,j];
                        // Draw sprite on background
                        put(fpg_ids[current_map], tile_code, x1 + 16, y1 + 16);
                        j++;
                    END
                    i++;
                END

            // Update previous values (for future optimizations if needed)
            prev_offset_x = offset_x;
            prev_offset_y = offset_y;
            prev_map = current_map;
            force_redraw = 0;

            // Draw NPCs (always when inventory not active)
            draw_z = ZLevels.npc;
            i = 0;
            WHILE (i < MapData[current_map].npc_count)
                // Calculate screen position
                x1 = MapData[current_map].NPCData[i].x + offset_x;
                y1 = MapData[current_map].NPCData[i].y + offset_y;
                // Check if visible on screen
                IF (x1 + 16 > 0 AND x1 - 16 < ScreenConfig.width AND y1 + 16 > 0 AND y1 - 16 < ScreenConfig.height)
                    // Update NPC direction to face player based on greater distance
                    dist_x = abs(PlayerData.x - MapData[current_map].NPCData[i].x);
                    dist_y = abs(PlayerData.y - MapData[current_map].NPCData[i].y);

                    IF (dist_x > dist_y)
                        // Horizontal distance is greater - look left or right
                        IF (PlayerData.x > MapData[current_map].NPCData[i].x)
                            MapData[current_map].NPCData[i].graph = 2; // Look right
                        ELSE
                            MapData[current_map].NPCData[i].graph = 4; // Look left
                        END
                    ELSE
                        // Vertical distance is greater - look up or down
                        IF (PlayerData.y < MapData[current_map].NPCData[i].y)
                            MapData[current_map].NPCData[i].graph = 1; // Look up
                        ELSE
                            MapData[current_map].NPCData[i].graph = 3; // Look down
                        END
                    END
                    // Draw NPC shadow first (behind NPC) with transparency
                    xput(hud_fpg_id, 3, x1, y1, 0, 100, 4, 0);
                    // Draw NPC sprite 24 pixels higher (put() doesn't require cleanup)
                    put(npc_fpg_ids[MapData[current_map].NPCData[i].npc_id], MapData[current_map].NPCData[i].graph, x1, y1 - 24);
                END
                i++;
            END

            // Draw player shadow first (behind player) with transparency
            xput(hud_fpg_id, 3, ScreenConfig.width / 2, ScreenConfig.height / 2, 0, 100, 4, 0);
            // Draw player sprite 24 pixels higher (always when inventory not active)
            draw_z = ZLevels.player;
            put(player_fpg_id, PlayerData.graph, ScreenConfig.width / 2, ScreenConfig.height / 2 - 24);
        END
        // Note: inventory_screen process handles its own clear_screen()

        FRAME;
    END
END

// Handles all player logic and interactions.
// NEW IMPROVEMENTS OVER JRPG_04: Uses PlayerData struct (renamed from Player to avoid conflicts)
// with complete animation system - 6-frame walk cycles in 4 directions, idle states,
// frame changes every 5 ticks. Uses TileTypes for terrain collision instead of Colors.
//
// RESPONSIBILITIES:
// - Movement input processing with terrain-based speed modulation
// - Collision detection: prevents movement into water tiles
// - Camera offset calculation to keep player centered
// - NPC proximity detection and interaction triggering
// - Map transition detection when stepping on city tiles
// - Inventory and dialogue system integration
//
// Note: Player rendering moved to map_drawer for optimized draw order.
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
    INT moving = 0; // Flag to track if player is moving
    INT new_direction = 0; // New direction for this frame
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
            speed = 5; // Normal speed in cities
        END

        // Movement only if no dialogue and inventory not open
        IF (DialogState.process_id == 0 AND inventory_active == 0)
            IF (KEY(Controls.left))
                new_x = PlayerData.x - speed;
                tile_i = new_x / 32;
                tile_j = PlayerData.y / 32;
                IF (current_map == 0)
                    IF (MapData[current_map].tiles[tile_i, tile_j] != TileTypes.river)
                        PlayerData.x = new_x;
                        moving = 1;
                        new_direction = 4; // Left
                    END
                ELSE
                    // In cities, allow movement
                    PlayerData.x = new_x;
                    moving = 1;
                    new_direction = 4; // Left
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
                        new_direction = 2; // Right
                    END
                ELSE
                    PlayerData.x = new_x;
                    moving = 1;
                    new_direction = 2; // Right
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
                        new_direction = 1; // Up
                    END
                ELSE
                    PlayerData.y = new_y;
                    moving = 1;
                    new_direction = 1; // Up
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
                        new_direction = 3; // Down
                    END
                ELSE
                    PlayerData.y = new_y;
                    moving = 1;
                    new_direction = 3; // Down
                END
            END
        END
        
        // Update player animation
        PlayerData.direction = new_direction;
        
        IF (moving)
            // Animate walking
            PlayerData.anim_counter++;
            IF (PlayerData.anim_counter >= 5)
                PlayerData.anim_counter = 0;
                PlayerData.anim_frame = (PlayerData.anim_frame + 1) % 6;
            END
            
            // Calculate walk animation graph based on direction
            IF (PlayerData.direction == 1)
                PlayerData.graph = 5 + PlayerData.anim_frame; // Walk up (5-10)
            ELSE
                IF (PlayerData.direction == 2)
                    PlayerData.graph = 11 + PlayerData.anim_frame; // Walk right (11-16)
                ELSE
                    IF (PlayerData.direction == 3)
                        PlayerData.graph = 17 + PlayerData.anim_frame; // Walk down (17-22)
                    ELSE
                        PlayerData.graph = 23 + PlayerData.anim_frame; // Walk left (23-28)
                    END
                END
            END
        ELSE
            // Reset animation when idle
            PlayerData.anim_frame = 0;
            PlayerData.anim_counter = 0;
            
            // Set idle graph based on direction
            IF (PlayerData.direction == 1)
                PlayerData.graph = 1; // Idle up
            ELSE
                IF (PlayerData.direction == 2)
                    PlayerData.graph = 2; // Idle right
                ELSE
                    IF (PlayerData.direction == 3)
                        PlayerData.graph = 3; // Idle down
                    ELSE
                        PlayerData.graph = 4; // Idle left
                    END
                END
            END
        END

        // Check for exiting city boundaries
        IF (current_map != 0 AND (PlayerData.x < 0 OR PlayerData.x >= 256 OR PlayerData.y < 0 OR PlayerData.y >= 256))
            // Force clean state before fade
            prev_map = -1;
            prev_offset_x = -9999;
            prev_offset_y = -9999;
            // Fade out before exiting
            fade_off();
            // Determine exit direction
            exit_direction = 0; // 0=north, 1=south, 2=west, 3=east
            IF (PlayerData.y < 0)
                exit_direction = 0; // north
            ELSE
                IF (PlayerData.y >= 256)
                    exit_direction = 1; // south
                ELSE
                    IF (PlayerData.x < 0)
                        exit_direction = 2; // west
                    ELSE
                        exit_direction = 3; // east
                    END
                END
            END
            // Set position based on city and exit direction
            IF (current_map == 1)
                current_map = 0;
                IF (exit_direction == 0) // north
                    PlayerData.x = 7 * 32;
                    PlayerData.y = 4 * 32;
                ELSE
                    IF (exit_direction == 1) // south
                        PlayerData.x = 7 * 32;
                        PlayerData.y = 9 * 32;
                    ELSE
                        IF (exit_direction == 2) // west
                            PlayerData.x = 5 * 32;
                            PlayerData.y = 6 * 32;
                        ELSE // east
                            PlayerData.x = 10 * 32;
                            PlayerData.y = 6 * 32;
                        END
                    END
                END
            ELSE
                IF (current_map == 2)
                    current_map = 0;
                    IF (exit_direction == 0) // north
                        PlayerData.x = 21 * 32;
                        PlayerData.y = 14 * 32;
                    ELSE
                        IF (exit_direction == 1) // south
                            PlayerData.x = 21 * 32;
                            PlayerData.y = 19 * 32;
                        ELSE
                            IF (exit_direction == 2) // west
                                PlayerData.x = 19 * 32;
                                PlayerData.y = 16 * 32;
                            ELSE // east
                                PlayerData.x = 24 * 32;
                                PlayerData.y = 16 * 32;
                            END
                        END
                    END
                END
            END
            // Fade in after exiting
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
                inventory_close_timer = ScreenConfig.fps; // 1 second delay
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
        min_dist = 51; // greater than 50
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
            IF (enter_pressed == 0 AND closest_npc != -1 AND inventory_active == 0)
                IF (DialogState.press_timer == 0)
                    DialogState.press_timer = ScreenConfig.fps / 3;
                    IF (DialogState.process_id == 0)
                        // NPC direction is already updated in map_drawer()
                        DialogState.process_id = dialogue(MapData[current_map].NPCData[closest_npc].name, MapData[current_map].NPCData[closest_npc].dialogue, MapData[current_map].NPCData[closest_npc].gives_item, MapData[current_map].NPCData[closest_npc].item_id);
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

        // Decrement press timer
        IF (DialogState.press_timer > 0)
            DialogState.press_timer--;
        END
        // Decrement inventory close timer
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
                    // Force clean state before fade
                    prev_map = -1;
                    prev_offset_x = -9999;
                    prev_offset_y = -9999;
                    // Fade out before entering city
                    fade_off();
                    current_map = MapData[0].TeleportData[k].target_map;
                    PlayerData.x = MapData[0].TeleportData[k].target_x;
                    PlayerData.y = MapData[0].TeleportData[k].target_y;
                    // Fade in after entering
                    fade_on();
                    BREAK;
                END
                k++;
            END
        END

        FRAME;
    END
END

// Manages the interactive dialogue system with optional yes/no choices.
// NEW IMPROVEMENT OVER JRPG_04: Uses sprite-based dialogue box with put() instead of draw() rectangle,
// ensuring consistent appearance and proper layering with other sprite elements.
//
// FEATURES:
// - Letter-by-letter text animation with configurable speed
// - Skippable text animation (press ENTER to complete instantly)
// - Optional yes/no selection menu for item rewards
// - Visual feedback with selection cursor
// - Automatic closing for simple dialogues
// - Manual closing for choice dialogues after selection
// - Proper z-leveling to appear above all other elements
//
// Creates dialogue box, name display, and manages all UI cleanup.
PROCESS dialogue(STRING name, STRING text, INT has_options, INT item_id)
PRIVATE
    STRING temp; // temporary string to build the text
    index = 0;
    letter_delay = 0;
    text_id = 0;
    name_id = 0;
    indicator_id = 0; // For "press ENTER" indicator
    options_text_ids[2]; // For Yes/No options
    options_box_id = 0; // For options background box
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
    INT frame_counter = 0; // Frame counter for blinking effect
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
    DialogState.open_timer = 5; // Short delay to avoid immediate closing
    DialogState.skip = 0;
    DialogState.complete = 0;
    DialogState.has_options = has_options;
    DialogState.item_to_give = item_id;
    len = strlen(text);

    // Write speaker name (adjusted to fit in bottom 50 pixels)
    name_id = write(0, 30, ScreenConfig.height - 45, 0, name);
    LOOP

        // Draw main dialogue box using HUD sprite (must redraw each frame)
        draw_z = ZLevels.dialog;
        put(hud_fpg_id, 1, ScreenConfig.width / 2, ScreenConfig.height - 25);

        // Decrement open timer
        IF (DialogState.open_timer > 0)
            DialogState.open_timer--;
        END

        // Decrement input timer
        IF (input_timer > 0)
            input_timer--;
        END

        // Animate text letter by letter
        IF (DialogState.skip AND index < len)
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
            letter_delay = 0; // Reset delay
        END
        IF (index < len AND DialogState.skip == 0)
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
            IF (complete == 0)
                complete = 1;
                DialogState.complete = 1;
                // Ensure full text is in temp
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

        // Show "press ENTER" indicator if complete and no options
        IF (indicator_id != 0)
            delete_text(indicator_id);
            indicator_id = 0;
        END
        IF (complete == 1 AND DialogState.has_options == 0 AND DialogState.open_timer == 0)
            // Blinking effect: show every 15 frames
            IF ((frame_counter / 15) % 2 == 0)
                indicator_id = write(0, ScreenConfig.width - 80, ScreenConfig.height - 20, 0, "[ENTER]");
            END
        END

        // Show options if complete and has options
        IF (complete == 1 AND DialogState.has_options == 1)
            IF (showing_options == 0)
                // Open options menu and start a small input cooldown
                showing_options = 1;
                input_timer = ScreenConfig.fps / 6; // avoid auto-select on skip
                // Treat current ENTER state as already consumed so a new
                // key release + press is required before confirming
                enter_pressed = 1;
            END
        END
        // Note: For non-option dialogues, wait for user to press ENTER to close

        // Handle options menu if showing
        IF (showing_options)
            // Clear previous options texts
            i = 0;
            WHILE (i < 2)
                IF (options_text_ids[i] != 0)
                    delete_text(options_text_ids[i]);
                    options_text_ids[i] = 0;
                END
                i++;
            END

            // Handle input
            IF (KEY(Controls.up) AND input_timer == 0)
                selected_option = (selected_option - 1 + 2) % 2;
                input_timer = 5; // Pause for 5 frames
            END
            IF (KEY(Controls.down) AND input_timer == 0)
                selected_option = (selected_option + 1) % 2;
                input_timer = 5; // Pause for 5 frames
            END
            IF (KEY(Controls.talk))
                IF (enter_pressed == 0)
                    // Confirm selection
                    IF (selected_option == 0) // Yes
                        // Give item - check if already have it
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
                    // Close
                    DialogState.closing = 1;
                    showing_options = 0;
                    enter_pressed = 1;
                    input_timer = 10; // Prevent immediate re-open
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
                    // Dialogue box is drawn with put(), force redraw to clear it
                    DialogState.box_id = 0;
                    force_redraw = 1;
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
        frame_counter++; // Increment frame counter

        FRAME;
    END
END

// Displays the inventory screen with full item management.
// NEW IMPROVEMENT OVER JRPG_04: Uses sprite-based fullscreen background with put() instead of draw() rectangle,
// providing consistent visual style with other HUD elements.
//
// FEATURES:
// - Sprite-based fullscreen background at dedicated z-level
// - Scrollable item list (shows up to 8 items)
// - Arrow key navigation with visual cursor
// - Item selection (use functionality placeholder)
// - Back option to return to game
// - Exit game option
//
// Sets inventory_active flag to pause rendering in map_drawer,
// preventing map/NPC/player draws while inventory is active.
PROCESS inventory_screen()
PRIVATE
    bg_id = 0, title_id = 0;
    STRUCT MenuOption[12]
        STRING text;
        INT text_id;
        INT desc_id;
    END
    INT menu_count;
    INT selected = 0;
    INT i;
    INT prev_selected = -1;
    STRING current_item;
    INT num_items_to_show;
    INT input_timer = 0;
    INT open_timer = 0;
    INT exit_inventory = 0; // Flag to exit cleanly
    INT do_exit_game = 0; // Flag to exit game after cleanup
    STRING qty_str;
BEGIN
    // Mark inventory as active
    inventory_active = 1;
    
    // Clear screen once at start
    clear_screen();
    
    // Initialize all text IDs to 0
    i = 0;
    WHILE (i < 12)
        MenuOption[i].text_id = 0;
        MenuOption[i].desc_id = 0;
        i++;
    END
    
    // Prepare menu options
    open_timer = 20; // ~0.67 seconds delay before allowing close
    num_items_to_show = item_count;
    IF (num_items_to_show > 8)
        num_items_to_show = 8;
    END
    IF (num_items_to_show < item_count)
        menu_count = 10; // Show first 8 items + back + exit
    ELSE
        menu_count = item_count + 2;
    END

    // Draw inventory background using HUD sprite
    draw_z = ZLevels.inventory_bg;
    put(hud_fpg_id, 2, ScreenConfig.width / 2, ScreenConfig.height / 2);

    // Title
    title_id = write(0, ScreenConfig.width / 2, 10, 4, "Inventory");

    LOOP
        // Decrement input timer
        IF (input_timer > 0)
            input_timer--;
        END
        // Decrement open timer
        IF (open_timer > 0)
            open_timer--;
        END
        // Clear previous texts
        i = 0;
        WHILE (i < menu_count)
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

        // Handle input
        IF (KEY(Controls.up) AND input_timer == 0)
            selected = (selected - 1 + menu_count) % menu_count;
            input_timer = 5; // Pause for 5 frames
        END
        IF (KEY(Controls.down) AND input_timer == 0)
            selected = (selected + 1) % menu_count;
            input_timer = 5; // Pause for 5 frames
        END
        IF (KEY(Controls.talk))
            IF (selected < num_items_to_show)
                // Use item - for now, do nothing
            ELSE
                IF (selected == num_items_to_show)
                    // Back
                    exit_inventory = 1;
                ELSE
                    // Exit game
                    exit_inventory = 1;
                    do_exit_game = 1;
                END
            END
        END
        IF (KEY(Controls.inventory) AND open_timer == 0)
            // Back to game
            exit_inventory = 1;
        END
        
        // Check if we should exit
        IF (exit_inventory)
            force_redraw = 1; // Force map redraw when exiting inventory
            BREAK;
        END

        // Draw menu options
        i = 0;
        WHILE (i < menu_count)
            IF (i < num_items_to_show)
                qty_str = itoa(inventory[i].quantity);
                current_item = inventory[i].item + " x" + qty_str;
                IF (i == selected)
                    MenuOption[i].text = "> " + current_item;
                ELSE
                    MenuOption[i].text = "  " + current_item;
                END
                MenuOption[i].text_id = write(0, 30, 30 + i * 20, 0, MenuOption[i].text);
                MenuOption[i].desc_id = write(0, 200, 30 + i * 20, 0, inventory[i].description);
            ELSE
                IF (i == num_items_to_show)
                    IF (i == selected)
                        MenuOption[i].text = "> Back";
                    ELSE
                        MenuOption[i].text = "  Back";
                    END
                ELSE
                    IF (i == selected)
                        MenuOption[i].text = "> Exit Game";
                    ELSE
                        MenuOption[i].text = "  Exit Game";
                    END
                END
                MenuOption[i].text_id = write(0, 30, 30 + i * 20, 0, MenuOption[i].text);
                MenuOption[i].desc_id = 0; // No description for back/exit
            END
            i++;
        END

        FRAME;
    END
    
    // Always cleanup - this code ALWAYS executes when we break from LOOP
    // Background is drawn with put(), will be cleared by map_drawer's clear_screen()
    delete_text(title_id);
    i = 0;
    WHILE (i < menu_count)
        IF (MenuOption[i].text_id != 0)
            delete_text(MenuOption[i].text_id);
        END
        IF (MenuOption[i].desc_id != 0)
            delete_text(MenuOption[i].desc_id);
        END
        i++;
    END
    inventory_active = 0;
    
    // Handle exit game if requested
    IF (do_exit_game)
        unload_song(song_id);
        EXIT("Goodbye", 0);
    END
END
