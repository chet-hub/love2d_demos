-- mods/test/scripts/tree_growth.lua - 树木生长脚本
local growth_timer = 0
local max_growth_stage = 3

function update(actor, dt)
    growth_timer = growth_timer + dt
    
    if growth_timer >= 5.0 then  -- 每5秒生长一次
        growth_timer = 0
        growTree(actor)
    end
end

function growTree(actor)
    if not actor.tile_data.growth_stage then
        actor.tile_data.growth_stage = 1
    end
    
    if actor.tile_data.growth_stage < max_growth_stage then
        actor.tile_data.growth_stage = actor.tile_data.growth_stage + 1
        print("Tree grew to stage", actor.tile_data.growth_stage)
        
        -- 随着生长改变颜色
        local stage = actor.tile_data.growth_stage
        local green_intensity = 0.2 + (stage / max_growth_stage) * 0.6
        actor.color = {0.6, 0.4, 0.2}  -- 保持树干颜色，由tile定义处理
        
        EventBus.emit("tree_grown", {actor = actor, stage = stage})
    end
end

function accelerateGrowth(actor)
    growTree(actor)
    print("Tree growth accelerated!")
end

function render(actor)
    -- 根据生长阶段渲染不同大小的树
    local stage = actor.tile_data.growth_stage or 1
    local size_multiplier = 0.5 + (stage / max_growth_stage) * 0.5
    
    local x = math.floor(actor.x / 32) * 32  -- TILE_SIZE
    local y = math.floor(actor.y / 32) * 32
    local size = 32 * size_multiplier
    local offset = (32 - size) / 2
    
    -- 绘制树干
    love.graphics.setColor(0.6, 0.4, 0.2)
    love.graphics.rectangle("fill", x + offset, y + offset, size, size)
    
    -- 绘制树冠（如果成长阶段足够）
    if stage >= 2 then
        local crown_size = size * 1.5
        local crown_offset = (32 - crown_size) / 2
        
        love.graphics.setColor(0.2, 0.7, 0.2, 0.8)
        love.graphics.circle("fill", 
            x + 16, -- center
            y + crown_offset + crown_size/4, 
            crown_size/2)
    end
end