local fennel = require("fennel")
fennel.path = fennel.path .. ";src/?.fnl"

local love = require("love")

-- ==============================
-- 全局资源表
-- ==============================
_G.Assets = {images={}, sounds={}, mod_times={}}

-- ==============================
-- 辅助函数：递归扫描目录
-- ==============================
local function scan_dir(dir, ext, filelist)
    filelist = filelist or {}
    for _, file in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local path = dir.."/"..file
        local info = love.filesystem.getInfo(path)
        if info then
            if info.type == "file" and file:match("%."..ext.."$") then
                table.insert(filelist, path)
            elseif info.type == "directory" then
                scan_dir(path, ext, filelist)
            end
        end
    end
    return filelist
end

-- ==============================
-- 文件修改时间
-- ==============================
local function get_modtime(path)
    local info = love.filesystem.getInfo(path)
    return info and info.modtime or 0
end

-- ==============================
-- 资源加载函数
-- ==============================
local function load_assets()
    -- 图片
    local pngs = scan_dir("assets","png")
    for _, path in ipairs(pngs) do
        local t = get_modtime(path)
        if _G.Assets.mod_times[path] ~= t then
            _G.Assets.images[path] = love.graphics.newImage(path)
            _G.Assets.mod_times[path] = t
            print("Loaded image:", path)
        end
    end
    -- 音效
    local wvs = scan_dir("assets","wav")
    for _, path in ipairs(wvs) do
        local t = get_modtime(path)
        if _G.Assets.mod_times[path] ~= t then
            _G.Assets.sounds[path] = love.audio.newSource(path,"static")
            _G.Assets.mod_times[path] = t
            print("Loaded sound:", path)
        end
    end
end

load_assets()

-- ==============================
-- 模块加载和热重载
-- ==============================
local fnl_files = scan_dir("src", "fnl")
local lua_files = scan_dir("src", "lua")

local fnl_mod_times = {}
local lua_mod_times = {}

local modules = {}

local function load_fnl(f)
    local mod = fennel.dofile(f)
    table.insert(modules, mod)
end

local function load_lua(f)
    local modname = f:gsub("src/", "src."):gsub("%.lua$", "")
    package.loaded[modname] = nil
    local mod = require(modname)
    table.insert(modules, mod)
end

-- 初始化模块
for _, f in ipairs(fnl_files) do
    fnl_mod_times[f] = get_modtime(f)
    load_fnl(f)
end
for _, f in ipairs(lua_files) do
    lua_mod_times[f] = get_modtime(f)
    load_lua(f)
end

-- ==============================
-- Love2D 回调
-- ==============================
function love.load()
    for _, m in ipairs(modules) do
        if m.init then m.init() end
    end
end

function love.update(dt)
    -- 模块热重载
    for i, f in ipairs(fnl_files) do
        local t = get_modtime(f)
        if t ~= fnl_mod_times[f] then
            fnl_mod_times[f] = t
            modules[i] = fennel.dofile(f)
            if modules[i].init then modules[i].init() end
            print("Reloaded Fennel:", f)
        end
    end
    for i, f in ipairs(lua_files) do
        local t = get_modtime(f)
        if t ~= lua_mod_times[f] then
            lua_mod_times[f] = t
            local modname = f:gsub("src/", "src."):gsub("%.lua$", "")
            package.loaded[modname] = nil
            modules[#modules+1] = require(modname)
            if modules[#modules].init then modules[#modules].init() end
            print("Reloaded Lua:", f)
        end
    end

    -- 资源热重载
    load_assets()

    -- 调用 update
    for _, m in ipairs(modules) do
        if m.update then m.update(dt) end
    end
end

function love.draw()
    -- 清屏，避免残影
    love.graphics.clear(0.1,0.1,0.1) -- 可改背景色

    for _, m in ipairs(modules) do
        if m.draw then m.draw() end
    end
end
