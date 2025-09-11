-- Core Mod - 提供基础 Tile 系统和世界管理
-- mods/core/init.lua

local core = {
    name = "core",
    version = "1.0.0",
    description = "2D Minecraft 核心系统"
}

-- Mod 初始化
function core:init(ctx)
    self.ctx = ctx
    self.kernel = ctx.kernel
    
    -- 初始化子系统
    self:initTileSystem()
    self:initWorldSystem()
    self:initChunkSystem()
    self:initRegistry()
    self:initSystems()
    self:initNetworking()
    
    -- 注册事件监听
    self:registerEvents()
    
    print("[Core] Initialized")
end

-- Tile 注册表
function core:initRegistry()
    self.registry = {
        tiles = {},
        items = {},
        entities = {},
        biomes = {},
        dimensions = {}
    }
    
    -- 暴露注册 API 给其他 Mod
    self.ctx.kernel.registry = self.registry
    
    -- 注册 Tile 的 API
    function self.registry:registerTile(id, definition)
        self.tiles[id] = {
            id = id,
            name = definition.name or id,
            texture = definition.texture,
            solid = definition.solid ~= false,
            transparent = definition.transparent or false,
            hardness = definition.hardness or 1.0,
            drops = definition.drops or {id},
            onPlace = definition.onPlace,
            onBreak = definition.onBreak,
            onInteract = definition.onInteract,
            onUpdate = definition.onUpdate,
            metadata = definition.metadata or {},
            tags = definition.tags or {}
        }
        return self.tiles[id]
    end
    
    -- 注册基础 Tiles
    self.registry:registerTile("air", {
        name = "Air",
        solid = false,
        transparent = true,
        hardness = 0
    })
    
    self.registry:registerTile("stone", {
        name = "Stone",
        texture = "stone.png",
        hardness = 1.5,
        drops = {"cobblestone"}
    })
    
    self.registry:registerTile("dirt", {
        name = "Dirt",
        texture = "dirt.png",
        hardness = 0.5
    })
    
    self.registry:registerTile("grass", {
        name = "Grass Block",
        texture = "grass.png",
        hardness = 0.6,
        drops = {"dirt"}
    })
end

-- Tile 系统
function core:initTileSystem()
    local TileSystem = {}
    
    -- Tile 数据结构
    function TileSystem:createTile(id, x, y, metadata)
        return {
            id = id or "air",
            x = x,
            y = y,
            metadata = metadata or {},
            light = 0,
            state = {}
        }
    end
    
    -- Tile 操作
    function TileSystem:placeTile(world, x, y, tile_id, metadata)
        local chunk = world:getChunkAt(x, y)
        if chunk then
            local lx, ly = world:worldToLocal(x, y)
            chunk:setTile(lx, ly, tile_id, metadata)
            
            -- 触发放置事件
            self.ctx.events:emit("tile.place", {
                x = x, y = y,
                tile = tile_id,
                metadata = metadata
            })
            
            return true
        end
        return false
    end
    
    function TileSystem:breakTile(world, x, y)
        local chunk = world:getChunkAt(x, y)
        if chunk then
            local lx, ly = world:worldToLocal(x, y)
            local tile = chunk:getTile(lx, ly)
            
            if tile and tile.id ~= "air" then
                -- 触发破坏事件
                self.ctx.events:emit("tile.break", {
                    x = x, y = y,
                    tile = tile.id,
                    drops = self.registry.tiles[tile.id].drops
                })
                
                chunk:setTile(lx, ly, "air")
                return true
            end
        end
        return false
    end
    
    self.tileSystem = TileSystem
end

