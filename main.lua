-- 2D Minecraft 微内核
-- main.lua - 最小化核心，所有功能通过 Mod 实现

local kernel = {}

-- 全局配置
kernel.config = {
    version = "0.1.0",
    debug = true,
    tick_rate = 60,
    network = {
        port = 25565,
        max_players = 100
    }
}

-- 核心模块
kernel.modules = {}
kernel.mods = {}
kernel.systems = {}
kernel.events = {}
kernel.hooks = {}

-- Fennel 编译器加载
local fennel
local function loadFennel()
    local ok, fnl = pcall(require, "lib.fennel")
    if ok then
        fennel = fnl
        -- 配置 Fennel
        fennel.path = fennel.path .. ";mods/?.fnl;mods/?/init.fnl"
        table.insert(package.loaders or package.searchers, fennel.searcher)
        return true
    end
    return false
end

-- 智能加载器（优先 .fnl 文件）
local function smartRequire(path)
    -- 尝试加载 .fnl 文件
    if fennel then
        local fnl_path = path:gsub("%.", "/") .. ".fnl"
        if love.filesystem.getInfo(fnl_path) then
            local code = love.filesystem.read(fnl_path)
            local compiled = fennel.compileString(code)
            return assert(loadstring(compiled))()
        end
        
        -- 尝试 init.fnl
        fnl_path = path:gsub("%.", "/") .. "/init.fnl"
        if love.filesystem.getInfo(fnl_path) then
            local code = love.filesystem.read(fnl_path)
            local compiled = fennel.compileString(code)
            return assert(loadstring(compiled))()
        end
    end
    
    -- 回退到 Lua
    return require(path)
end

-- ECS 系统初始化
kernel.ecs = {
    world = nil,
    systems = {},
    components = {},
    assemblages = {}
}

function kernel.ecs:init()
    local concord = smartRequire("lib.concord")
    self.world = concord.world()
    
    -- 注册核心组件
    self.components.position = concord.component("position", function(c, x, y)
        c.x = x or 0
        c.y = y or 0
    end)
    
    self.components.velocity = concord.component("velocity", function(c, vx, vy)
        c.vx = vx or 0
        c.vy = vy or 0
    end)
    
    self.components.tile = concord.component("tile", function(c, id, metadata)
        c.id = id
        c.metadata = metadata or {}
    end)
    
    self.components.chunk = concord.component("chunk", function(c, cx, cy)
        c.cx = cx
        c.cy = cy
        c.tiles = {}
        c.dirty = true
    end)
    
    return self
end

-- Actor 消息系统
kernel.actor = {
    actors = {},
    messages = {},
    handlers = {}
}

function kernel.actor:spawn(id, actor_type, data)
    local actor = {
        id = id,
        type = actor_type,
        data = data or {},
        mailbox = {},
        handlers = {}
    }
    self.actors[id] = actor
    return actor
end

function kernel.actor:send(target_id, message, data)
    local actor = self.actors[target_id]
    if actor then
        table.insert(actor.mailbox, {
            type = message,
            data = data,
            timestamp = love.timer.getTime()
        })
    end
end

function kernel.actor:broadcast(message, data)
    for id, actor in pairs(self.actors) do
        self:send(id, message, data)
    end
end

function kernel.actor:process()
    for id, actor in pairs(self.actors) do
        while #actor.mailbox > 0 do
            local msg = table.remove(actor.mailbox, 1)
            local handler = actor.handlers[msg.type]
            if handler then
                handler(actor, msg.data)
            end
        end
    end
end

-- 节点树系统
kernel.node = {
    root = nil,
    nodes = {}
}

function kernel.node:create(name, parent)
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
    self.root = self:create("root")
    self:create("world", self.root)
    self:create("ui", self.root)
    self:create("network", self.root)
    return self
end

-- 事件系统
kernel.events = {
    listeners = {},
    queue = {}
}

function kernel.events:on(event, callback, priority)
    priority = priority or 0
    if not self.listeners[event] then
        self.listeners[event] = {}
    end
    table.insert(self.listeners[event], {
        callback = callback,
        priority = priority
    })
    -- 按优先级排序
    table.sort(self.listeners[event], function(a, b)
        return a.priority > b.priority
    end)
end

