//------------------------------------------------------------------------------
// TITLE:       Data Generator for JRPG_04
// AUTHOR:      Sebastian J. MONCHO MAQUET
// DATE:        06/01/2026
// DESCRIPTION: Generates the Maps.dat file with all map, NPC, and teleport data.
//              Run this program once to create the Maps.dat and Items.dat files.
//------------------------------------------------------------------------------

PROGRAM MapGenerator;
GLOBAL
    STRUCT ItemList[20]
        STRING name[20];
        STRING description[50];
        INT price;
    END
    INT item_list_count = 0;
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
            STRING name[20];
            STRING dialogue[50];
            INT x;
            INT y;
            INT color;
            INT gives_item;
            INT item_id;
        END
        INT npc_count;
    END
    STRUCT Colors
        INT field = 38;
        INT mountain = 117;
        INT river = 57;
        INT bridge = 8;
        INT city = 235;
        INT forest = 34;
    END
BEGIN
    write(0, 10, 10, 0, "Generating Maps.dat and Items.dat...");
    GenerateItemsData();
    GenerateMapsData();
    write(0, 10, 30, 0, "Maps.dat created successfully!");
    write(0, 10, 40, 0, "Items.dat created successfully!");
    write(0, 10, 60, 0, "Press any key to exit...");
    LOOP
        IF (scan_code != 0)
            EXIT("", 0);
        END
        FRAME;
    END
END

PROCESS GenerateItemsData()
PRIVATE
    file_handle;
    data_size;
BEGIN
    // Initialize item database
    ItemList[0].name = "Potion";
    ItemList[0].description = "Restores 50 HP";
    ItemList[0].price = 50;
    
    ItemList[1].name = "Elixir";
    ItemList[1].description = "Restores all HP";
    ItemList[1].price = 200;
    
    ItemList[2].name = "Antidote";
    ItemList[2].description = "Cures poison";
    ItemList[2].price = 30;
    
    ItemList[3].name = "Phoenix Down";
    ItemList[3].description = "Revives fallen ally";
    ItemList[3].price = 500;
    
    ItemList[4].name = "Ether";
    ItemList[4].description = "Restores 50 MP";
    ItemList[4].price = 100;
    
    ItemList[5].name = "Tent";
    ItemList[5].description = "Rests the party";
    ItemList[5].price = 150;
    
    ItemList[6].name = "Herb";
    ItemList[6].description = "Restores 20 HP";
    ItemList[6].price = 20;
    
    ItemList[7].name = "Mana Potion";
    ItemList[7].description = "Restores 30 MP";
    ItemList[7].price = 80;
    
    item_list_count = 8;
    
    // Write Items.dat file
    file_handle = fopen("Items.dat", "w");
    
    IF (file_handle == 0)
        write(0, 10, 70, 0, "ERROR: Could not create Items.dat!");
        RETURN;
    END
    
    // Write item_list_count first
    data_size = sizeof(item_list_count);
    fwrite(OFFSET item_list_count, data_size, file_handle);
    
    // Write entire ItemList structure (all 20 item slots)
    data_size = sizeof(ItemList);
    IF (fwrite(OFFSET ItemList, data_size, file_handle) == 0)
        write(0, 10, 80, 0, "ERROR: Could not write to Items.dat!");
    END
    
    fclose(file_handle);
END