-- 区块系统
function core:initChunkSystem()
    local Chunk = {}
    Chunk.__index = Chunk
    
    function Chunk:new(cx, cy, size)
        local chunk = {
            cx = cx,
            cy = cy,
            size = size or 16,
            tiles = {},
            entities = {},
            dirty = true,
            loaded = false,
            generation_seed = 0
        }
        
        -- 初始化 Tile 数组
        for x = 0, chunk.size - 1 do
            chunk.tiles[x] = {}
            for y = 0, chunk.size - 1 do
                chunk.tiles[x][y] = {
                    id = "air",
                    metadata = {}
                }
            end
        end
        
        setmetatable(chunk, Chunk)
        return chunk
    end
    
    function Chunk:generate(generator)
        if generator then
            generator(self)
        else
            -- 默认生成器（简单地形）
            for x = 0, self.size - 1 do
                for y = 0, self.size - 1 do
                    local wx = self.cx * self.size + x
                    local wy = self.cy * self.size + y
                    
                    if wy > 10 then
                        self.tiles[x][y].id = "stone"
                    elseif wy > 5 then
                        self.tiles[x][y].id = "dirt"
                    elseif wy == 5 then
                        self.tiles[x][y].id = "grass"
                    end
                end
            end
        end
        self.dirty = true
    end
    
    function Chunk:getTile(x, y)
        if x >= 0 and x < self.size and y >= 0 and y < self.size then
            return self.tiles[x][y]
        end
        return nil
    end
    
    function Chunk:setTile(x, y, tile_id, metadata)
        if x >= 0 and x < self.size and y >= 0 and y < self.size then
            self.tiles[x][y] = {
                id = tile_id,
                metadata = metadata or {}
            }
            self.dirty = true
            return true
        end
        return false
    end
    
    function Chunk:save()
        -- 序列化区块数据
        local data = {
            cx = self.cx,
            cy = self.cy,
            tiles = self.tiles,
            entities = self.entities
        }
        return data
    end
    
    function Chunk:load(data)
        self.tiles = data.tiles
        self.entities = data.entities
        self.dirty = true
    end
    
    self.Chunk = Chunk
end

-- 世界系统
function core:initWorldSystem()
    local World = {}
    World.__index = World
    
    function World:new(name, seed)
        local world = {
            name = name or "world",
            seed = seed or os.time(),
            chunks = {},
            chunk_size = 16,
            loaded_chunks = {},
            view_distance = 3,
            generator = nil,
            time = 0,
            weather = "clear"
        }
        setmetatable(world, World)
        return world
    end
    
    function World:getChunk(cx, cy)
        local key = cx .. "," .. cy
        return self.chunks[key]
    end
    
    function World:loadChunk(cx, cy)
        local key = cx .. "," .. cy
        
        if not self.chunks[key] then
            -- 创建新区块
            local chunk = self.Chunk:new(cx, cy, self.chunk_size)
            
            -- 尝试从存储加载
            local saved = self:loadChunkFromDisk(cx, cy)
            if saved then
                chunk:load(saved)
            else
                -- 生成新区块
                chunk:generate(self.generator)
            end
            
            self.chunks[key] = chunk
            self.loaded_chunks[key] = true
            
            -- 触发区块加载事件
            self.ctx.events:emit("chunk.load", {
                cx = cx, cy = cy,
                chunk = chunk
            })
        end
        
        return self.chunks[key]
    end
    
    function World:unloadChunk(cx, cy)
        local key = cx .. "," .. cy
        local chunk = self.chunks[key]
        
        if chunk then
            -- 保存区块
            self:saveChunkToDisk(chunk)
            
            -- 触发区块卸载事件
            self.ctx.events:emit("chunk.unload", {
                cx = cx, cy = cy
            })
            
            self.chunks[key] = nil
            self.loaded_chunks[key] = nil
        end
    end
    
    function World:getChunkAt(world_x, world_y)
        local cx = math.floor(world_x / self.chunk_size)
        local cy = math.floor(world_y / self.chunk_size)
        return self:getChunk(cx, cy) or self:loadChunk(cx, cy)
    end
    
    function World:worldToLocal(world_x, world_y)
        local lx = world_x % self.chunk_size
        local ly = world_y % self.chunk_size
        return lx, ly
    end
    
    function World:localToWorld(cx, cy, lx, ly)
        local wx = cx * self.chunk_size + lx
        local wy = cy * self.chunk_size + ly
        return wx, wy
    end
    
    function World:getTileAt(world_x, world_y)
        local chunk = self:getChunkAt(world_x, world_y)
        if chunk then
            local lx, ly = self:worldToLocal(world_x, world_y)
            return chunk:getTile(lx, ly)
        end
        return nil
    end
    
    function World:setTileAt(world_x, world_y, tile_id, metadata)
        local chunk = self:getChunkAt(world_x, world_y)
        if chunk then
            local lx, ly = self:worldToLocal(world_x, world_y)
            return chunk:setTile(lx, ly, tile_id, metadata)
        end
        return false
    end
    
    function World:updateLoadedChunks(center_x, center_y)
        local ccx = math.floor(center_x / self.chunk_size)
        local ccy = math.floor(center_y / self.chunk_size)
        
        -- 加载视野内的区块
        for dx = -self.view_distance, self.view_distance do
            for dy = -self.view_distance, self.view_distance do
                local cx = ccx + dx
                local cy = ccy + dy
                local key = cx .. "," .. cy
                
                if not self.loaded_chunks[key] then
                    self:loadChunk(cx, cy)
                end
            end
        end
        
        -- 卸载远处的区块
        for key, _ in pairs(self.loaded_chunks) do
            local cx, cy = key:match("(-?%d+),(-?%d+)")
            cx, cy = tonumber(cx), tonumber(cy)
            
            local dist = math.max(math.abs(cx - ccx), math.abs(cy - ccy))
            if dist > self.view_distance + 1 then
                self:unloadChunk(cx, cy)
            end
        end
    end
    
    function World:saveChunkToDisk(chunk)
        -- 这里应该实现实际的存储逻辑
        -- 可以使用 love.filesystem 保存到本地
    end
    
    function World:loadChunkFromDisk(cx, cy)
        -- 这里应该实现实际的加载逻辑
        return nil
    end
    
    self.World = World
    
    -- 将 World 暴露给 kernel
    self.ctx.kernel.World = World
