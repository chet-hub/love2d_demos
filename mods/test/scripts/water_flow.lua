-- mods/test/scripts/water_flow.lua - 水流动脚本
local flow_timer = 0
local flow_interval = 1.0

function update(actor, dt)
    flow_timer = flow_timer + dt
    
    if flow_timer >= flow_interval then
        flow_timer = 0
        tryFlow(actor)
    end
end

function tryFlow(actor)
    local tile_x = math.floor(actor.x / 32)  -- TILE_SIZE
    local tile_y = math.floor(actor.y / 32)
    
    local flow_direction = actor.tile_data.flow_direction or 1
    
    -- 确定流动目标位置
    local target_x, target_y
    if flow_direction == 1 then      -- 右
        target_x, target_y = tile_x + 1, tile_y
    elseif flow_direction == 2 then  -- 下
        target_x, target_y = tile_x, tile_y + 1
    elseif flow_direction == 3 then  -- 左
        target_x, target_y = tile_x - 1, tile_y
    else                            -- 上
        target_x, target_y = tile_x, tile_y - 1
    end
    
    -- 检查目标位置
    local tile_system = GAME.tile_system()
    local target_tile = tile_system:getTile(target_x, target_y)
    
    if not target_tile then
        -- 目标位置为空，尝试流动
        if math.random() < 0.3 then  -- 30%概率流动
            tile_system:placeTile(target_x, target_y, "water", {
                flow_direction = flow_direction
            })
            print("Water flowed to", target_x, target_y)
        end
    elseif target_tile.type == "water" then
        -- 目标是水，随机改变流动方向
        actor.tile_data.flow_direction = math.random(4)
    end
end

function render(actor)
    -- 渲染带有流动效果的水
    local x = math.floor(actor.x / 32) * 32
    local y = math.floor(actor.y / 32) * 32
    
    -- 基础水块
    love.graphics.setColor(0.2, 0.4, 0.8, 0.7)
    love.graphics.rectangle("fill", x, y, 32, 32)
    
    -- 流动方向指示
    local flow_direction = actor.tile_data.flow_direction or 1
    love.graphics.setColor(1, 1, 1, 0.5)
    
    local arrow_x, arrow_y = x + 16, y + 16
    local arrow_size = 6
    
    if flow_direction == 1 then      -- 右
        love.graphics.polygon("fill", 
            arrow_x, arrow_y - arrow_size,
            arrow_x + arrow_size, arrow_y,
            arrow_x, arrow_y + arrow_size)
    elseif flow_direction == 2 then  -- 下
        love.graphics.polygon("fill",
            arrow_x - arrow_size, arrow_y,
            arrow_x, arrow_y + arrow_size,
            arrow_x + arrow_size, arrow_y)
    elseif flow_direction == 3 then  -- 左
        love.graphics.polygon("fill",
            arrow_x, arrow_y - arrow_size,
            arrow_x - arrow_size, arrow_y,
            arrow_x, arrow_y + arrow_size)
    else                            -- 上
        love.graphics.polygon("fill",
            arrow_x - arrow_size, arrow_y,
            arrow_x, arrow_y - arrow_size,
            arrow_x + arrow_size, arrow_y)
    end
end