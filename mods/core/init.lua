-- Core mod: provides tile, chunk, world, and ECS systems
local core = {
    name = "core",
    version = "1.0.0",
    description = "2D Minecraft core systems"
}

-- Initialize the mod
function core:init(ctx)
    -- Store context
    self.ctx = ctx
    self.kernel = ctx.kernel
    
    -- Check Love2D dependency
    if not love or not love.filesystem then
        error("[Core] Critical error: Love2D not found")
    end
    
    -- Check Concord ECS dependency
    local concord = self.ctx.kernel.modules.concord or require("lib.concord")
    if not concord then
        error("[Core] Critical error: Concord ECS library not found")
    end
    print("[Core] Concord ECS loaded successfully: " .. tostring(concord))
    
    -- Initialize subsystems
    print("[Core] Starting initialization")
    self:initTileSystem()
    print("[Core] Tile system initialized")
    self:initChunkSystem()
    print("[Core] Chunk system initialized")
    self:initWorldSystem()
    print("[Core] World system initialized")
    self:initRegistry()
    print("[Core] Registry initialized")
    self:initSystems()
    print("[Core] ECS systems initialized")
    self:initNetworking()
    print("[Core] Network system initialized")
    
    -- Register event listeners
    self:registerEvents()
    print("[Core] Event system initialized")
    
    print("[Core] Initialization completed")
end

-- Tile registry: manages tile, item, entity definitions
function core:initRegistry()
    self.registry = {
        tiles = {},            -- Tile definitions
        items = {},            -- Item definitions (unused)
        entities = {},         -- Entity definitions (unused)
        biomes = {},           -- Biome definitions (unused)
        dimensions = {}        -- Dimension definitions (unused)
    }
    
    -- Expose registry to other mods
    self.ctx.kernel.registry = self.registry
    
    -- API to register tiles
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
    
    -- Register basic tiles
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

-- Tile system: manages tile creation and operations
function core:initTileSystem()
    local TileSystem = {
        kernel = self.ctx.kernel -- Store kernel reference for event access
    }
    
    -- Create tile data structure
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
    
    -- Place a tile
    function TileSystem:placeTile(world, x, y, tile_id, metadata)
        local chunk = world:getChunkAt(x, y)
        if chunk then
            local lx, ly = world:worldToLocal(x, y)
            chunk:setTile(lx, ly, tile_id, metadata)
            -- Emit tile placement event using kernel.events
            self.kernel.events:enqueue("tile.place", {
                x = x, y = y,
                tile = tile_id,
                metadata = metadata
            })
            return true
        end
        return false
    end
    
    -- Break a tile
    function TileSystem:breakTile(world, x, y)
        local chunk = world:getChunkAt(x, y)
        if chunk then
            local lx, ly = world:worldToLocal(x, y)
            local tile = chunk:getTile(lx, ly)
            if tile and tile.id ~= "air" then
                -- Emit tile break event using kernel.events
                self.kernel.events:enqueue("tile.break", {
                    x = x, y = y,
                    tile = tile.id,
                    drops = self.kernel.registry.tiles[tile.id].drops
                })
                chunk:setTile(lx, ly, "air")
                return true
            end
        end
        return false
    end
    
    self.tileSystem = TileSystem
    self.ctx.kernel.tileSystem = TileSystem
end

-- Chunk system: manages chunk data and generation
function core:initChunkSystem()
    local Chunk = {}
    Chunk.__index = Chunk
    
    function Chunk:new(cx, cy, size)
        -- Create a new chunk
        local chunk = {
            cx = cx,           -- Chunk X coordinate
            cy = cy,           -- Chunk Y coordinate
            size = size or 16, -- Chunk size (default 16x16)
            tiles = {},        -- Tile array
            entities = {},     -- Entity list (unused)
            dirty = true,      -- Needs redraw
            loaded = false     -- Loaded status
        }
        
        -- Initialize tile array
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
        -- Generate chunk content
        if generator then
            generator(self)
        else
            -- Default generator: simple terrain
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
        -- Get tile at specified position
        if x >= 0 and x < self.size and y >= 0 and y < self.size then
            return self.tiles[x][y]
        end
        return nil
    end
    
    function Chunk:setTile(x, y, tile_id, metadata)
        -- Set tile at specified position
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
    
    self.Chunk = Chunk
    self.ctx.kernel.Chunk = Chunk
end

