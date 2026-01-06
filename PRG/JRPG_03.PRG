//------------------------------------------------------------------------------
// TITLE:       JRPG with graphic primitives - Optimized edition with features
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        06/01/2026
// DESCRIPTION: Enhanced JRPG with significant optimizations over JRPG_02.
//
//              KEY IMPROVEMENTS OVER JRPG_02:
//              - NPCs data-driven: Defined within MapData structure per map
//              - Teleports managed via MapData with WHILE loops for modularity
//------------------------------------------------------------------------------

PROGRAM JRPG;
CONST
    SONG_FILE = "MOD/BULERIA.S3M";
GLOBAL
    offset_x = 0;
    offset_y = 0;
    player_x = 160;
    player_y = 120;
    current_map = 0; // 0 = world, 1 = city1, 2 = city2
    song_id = 0;
    prev_offset_x = -1;
    prev_offset_y = -1;
    prev_map = 0;
    STRUCT Inventory[10]
        STRING item;
        INT quantity;
        STRING description;
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
        STRUCT TeleportData[50]
            INT tile_i;
            INT tile_j;
            INT target_map;
            INT target_x;
            INT target_y;
        END
        INT teleport_count;
        STRUCT NPCData[10]
            STRING name;
            STRING dialogue;
            INT x;
            INT y;
            INT color;
            INT gives_item;
            STRING item_name;
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
        STRING item_to_give;        // Item to give if yes
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
        INT map = 100;           // Map at the back
        INT npc = 0;             // NPCs over map
        INT player = -10;        // Player over map
        INT inventory_bg = -150; // Inventory background
        INT dialog = -200;       // Dialogue over everything
    END
    STRUCT ScreenConfig
        INT width = 320;
        INT height = 240;
        INT fps = 30;
    END
BEGIN
    set_mode(ScreenConfig.width * 1000 + ScreenConfig.height);
    set_fps(ScreenConfig.fps, 0);

    // Load and play background music
    song_id = load_song(SONG_FILE, 1); // 1 for indefinite loop
    song(song_id);

    // Initialize controls
    InitControls();

    // Initialize the map
    InitMap();

    // Initialize NPC data
    InitNPCData();

    // Create processes
    map_drawer();
    player();
    LOOP
        FRAME;
    END
END

// Initializes the NPC data for each map.
// Sets names, dialogues, positions, colors, and item rewards for NPCs per map.
// This data-driven approach integrates NPCs into the MapData structure.
PROCESS InitNPCData()
PRIVATE
    i;
BEGIN
    // World NPCs
    MapData[0].NPCData[0].name = "NPC 1";
    MapData[0].NPCData[0].dialogue = "Hello, I am NPC 1. Do you want a potion?";
    MapData[0].NPCData[0].x = 50;
    MapData[0].NPCData[0].y = 50;
    MapData[0].NPCData[0].color = 12;
    MapData[0].NPCData[0].gives_item = 1;
    MapData[0].NPCData[0].item_name = "Potion";
    MapData[0].NPCData[1].name = "NPC 2";
    MapData[0].NPCData[1].dialogue = "Hello, I am NPC 2. Have a good day!";
    MapData[0].NPCData[1].x = 250;
    MapData[0].NPCData[1].y = 150;
    MapData[0].NPCData[1].color = 14;
    MapData[0].NPCData[1].gives_item = 0;

    // City 1 NPCs
    MapData[1].NPCData[0].name = "City1 Guard";
    MapData[1].NPCData[0].dialogue = "Welcome to City 1. Stay safe!";
    MapData[1].NPCData[0].x = 64; // 2*32
    MapData[1].NPCData[0].y = 96; // 3*32
    MapData[1].NPCData[0].color = 9; // Dark blue
    MapData[1].NPCData[0].gives_item = 0;
    MapData[1].NPCData[1].name = "City1 Merchant";
    MapData[1].NPCData[1].dialogue = "The lost to the river";
    MapData[1].NPCData[1].x = 160; // 5*32
    MapData[1].NPCData[1].y = 128; // 4*32
    MapData[1].NPCData[1].color = 10; // Light green
    MapData[1].NPCData[1].gives_item = 0;

    // City 2 NPCs
    MapData[2].NPCData[0].name = "City2 Elder";
    MapData[2].NPCData[0].dialogue = "Chiadow, you should buy yourself an Evercade.";
    MapData[2].NPCData[0].x = 96; // 3*32
    MapData[2].NPCData[0].y = 64; // 2*32
    MapData[2].NPCData[0].color = 13; // Magenta
    MapData[2].NPCData[0].gives_item = 0;
    MapData[2].NPCData[1].name = "City2 Child";
    MapData[2].NPCData[1].dialogue = "Eboke resignation!";
    MapData[2].NPCData[1].x = 192; // 6*32
    MapData[2].NPCData[1].y = 160; // 5*32
    MapData[2].NPCData[1].color = 11; // Cyan
    MapData[2].NPCData[1].gives_item = 0;

    // Set NPC counts
    MapData[0].npc_count = 2;
    MapData[1].npc_count = 2;
    MapData[2].npc_count = 2;
