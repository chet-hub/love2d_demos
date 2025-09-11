-- lib/chunk_manager.lua - Chunk管理系统
local EventBus = require "lib.event_bus"

local ChunkManager = {}
ChunkManager.__index = ChunkManager

function ChunkManager.new(tile_system)
    local self = setmetatable({}, ChunkManager)
    self.tile_system = tile_system
    self.loaded_chunks = {}  -- [chunk_key] = {chunk_x, chunk_y, last_access_time}
    self.chunk_generators = {}  -- 注册的chunk生成器
    self.last_camera_chunk = {x = nil, y = nil}
    
    return self
end

function ChunkManager:registerGenerator(name, generator_func, priority)
    table.insert(self.chunk_generators, {
        name = name,
        generate = generator_func,
        priority = priority or 0
    })
    
    -- 按优先级排序
    table.sort(self.chunk_generators, function(a, b)
        return a.priority > b.priority
    end)
end

function ChunkManager:update(camera_x, camera_y)
    local chunk_x = math.floor(camera_x / (CHUNK_SIZE * TILE_SIZE))
    local chunk_y = math.floor(camera_y / (CHUNK_SIZE * TILE_SIZE))
    
    -- 检查是否需要加载新chunk
    if chunk_x ~= self.last_camera_chunk.x or chunk_y ~= self.last_camera_chunk.y then
        self.last_camera_chunk.x = chunk_x
        self.last_camera_chunk.y = chunk_y
        
        self:loadChunksAroundCamera(chunk_x, chunk_y)
    end
    
    -- 卸载距离过远的chunk
    self:unloadDistantChunks(chunk_x, chunk_y)
end

function ChunkManager:loadChunksAroundCamera(camera_chunk_x, camera_chunk_y)
    for dy = -VIEW_DISTANCE, VIEW_DISTANCE do
        for dx = -VIEW_DISTANCE, VIEW_DISTANCE do
            local chunk_x = camera_chunk_x + dx
            local chunk_y = camera_chunk_y + dy
            
            self:loadChunk(chunk_x, chunk_y)
        end
    end
end

function ChunkManager:loadChunk(chunk_x, chunk_y)
    local chunk_key = chunk_x .. "," .. chunk_y
    
    if self.loaded_chunks[chunk_key] then
        -- 更新访问时间
        self.loaded_chunks[chunk_key].last_access_time = love.timer.getTime()
        return true
    end
    
    -- 检查是否超出最大加载数量
    if self:getLoadedChunkCount() >= MAX_CHUNKS_LOADED then
        self:unloadOldestChunk()
    end
    
    -- 尝试从保存数据加载
    local loaded_from_save = self:loadChunkFromSave(chunk_x, chunk_y)
    
    if not loaded_from_save then
        -- 生成新chunk
        self:generateChunk(chunk_x, chunk_y)
    end
    
    -- 标记chunk为已加载
    self.loaded_chunks[chunk_key] = {
        chunk_x = chunk_x,
        chunk_y = chunk_y,
        last_access_time = love.timer.getTime(),
        generated = not loaded_from_save
    }
    
    EventBus.emit("chunk_loaded", {chunk_x = chunk_x, chunk_y = chunk_y})
    return true
end

function ChunkManager:unloadChunk(chunk_x, chunk_y)
    local chunk_key = chunk_x .. "," .. chunk_y
    
    if not self.loaded_chunks[chunk_key] then
        return false
    end
    
    -- 保存chunk数据
    self:saveChunkToSave(chunk_x, chunk_y)
    
    -- 移除已加载标记
    self.loaded_chunks[chunk_key] = nil
    
    EventBus.emit("chunk_unloaded", {chunk_x = chunk_x, chunk_y = chunk_y})
    return true
end

function ChunkManager:unloadDistantChunks(camera_chunk_x, camera_chunk_y)
    local current_time = love.timer.getTime()
    local chunks_to_unload = {}
    
    for chunk_key, chunk_info in pairs(self.loaded_chunks) do
        local dx = math.abs(chunk_info.chunk_x - camera_chunk_x)
        local dy = math.abs(chunk_info.chunk_y - camera_chunk_y)
        local distance = math.max(dx, dy)
        
        if distance > VIEW_DISTANCE then
            local idle_time = current_time - chunk_info.last_access_time
            if idle_time > CHUNK_UNLOAD_DELAY then
                table.insert(chunks_to_unload, {chunk_info.chunk_x, chunk_info.chunk_y})
            end
        end
    end
    
    for _, chunk_pos in ipairs(chunks_to_unload) do
        self:unloadChunk(chunk_pos[1], chunk_pos[2])
    end
