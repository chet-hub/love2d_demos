

-- libs/concord.lua - ECS库接口（需要实际的Concord库）
-- 这里提供一个简化的接口示例，实际使用时应该包含完整的Concord库

local Concord = {}

-- 简化的组件系统
local Component = {}
Component.__index = Component

function Component.new(name, fields)
    local comp = setmetatable({
        __name = name,
        __fields = fields or {}
    }, Component)
    return comp
end

-- 简化的实体系统
local Entity = {}
Entity.__index = Entity

function Entity.new()
    local entity = setmetatable({
        __components = {},
        __id = math.random(1000000)
    }, Entity)
    return entity
end

function Entity:give(component, ...)
    local name = component.__name
    self.__components[name] = {...}
    return self
end

function Entity:remove(component)
    local name = component.__name
    self.__components[name] = nil
    return self
end

function Entity:get(component)
    local name = component.__name
    return self.__components[name]
end

function Entity:has(component)
    local name = component.__name
    return self.__components[name] ~= nil
end

-- 简化的世界系统
local World = {}
World.__index = World

function World.new()
    local world = setmetatable({
        entities = {},
        systems = {},
        events = {}
    }, World)
    return world
end

function World:addEntity(entity)
    table.insert(self.entities, entity)
    return entity
end

function World:removeEntity(entity)
    for i, e in ipairs(self.entities) do
        if e == entity then
            table.remove(self.entities, i)
            break
        end
    end
end

function World:addSystem(system)
    table.insert(self.systems, system)
    return system
end

function World:emit(event, ...)
    for _, system in ipairs(self.systems) do
        if system[event] then
            system[event](system, ...)
        end
    end
end

-- 简化的系统基类
local System = {}
System.__index = System

function System.new(requirements)
    local system = setmetatable({
        requirements = requirements or {}
    }, System)
    return system
end

-- Concord接口
function Concord.component(name, fields)
    return Component.new(name, fields)
end

function Concord.entity()
    return Entity.new()
end

function Concord.world()
    return World.new()
end

function Concord.system(requirements)
    return System.new(requirements)
end

return Concord

---

-- libs/hump/signal.lua - 事件信号库接口（需要实际的hump库）
-- 这里提供一个简化的信号系统示例

local Signal = {}
Signal.__index = Signal

function Signal.new()
    local signal = setmetatable({
        callbacks = {}
    }, Signal)
    return signal
end

function Signal:register(event, callback)
    if not self.callbacks[event] then
        self.callbacks[event] = {}
    end
    table.insert(self.callbacks[event], callback)
end

function Signal:remove(event, callback)
    if not self.callbacks[event] then
        return
    end
    
    for i, cb in ipairs(self.callbacks[event]) do
        if cb == callback then
            table.remove(self.callbacks[event], i)
            break
        end
    end
end

function Signal:emit(event, ...)
    if not self.callbacks[event] then
        return
    end
    
    for _, callback in ipairs(self.callbacks[event]) do
        callback(...)
    end
end

function Signal:clear()
    self.callbacks = {}
end

return Signal



--[[

README.md - 项目说明文档
# 2D Minecraft-like Microkernel Framework

## 简介

这是一个基于 Love2D 的 2D Minecraft-like 游戏框架，采用微内核架构设计。框架核心只提供基础的 Tile 管理、事件系统、ECS 和 Actor 系统，所有游戏逻辑通过 Mod 系统实现，支持无限扩展。

## 核心特性

- **微内核架构**: 核心系统最小化，所有游戏逻辑通过 Mod 扩展
- **ECS + Actor 混合系统**: 静态 Tile 直接存储数据，动态 Tile 使用 Actor 对象
- **强大的 Mod 系统**: 支持 Lua 脚本 Mod，支持热重载
- **无限世界**: 基于 Chunk 的世界管理系统
- **事件驱动**: 全局事件总线，支持松耦合的组件通信
- **脚本组件**: 支持动态加载和执行脚本逻辑

## 目录结构

```
├── main.lua                    # Love2D 入口点
├── config.lua                  # 全局配置
├── lib/                        # 核心库
│   ├── ecs.lua                # ECS 系统封装
│   ├── actor.lua              # Actor 对象系统
│   ├── script_component.lua   # 脚本组件系统
│   ├── event_bus.lua          # 全局事件总线
│   ├── tile_system.lua        # Tile 管理系统
│   ├── chunk_manager.lua      # Chunk 管理系统
│   └── mod_manager.lua        # Mod 管理系统
├── libs/                      # 第三方库
│   ├── concord.lua           # ECS 库 (Concord)
│   └── hump/
│       └── signal.lua        # 信号/事件库
├── mods/                      # Mod 目录
│   └── test/                 # 测试 Mod
│       ├── mod.lua           # Mod 主文件
│       └── scripts/          # Mod 脚本
│           ├── tree_growth.lua
│           └── water_flow.lua
└── saves/                    # 存档目录
```

## 快速开始

### 安装依赖

1. 下载并安装 [Love2D](https://love2d.org/)
2. 下载 [Concord ECS 库](https://github.com/Tjakka5/Concord) 到 `libs/` 目录
3. 下载 [hump 库](https://github.com/vrld/hump) 到 `libs/` 目录

### 运行框架

```bash
love .
```

### 基本操作

- **WASD 或方向键**: 移动相机
- **鼠标左键**: 放置 Tile
- **鼠标右键**: 移除 Tile
- **数字键 1-4**: 切换要放置的 Tile 类型
- **R 键**: 热重载所有 Mod

]]
