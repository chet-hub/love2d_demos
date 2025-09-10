-- main.lua - Product-Grade 2D Minecraft-like Framework
-- Features: Concord ECS, Chunk System, Mod Loading, Camera, Persistence
-- Scans mods/*/init.lua and mods/*/init.fnl, compiles Fennel to Lua if needed
-- Run: love .

-- Optional Fennel support
local fennel
local has_fennel, fennel_module = pcall(require, "lib.fennel")
if has_fennel then
    fennel = fennel_module
    debug.traceback = fennel.traceback
end

local love = require("love")
local concord = require("lib.concord")

-- Initialize Concord
concord.init({ useEvents = true })
local world = concord.world()

-- Configuration
local config = {
    tile_size = 32,
    chunk_size = 16,
    view_distance = 5,
    save_dir = "saves/",
    debug_mode = true,
    hot_reload_key = "f5"
}

local function load_config()
    local config_file = "config.json"
    local info = love.filesystem.getInfo(config_file)
    if info then
        local ok, data = pcall(loadstring("return " .. love.filesystem.read(config_file)))
        if ok and data then
            config = data or config
        end
    end
end

-- Chunk System
local chunks = {}
local loaded_chunks = {}

local function chunk_key(cx, cy)
    return cx .. "," .. cy
end

local function load_chunk(cx, cy)
    local key = chunk_key(cx, cy)
    local save_file = config.save_dir .. key .. ".lua"
    if not chunks[key] then
        local chunk = {
            tiles = {},
            entities = {},
            dirty = false
        }
        for lx = 1, config.chunk_size do
            chunk.tiles[lx] = {}
            for ly = 1, config.chunk_size do
                chunk.tiles[lx][ly] = nil
            end
        end
        local info = love.filesystem.getInfo(save_file)
        if info then
            local ok, data = pcall(loadstring(love.filesystem.read(save_file)))
            if ok and data then
                chunk.tiles = data.tiles or chunk.tiles
            end
        end
        chunks[key] = chunk
        world:emit("generate-chunk", cx, cy, key)
    end
    loaded_chunks[key] = true
end

local function unload_chunk(cx, cy)
    local key = chunk_key(cx, cy)
    local chunk = chunks[key]
    if chunk and chunk.dirty then
        love.filesystem.write(config.save_dir .. key .. ".lua", "return " .. table_to_string({ tiles = chunk.tiles }))
    end
    loaded_chunks[key] = nil
    world:emit("unload-chunk", cx, cy, chunk)
end

local function get_tile(wx, wy)
    local cx = math.floor(wx / config.chunk_size)
    local cy = math.floor(wy / config.chunk_size)
    local lx = wx % config.chunk_size + 1
    local ly = wy % config.chunk_size + 1
    local chunk = chunks[chunk_key(cx, cy)]
    return chunk and chunk.tiles[lx][ly]
end

local function set_tile(wx, wy, val)
    local cx = math.floor(wx / config.chunk_size)
    local cy = math.floor(wy / config.chunk_size)
    local lx = wx % config.chunk_size + 1
    local ly = wy % config.chunk_size + 1
    local key = chunk_key(cx, cy)
    local chunk = chunks[key]
    if not chunk then
        load_chunk(cx, cy)
        chunk = chunks[key]
    end
    chunk.tiles[lx][ly] = val
    chunk.dirty = true
end

-- Utility: Serialize table to Lua string (for saves)
local function table_to_string(t)
    local str = "{"
    for k, v in pairs(t) do
        if type(k) == "string" then
            k = string.format("[%q]", k)
        end
        if type(v) == "table" then
            v = table_to_string(v)
        elseif type(v) == "string" then
            v = string.format("%q", v)
        elseif v == nil then
            v = "nil"
        end
        str = str .. k .. "=" .. tostring(v) .. ","
    end
    return str .. "}"
end

-- Mod API
local api = {
    config = config,
    world = world,
    load_chunk = load_chunk,
    unload_chunk = unload_chunk,
    get_tile = get_tile,
    set_tile = set_tile,
    emit = function(evt, ...)
        world:emit(evt, ...)
    end,
    register_block = function(type, props)
        world:emit("register-block", type, props)
    end,
    register_entity_type = function(type, prefab_fn)
        world:emit("register-entity-type", type, prefab_fn)
    end,
    register_item = function(type, props)
        world:emit("register-item", type, props)
    end,
    register_recipe = function(recipe)
        world:emit("register-recipe", recipe)
    end
}

-- Mod Loading with Fennel Compilation
local mods = {}  -- {mod-name: {init: fn, reloaded: bool, path: string}}

