-- lib/ecs.lua - ECS系统封装
local Concord = require "vendor.concord"

local ECS = {}

function ECS.newWorld()
    return Concord.world()
end

function ECS.newEntity()
    return Concord.entity()
end

function ECS.newComponent(name, fields)
    return Concord.component(name, fields or {})
end

function ECS.newSystem(requirements)
    return Concord.system(requirements or {})
end

return ECS