end

function ChunkManager:unloadOldestChunk()
    local oldest_chunk = nil
    local oldest_time = math.huge
    
    for chunk_key, chunk_info in pairs(self.loaded_chunks) do
        if chunk_info.last_access_time < oldest_time then
            oldest_time = chunk_info.last_access_time
            oldest_chunk = chunk_info
        end
    end
    
    if oldest_chunk then
        self:unloadChunk(oldest_chunk.chunk_x, oldest_chunk.chunk_y)
    end
end

function ChunkManager:generateChunk(chunk_x, chunk_y)
    -- 使用注册的生成器生成chunk
    for _, generator in ipairs(self.chunk_generators) do
        local success = generator.generate(chunk_x, chunk_y, self.tile_system)
        if success then
            EventBus.emit("chunk_generated", {
                chunk_x = chunk_x, 
                chunk_y = chunk_y, 
                generator = generator.name
            })
            return true
        end
    end
    
    -- 如果没有生成器，创建空chunk
    EventBus.emit("chunk_generated", {chunk_x = chunk_x, chunk_y = chunk_y, generator = "empty"})
    return true
end

function ChunkManager:loadChunkFromSave(chunk_x, chunk_y)
    local chunk_file = SAVE_DIR .. "/chunk_" .. chunk_x .. "_" .. chunk_y .. ".dat"
    
    if not love.filesystem.getInfo(chunk_file) then
        return false
    end
    
    local data = love.filesystem.read(chunk_file)
    if not data then
        return false
    end
    
    -- 简单的序列化格式解析
    local success, chunk_data = pcall(function() return load("return " .. data)() end)
    if not success then
        print("Failed to load chunk data from: " .. chunk_file)
        return false
    end
    
    -- 恢复tile数据
    for _, tile_info in ipairs(chunk_data.tiles or {}) do
        self.tile_system:placeTile(tile_info.x, tile_info.y, tile_info.type, tile_info.data)
    end
    
    return true
end

function ChunkManager:saveChunkToSave(chunk_x, chunk_y)
    if not love.filesystem.getInfo(SAVE_DIR) then
        love.filesystem.createDirectory(SAVE_DIR)
    end
    
    local chunk_data = {tiles = {}}
    
    -- 收集静态tile数据
    local static_tiles = self.tile_system:getChunkTiles(chunk_x, chunk_y)
    for pos, tile_info in pairs(static_tiles) do
        table.insert(chunk_data.tiles, {
            x = tile_info.x,
            y = tile_info.y,
            type = tile_info.type,
            data = tile_info.data
        })
    end
    
    -- 收集动态tile数据
    for y = chunk_y * CHUNK_SIZE, (chunk_y + 1) * CHUNK_SIZE - 1 do
        for x = chunk_x * CHUNK_SIZE, (chunk_x + 1) * CHUNK_SIZE - 1 do
            local tile = self.tile_system:getTile(x, y)
            if tile and tile.is_dynamic then
                table.insert(chunk_data.tiles, {
                    x = x,
                    y = y,
                    type = tile.type,
                    data = tile.data
                })
            end
        end
    end
    
    -- 序列化并保存
    local chunk_file = SAVE_DIR .. "/chunk_" .. chunk_x .. "_" .. chunk_y .. ".dat"
    local serialized = self:serializeTable(chunk_data)
    love.filesystem.write(chunk_file, serialized)
end

function ChunkManager:serializeTable(t)
    local function serialize_value(v)
        if type(v) == "string" then
            return string.format("%q", v)
        elseif type(v) == "table" then
            local parts = {}
            for k, val in pairs(v) do
                local key = type(k) == "string" and k or "[" .. serialize_value(k) .. "]"
                table.insert(parts, key .. "=" .. serialize_value(val))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        else
            return tostring(v)
        end
    end
    
    return serialize_value(t)
end

function ChunkManager:isChunkLoaded(chunk_x, chunk_y)
    local chunk_key = chunk_x .. "," .. chunk_y
    return self.loaded_chunks[chunk_key] ~= nil
end

function ChunkManager:getLoadedChunkCount()
    local count = 0
    for _ in pairs(self.loaded_chunks) do
        count = count + 1
    end
    return count
end

function ChunkManager:render(camera_x, camera_y, screen_width, screen_height, zoom)
    -- 更新tile系统渲染
    self.tile_system:updateDynamicTiles(love.timer.getDelta())
    self.tile_system:renderTiles(camera_x, camera_y, screen_width, screen_height, zoom)
end

return ChunkManager