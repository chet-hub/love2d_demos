-- lib/actor.lua - Actor对象封装
local EventBus = require "lib.event_bus"

local Actor = {}
Actor.__index = Actor

function Actor.new(x, y, tile_type)
    local self = setmetatable({}, Actor)
    self.x = x or 0
    self.y = y or 0
    self.tile_type = tile_type or "unknown"
    self.components = {}
    self.active = true
    self.created_time = love.timer.getTime()
    
    -- 生成唯一ID
    self.id = "actor_" .. tostring(self):match("0x%x+") .. "_" .. math.floor(love.timer.getTime() * 1000)
    
    return self
end

function Actor:addComponent(name, component)
    self.components[name] = component
    if component.onAttach then
        component:onAttach(self)
    end
    EventBus.emit("actor_component_added", {actor = self, name = name, component = component})
end

function Actor:removeComponent(name)
    local component = self.components[name]
    if component then
        if component.onDetach then
            component:onDetach(self)
        end
        self.components[name] = nil
        EventBus.emit("actor_component_removed", {actor = self, name = name, component = component})
    end
end

function Actor:getComponent(name)
    return self.components[name]
end

function Actor:hasComponent(name)
    return self.components[name] ~= nil
end

function Actor:update(dt)
    if not self.active then return end
    
    for name, component in pairs(self.components) do
        if component.update then
            component:update(self, dt)
        end
    end
    
    EventBus.emit("actor_update", {actor = self, dt = dt})
end

function Actor:render()
    if not self.active then return end
    
    for name, component in pairs(self.components) do
        if component.render then
            component:render(self)
        end
    end
    
    EventBus.emit("actor_render", {actor = self})
end

function Actor:destroy()
    self.active = false
    
    for name, component in pairs(self.components) do
        if component.onDestroy then
            component:onDestroy(self)
        end
    end
    
    EventBus.emit("actor_destroyed", {actor = self})
end

function Actor:setPosition(x, y)
    self.x = x
    self.y = y
    EventBus.emit("actor_moved", {actor = self, x = x, y = y})
end

function Actor:getPosition()
    return self.x, self.y
end

return Actor