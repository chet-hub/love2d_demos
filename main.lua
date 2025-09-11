-- main.lua - Love2D入口点

require "config"
local ECS = require "lib.ecs"
local EventBus = require "lib.event_bus"
local TileSystem = require "lib.tile_system"
local ChunkManager = require "lib.chunk_manager"
local ModManager = require "lib.mod_manager"

-- 全局对象
local world
local tile_system
local chunk_manager
local mod_manager
local camera = {x = 0, y = 0, zoom = 1}

function love.load()
    love.window.setTitle("2D Minecraft-like Framework")
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
    
    -- 初始化核心系统
    world = ECS.newWorld()
    tile_system = TileSystem.new()
    chunk_manager = ChunkManager.new(tile_system)
    mod_manager = ModManager.new(world, tile_system, chunk_manager)
    
    -- 发布初始化事件
    EventBus.emit("game_init", {
        world = world,
        tile_system = tile_system,
        chunk_manager = chunk_manager,
        mod_manager = mod_manager
    })
    
    -- 加载Mod
    mod_manager:loadMods()
    
    print("Framework initialized successfully!")
end

function love.update(dt)
    -- 更新ECS世界
    world:emit("update", dt)
    
    -- 更新Chunk管理器
    chunk_manager:update(camera.x, camera.y)
    
    -- 发布更新事件
    EventBus.emit("update", dt)
    
    -- 相机控制
    local speed = 200 * dt
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        camera.x = camera.x - speed
    end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        camera.x = camera.x + speed
    end
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        camera.y = camera.y - speed
    end
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        camera.y = camera.y + speed
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x + WINDOW_WIDTH/2, -camera.y + WINDOW_HEIGHT/2)
    love.graphics.scale(camera.zoom)
    
    -- 渲染Tile
    chunk_manager:render(camera.x, camera.y, WINDOW_WIDTH, WINDOW_HEIGHT, camera.zoom)
    
    -- 渲染ECS实体
    world:emit("render")
    
    love.graphics.pop()
    
    -- 发布渲染事件
    EventBus.emit("render", camera)
    
    -- 显示调试信息
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    love.graphics.print("Camera: (" .. math.floor(camera.x) .. ", " .. math.floor(camera.y) .. ")", 10, 30)
    love.graphics.print("Loaded Chunks: " .. chunk_manager:getLoadedChunkCount(), 10, 50)
end

function love.keypressed(key)
    if key == "r" then
        -- 热重载Mod
        mod_manager:reloadMods()
        print("Mods reloaded!")
    elseif key == "escape" then
        love.event.quit()
    end
    
    EventBus.emit("keypressed", key)
end

function love.mousepressed(x, y, button)
    -- 转换屏幕坐标到世界坐标
    local world_x = (x - WINDOW_WIDTH/2) / camera.zoom + camera.x
    local world_y = (y - WINDOW_HEIGHT/2) / camera.zoom + camera.y
    
    EventBus.emit("mousepressed", {
        screen_x = x, screen_y = y,
        world_x = world_x, world_y = world_y,
        button = button
    })
end

-- 导出全局访问接口
_G.GAME = {
    world = function() return world end,
    tile_system = function() return tile_system end,
    chunk_manager = function() return chunk_manager end,
    mod_manager = function() return mod_manager end,
    camera = function() return camera end
}