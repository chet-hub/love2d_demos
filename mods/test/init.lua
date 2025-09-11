-- Test mod: Validates core functionality and serves as a template for mod development
local test = {
    name = "test",
    version = "1.0.0",
    description = "Test mod for validating core systems and learning mod development"
}

-- Initialize the mod
function test:init(ctx)
    -- Store context
    self.ctx = ctx
    self.kernel = ctx.kernel
    print("[Test] Starting initialization")

    -- Check kernel dependencies
    if not self.kernel.World or not self.kernel.Chunk or not self.kernel.tileSystem then
        print("[Test] Error: Core mod systems (World, Chunk, or tileSystem) not found")
        return
    end
    print("[Test] Core mod systems verified")

    -- Initialize world
    self.world = self.kernel.World:new("test_world", os.time())
    print("[Test] World created: " .. self.world.name)

    -- Initialize camera
    self.camera = {
        x = 0, y = 0,          -- Camera position
        width = love.graphics.getWidth(),
        height = love.graphics.getHeight(),
        zoom = 1               -- Camera zoom level
    }
    print("[Test] Camera initialized: " .. self.camera.width .. "x" .. self.camera.height)

    -- Initialize player
    local ok, err = pcall(function()
        self:initPlayer()
    end)
    if not ok then
        print("[Test] Error initializing player: " .. tostring(err))
    else
        print("[Test] Player initialized")
    end

    -- Register event listeners
    ok, err = pcall(function()
        self:registerEvents()
    end)
    if not ok then
        print("[Test] Error registering events: " .. tostring(err))
    else
        print("[Test] Event listeners registered")
    end

    -- Register hooks
    ok, err = pcall(function()
        self:registerHooks()
    end)
    if not ok then
        print("[Test] Error registering hooks: " .. tostring(err))
    else
        print("[Test] Hooks registered")
    end

    -- Initialize test actor
    ok, err = pcall(function()
        self:initActor()
    end)
    if not ok then
        print("[Test] Error initializing actor: " .. tostring(err))
    else
        print("[Test] Test actor initialized")
    end

    print("[Test] Initialization completed")
end

-- Initialize player entity with ECS components
function test:initPlayer()
    local concord = self.ctx.kernel.modules.concord or require("lib.concord")
    if not concord then
        error("[Test] Critical error: Concord ECS library not found")
    end

    -- Create player entity
    self.player = self.ctx.ecs.world:newEntity()
    self.player:give("position", 0, 0)              -- Start at origin
    self.player:give("velocity", 0, 0)              -- Initial velocity
    self.player:give("sprite", {
        texture = nil,                              -- Placeholder (no texture yet)
        scale_x = 1,
        scale_y = 1
    })
    self.player_speed = 100                         -- Pixels per second
    print("[Test] Player entity created with position, velocity, and sprite components")

    -- Load initial chunks around player
    self.world:updateLoadedChunks(0, 0)
    print("[Test] Initial chunks loaded around player")
end

