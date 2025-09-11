-- lib/event_bus.lua - 全局事件总线
local Signal = require "vendor.hump.signal"

local EventBus = {}
local registry = Signal.new()
local event_queue = {}
local max_queue_size = MAX_EVENT_QUEUE_SIZE or 1000

function EventBus.on(event, callback)
    registry:register(event, callback)
end

function EventBus.off(event, callback)
    registry:remove(event, callback)
end

function EventBus.emit(event, ...)
    registry:emit(event, ...)
end

function EventBus.queue(event, ...)
    if #event_queue >= max_queue_size then
        table.remove(event_queue, 1)  -- 移除最老的事件
    end
    
    table.insert(event_queue, {event = event, args = {...}})
end

function EventBus.processQueue()
    for _, queued in ipairs(event_queue) do
        registry:emit(queued.event, unpack(queued.args))
    end
    event_queue = {}
end

function EventBus.clear()
    registry:clear()
    event_queue = {}
end

return EventBus