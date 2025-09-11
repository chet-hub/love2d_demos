-- Microkernel main file, responsible for initializing core systems, loading mods, and handling Love2D event loop
local kernel = {}

-- Global configuration
kernel.config = {
    version = "0.1.0",          -- Kernel version
    debug = true,              -- Debug mode
    tick_rate = 60,            -- Ticks per second
    network = {
        port = 25565,          -- Default network port
        max_players = 100      -- Maximum players
    }
}

-- Kernel modules and mod storage
kernel.modules = {}            -- External libraries (e.g., Concord)
kernel.mods = {}               -- Loaded mods
kernel.systems = {}            -- Systems (unused, reserved for extension)
kernel.events = {}             -- Event system
kernel.hooks = {}              -- Hook system

-- Fennel compiler loading (supports .fnl files)
local fennel
local function loadFennel()
    -- Attempt to load Fennel compiler
    local ok, fnl = pcall(require, "lib.fennel")
    if ok then
        fennel = fnl
        -- Add mods directory to Fennel search path
        fennel.path = fennel.path .. ";mods/?.fnl;mods/?/init.fnl"
        table.insert(package.loaders or package.searchers, fennel.searcher)
        print("[Kernel] Fennel compiler loaded successfully")
        return true
    else
        print("[Kernel] Warning: Fennel not found, using Lua only: " .. tostring(fnl))
        return false
    end
end

-- Smart require: prioritizes .fnl files, falls back to .lua
local function smartRequire(path)
    print("[Kernel] Attempting to load module: " .. path)
    if fennel then
        -- Try loading .fnl file
        local fnl_path = path:gsub("%.", "/") .. ".fnl"
        if love.filesystem.getInfo(fnl_path) then
            print("[Kernel] Found Fennel file: " .. fnl_path)
            local code, err = love.filesystem.read(fnl_path)
            if not code then
                print("[Kernel] Failed to read Fennel file: " .. fnl_path .. " - " .. tostring(err))
                return require(path)
            end
            local ok, compiled = pcall(fennel.compileString, code)
            if ok then
                local fn, load_err = loadstring(compiled)
                if fn then
                    local result = fn()
                    print("[Kernel] Successfully loaded Fennel module: " .. path)
                    return result
                else
                    print("[Kernel] Failed to load compiled Fennel code: " .. tostring(load_err))
                    return require(path)
                end
            else
                print("[Kernel] Fennel compilation failed: " .. tostring(compiled))
                return require(path)
            end
        end
        -- Try loading init.fnl file
        fnl_path = path:gsub("%.", "/") .. "/init.fnl"
        if love.filesystem.getInfo(fnl_path) then
            print("[Kernel] Found Fennel file: " .. fnl_path)
            local code, err = love.filesystem.read(fnl_path)
            if not code then
                print("[Kernel] Failed to read Fennel file: " .. fnl_path .. " - " .. tostring(err))
                return require(path)
            end
            local ok, compiled = pcall(fennel.compileString, code)
            if ok then
                local fn, load_err = loadstring(compiled)
                if fn then
                    local result = fn()
                    print("[Kernel] Successfully loaded Fennel module: " .. path)
                    return result
                else
                    print("[Kernel] Failed to load compiled Fennel code: " .. tostring(load_err))
                    return require(path)
                end
            else
                print("[Kernel] Fennel compilation failed: " .. tostring(compiled))
                return require(path)
            end
        end
    end
    -- Fall back to Lua require
    print("[Kernel] Falling back to Lua require for: " .. path)
    local result = require(path)
    print("[Kernel] Lua module loaded: " .. path .. " - Type: " .. type(result))
    return result
end

-- ECS system: manages entities, components, and systems
kernel.ecs = {
    world = nil,               -- Concord ECS world
    systems = {},              -- ECS systems
    components = {},           -- ECS components
    assemblages = {}           -- ECS assemblages (unused)
}

function kernel.ecs:init()
    -- Initialize Concord ECS
    print("[Kernel] Initializing ECS")
    local ok, concord = pcall(smartRequire, "lib.concord")
    if not ok then
        error("[Kernel] Critical error: Failed to load Concord ECS: " .. tostring(concord))
    end
    if type(concord) ~= "table" then
        error("[Kernel] Critical error: Concord ECS is not a table, got: " .. type(concord))
    end
    self.world = concord.world()
    kernel.modules.concord = concord -- Store Concord module for core mod
    print("[Kernel] ECS world initialized")
    
    -- Register position component
    self.components.position = concord.component("position", function(c, x, y)
        c.x = x or 0
        c.y = y or 0
    end)
    
    -- Register velocity component
    self.components.velocity = concord.component("velocity", function(c, vx, vy)
        c.vx = vx or 0
        c.vy = vy or 0
    end)
    
    return self
end

-- Actor messaging system: supports asynchronous message passing
kernel.actor = {
    actors = {}                -- Actor instances
}

