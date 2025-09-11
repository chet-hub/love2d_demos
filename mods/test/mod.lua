-- mods/test/mod.lua - 测试Mod示例
function init(ctx)
    print("Test mod initializing...")
    
    -- 注册基础tile类型
    ctx.registerTileType("grass", {
        is_dynamic = false,
        is_solid = false,
        color = {0.2, 0.8, 0.2},
        on_place = function(actor, x, y, data)
            print("Placed grass at", x, y)
        end
    })
    
    ctx.registerTileType("stone", {
        is_dynamic = false,
        is_solid = true,
        color = {0.5, 0.5, 0.5},
        on_break = function(actor, x, y)
            print("Stone broken at", x, y)
        end
    })
    
    ctx.registerTileType("tree", {
        is_dynamic = true,
        is_solid = true,
        color = {0.6, 0.4, 0.2},
        on_place = function(actor, x, y, data)
            if actor then
                -- 为树添加生长脚本组件
                local growth_script = ctx.loadScript("scripts/tree_growth.lua")
                if growth_script then
                    actor:addComponent("growth", growth_script)
                end
            end
        end,
        on_interact = function(actor, x, y)
            print("Interacted with tree at", x, y)
            if actor then
                local growth = actor:getComponent("growth")
                if growth then
                    growth:call("accelerateGrowth", actor)
                end
            end
        end
    })
    
    ctx.registerTileType("water", {
        is_dynamic = true,
        is_solid = false,
        color = {0.2, 0.4, 0.8, 0.7},
        on_place = function(actor, x, y, data)
            if actor then
                local flow_script = ctx.loadScript("scripts/water_flow.lua")
                if flow_script then
                    actor:addComponent("flow", flow_script)
                end
            end
        end
    })
    
    -- 注册世界生成器
    ctx.registerChunkGenerator("terrain", function(chunk_x, chunk_y, tile_system)
        -- 简单的地形生成
        local start_x = chunk_x * 16
        local start_y = chunk_y * 16
        
        for y = 0, 15 do
            for x = 0, 15 do
                local world_x = start_x + x
                local world_y = start_y + y
                
                -- 使用噪声生成地形高度
                local height = math.sin(world_x * 0.1) * 3 + math.cos(world_y * 0.07) * 2
                
                if world_y < height then
                    -- 地下部分
                    if world_y < height - 2 then
                        tile_system:placeTile(world_x, world_y, "stone")
                    else
                        tile_system:placeTile(world_x, world_y, "grass")
                    end
                elseif world_y == math.floor(height) and math.random() < 0.1 then
                    -- 偶尔生成树
                    tile_system:placeTile(world_x, world_y, "tree", {growth_stage = 1})
                elseif world_y > height + 2 and math.random() < 0.05 then
                    -- 偶尔生成水
                    tile_system:placeTile(world_x, world_y, "water", {flow_direction = math.random(4)})
                end
            end
        end
        
        return true
    end, 10)
    
    -- 注册事件监听
    ctx.event_bus.on("mousepressed", function(event)
        if event.button == 1 then  -- 左键放置tile
            local tile_x = math.floor(event.world_x / 32)  -- TILE_SIZE
            local tile_y = math.floor(event.world_y / 32)
            
            local current_tile = ctx.tile_system:getTile(tile_x, tile_y)
            if not current_tile then
                ctx.tile_system:placeTile(tile_x, tile_y, "grass")
            end
        elseif event.button == 2 then  -- 右键移除tile
            local tile_x = math.floor(event.world_x / 32)
            local tile_y = math.floor(event.world_y / 32)
            
            ctx.tile_system:removeTile(tile_x, tile_y)
        end
    end)
    
    ctx.event_bus.on("keypressed", function(key)
        if key == "1" then
            current_place_tile = "grass"
        elseif key == "2" then
            current_place_tile = "stone"
        elseif key == "3" then
            current_place_tile = "tree"
        elseif key == "4" then
            current_place_tile = "water"
        end
    end)
    
    -- 保存当前要放置的tile类型
    current_place_tile = "grass"
    
    return {
        name = "Test Mod",
        version = "1.0.0",
        description = "A test mod demonstrating the framework features",
        dependencies = {},
        
        init = function(context)
            print("Test mod fully initialized!")
        end,
        
        update = function(context, dt)
            -- Mod更新逻辑
        end,
        
        cleanup = function(context)
            print("Test mod cleaned up!")
        end
    }
end