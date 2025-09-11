-- lib/tile_system.lua - Tile管理系统
local Actor = require "lib.actor"
local EventBus = require "lib.event_bus"

local TileSystem = {}
TileSystem.__index = TileSystem

function TileSystem.new()
    local self = setmetatable({}, TileSystem)
    self.tile_types = {}  -- tile类型定义
    self.static_tiles = {}  -- 静态tile数据 [chunk_key][local_pos] = tile_data
    self.dynamic_actors = {}  -- 动态tile的actor对象 [world_pos] = actor
    self.tile_callbacks = {}  -- tile事件回调
    
    return self
end

function TileSystem:registerTileType(name, definition)
    self.tile_types[name] = {
        name = name,
        is_dynamic = definition.is_dynamic or false,
        is_solid = definition.is_solid or false,
        texture = definition.texture,
        color = definition.color or {1, 1, 1},
        on_place = definition.on_place,
        on_break = definition.on_break,
        on_interact = definition.on_interact,
        -- 其他属性...
    }
    
    EventBus.emit("tile_type_registered", {name = name, definition = self.tile_types[name]})
end

function TileSystem:getTileType(name)
    return self.tile_types[name]
end

function TileSystem:placeTile(x, y, tile_type, data)
    local tile_def = self.tile_types[tile_type]
    if not tile_def then
        print("Warning: Unknown tile type: " .. tile_type)
        return false
    end
    
    local world_pos = x .. "," .. y
    
    -- 移除现有tile
    self:removeTile(x, y)
    
    if tile_def.is_dynamic then
        -- 动态tile创建Actor
        local actor = Actor.new(x * TILE_SIZE + TILE_SIZE/2, y * TILE_SIZE + TILE_SIZE/2, tile_type)
        actor.tile_data = data or {}
        self.dynamic_actors[world_pos] = actor
        
        -- 调用放置回调
        if tile_def.on_place then
            tile_def.on_place(actor, x, y, data)
        end
    else
        -- 静态tile直接存储数据
        local chunk_x, chunk_y = self:worldToChunk(x, y)
        local chunk_key = chunk_x .. "," .. chunk_y
        
        if not self.static_tiles[chunk_key] then
            self.static_tiles[chunk_key] = {}
        end
        
        local local_x, local_y = self:worldToLocal(x, y)
        local local_pos = local_x .. "," .. local_y
        
        self.static_tiles[chunk_key][local_pos] = {
            type = tile_type,
            data = data or {},
            x = x,
            y = y
        }
        
        -- 调用放置回调
        if tile_def.on_place then
            tile_def.on_place(nil, x, y, data)
        end
    end
    
    EventBus.emit("tile_placed", {x = x, y = y, type = tile_type, data = data})
    return true
end

function TileSystem:removeTile(x, y)
    local world_pos = x .. "," .. y
    
    -- 检查动态tile
    local actor = self.dynamic_actors[world_pos]
    if actor then
        local tile_def = self.tile_types[actor.tile_type]
        if tile_def and tile_def.on_break then
            tile_def.on_break(actor, x, y)
        end
        
        actor:destroy()
        self.dynamic_actors[world_pos] = nil
        
        EventBus.emit("tile_removed", {x = x, y = y, type = actor.tile_type, was_dynamic = true})
        return true
    end
    
    -- 检查静态tile
    local chunk_x, chunk_y = self:worldToChunk(x, y)
    local chunk_key = chunk_x .. "," .. chunk_y
    local chunk_data = self.static_tiles[chunk_key]
    
    if chunk_data then
        local local_x, local_y = self:worldToLocal(x, y)
        local local_pos = local_x .. "," .. local_y
        local tile_data = chunk_data[local_pos]
        
        if tile_data then
            local tile_def = self.tile_types[tile_data.type]
            if tile_def and tile_def.on_break then
                tile_def.on_break(nil, x, y)
            end
            
            chunk_data[local_pos] = nil
            EventBus.emit("tile_removed", {x = x, y = y, type = tile_data.type, was_dynamic = false})
            return true
        end
    end
    
    return false
end