END

// Generates all tile-based maps (world + cities).
// Assigns color values to each tile creating varied terrains:
// - Fields (green): Normal movement speed
// - Mountains (brown): Slow movement, found on edges
// - Rivers (blue): Impassable water obstacles
// - Bridges (dark brown): Walkable paths over water
// - Forests (dark green): Slow movement areas
// - Cities (yellow): Entry points to detailed city maps
// Map sizes: World 32x24 tiles (1024x768px), Cities 8x8 tiles (256x256px)
PROCESS InitMap()
PRIVATE
    i, j, count;
BEGIN
    // Set map dimensions
    MapData[0].tilesX = 32;
    MapData[0].tilesY = 24;
    MapData[1].tilesX = 8;
    MapData[1].tilesY = 8;
    MapData[2].tilesX = 8;
    MapData[2].tilesY = 8;

    // Initialize world map (32x24 tiles)
    FROM i = 0 TO 31; // i: horizontal tile index (0-31)
        FROM j = 0 TO 23; // j: vertical tile index (0-23)
            // Default terrain: green field
            MapData[0].tiles[i,j] = Colors.field;
            // Mountains on edges: slow movement terrain
            IF (i < 4 OR i > 27 OR j < 3)
                MapData[0].tiles[i,j] = Colors.mountain;
            END
            // Sea at bottom: impassable water
            IF (j > 20)
                MapData[0].tiles[i,j] = Colors.river;
            END
            // Horizontal river in middle: impassable
            IF (j == 12 OR j == 13)
                MapData[0].tiles[i,j] = Colors.river;
            END
            // Bridge over river: passable path
            IF (i == 16 AND (j == 12 OR j == 13))
                MapData[0].tiles[i,j] = Colors.bridge;
            END
            // Forests: slow movement areas
            IF ((i >= 8 AND i <= 15 AND j >= 6 AND j <= 11) OR (i >= 18 AND i <= 25 AND j >= 14 AND j <= 19))
                MapData[0].tiles[i,j] = Colors.forest;
            END
            // Cities: entry points to detailed maps
            IF ((i >= 6 AND i <= 9 AND j >= 5 AND j <= 8) OR (i >= 20 AND i <= 23 AND j >= 15 AND j <= 18))
                MapData[0].tiles[i,j] = Colors.city;
            END
            // Connecting paths: brown bridges for walkable paths
            // Vertical path from city1 to river
            IF (i == 7 AND j >= 6 AND j <= 11)
                MapData[0].tiles[i,j] = Colors.bridge;
            END
            // Horizontal path above river
            IF (j == 11 AND i >= 7 AND i <= 16)
                MapData[0].tiles[i,j] = Colors.bridge;
            END
            // Vertical path down to city2
            IF (i == 16 AND j >= 11 AND j <= 15)
                MapData[0].tiles[i,j] = Colors.bridge;
            END
            // Horizontal path to city2
            IF (j == 15 AND i >= 16 AND i <= 21)
                MapData[0].tiles[i,j] = Colors.bridge;
            END
        END
    END

    // Initialize city 1 map (small town)
    FROM i = 0 TO 7;
        FROM j = 0 TO 7;
            MapData[1].tiles[i,j] = Colors.field; // Grass by default
            // Buildings in center
            IF ((i >= 2 AND i <= 5 AND j >= 2 AND j <= 5))
                MapData[1].tiles[i,j] = Colors.city; // Yellow buildings
            END
            // Streets
            IF (i == 3 OR i == 4 OR j == 3 OR j == 4)
                MapData[1].tiles[i,j] = Colors.bridge; // Brown streets
            END
            // Exit at bottom
            IF (j == 7 AND i == 3)
                MapData[1].tiles[i,j] = Colors.field; // Exit
            END
        END
    END

    // Initialize city 2 map (similar but different)
    FROM i = 0 TO 7;
        FROM j = 0 TO 7;
            MapData[2].tiles[i,j] = Colors.field;
            // Different layout
            IF ((i >= 1 AND i <= 6 AND j >= 1 AND j <= 6))
                MapData[2].tiles[i,j] = Colors.city;
            END
            // Paths
            IF (i == 2 OR i == 5 OR j == 2 OR j == 5)
                MapData[2].tiles[i,j] = Colors.bridge;
            END
            // Exit
            IF (j == 7 AND i == 4)
                MapData[2].tiles[i,j] = Colors.field;
            END
        END
    END

    // Initialize teleports for map 0 (world)
    count = 0;
    FROM i = 6 TO 9;
        FROM j = 5 TO 8;
            MapData[0].TeleportData[count].tile_i = i;
            MapData[0].TeleportData[count].tile_j = j;
            MapData[0].TeleportData[count].target_map = 1;
            MapData[0].TeleportData[count].target_x = (i - 6) * 64;
            MapData[0].TeleportData[count].target_y = (j - 5) * 64;
            count++;
        END
    END
    FROM i = 20 TO 23;
        FROM j = 15 TO 18;
            MapData[0].TeleportData[count].tile_i = i;
            MapData[0].TeleportData[count].tile_j = j;
            MapData[0].TeleportData[count].target_map = 2;
            MapData[0].TeleportData[count].target_x = (i - 20) * 64;
            MapData[0].TeleportData[count].target_y = (j - 15) * 64;
            count++;
        END
    END
    MapData[0].teleport_count = count;

    // No teleports for city maps (exits handled separately)
    MapData[1].teleport_count = 0;
    MapData[2].teleport_count = 0;
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