function kernel.actor:spawn(id, actor_type, data)
    -- Create a new actor
    local actor = {
        id = id,
        type = actor_type,
        data = data or {},
        mailbox = {},          -- Message queue
        handlers = {}          -- Message handlers
    }
    self.actors[id] = actor
    return actor
end

function kernel.actor:send(target_id, message, data)
    -- Send a message to a specific actor
    local actor = self.actors[target_id]
    if actor then
        if #actor.mailbox > 1000 then
            print("[Actor] Warning: Mailbox for actor " .. target_id .. " is full, clearing old messages")
            actor.mailbox = {}
        end
        table.insert(actor.mailbox, {
            type = message,
            data = data,
            timestamp = love.timer.getTime()
        })
    end
end

function kernel.actor:broadcast(message, data)
    -- Broadcast message to all actors
    for id, actor in pairs(self.actors) do
        self:send(id, message, data)
    end
end

function kernel.actor:process()
    -- Process messages for all actors
    for id, actor in pairs(self.actors) do
        while #actor.mailbox > 0 do
            local msg = table.remove(actor.mailbox, 1)
            local handler = actor.handlers[msg.type]
            if handler then
                local ok, err = pcall(handler, actor, msg.data)
                if not ok then
                    print("[Actor] Error processing message for actor " .. id .. ": " .. tostring(err))
                end
            end
        end
    end
end

-- Node tree system: manages scene graph (world, UI, etc.)
kernel.node = {
    root = nil,                -- Root node
    nodes = {}                 -- All nodes
}

function kernel.node:create(name, parent)
    -- Create a new node
    local node = {
        name = name,
        parent = parent,
        children = {},
        transform = {x = 0, y = 0, rotation = 0, scale = 1},
        components = {},
        active = true
    }
    
    if parent then
        table.insert(parent.children, node)
    end
    
    self.nodes[name] = node
    return node
end

function kernel.node:init()
    -- Initialize node tree, create root and default child nodes
    self.root = self:create("root")
    self:create("world", self.root)
    self:create("ui", self.root)
    self:create("network", self.root)
    print("[Kernel] Node system initialized")
    return self
end

function kernel.node:update(dt)
    -- Update node tree
    local function updateNode(node, dt)
        if not node.active then return end
        for _, child in ipairs(node.children) do
            updateNode(child, dt)
        end
    end
    updateNode(self.root, dt)
end

function kernel.node:draw()
    -- Render node tree
    local function drawNode(node)
        if not node.active then return end
        love.graphics.push()
        love.graphics.translate(node.transform.x, node.transform.y)
        love.graphics.rotate(node.transform.rotation)
        love.graphics.scale(node.transform.scale)
        for _, child in ipairs(node.children) do
            drawNode(child)
        end
        love.graphics.pop()
    end
    drawNode(self.root)
end

-- Event system: supports event listeners and queue processing
kernel.events = {
    listeners = {},            -- Event listeners
    queue = {}                 -- Event queue
}

function kernel.events:on(event, callback, priority)
    -- Register an event listener
    priority = priority or 0
    if not self.listeners[event] then
        self.listeners[event] = {}
    end
    table.insert(self.listeners[event], {
        callback = callback,
        priority = priority
    })
    table.sort(self.listeners[event], function(a, b)
        return a.priority > b.priority
    end)
end