local function load_mod(mod_dir)
    local lua_path = "mods/" .. mod_dir .. "/init.lua"
    local fnl_path = "mods/" .. mod_dir .. "/init.fnl"
    local lua_info = love.filesystem.getInfo(lua_path)
    local fnl_info = love.filesystem.getInfo(fnl_path)
    local mod_path, mod_loader

    if lua_info then
        mod_path = "mods." .. mod_dir .. ".init"
        mod_loader = require
    elseif fnl_info and has_fennel then
        mod_path = fnl_path
        mod_loader = function(path)
            local code = love.filesystem.read(path)
            local lua_code = fennel.compileString(code, { filename = path })
            local chunk, err = loadstring(lua_code, path)
            if not chunk then
                if config.debug_mode then print("Fennel compile error for " .. path .. ": " .. err) end
                return nil
            end
            return chunk()
        end
    else
        if config.debug_mode then print("No init.lua or init.fnl found for mod " .. mod_dir) end
        return
    end

    local ok, mod_module = pcall(mod_loader, mod_path)
    if ok and mod_module and mod_module.init then
        local init_ok, err = pcall(mod_module.init, api)
        if init_ok then
            mods[mod_dir] = { init = mod_module.init, reloaded = false, path = mod_path }
        elseif config.debug_mode then
            print("Mod " .. mod_dir .. " init error: " .. err)
        end
    elseif config.debug_mode then
        print("Mod " .. mod_dir .. " load error: " .. (ok and "no init function" or mod_module))
    end
end

local function reload_mod(mod_name)
    local mod = mods[mod_name]
    if mod then
        package.loaded[mod.path] = nil
        local ok, new_module = pcall(require, mod.path)
        if ok and new_module and new_module.init then
            local reload_ok, err = pcall(new_module.init, api)
            if reload_ok then
                mod.init = new_module.init
                mod.reloaded = true
                world:emit("mod-reloaded", mod_name)
            elseif config.debug_mode then
                print("Reload error for " .. mod_name .. ": " .. err)
            end
        elseif config.debug_mode then
            print("Reload failed for " .. mod_name .. ": " .. (ok and "no init function" or new_module))
        end
    end
end

local function load_mods()
    local mod_dirs = love.filesystem.getDirectoryItems("mods")
    for _, dir in ipairs(mod_dirs) do
        load_mod(dir)
    end
    world:emit("mods-loaded")
end

-- Camera System
local camera = { x = 0, y = 0, scale = 1 }

local camera_system = concord.system({
    players = { "player", "position" },
    update = function(self, dt)
        if #self.players > 0 then
            local pos = self.players[1]:get("position").pos
            local w = love.graphics.getWidth()
            local h = love.graphics.getHeight()
            camera.x = pos.x - w / 2
            camera.y = pos.y - h / 2
        end
    end
})

-- Chunk Management System
local chunk_system = concord.system({
    players = { "player", "position" },
    update = function(self, dt)
        if #self.players > 0 then
            local pos = self.players[1]:get("position").pos
            local pcx = math.floor(pos.x / (config.chunk_size * config.tile_size))
            local pcy = math.floor(pos.y / (config.chunk_size * config.tile_size))
            for cx = pcx - config.view_distance, pcx + config.view_distance do
                for cy = pcy - config.view_distance, pcy + config.view_distance do
                    load_chunk(cx, cy)
                end
            end
            for key, _ in pairs(loaded_chunks) do
                local cx, cy = key:match("(-?%d+),(-?%d+)")
                cx, cy = tonumber(cx), tonumber(cy)
                if math.abs(cx - pcx) > config.view_distance * 1.5 or math.abs(cy - pcy) > config.view_distance * 1.5 then
                    unload_chunk(cx, cy)
                end
            end
        end
    end
})

-- Love2D Callbacks
function love.load(args)
    load_config()
    love.filesystem.createDirectory(config.save_dir)
    world:addSystem(camera_system)
    world:addSystem(chunk_system)
    load_mods()
end

function love.update(dt)
    world:update(dt)
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)
    love.graphics.scale(camera.scale)
    world:draw()
    love.graphics.pop()
end

function love.keypressed(key)
    world:emit("keypressed", key)
    if key == config.hot_reload_key then
        for mod_name, _ in pairs(mods) do
            reload_mod(mod_name)
        end
    end
end

function love.errhand(msg)
    print("Error: " .. msg)
    if config.debug_mode then
        love.system.openURL("https://love2d.org/wiki")
    end
end