// Central rendering process - MAIN IMPROVEMENT OVER JRPG_01.
// Uses dirty rectangle optimization: only redraws map when camera offset or
// current_map changes, drastically reducing draw calls per frame.
//
// Renders in order:
// 1. Map tiles (only if dirty) - calculates visible tile range
// 2. NPCs (every frame) - checks visibility and current map
// 3. Player (every frame) - always centered on screen
//
// All drawing consolidated here eliminates separate NPC processes,
// improving performance and simplifying draw ID management.
PROCESS map_drawer()
PRIVATE
    i, j, color, x1, y1, x2, y2;
    i_min, i_max, j_min, j_max;
    map_width, map_height;
    draw_ids[256]; // array for map draw IDs (maximum safe)
    draw_counter = 0;
    npc_draw_ids[10]; // separate array for NPC draw IDs
    npc_draw_count = 0;
    player_draw_id = 0; // single ID for player
    dirty;
    last_inventory_state;
BEGIN
    force_redraw = 1;
    last_inventory_state = inventory_active;
    LOOP
        // Always delete previous NPC and player draws at start of frame
        FOR (i = 0; i < npc_draw_count; i++)
            delete_draw(npc_draw_ids[i]);
        END
        npc_draw_count = 0;
        IF (player_draw_id != 0)
            delete_draw(player_draw_id);
            player_draw_id = 0;
        END

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

            IF (dirty)
                // Delete previous map draws
                FOR (i = 0; i < draw_counter; i++)
                    delete_draw(draw_ids[i]);
                END
                draw_counter = 0;

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
                        // Get color based on current_map
                        color = MapData[current_map].tiles[i,j];
                        // Set Z for map
                        draw_z = ZLevels.map;
                        // Draw filled rectangle
                        draw_ids[draw_counter] = draw(3, color, 15, 0, x1, y1, x2, y2);
                        draw_counter++;
                        j++;
                    END
                    i++;
                END

                // Update previous values
                prev_offset_x = offset_x;
                prev_offset_y = offset_y;
                prev_map = current_map;
                force_redraw = 0;

            END

            // Draw NPCs (always when inventory not active)
            draw_z = ZLevels.npc;
            i = 0;
            WHILE (i < MapData[current_map].npc_count)
                // Calculate screen position
                x1 = MapData[current_map].NPCData[i].x + offset_x;
                y1 = MapData[current_map].NPCData[i].y + offset_y;
                // Check if visible on screen
                IF (x1 + 10 > 0 AND x1 - 10 < ScreenConfig.width AND y1 + 10 > 0 AND y1 - 10 < ScreenConfig.height)
                    npc_draw_ids[npc_draw_count] = draw(5, MapData[current_map].NPCData[i].color, 15, 0, x1 - 10, y1 - 10, x1 + 10, y1 + 10);
                    npc_draw_count++;
                END
                i++;
            END

            // Draw player (always when inventory not active)
            draw_z = ZLevels.player;
            player_draw_id = draw(5, 15, 15, 0, ScreenConfig.width / 2 - 10, ScreenConfig.height / 2 - 10, ScreenConfig.width / 2 + 10, ScreenConfig.height / 2 + 10);
        ELSE
            // Inventory is open - clear map draws to avoid conflicts
            // Clear map draws
            FOR (i = 0; i < draw_counter; i++)
                delete_draw(draw_ids[i]);
            END
            draw_counter = 0;
        END

        FRAME;
    END
