-- lib/script_component.lua - 脚本组件系统
local ScriptComponent = {}
ScriptComponent.__index = ScriptComponent

function ScriptComponent.new(script_path_or_code, is_code)
    local self = setmetatable({}, ScriptComponent)
    self.script_path = not is_code and script_path_or_code or nil
    self.script_code = is_code and script_path_or_code or nil
    self.script_env = {}
    self.loaded = false
    self.error_message = nil
    
    self:reload()
    return self
end

function ScriptComponent:reload()
    local code = self.script_code
    
    if self.script_path then
        local file_info = love.filesystem.getInfo(self.script_path)
        if not file_info then
            self.error_message = "Script file not found: " .. self.script_path
            self.loaded = false
            return false
        end
        
        local content = love.filesystem.read(self.script_path)
        if not content then
            self.error_message = "Failed to read script file: " .. self.script_path
            self.loaded = false
            return false
        end
        
        code = content
    end
    
    if not code then
        self.error_message = "No script code provided"
        self.loaded = false
        return false
    end
    
    -- 创建沙盒环境
    local env = {
        -- 基本Lua函数
        print = print,
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        type = type,
        tostring = tostring,
        tonumber = tonumber,
        math = math,
        string = string,
        table = table,
        
        -- Love2D绘图函数
        love = {
            graphics = love.graphics,
            timer = love.timer
        },
        
        -- 框架接口
        EventBus = require "lib.event_bus",
        GAME = _G.GAME
    }
    
    -- 设置元表以访问全局环境
    setmetatable(env, {__index = _G})
    
    local chunk, load_error = load(code, self.script_path or "script_component", "t", env)
    if not chunk then
        self.error_message = "Script compile error: " .. load_error
        self.loaded = false
        return false
    end
    
    local success, result = pcall(chunk)
    if not success then
        self.error_message = "Script execution error: " .. result
        self.loaded = false
        return false
    end
    
    -- 如果脚本返回一个表，将其合并到环境中
    if type(result) == "table" then
        for k, v in pairs(result) do
            env[k] = v
        end
    end
    
    self.script_env = env
    self.loaded = true
    self.error_message = nil
    return true
end

function ScriptComponent:call(func_name, ...)
    if not self.loaded then
        return nil, self.error_message
    end
    
    local func = self.script_env[func_name]
    if not func or type(func) ~= "function" then
        return nil, "Function not found: " .. func_name
    end
    
    local success, result = pcall(func, ...)
    if not success then
        return nil, "Script function error: " .. result
    end
    
    return result
end

function ScriptComponent:onAttach(actor)
    self:call("onAttach", actor)
end

function ScriptComponent:onDetach(actor)
    self:call("onDetach", actor)
end

function ScriptComponent:update(actor, dt)
    self:call("update", actor, dt)
end

function ScriptComponent:render(actor)
    self:call("render", actor)
end

function ScriptComponent:onDestroy(actor)
    self:call("onDestroy", actor)
end

return ScriptComponent