-- World system: manages chunks and tile operations
function core:initWorldSystem()
    local World = {}
    World.__index = World
    
    function World:new(name, seed)
        -- Create a new world
        local world = {
            name = name or "world",
            seed = seed or os.time(),
            chunks = {},           -- All chunks
            chunk_size = 16,       -- Chunk size
            loaded_chunks = {},    -- Loaded chunks
            view_distance = 3,     -- View distance (chunks)
            generator = nil,       -- Terrain generator (unused)
            time = 0,              -- World time
            weather = "clear"      -- Weather state
        }
        setmetatable(world, World)
        return world
    end
    
    function World:getChunk(cx, cy)
        -- Get a specific chunk
        local key = cx .. "," .. cy
        return self.chunks[key]
    end
    
    function World:loadChunk(cx, cy)
        -- Load or create a chunk
        local key = cx .. "," .. cy
        if not self.chunks[key] then
            local chunk = self.ctx.kernel.Chunk:new(cx, cy, self.chunk_size)
            local saved = self:loadChunkFromDisk(cx, cy)
            if saved then
                chunk:load(saved)
            else
                chunk:generate(self.generator)
            end
            self.chunks[key] = chunk
            self.loaded_chunks[key] = true
            -- Emit chunk load event
            self.ctx.events:enqueue("chunk.load", {
                cx = cx, cy = cy,
                chunk = chunk
            })
        end
        return self.chunks[key]
    end
    
    function World:unloadChunk(cx, cy)
        -- Unload a chunk
        local key = cx .. "," .. cy
        local chunk = self.chunks[key]
        if chunk then
            self:saveChunkToDisk(chunk)
            self.ctx.events:enqueue("chunk.unload", {
                cx = cx, cy = cy
            })
            self.chunks[key] = nil
            self.loaded_chunks[key] = nil
        end
    end
    
    function World:getChunkAt(world_x, world_y)
        -- Get chunk at world coordinates
        local cx = math.floor(world_x / self.chunk_size)
        local cy = math.floor(world_y / self.chunk_size)
        return self:getChunk(cx, cy) or self:loadChunk(cx, cy)
    end
    
    function World:worldToLocal(world_x, world_y)
        -- Convert world coordinates to local
        local lx = world_x % self.chunk_size
        local ly = world_y % self.chunk_size
        if lx < 0 then lx = lx + self.chunk_size end
        if ly < 0 then ly = ly + self.chunk_size end
        return lx, ly
    end
    
    function World:localToWorld(cx, cy, lx, ly)
        -- Convert local coordinates to world
        local wx = cx * self.chunk_size + lx
        local wy = cy * self.chunk_size + ly
        return wx, wy
    end
    
    function World:getTileAt(world_x, world_y)
        -- Get tile at world coordinates
        local chunk = self:getChunkAt(world_x, world_y)
        if chunk then
            local lx, ly = self:worldToLocal(world_x, world_y)
            return chunk:getTile(lx, ly)
        end
        return nil
    end
    
    function World:setTileAt(world_x, world_y, tile_id, metadata)
        -- Set tile at world coordinates
        local chunk = self:getChunkAt(world_x, world_y)
        if chunk then
            local lx, ly = self:worldToLocal(world_x, world_y)
            return chunk:setTile(lx, ly, tile_id, metadata)
        end
        return false
    end
    
    function World:updateLoadedChunks(center_x, center_y)
        -- Update loaded chunks
        local ccx = math.floor(center_x / self.chunk_size)
        local ccy = math.floor(center_y / self.chunk_size)
        
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
        -- Save chunk to disk (placeholder implementation)
        print("[Core] Saving chunk (placeholder): " .. chunk.cx .. "," .. chunk.cy)
        -- TODO: Implement chunk saving logic
    end
    
    function World:loadChunkFromDisk(cx, cy)
        -- Load chunk from disk (placeholder implementation)
        print("[Core] Loading chunk from disk (placeholder): " .. cx .. "," .. cy)
        return nil
        -- TODO: Implement chunk loading logic
    end
    
    self.World = World
    self.ctx.kernel.World = World
    print("[Core] World system initialized, kernel.World set to: " .. tostring(World))
end

-- ECS systems: register rendering and physics systems
function core:initSystems()
    local concord = self.ctx.kernel.modules.concord or require("lib.concord")
    if not concord then
        error("[Core] Critical error: Concord ECS library not found")
    end
    
    -- Register sprite component
    self.ctx.ecs.components.sprite = concord.component("sprite", function(c, data)
        c.texture = data.texture
        c.scale_x = data.scale_x or 1
        c.scale_y = data.scale_y or 1
    end)
    
    -- Render system: draws entities with position and sprite components
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
    
    -- Physics system: updates entities with position and velocity components
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
    
    -- Chunk render system: draws tiles in the world
    local ChunkRenderSystem = {}
    
    function ChunkRenderSystem:draw(world, camera)
        if not world or not camera then
            print("[Core] ChunkRenderSystem: No world or camera provided, skipping render")
            return
        end
        local chunk_size = world.chunk_size
        local tile_size = 32
        
        for key, chunk in pairs(world.chunks) do
            if chunk.dirty then
                chunk.dirty = false
                print("[Core] Rendering chunk: (" .. chunk.cx .. "," .. chunk.cy .. ")")
            end
            for x = 0, chunk.size - 1 do
                for y = 0, chunk.size - 1 do
                    local tile = chunk.tiles[x][y]
                    if tile and tile.id ~= "air" then
                        local wx = chunk.cx * chunk_size + x
                        local wy = chunk.cy * chunk_size + y
                        local sx = wx * tile_size
                        local sy = wy * tile_size
                        local tile_def = self.ctx.kernel.registry.tiles[tile.id]
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
    
    -- Register ECS systems to world
    self.ctx.ecs.world:addSystems(RenderSystem, PhysicsSystem)
end

-- Network synchronization (placeholder interface)
function core:initNetworking()
    -- Initialize network (placeholder implementation)
    print("[Core] Network system initialized (placeholder)")
    -- TODO: Implement enet or other network library logic
end

-- Register event listeners
function core:registerEvents()
    -- Listen for tile placement event
    self.ctx.events:on("tile.place", function(data)
        print("[Core] Tile placed: (" .. data.x .. "," .. data.y .. ") - " .. data.tile)
    end)
    
    -- Listen for tile break event
    self.ctx.events:on("tile.break", function(data)
        print("[Core] Tile broken: (" .. data.x .. "," .. data.y .. ") - " .. data.tile)
    end)
    
    -- Listen for chunk load event
    self.ctx.events:on("chunk.load", function(data)
        print("[Core] Chunk loaded: (" .. data.cx .. "," .. data.cy .. ")")
    end)
    
    -- Listen for chunk unload event
    self.ctx.events:on("chunk.unload", function(data)
        print("[Core] Chunk unloaded: (" .. data.cx .. "," .. data.cy .. ")")
    end)
end

return core