PROCESS GenerateMapsData()
PRIVATE
    file_handle;
    data_size;
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
    FROM i = 0 TO 31;
        FROM j = 0 TO 23;
            MapData[0].tiles[i,j] = Colors.field;
            IF (i < 4 OR i > 27 OR j < 3)
                MapData[0].tiles[i,j] = Colors.mountain;
            END
            IF (j > 20)
                MapData[0].tiles[i,j] = Colors.river;
            END
            IF (j == 12 OR j == 13)
                MapData[0].tiles[i,j] = Colors.river;
            END
            IF (i == 16 AND (j == 12 OR j == 13))
                MapData[0].tiles[i,j] = Colors.bridge;
            END
            IF ((i >= 8 AND i <= 15 AND j >= 6 AND j <= 11) OR (i >= 18 AND i <= 25 AND j >= 14 AND j <= 19))
                MapData[0].tiles[i,j] = Colors.forest;
            END
            IF ((i >= 6 AND i <= 9 AND j >= 5 AND j <= 8) OR (i >= 20 AND i <= 23 AND j >= 15 AND j <= 18))
                MapData[0].tiles[i,j] = Colors.city;
            END
            IF (i == 7 AND j >= 6 AND j <= 11)
                MapData[0].tiles[i,j] = Colors.bridge;
            END
            IF (j == 11 AND i >= 7 AND i <= 16)
                MapData[0].tiles[i,j] = Colors.bridge;
            END
            IF (i == 16 AND j >= 11 AND j <= 15)
                MapData[0].tiles[i,j] = Colors.bridge;
            END
            IF (j == 15 AND i >= 16 AND i <= 21)
                MapData[0].tiles[i,j] = Colors.bridge;
            END
        END
    END

    // Initialize city 1 map
    FROM i = 0 TO 7;
        FROM j = 0 TO 7;
            MapData[1].tiles[i,j] = Colors.field;
            IF ((i >= 2 AND i <= 5 AND j >= 2 AND j <= 5))
                MapData[1].tiles[i,j] = Colors.city;
            END
            IF (i == 3 OR i == 4 OR j == 3 OR j == 4)
                MapData[1].tiles[i,j] = Colors.bridge;
            END
            IF (j == 7 AND i == 3)
                MapData[1].tiles[i,j] = Colors.field;
            END
        END
    END

    // Initialize city 2 map
    FROM i = 0 TO 7;
        FROM j = 0 TO 7;
            MapData[2].tiles[i,j] = Colors.field;
            IF ((i >= 1 AND i <= 6 AND j >= 1 AND j <= 6))
                MapData[2].tiles[i,j] = Colors.city;
            END
            IF (i == 2 OR i == 5 OR j == 2 OR j == 5)
                MapData[2].tiles[i,j] = Colors.bridge;
            END
            IF (j == 7 AND i == 4)
                MapData[2].tiles[i,j] = Colors.field;
            END
        END
    END

    // Initialize teleports for world map
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
    MapData[1].teleport_count = 0;
    MapData[2].teleport_count = 0;

    // Initialize NPCs
    MapData[0].NPCData[0].name = "NPC 1";
    MapData[0].NPCData[0].dialogue = "Hello, I am NPC 1. Do you want a potion?";
    MapData[0].NPCData[0].x = 50;
    MapData[0].NPCData[0].y = 50;
    MapData[0].NPCData[0].color = 12;
    MapData[0].NPCData[0].gives_item = 1;
    MapData[0].NPCData[0].item_id = 0; // Potion
    MapData[0].NPCData[1].name = "NPC 2";
    MapData[0].NPCData[1].dialogue = "Hello, I am NPC 2. Have a good day!";
    MapData[0].NPCData[1].x = 250;
    MapData[0].NPCData[1].y = 150;
    MapData[0].NPCData[1].color = 14;
    MapData[0].NPCData[1].gives_item = 0;
    MapData[0].NPCData[1].item_id = -1;

    MapData[1].NPCData[0].name = "City1 Guard";
    MapData[1].NPCData[0].dialogue = "Welcome to City 1. Stay safe!";
    MapData[1].NPCData[0].x = 64;
    MapData[1].NPCData[0].y = 96;
    MapData[1].NPCData[0].color = 9;
    MapData[1].NPCData[0].gives_item = 0;
    MapData[1].NPCData[0].item_id = -1;
    MapData[1].NPCData[1].name = "City1 Merchant";
    MapData[1].NPCData[1].dialogue = "The lost to the river";
    MapData[1].NPCData[1].x = 160;
    MapData[1].NPCData[1].y = 128;
    MapData[1].NPCData[1].color = 10;
    MapData[1].NPCData[1].gives_item = 0;
    MapData[1].NPCData[1].item_id = -1;

    MapData[2].NPCData[0].name = "City2 Elder";
    MapData[2].NPCData[0].dialogue = "Chiadow, you should buy yourself an Evercade.";
    MapData[2].NPCData[0].x = 96;
    MapData[2].NPCData[0].y = 64;
    MapData[2].NPCData[0].color = 13;
    MapData[2].NPCData[0].gives_item = 0;
    MapData[2].NPCData[0].item_id = -1;
    MapData[2].NPCData[1].name = "City2 Child";
    MapData[2].NPCData[1].dialogue = "Eboke resignation!";
    MapData[2].NPCData[1].x = 192;
    MapData[2].NPCData[1].y = 160;
    MapData[2].NPCData[1].color = 11;
    MapData[2].NPCData[1].gives_item = 0;
    MapData[2].NPCData[1].item_id = -1;

    MapData[0].npc_count = 2;
    MapData[1].npc_count = 2;
    MapData[2].npc_count = 2;

    // Now write all data to file
    file_handle = fopen("Maps.dat", "w");
    
    IF (file_handle == 0)
        write(0, 10, 70, 0, "ERROR: Could not create Maps.dat!");
        RETURN;
    END
    
    // Get size of MapData structure
    data_size = sizeof(MapData);
    
    // Write entire MapData structure to file
    IF (fwrite(OFFSET MapData, data_size, file_handle) == 0)
        write(0, 10, 70, 0, "ERROR: Could not write to Maps.dat!");
    END
    
    // Close the file
    fclose(file_handle);
END
