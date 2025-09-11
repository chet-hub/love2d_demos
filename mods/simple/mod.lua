-- mods/simple/mod.lua - 最简单的Mod示例
function init(ctx)
    print("Simple mod loading...")
    
    -- 注册一个沙子 Tile
    ctx.registerTileType("sand", {
        is_dynamic = false,
        is_solid = false,
        color = {1, 0.9, 0.6},  -- 黄色沙子
        on_place = function(actor, x, y, data)
            print("Placed sand at " .. x .. ", " .. y)
        end,
        on_break = function(actor, x, y)
            print("Sand removed from " .. x .. ", " .. y)
        end
    })
    
    -- 注册一个发光块
    ctx.registerTileType("glow_block", {
        is_dynamic = false,
        is_solid = true,
        color = {1, 1, 0},  -- 黄色发光
        on_place = function(actor, x, y, data)
            print("Glow block placed - lighting up the area!")
        end
    })
    
    -- 监听键盘事件，添加快捷键
    ctx.event_bus.on("keypressed", function(key)
        if key == "5" then
            current_place_tile = "sand"
            print("Selected: Sand")
        elseif key == "6" then
            current_place_tile = "glow_block"
            print("Selected: Glow Block")
        elseif key == "space" then
            print("Simple mod says: Hello World!")
        end
    end)
    
    -- 监听鼠标点击，添加特殊交互
    ctx.event_bus.on("mousepressed", function(event)
        if event.button == 3 then  -- 中键
            local tile_x = math.floor(event.world_x / 32)
            local tile_y = math.floor(event.world_y / 32)
            
            local tile = ctx.tile_system:getTile(tile_x, tile_y)
            if tile then
                print("Tile info: " .. tile.type .. " at (" .. tile_x .. ", " .. tile_y .. ")")
            else
                print("Empty space at (" .. tile_x .. ", " .. tile_y .. ")")
            end
        end
    end)
    
    -- 监听游戏初始化事件
    ctx.event_bus.on("game_init", function(data)
        print("Simple mod detected game initialization!")
    end)
    
    -- 返回 Mod 定义
    return {
        name = "Simple Mod",
        version = "1.0.0",
        description = "最简单的 Mod 示例，演示基本功能",
        dependencies = {},  -- 无依赖
        
        init = function(context)
            print("Simple mod fully initialized!")
            print("Controls added:")
            print("  - Press 5 to select sand")
            print("  - Press 6 to select glow block")
            print("  - Press SPACE for hello message")
            print("  - Middle mouse click to inspect tiles")
        end,
        
        update = function(context, dt)
            -- 可以在这里添加每帧更新的逻辑
            -- 比如简单的计时器或动画
        end,
        
        cleanup = function(context)
            print("Simple mod cleaned up!")
        end
    }
end