END

// Handles all player logic and interactions.
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
BEGIN
    x = player_x;
    y = player_y;
    LOOP
        // Calculate current tile and speed
        tile_i = player_x / 32;
        tile_j = player_y / 32;
        IF (current_map == 0)
            speed = 5;
            IF (MapData[current_map].tiles[tile_i, tile_j] == Colors.forest OR MapData[current_map].tiles[tile_i, tile_j] == Colors.mountain)
                speed = 2;
            END
        ELSE
            speed = 5; // Normal speed in cities
        END

        // Movement only if no dialogue and inventory not open
        IF (DialogState.process_id == 0 AND inventory_active == 0)
            IF (KEY(Controls.left))
                new_x = player_x - speed;
                tile_i = new_x / 32;
                tile_j = player_y / 32;
                IF (current_map == 0)
                    IF (MapData[current_map].tiles[tile_i, tile_j] != Colors.river)
                        player_x = new_x;
                    END
                ELSE
                    // In cities, allow movement
                    player_x = new_x;
                END
            END
            IF (KEY(Controls.right))
                new_x = player_x + speed;
                tile_i = new_x / 32;
                tile_j = player_y / 32;
                IF (current_map == 0)
                    IF (MapData[current_map].tiles[tile_i, tile_j] != Colors.river)
                        player_x = new_x;
                    END
                ELSE
                    player_x = new_x;
                END
            END
            IF (KEY(Controls.up))
                new_y = player_y - speed;
                tile_i = player_x / 32;
                tile_j = new_y / 32;
                IF (current_map == 0)
                    IF (MapData[current_map].tiles[tile_i, tile_j] != Colors.river)
                        player_y = new_y;
                    END
                ELSE
                    player_y = new_y;
                END
            END
            IF (KEY(Controls.down))
                new_y = player_y + speed;
                tile_i = player_x / 32;
                tile_j = new_y / 32;
                IF (current_map == 0)
                    IF (MapData[current_map].tiles[tile_i, tile_j] != Colors.river)
                        player_y = new_y;
                    END
                ELSE
                    player_y = new_y;
                END
            END
        END

        // Check for exiting city boundaries
        IF (current_map != 0 AND (player_x < 0 OR player_x >= 256 OR player_y < 0 OR player_y >= 256))
            // Force clean state before fade
            prev_map = -1;
            prev_offset_x = -9999;
            prev_offset_y = -9999;
            // Fade out before exiting
            fade_off();
            // Determine exit direction
            exit_direction = 0; // 0=north, 1=south, 2=west, 3=east
            IF (player_y < 0)
                exit_direction = 0; // north
            ELSE
                IF (player_y >= 256)
                    exit_direction = 1; // south
                ELSE
                    IF (player_x < 0)
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
                    player_x = 7 * 32;
                    player_y = 4 * 32;
                ELSE
                    IF (exit_direction == 1) // south
                        player_x = 7 * 32;
                        player_y = 9 * 32;
                    ELSE
                        IF (exit_direction == 2) // west
                            player_x = 5 * 32;
                            player_y = 6 * 32;
                        ELSE // east
                            player_x = 10 * 32;
                            player_y = 6 * 32;
                        END
                    END
                END
            ELSE
                IF (current_map == 2)
                    current_map = 0;
                    IF (exit_direction == 0) // north
                        player_x = 21 * 32;
                        player_y = 14 * 32;
                    ELSE
                        IF (exit_direction == 1) // south
                            player_x = 21 * 32;
                            player_y = 19 * 32;
                        ELSE
                            IF (exit_direction == 2) // west
                                player_x = 19 * 32;
                                player_y = 16 * 32;
                            ELSE // east
                                player_x = 24 * 32;
                                player_y = 16 * 32;
                            END
                        END
                    END
                END
            END
            // Fade in after exiting
            fade_on();
        END

        // Center camera on player
        offset_x = ScreenConfig.width / 2 - player_x;
        offset_y = ScreenConfig.height / 2 - player_y;
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

        x = player_x;
        y = player_y;

        // Calculate distances for interaction
        closest_npc = -1;
        min_dist = 51; // greater than 50
        i = 0;
        WHILE (i < MapData[current_map].npc_count)
            temp_dist = sqrt((player_x - MapData[current_map].NPCData[i].x) * (player_x - MapData[current_map].NPCData[i].x) + (player_y - MapData[current_map].NPCData[i].y) * (player_y - MapData[current_map].NPCData[i].y));
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
                        DialogState.process_id = dialogue(MapData[current_map].NPCData[closest_npc].name, MapData[current_map].NPCData[closest_npc].dialogue, MapData[current_map].NPCData[closest_npc].gives_item, MapData[current_map].NPCData[closest_npc].item_name);
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
            tile_i = player_x / 32;
            tile_j = player_y / 32;
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
                    player_x = MapData[0].TeleportData[k].target_x;
                    player_y = MapData[0].TeleportData[k].target_y;
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
PROCESS dialogue(STRING name, STRING text, INT has_options, STRING item_name[10])
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
    strcpy(DialogState.item_to_give, item_name);
    len = strlen(text);

    // Draw main dialogue box (larger and semi-transparent)
    draw_z = ZLevels.dialog;
    DialogState.box_id = draw(3, 0, 8, 0, 10, ScreenConfig.height - 90, ScreenConfig.width - 10, ScreenConfig.height - 10); // black semi-transparent rectangle

    // Write speaker name
    name_id = write(0, 30, ScreenConfig.height - 65, 0, name);
    LOOP

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
        text_id = write(0, 30, ScreenConfig.height - 45, 0, temp);

        // Show "press ENTER" indicator if complete and no options
        IF (indicator_id != 0)
            delete_text(indicator_id);
            indicator_id = 0;
        END
        IF (complete == 1 AND DialogState.has_options == 0 AND DialogState.open_timer == 0)
            // Blinking effect: show every 15 frames
            IF ((frame_counter / 15) % 2 == 0)
                indicator_id = write(0, ScreenConfig.width - 100, ScreenConfig.height - 25, 0, "[ENTER]");
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
                            IF (strcmp(inventory[j].item, DialogState.item_to_give) == 0)
                                found = j;
                                BREAK;
                            END
                        END
                        IF (found != -1)
                            inventory[found].quantity++;
                        ELSE
                            IF (item_count < 10)
                                strcpy(inventory[item_count].item, DialogState.item_to_give);
                                inventory[item_count].quantity = 1;
                                // Set description
                                IF (strcmp(DialogState.item_to_give, "Potion") == 0)
                                    strcpy(inventory[item_count].description, "Heals HP");
                                ELSE
                                    strcpy(inventory[item_count].description, "Unknown item");
                                END
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
                    options_text_ids[i] = write(0, 30, ScreenConfig.height - 35 + i * 20, 0, OptionStrings[i].selected);
                ELSE
                    options_text_ids[i] = write(0, 30, ScreenConfig.height - 35 + i * 20, 0, OptionStrings[i].normal);
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
                    delete_draw(DialogState.box_id);
                    DialogState.box_id = 0;
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
//
// FEATURES:
// - Blue fullscreen background at dedicated z-level
// - Scrollable item list (shows up to 8 items)
// - Arrow key navigation with visual cursor
// - Item selection (use functionality placeholder)
// - Back option to return to game
// - Exit game option
//
// Sets inventory_open flag to pause rendering in map_drawer,
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

    // Draw blue background
    draw_z = ZLevels.inventory_bg;
    bg_id = draw(3, 244, 15, 0, 0, 0, ScreenConfig.width, ScreenConfig.height); // Blue rectangle

    // Title
    title_id = write(0, 10, 10, 0, "Inventory - Use arrows to select, ENTER to choose");

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
    delete_draw(bg_id);
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