end

-- ECS 系统
function core:initSystems()
    local concord = self.ctx.kernel.modules.concord or require("lib.concord")
    
    -- 渲染系统
    local RenderSystem = concord.system({
        pool = {"position", "sprite"}
    })
    
    function RenderSystem:draw()
        for _, entity in ipairs(self.pool) do
            local pos = entity.position
            local sprite = entity.sprite
            
            if sprite.texture then
                love.graphics.draw(
                    sprite.texture,
                    pos.x, pos.y,
                    0,
                    sprite.scale_x or 1,
                    sprite.scale_y or 1
                )
            end
        end
    end
    
    -- 物理系统
    local PhysicsSystem = concord.system({
        pool = {"position", "velocity"}
    })
    
    function PhysicsSystem:update(dt)
        for _, entity in ipairs(self.pool) do
            local pos = entity.position
            local vel = entity.velocity
            
            pos.x = pos.x + vel.vx * dt
            pos.y = pos.y + vel.vy * dt
        end
    end
    
    -- 区块渲染系统
    local ChunkRenderSystem = {}
    
    function ChunkRenderSystem:draw(world, camera)
        if not world then return end
        
        -- 计算可见区块范围
        local view_left = camera.x - camera.width / 2
        local view_right = camera.x + camera.width / 2
        local view_top = camera.y - camera.height / 2
        local view_bottom = camera.y + camera.height / 2
        
        local chunk_size = world.chunk_size
        local tile_size = 32 -- 像素大小
        
        -- 遍历可见区块
        for key, chunk in pairs(world.chunks) do
            if chunk.dirty then
                -- 这里可以重建区块的渲染缓存
                chunk.dirty = false
            end
            
            -- 渲染区块中的 Tiles
            for x = 0, chunk.size - 1 do
                for y = 0, chunk.size - 1 do
                    local tile = chunk.tiles[x][y]
                    if tile and tile.id ~= "air" then
                        local wx = chunk.cx * chunk_size + x
                        local wy = chunk.cy * chunk_size + y
                        local sx = wx * tile_size
                        local sy = wy * tile_size
                        
                        -- 简单渲染（用颜色代替纹理）
                        local tile_def = self.registry.tiles[tile.id]
                        if tile_def then
                            if tile.id == "stone" then
                                love.graphics.setColor(0.5, 0.5, 0.5)
                            elseif tile.id == "dirt" then
                                love.graphics.setColor(0.4, 0.2, 0)
                            elseif tile.id == "grass" then
                                love.graphics.setColor(0.2, 0.8, 0.2)
                            else
                                love.graphics.setColor(1, 1, 1)
                            end
                            
                            love.graphics.rectangle("fill", 
                                sx - camera.x + camera.width/2, 
                                sy - camera.y + camera.height/2, 
                                tile_size, tile_size)
                        end
                    end
                end
            end
        end
        
        love.graphics.setColor(1, 1, 1)
    end
    
    self.systems = {
        render = RenderSystem,
        physics = PhysicsSystem,
        chunkRender = ChunkRenderSystem
    }
end

-- 网络同步
function core:initNetworking()
    -- 注册网络消息处理
    self.ctx.events:on("network.server.start", function(config)
        print("[Core] Starting server on port " .. (config.port or 25565))
        
        -- 初始化服务器世界
        self.serverWorld = self.World:new("server_world")
        
        -- 处理客户端连接
        self.ctx.events:on("network.client.connected", function(peer)
            -- 发送世界数据给新客户端
            self:syncWorldToClient(peer)
        end)
    end)
    
    self.ctx.events:on("network.client.start", function(config)
        print("[Core] Connecting to server...")
        
        -- 初始化客户端世界
        self.clientWorld = self.World:new("client_world")
    end)
    
    -- Tile 同步
    self.ctx.events:on("tile.place", function(data)
        if self.ctx.kernel.network.mode == "server" then
            -- 广播给所有客户端
            self:broadcastTileChange(data)
        end
    end)
end