function kernel.events:emit(event, ...)
    local handlers = self.listeners[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            local result = handler.callback(...)
            if result == false then
                break -- 允许中断事件链
            end
        end
    end
end

function kernel.events:queue(event, data)
    table.insert(self.queue, {event = event, data = data})
end

function kernel.events:process()
    while #self.queue > 0 do
        local e = table.remove(self.queue, 1)
        self:emit(e.event, e.data)
    end
end

-- Hook 系统（用于 Mod 扩展）
function kernel.hooks:register(name, fn)
    if not self[name] then
        self[name] = {}
    end
    table.insert(self[name], fn)
end

function kernel.hooks:call(name, ...)
    if self[name] then
        local results = {}
        for _, fn in ipairs(self[name]) do
            local result = {fn(...)}
            if #result > 0 then
                table.insert(results, result)
            end
        end
        return results
    end
end

-- Mod 加载器
kernel.modloader = {}

function kernel.modloader:scan()
    local mods = {}
    local mod_dir = "mods"
    
    if love.filesystem.getInfo(mod_dir) then
        local items = love.filesystem.getDirectoryItems(mod_dir)
        for _, item in ipairs(items) do
            local mod_path = mod_dir .. "/" .. item
            if love.filesystem.getInfo(mod_path, "directory") then
                -- 优先检查 init.fnl，然后 init.lua
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
            mod:init(context)
            kernel.mods[mod_info.name] = mod
            print("[Mod] Loaded: " .. mod_info.name)
            return true
        else
            print("[Mod] Failed: " .. mod_info.name .. " - Invalid mod structure")
        end
    else
        print("[Mod] Failed to load: " .. mod_info.name .. " - " .. tostring(mod))
    end
    return false
end

function kernel.modloader:loadAll()
    local mods = self:scan()
    
    -- 按依赖顺序加载（这里简化为按字母顺序）
    table.sort(mods, function(a, b)
        -- core mod 总是第一个加载
        if a.name == "core" then return true end
        if b.name == "core" then return false end
        return a.name < b.name
    end)
    
    for _, mod_info in ipairs(mods) do
        self:load(mod_info)
    end
end

-- 网络系统（基础框架）
kernel.network = {
    mode = "none", -- "server", "client", "none"
    server = nil,
    client = nil,
    peers = {}
}

function kernel.network:init(mode, config)
    self.mode = mode
    if mode == "server" then
        -- 服务器初始化逻辑
        kernel.events:emit("network.server.start", config)
    elseif mode == "client" then
        -- 客户端初始化逻辑
        kernel.events:emit("network.client.start", config)
    end
end

-- Love2D 回调
function love.load(args)
    -- 加载 Fennel
    if loadFennel() then
        print("[Kernel] Fennel compiler loaded")
    else
        print("[Kernel] Fennel not found, using Lua only")
    end
    
    -- 初始化核心系统
    kernel.ecs:init()
    kernel.node:init()
    
    -- 加载所有 Mods
    kernel.modloader:loadAll()
    
    -- 触发初始化事件
    kernel.events:emit("kernel.init", kernel)
    kernel.events:emit("game.load", args)
end

function love.update(dt)
    -- 处理消息队列
    kernel.actor:process()
    kernel.events:process()
    
    -- 调用 Mod 钩子
    kernel.hooks:call("update", dt)
    
    -- 更新 ECS
    if kernel.ecs.world then
        kernel.ecs.world:emit("update", dt)
    end
    
    -- 触发更新事件
    kernel.events:emit("game.update", dt)
end

function love.draw()
    -- 调用渲染钩子
    kernel.hooks:call("predraw")
    
    -- ECS 渲染
    if kernel.ecs.world then
        kernel.ecs.world:emit("draw")
    end
    
    -- 触发渲染事件
    kernel.events:emit("game.draw")
    
    -- UI 渲染（最后）
    kernel.hooks:call("postdraw")
end

function love.keypressed(key, scancode, isrepeat)
    kernel.events:emit("input.keypressed", key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    kernel.events:emit("input.keyreleased", key, scancode)
end

function love.mousepressed(x, y, button)
    kernel.events:emit("input.mousepressed", x, y, button)
end

function love.mousereleased(x, y, button)
    kernel.events:emit("input.mousereleased", x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    kernel.events:emit("input.mousemoved", x, y, dx, dy)
end

function love.wheelmoved(x, y)
    kernel.events:emit("input.wheelmoved", x, y)
end

function love.quit()
    kernel.events:emit("game.quit")
    kernel.hooks:call("quit")
end

-- 导出内核 API
_G.kernel = kernel
return kernel