function TileSystem:getTile(x, y)
    local world_pos = x .. "," .. y
    
    -- 检查动态tile
    local actor = self.dynamic_actors[world_pos]
    if actor then
        return {
            type = actor.tile_type,
            data = actor.tile_data,
            actor = actor,
            is_dynamic = true
        }
    end
    
    -- 检查静态tile
    local chunk_x, chunk_y = self:worldToChunk(x, y)
    local chunk_key = chunk_x .. "," .. chunk_y
    local chunk_data = self.static_tiles[chunk_key]
    
    if chunk_data then
        local local_x, local_y = self:worldToLocal(x, y)
        local local_pos = local_x .. "," .. local_y
        local tile_data = chunk_data[local_pos]
        
        if tile_data then
            return {
                type = tile_data.type,
                data = tile_data.data,
                actor = nil,
                is_dynamic = false
            }
        end
    end
    
    return nil
end

function TileSystem:interactTile(x, y, ...)
    local tile = self:getTile(x, y)
    if not tile then return false end
    
    local tile_def = self.tile_types[tile.type]
    if tile_def and tile_def.on_interact then
        tile_def.on_interact(tile.actor, x, y, ...)
        return true
    end
    
    return false
end

function TileSystem:updateDynamicTiles(dt)
    for pos, actor in pairs(self.dynamic_actors) do
        if actor.active then
            actor:update(dt)
        else
            -- 清理被销毁的actor
            self.dynamic_actors[pos] = nil
        end
    end
end

function TileSystem:renderTiles(camera_x, camera_y, screen_width, screen_height, zoom)
    -- 计算可见区域
    local left = math.floor((camera_x - screen_width/(2*zoom)) / TILE_SIZE) - 1
    local right = math.ceil((camera_x + screen_width/(2*zoom)) / TILE_SIZE) + 1
    local top = math.floor((camera_y - screen_height/(2*zoom)) / TILE_SIZE) - 1
    local bottom = math.ceil((camera_y + screen_height/(2*zoom)) / TILE_SIZE) + 1
    
    -- 渲染静态tiles
    for y = top, bottom do
        for x = left, right do
            local tile = self:getTile(x, y)
            if tile and not tile.is_dynamic then
                self:renderStaticTile(tile, x, y)
            end
        end
    end
    
    -- 渲染动态tiles
    for pos, actor in pairs(self.dynamic_actors) do
        local tile_x = math.floor(actor.x / TILE_SIZE)
        local tile_y = math.floor(actor.y / TILE_SIZE)
        
        if tile_x >= left and tile_x <= right and tile_y >= top and tile_y <= bottom then
            actor:render()
            -- 如果actor没有自定义渲染，使用默认渲染
            if not actor:hasComponent("render") then
                self:renderDynamicTile(actor, tile_x, tile_y)
            end
        end
    end
end

function TileSystem:renderStaticTile(tile, x, y)
    local tile_def = self.tile_types[tile.type]
    if not tile_def then return end
    
    local screen_x = x * TILE_SIZE
    local screen_y = y * TILE_SIZE
    
    if tile_def.texture then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(tile_def.texture, screen_x, screen_y)
    else
        love.graphics.setColor(tile_def.color)
        love.graphics.rectangle("fill", screen_x, screen_y, TILE_SIZE, TILE_SIZE)
    end
end

function TileSystem:renderDynamicTile(actor, x, y)
    local tile_def = self.tile_types[actor.tile_type]
    if not tile_def then return end
    
    local screen_x = x * TILE_SIZE
    local screen_y = y * TILE_SIZE
    
    if tile_def.texture then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(tile_def.texture, screen_x, screen_y)
    else
        love.graphics.setColor(tile_def.color)
        love.graphics.rectangle("fill", screen_x, screen_y, TILE_SIZE, TILE_SIZE)
    end
    
    -- 动态tile添加一个小标记
    love.graphics.setColor(1, 1, 0, 0.5)
    love.graphics.rectangle("fill", screen_x + TILE_SIZE - 4, screen_y, 4, 4)
end

function TileSystem:worldToChunk(x, y)
    return math.floor(x / CHUNK_SIZE), math.floor(y / CHUNK_SIZE)
end

function TileSystem:worldToLocal(x, y)
    return x % CHUNK_SIZE, y % CHUNK_SIZE
end

function TileSystem:getChunkTiles(chunk_x, chunk_y)
    local chunk_key = chunk_x .. "," .. chunk_y
    return self.static_tiles[chunk_key] or {}
end

return TileSystem