-- Register event listeners for testing
function test:registerEvents()
    -- Listen for tile placement
    self.ctx.events:on("tile.place", function(data)
        print("[Test] Tile placed at (" .. data.x .. "," .. data.y .. "): " .. data.tile)
    end)

    -- Listen for tile break
    self.ctx.events:on("tile.break", function(data)
        print("[Test] Tile broken at (" .. data.x .. "," .. data.y .. "): " .. data.tile)
    end)

    -- Listen for chunk load
    self.ctx.events:on("chunk.load", function(data)
        print("[Test] Chunk loaded at (" .. data.cx .. "," .. data.cy .. ")")
    end)

    -- Listen for chunk unload
    self.ctx.events:on("chunk.unload", function(data)
        print("[Test] Chunk unloaded at (" .. data.cx .. "," .. data.cy .. ")")
    end)

    -- Listen for input events (keyboard for movement)
    self.ctx.events:on("input.keypressed", function(key, scancode, isrepeat)
        if not isrepeat then
            if key == "w" or key == "up" then
                self.player.velocity.vy = -self.player_speed
            elseif key == "s" or key == "down" then
                self.player.velocity.vy = self.player_speed
            elseif key == "a" or key == "left" then
                self.player.velocity.vx = -self.player_speed
            elseif key == "d" or key == "right" then
                self.player.velocity.vx = self.player_speed
            end
        end
    end)

    self.ctx.events:on("input.keyreleased", function(key, scancode)
        if key == "w" or key == "up" or key == "s" or key == "down" then
            self.player.velocity.vy = 0
        elseif key == "a" or key == "left" or key == "d" or key == "right" then
            self.player.velocity.vx = 0
        end
    end)

    -- Listen for mouse input (place/break tiles)
    self.ctx.events:on("input.mousepressed", function(x, y, button)
        -- Convert screen coordinates to world coordinates
        local tile_size = 32
        local wx = math.floor((x - self.camera.width/2 + self.camera.x) / tile_size)
        local wy = math.floor((y - self.camera.height/2 + self.camera.y) / tile_size)

        local ok, err = pcall(function()
            if button == 1 then -- Left click: place tile
                local tiles = {"grass", "dirt", "stone"}
                self.current_tile = self.current_tile or 1
                local tile_id = tiles[self.current_tile]
                self.kernel.tileSystem:placeTile(self.world, wx, wy, tile_id)
                self.current_tile = (self.current_tile % #tiles) + 1
            elseif button == 2 then -- Right click: break tile
                self.kernel.tileSystem:breakTile(self.world, wx, wy)
            end
        end)
        if not ok then
            print("[Test] Error handling mouse input: " .. tostring(err))
        end
    end)
end

-- Register hooks for rendering
function test:registerHooks()
    -- Pre-draw hook: update camera, chunks, and render chunks
    self.ctx.hooks:register("predraw", function()
        -- Update camera to follow player
        if self.player and self.player.position then
            self.camera.x = self.player.position.x
            self.camera.y = self.player.position.y
            -- Update loaded chunks based on player position
            self.world:updateLoadedChunks(self.player.position.x, self.player.position.y)
            -- Render chunks
            local ok, err = pcall(function()
                self.ctx.kernel.core.systems.chunkRender:draw(self.world, self.camera)
            end)
            if not ok then
                print("[Test] Error rendering chunks: " .. tostring(err))
            end
        end
    end)

    -- Post-draw hook: draw player and debug info
    self.ctx.hooks:register("postdraw", function()
        -- Draw player (placeholder rectangle)
        if self.player and self.player.position then
            love.graphics.setColor(1, 0, 0) -- Red for player
            love.graphics.rectangle("fill",
                self.player.position.x - self.camera.x + self.camera.width/2 - 16,
                self.player.position.y - self.camera.y + self.camera.height/2 - 16,
                32, 32)
            love.graphics.setColor(1, 1, 1) -- Reset color
        end

        -- Draw debug info
        love.graphics.print("Player: (" .. (self.player and self.player.position and self.player.position.x or 0) .. "," .. 
            (self.player and self.player.position and self.player.position.y or 0) .. ")", 10, 10)
        love.graphics.print("Chunks loaded: " .. table_size(self.world.loaded_chunks), 10, 30)
    end)
end

-- Initialize test actor for message passing
function test:initActor()
    -- Create a test actor
    local actor = self.ctx.actor:spawn("test_actor", "debug", {})
    actor.handlers["ping"] = function(actor, data)
        print("[Test] Actor received ping: " .. tostring(data.message))
        self.ctx.actor:send("test_actor", "pong", {message = "Pong from test actor"})
    end
    actor.handlers["pong"] = function(actor, data)
        print("[Test] Actor received pong: " .. tostring(data.message))
    end

    -- Send a test message
    self.ctx.actor:send("test_actor", "ping", {message = "Hello from test mod"})
end

-- Helper function to count table entries (for debug info)
function table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

return test