function kernel.events:emit(event, ...)
    -- Emit an event, calling all listeners
    local handlers = self.listeners[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            local ok, result = pcall(handler.callback, ...)
            if not ok then
                print("[Events] Error in handler for event " .. event .. ": " .. tostring(result))
            elseif result == false then
                break
            end
        end
    end
end

function kernel.events:enqueue(event, data)
    -- Enqueue an event
    if type(self.queue) ~= "table" then
        print("[Events] Error: Event queue is not a table, resetting to empty table")
        self.queue = {}
    end
    if #self.queue > 1000 then
        print("[Events] Warning: Event queue full, clearing old events")
        self.queue = {}
    end
    table.insert(self.queue, {event = event, data = data})
end

function kernel.events:process()
    -- Process event queue
    if type(self.queue) ~= "table" then
        print("[Events] Error: Event queue is not a table, resetting to empty table")
        self.queue = {}
    end
    while #self.queue > 0 do
        local e = table.remove(self.queue, 1)
        self:emit(e.event, e.data)
    end
end

-- Hook system: supports extension points (e.g., update, draw)
function kernel.hooks:register(name, fn)
    -- Register a hook function
    if not self[name] then
        self[name] = {}
    end
    table.insert(self[name], fn)
end

function kernel.hooks:call(name, ...)
    -- Call all functions for a specific hook
    if self[name] then
        for _, fn in ipairs(self[name]) do
            local ok, err = pcall(fn, ...)
            if not ok then
                print("[Hooks] Error in hook " .. name .. ": " .. tostring(err))
            end
        end
    end
end

-- Mod loader
kernel.modloader = {}

function kernel.modloader:scan()
    -- Scan mods/ directory for available mods
    local mods = {}
    local mod_dir = "mods"
    
    if love.filesystem.getInfo(mod_dir) then
        local items = love.filesystem.getDirectoryItems(mod_dir)
        for _, item in ipairs(items) do
            local mod_path = mod_dir .. "/" .. item
            if love.filesystem.getInfo(mod_path, "directory") then
                local init_file = mod_path .. "/init"
                if love.filesystem.getInfo(init_file .. ".fnl") or 
                   love.filesystem.getInfo(init_file .. ".lua") then
                    table.insert(mods, {
                        name = item,
                        path = "mods." .. item .. ".init"
                    })
                end
            end
        end
    end
    
    return mods
end

function kernel.modloader:load(mod_info)
    -- Load a single mod
    local success, mod = pcall(smartRequire, mod_info.path)
    if success then
        if type(mod) == "table" and mod.init then
            local context = {
                kernel = kernel,
                events = kernel.events,
                ecs = kernel.ecs,
                actor = kernel.actor,
                node = kernel.node,
                hooks = kernel.hooks
            }
            local init_success, init_err = pcall(mod.init, mod, context)
            if init_success then
                kernel.mods[mod_info.name] = mod
                print("[Mod] Loaded successfully: " .. mod_info.name)
                return true
            else
                print("[Mod] Initialization failed: " .. mod_info.name .. " - " .. tostring(init_err))
            end
        else
            print("[Mod] Failed: " .. mod_info.name .. " - Invalid mod structure")
        end
    else
        print("[Mod] Failed to load: " .. mod_info.name .. " - " .. tostring(mod))
    end
    return false
end

function kernel.modloader:loadAll()
    -- Load all mods, prioritizing core
    local mods = self:scan()
    table.sort(mods, function(a, b)
        if a.name == "core" then return true end
        if b.name == "core" then return false end
        return a.name < b.name
    end)
    
    for _, mod_info in ipairs(mods) do
        self:load(mod_info)
    end
    
    if not kernel.mods.core then
        error("[Modloader] Critical error: core mod failed to load")
    end
    print("[Modloader] All mods loaded, core mod present")
end

-- Network system (placeholder interface)
kernel.network = {
    mode = "none",             -- Network mode (none/server/client)
    server = nil,              -- Server instance
    client = nil,              -- Client instance
    peers = {}                 -- Connected peers
}

function kernel.network:init(mode, config)
    -- Initialize network system (placeholder implementation)
    self.mode = mode
    print("[Network] Network initialized (placeholder): " .. mode .. " mode")
    -- TODO: Implement enet or other network library initialization
end

-- Love2D callbacks
function love.load(args)
    -- Initialize kernel
    local ok, err = pcall(function()
        if loadFennel() then
            print("[Kernel] Fennel compiler loaded successfully")
        else
            print("[Kernel] Fennel not found, using Lua only")
        end
        
        kernel.ecs:init()
        kernel.node:init()
        kernel.network:init("none", kernel.config.network)
        kernel.modloader:loadAll()
        
        kernel.events:emit("kernel.init", kernel)
        kernel.events:emit("game.load", args)
    end)
    if not ok then
        error("[Kernel] Initialization failed: " .. tostring(err))
    end
end

function love.update(dt)
    -- Update logic
    -- TODO: Handle network events (e.g., enet service)
    kernel.actor:process()
    kernel.events:process()
    kernel.hooks:call("update", dt)
    if kernel.ecs.world then
        kernel.ecs.world:emit("update", dt)
    end
    kernel.node:update(dt)
    kernel.events:emit("game.update", dt)
end

function love.draw()
    -- Render logic
    kernel.hooks:call("predraw")
    if kernel.ecs.world then
        kernel.ecs.world:emit("draw")
    end
    kernel.node:draw()
    kernel.events:emit("game.draw")
    kernel.hooks:call("postdraw")
end

function love.keypressed(key, scancode, isrepeat)
    -- Keyboard press event
    kernel.events:emit("input.keypressed", key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    -- Keyboard release event
    kernel.events:emit("input.keyreleased", key, scancode)
end

function love.mousepressed(x, y, button)
    -- Mouse press event
    kernel.events:emit("input.mousepressed", x, y, button)
end

function love.mousereleased(x, y, button)
    -- Mouse release event
    kernel.events:emit("input.mousereleased", x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    -- Mouse move event
    kernel.events:emit("input.mousemoved", x, y, dx, dy)
end

function love.wheelmoved(x, y)
    -- Mouse wheel event
    kernel.events:emit("input.wheelmoved", x, y)
end

function love.quit()
    -- Game quit event
    kernel.events:emit("game.quit")
    kernel.hooks:call("quit")
end

_G.kernel = kernel
return kernel