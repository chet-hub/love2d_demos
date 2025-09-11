-- lib/mod_manager.lua - Mod管理系统
local EventBus = require "lib.event_bus"
local ScriptComponent = require "lib.script_component"

local ModManager = {}
ModManager.__index = ModManager

function ModManager.new(world, tile_system, chunk_manager)
    local self = setmetatable({}, ModManager)
    self.world = world
    self.tile_system = tile_system
    self.chunk_manager = chunk_manager
    self.loaded_mods = {}
    self.mod_order = {}
    
    return self
end

function ModManager:loadMods()
    if not love.filesystem.getInfo(MODS_DIR) then
        love.filesystem.createDirectory(MODS_DIR)
        print("Created mods directory: " .. MODS_DIR)
        return
    end
    
    local mod_dirs = love.filesystem.getDirectoryItems(MODS_DIR)
    
    for _, dir_name in ipairs(mod_dirs) do
        local mod_path = MODS_DIR .. "/" .. dir_name
        local mod_info = love.filesystem.getInfo(mod_path)
        
        if mod_info and mod_info.type == "directory" then
            self:loadMod(dir_name, mod_path)
        end
    end
    
    -- 排序mods按依赖顺序
    self:sortModsByDependencies()
    
    -- 初始化mods
    for _, mod_name in ipairs(self.mod_order) do
        local mod = self.loaded_mods[mod_name]
        if mod and mod.init then
            local success, err = pcall(mod.init, mod.context)
            if not success then
                print("Error initializing mod " .. mod_name .. ": " .. err)
            end
        end
    end
    
    print("Loaded " .. #self.mod_order .. " mods")
end

function ModManager:loadMod(mod_name, mod_path)
    local manifest_path = mod_path .. "/mod.lua"
    
    if not love.filesystem.getInfo(manifest_path) then
        print("Mod manifest not found: " .. manifest_path)
        return false
    end
    
    local mod_script = ScriptComponent.new(manifest_path)
    if not mod_script.loaded then
        print("Failed to load mod script: " .. mod_script.error_message)
        return false
    end
    
    -- 创建mod上下文
    local mod_context = {
        name = mod_name,
        path = mod_path,
        world = self.world,
        tile_system = self.tile_system,
        chunk_manager = self.chunk_manager,
        event_bus = EventBus,
        
        -- Mod API
        registerTileType = function(name, def) return self.tile_system:registerTileType(name, def) end,
        registerChunkGenerator = function(name, func, priority) 
            return self.chunk_manager:registerGenerator(name, func, priority) 
        end,
        loadTexture = function(path) 
            local full_path = mod_path .. "/" .. path
            if love.filesystem.getInfo(full_path) then
                return love.graphics.newImage(full_path)
            else
                print("Texture not found: " .. full_path)
                return nil
            end
        end,
        loadScript = function(path)
            local full_path = mod_path .. "/" .. path
            return ScriptComponent.new(full_path)
        end
    }
    
    -- 执行mod初始化
    local mod_def = mod_script:call("init", mod_context)
    if not mod_def then
        print("Mod did not return definition: " .. mod_name)
        return false
    end
    
    -- 存储mod信息
    self.loaded_mods[mod_name] = {
        name = mod_name,
        path = mod_path,
        script = mod_script,
        context = mod_context,
        definition = mod_def,
        dependencies = mod_def.dependencies or {},
        version = mod_def.version or "1.0.0",
        init = mod_def.init,
        update = mod_def.update,
        cleanup = mod_def.cleanup
    }
    
    EventBus.emit("mod_loaded", {name = mod_name, mod = self.loaded_mods[mod_name]})
    print("Loaded mod: " .. mod_name .. " v" .. (mod_def.version or "1.0.0"))
    
    return true
end

function ModManager:unloadMod(mod_name)
    local mod = self.loaded_mods[mod_name]
    if not mod then
        return false
    end
    
    -- 调用清理函数
    if mod.cleanup then
        local success, err = pcall(mod.cleanup, mod.context)
        if not success then
            print("Error during mod cleanup " .. mod_name .. ": " .. err)
        end
    end
    
    -- 从加载列表移除
    self.loaded_mods[mod_name] = nil
    
    -- 从顺序列表移除
    for i, name in ipairs(self.mod_order) do
        if name == mod_name then
            table.remove(self.mod_order, i)
            break
        end
    end
    
    EventBus.emit("mod_unloaded", {name = mod_name})
    print("Unloaded mod: " .. mod_name)
    
    return true
end

function ModManager:reloadMods()
    -- 清理现有mods
    for mod_name in pairs(self.loaded_mods) do
        self:unloadMod(mod_name)
    end
    
    -- 重新加载
    self:loadMods()
    
    EventBus.emit("mods_reloaded")
end

function ModManager:sortModsByDependencies()
    local sorted = {}
    local visited = {}
    local visiting = {}
    
    local function visit(mod_name)
        if visiting[mod_name] then
            error("Circular dependency detected involving: " .. mod_name)
        end
        
        if visited[mod_name] then
            return
        end
        
        visiting[mod_name] = true
        
        local mod = self.loaded_mods[mod_name]
        if mod then
            for _, dep_name in ipairs(mod.dependencies) do
                if self.loaded_mods[dep_name] then
                    visit(dep_name)
                else
                    print("Warning: Dependency not found: " .. dep_name .. " (required by " .. mod_name .. ")")
                end
            end
        end
        
        visiting[mod_name] = nil
        visited[mod_name] = true
        table.insert(sorted, mod_name)
    end
    
    for mod_name in pairs(self.loaded_mods) do
        visit(mod_name)
    end
    
    self.mod_order = sorted
end

function ModManager:updateMods(dt)
    for _, mod_name in ipairs(self.mod_order) do
        local mod = self.loaded_mods[mod_name]
        if mod and mod.update then
            local success, err = pcall(mod.update, mod.context, dt)
            if not success then
                print("Error updating mod " .. mod_name .. ": " .. err)
            end
        end
    end
end

function ModManager:getLoadedMods()
    return self.loaded_mods
end

function ModManager:isModLoaded(mod_name)
    return self.loaded_mods[mod_name] ~= nil
end

return ModManager