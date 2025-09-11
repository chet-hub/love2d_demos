# 2D Minecraft-like Framework Mod开发详细教程

## 目录
1. [Mod系统概述](#mod系统概述)
2. [创建你的第一个Mod](#创建你的第一个mod)
3. [Tile系统详解](#tile系统详解)
4. [事件系统使用](#事件系统使用)
5. [脚本组件开发](#脚本组件开发)
6. [世界生成器](#世界生成器)
7. [资源管理](#资源管理)
8. [高级技巧](#高级技巧)
9. [调试与测试](#调试与测试)
10. [最佳实践](#最佳实践)

---

## Mod系统概述

### Mod的基本结构
每个Mod都是一个文件夹，包含：
- **`mod.lua`**（必需）：Mod的主入口文件
- **其他文件**（可选）：脚本、纹理、数据等

### Mod生命周期
```
1. 扫描 mods/ 目录
2. 加载每个 mod.lua 文件
3. 调用 init() 函数，获取Mod定义
4. 按依赖关系排序
5. 调用每个Mod的 init 回调
6. 游戏运行时调用 update 回调
7. 退出时调用 cleanup 回调
```

---

## 创建你的第一个Mod

### 步骤1：创建Mod目录
```
mods/my_first_mod/
└── mod.lua
```

### 步骤2：编写最小可用的mod.lua
```lua
function init(ctx)
    print("Hello from my first mod!")
    
    return {
        name = "My First Mod",
        version = "1.0.0",
        description = "我的第一个Mod"
    }
end
```

### 步骤3：测试Mod
1. 启动游戏
2. 查看控制台输出，应该显示 "Hello from my first mod!"
3. 按 `R` 键测试热重载功能

### 步骤4：添加简单功能
```lua
function init(ctx)
    print("My first mod is loading...")
    
    -- 监听空格键
    ctx.event_bus.on("keypressed", function(key)
        if key == "space" then
            print("Space pressed! Hello from my mod!")
        end
    end)
    
    return {
        name = "My First Mod",
        version = "1.0.0",
        description = "学习用的第一个Mod",
        
        init = function(context)
            print("My first mod initialized!")
        end
    }
end
```

---

## Tile系统详解

### 基础Tile类型注册

#### 静态Tile（推荐用于简单块）
```lua
function init(ctx)
    -- 基础块类型
    ctx.registerTileType("dirt", {
        is_dynamic = false,      -- 静态tile，性能更好
        is_solid = true,         -- 是否阻挡移动
        color = {0.6, 0.4, 0.2}, -- RGB颜色
        on_place = function(actor, x, y, data)
            print("泥土放置在 " .. x .. ", " .. y)
        end,
        on_break = function(actor, x, y)
            print("泥土被破坏")
        end,
        on_interact = function(actor, x, y, player)
            print("与泥土交互")
        end
    })
    
    return {
        name = "Basic Blocks Mod",
        version = "1.0.0"
    }
end
```

#### 动态Tile（用于有复杂逻辑的块）
```lua
function init(ctx)
    ctx.registerTileType("magic_crystal", {
        is_dynamic = true,       -- 动态tile，会创建Actor对象
        is_solid = true,
        color = {0.8, 0.2, 1.0}, -- 紫色
        on_place = function(actor, x, y, data)
            -- actor参数不为nil，因为是动态tile
            actor.tile_data.energy = 100
            actor.tile_data.last_pulse = 0
            print("魔法水晶充能完成！")
        end,
        on_interact = function(actor, x, y)
            if actor.tile_data.energy > 0 then
                actor.tile_data.energy = actor.tile_data.energy - 10
                print("水晶能量：" .. actor.tile_data.energy)
            else
                print("水晶能量耗尽！")
            end
        end
    })
    
    return { name = "Magic Mod", version = "1.0.0" }
end
```

### Tile属性详解
```lua
{
    is_dynamic = false,      -- 是否为动态tile
    is_solid = true,         -- 是否为实体（阻挡）
    color = {r, g, b, a},    -- 颜色 (a为可选透明度)
    texture = image_object,  -- 纹理图片（优先于color）
    
    -- 事件回调
    on_place = function(actor, x, y, data) end,    -- 放置时
    on_break = function(actor, x, y) end,          -- 破坏时
    on_interact = function(actor, x, y, ...) end, -- 交互时
    
    -- 自定义属性
    hardness = 10,           -- 自定义：硬度
    tool_required = "pickaxe", -- 自定义：需要的工具
}
```

---

## 事件系统使用

### 监听系统事件
```lua
function init(ctx)
    -- 游戏初始化事件
    ctx.event_bus.on("game_init", function(data)
        print("游戏初始化完成！")
        print("世界：", data.world)
    end)
    
    -- 更新事件（每帧）
    ctx.event_bus.on("update", function(dt)
        -- dt是帧时间间隔
        -- 注意：高频事件，避免复杂操作
    end)
    
    -- 渲染事件（每帧）
    ctx.event_bus.on("render", function(camera)
        -- 可以在这里添加自定义渲染
        love.graphics.print("我的Mod文本", 10, 100)
    end)
    
    return { name = "Event Demo", version = "1.0.0" }
end
```

### 监听输入事件
```lua
function init(ctx)
    -- 键盘事件
    ctx.event_bus.on("keypressed", function(key)
        if key == "t" then
            print("T键被按下")
        elseif key == "return" then
            print("回车键被按下")
        end
    end)
    
    -- 鼠标事件
    ctx.event_bus.on("mousepressed", function(event)
        local button = event.button
        local world_x, world_y = event.world_x, event.world_y
        local tile_x = math.floor(world_x / 32)  -- TILE_SIZE = 32
        local tile_y = math.floor(world_y / 32)
        
        if button == 1 then
            print("左键点击瓦片：", tile_x, tile_y)
        elseif button == 2 then
            print("右键点击瓦片：", tile_x, tile_y)
        end
    end)
    
    return { name = "Input Handler", version = "1.0.0" }
end
```

### 发送自定义事件
```lua
function init(ctx)
    -- 定时器示例
    local timer = 0
    
    ctx.event_bus.on("update", function(dt)
        timer = timer + dt
        if timer >= 5.0 then  -- 每5秒
            timer = 0
            -- 发送自定义事件
            ctx.event_bus.emit("my_custom_event", {
                message = "定时器触发",
                timestamp = love.timer.getTime()
            })
        end
    end)
    
    -- 监听自定义事件
    ctx.event_bus.on("my_custom_event", function(data)
        print("收到自定义事件：", data.message)
    end)
    
    return { name = "Custom Events", version = "1.0.0" }
end
```

---

## 脚本组件开发

### 创建脚本组件文件
首先创建目录结构：
```
mods/scripted_mod/
├── mod.lua
└── scripts/
    └── my_component.lua
```

### 编写脚本组件（scripts/my_component.lua）
```lua
-- 组件的局部变量
local pulse_timer = 0
local pulse_interval = 2.0

-- 当组件被附加到Actor时调用
function onAttach(actor)
    print("脚本组件附加到：", actor.tile_type)
    actor.tile_data.pulse_count = 0
end

-- 每帧更新
function update(actor, dt)
    pulse_timer = pulse_timer + dt
    
    if pulse_timer >= pulse_interval then
        pulse_timer = 0
        actor.tile_data.pulse_count = actor.tile_data.pulse_count + 1
        
        print("脉搏 #" .. actor.tile_data.pulse_count .. 
              " 在 (" .. math.floor(actor.x/32) .. "," .. math.floor(actor.y/32) .. ")")
              
        -- 发送脉搏事件
        EventBus.emit("tile_pulse", {
            actor = actor,
            count = actor.tile_data.pulse_count
        })
    end
end

-- 自定义渲染
function render(actor)
    local tile_x = math.floor(actor.x / 32) * 32
    local tile_y = math.floor(actor.y / 32) * 32
    
    -- 基础渲染
    love.graphics.setColor(1, 0.5, 0.8)  -- 粉红色
    love.graphics.rectangle("fill", tile_x, tile_y, 32, 32)
    
    -- 脉搏效果
    local pulse_alpha = (math.sin(love.timer.getTime() * 3) + 1) / 4 + 0.5
    love.graphics.setColor(1, 1, 1, pulse_alpha)
    love.graphics.rectangle("line", tile_x-2, tile_y-2, 36, 36)
end

-- 当组件被移除时调用
function onDetach(actor)
    print("脚本组件从Actor移除")
end

-- 当Actor被销毁时调用
function onDestroy(actor)
    print("Actor销毁，脉搏停止")
end

-- 自定义函数，可以从外部调用
function acceleratePulse(actor)
    pulse_interval = math.max(0.1, pulse_interval * 0.5)
    print("脉搏加速！新间隔：", pulse_interval)
end
```

### 在mod.lua中使用脚本组件
```lua
function init(ctx)
    ctx.registerTileType("pulse_block", {
        is_dynamic = true,  -- 必须是动态的才能使用脚本组件
        is_solid = true,
        on_place = function(actor, x, y, data)
            -- 加载并附加脚本组件
            local pulse_script = ctx.loadScript("scripts/my_component.lua")
            if pulse_script and pulse_script.loaded then
                actor:addComponent("pulse", pulse_script)
            else
                print("无法加载脉搏脚本：", pulse_script.error_message)
            end
        end,
        on_interact = function(actor, x, y)
            local pulse_component = actor:getComponent("pulse")
            if pulse_component then
                -- 调用脚本组件的自定义函数
                pulse_component:call("acceleratePulse", actor)
            end
        end
    })
    
    -- 监听脉搏事件
    ctx.event_bus.on("tile_pulse", function(data)
        print("检测到脉搏事件，计数：", data.count)
    end)
    
    return { name = "Scripted Mod", version = "1.0.0" }
end
```

---

## 世界生成器

### 基础地形生成器
```lua
function init(ctx)
    ctx.registerChunkGenerator("basic_terrain", function(chunk_x, chunk_y, tile_system)
        local start_x = chunk_x * 16  -- CHUNK_SIZE = 16
        local start_y = chunk_y * 16
        
        -- 生成地形
        for y = 0, 15 do
            for x = 0, 15 do
                local world_x = start_x + x
                local world_y = start_y + y
                
                -- 简单的高度图
                local height = 5 + math.sin(world_x * 0.1) * 3
                
                if world_y < height - 5 then
                    tile_system:placeTile(world_x, world_y, "stone")
                elseif world_y < height then
                    tile_system:placeTile(world_x, world_y, "dirt")
                elseif world_y == math.floor(height) then
                    tile_system:placeTile(world_x, world_y, "grass")
                end
            end
        end
        
        return true  -- 返回true表示生成成功
    end, 5)  -- 优先级为5
    
    return { name = "Terrain Generator", version = "1.0.0" }
end
```

### 复杂生成器（结构生成）
```lua
function init(ctx)
    -- 注册基础方块
    ctx.registerTileType("wood", { is_dynamic = false, is_solid = true, color = {0.6, 0.4, 0.2} })
    ctx.registerTileType("leaves", { is_dynamic = false, is_solid = false, color = {0.2, 0.8, 0.2} })
    
    -- 生成房屋的函数
    local function generateHouse(tile_system, x, y)
        -- 房屋基础（3x3）
        for house_y = y, y + 2 do
            for house_x = x, x + 2 do
                if house_y == y or house_y == y + 2 or 
                   house_x == x or house_x == x + 2 then
                    tile_system:placeTile(house_x, house_y, "wood")
                end
            end
        end
        
        -- 门（底部中间留空）
        tile_system:removeTile(x + 1, y + 2)
        
        print("房屋生成在：", x, y)
    end
    
    -- 结构生成器
    ctx.registerChunkGenerator("structures", function(chunk_x, chunk_y, tile_system)
        -- 只在某些chunk生成结构
        if (chunk_x + chunk_y) % 4 == 0 then
            local start_x = chunk_x * 16
            local start_y = chunk_y * 16
            
            -- 在chunk中间生成房屋
            generateHouse(tile_system, start_x + 6, start_y + 6)
        end
        
        return true
    end, 3)  -- 较低优先级，在地形生成后
    
    return { name = "Structure Generator", version = "1.0.0" }
end
```

---

## 资源管理

### 加载和使用纹理
```lua
function init(ctx)
    -- 加载纹理
    local grass_texture = ctx.loadTexture("textures/grass.png")
    local stone_texture = ctx.loadTexture("textures/stone.png")
    
    if grass_texture then
        ctx.registerTileType("textured_grass", {
            is_dynamic = false,
            is_solid = false,
            texture = grass_texture  -- 使用纹理而不是color
        })
    else
        print("无法加载草地纹理，使用颜色代替")
        ctx.registerTileType("textured_grass", {
            is_dynamic = false,
            is_solid = false,
            color = {0.2, 0.8, 0.2}
        })
    end
    
    return { name = "Textured Mod", version = "1.0.0" }
end
```

### Mod文件结构（包含资源）
```
mods/textured_mod/
├── mod.lua
├── textures/
│   ├── grass.png
│   ├── stone.png
│   └── water.png
├── scripts/
│   └── animated_water.lua
└── data/
    └── recipes.lua
```

### 加载数据文件
```lua
function init(ctx)
    -- 加载数据文件
    local data_path = ctx.path .. "/data/recipes.lua"
    local recipes = nil
    
    if love.filesystem.getInfo(data_path) then
        local chunk = love.filesystem.load(data_path)
        if chunk then
            recipes = chunk()  -- 执行并获取返回值
        end
    end
    
    if recipes then
        print("加载了", #recipes, "个配方")
        -- 使用配方数据...
    end
    
    return { name = "Data Loader", version = "1.0.0" }
end
```

---

## 高级技巧

### Mod间通信
```lua
-- Mod A: 提供服务
function init(ctx)
    -- 注册全局服务
    _G.MyModService = {
        version = "1.0.0",
        
        registerSpell = function(name, effect)
            print("注册法术：", name)
            -- 注册逻辑...
        end,
        
        castSpell = function(name, x, y)
            print("释放法术：", name, "在", x, y)
            -- 释放逻辑...
        end
    }
    
    return { 
        name = "Magic System",
        version = "1.0.0",
        provides = {"magic_api"}  -- 声明提供的服务
    }
end

-- Mod B: 使用服务
function init(ctx)
    return {
        name = "Fire Magic",
        version = "1.0.0",
        dependencies = {"Magic System"},  -- 声明依赖
        
        init = function(context)
            -- 确保服务可用
            if _G.MyModService then
                _G.MyModService.registerSpell("fireball", function(x, y)
                    context.tile_system:placeTile(x, y, "fire")
                end)
            end
        end
    }
end
```

### 自定义UI元素
```lua
function init(ctx)
    local ui_visible = false
    local ui_text = "Mod UI面板"
    
    -- 切换UI显示
    ctx.event_bus.on("keypressed", function(key)
        if key == "u" then
            ui_visible = not ui_visible
        end
    end)
    
    -- 渲染UI
    ctx.event_bus.on("render", function(camera)
        if ui_visible then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", 100, 100, 300, 200)
            
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", 100, 100, 300, 200)
            love.graphics.print(ui_text, 110, 110)
            love.graphics.print("按 U 键关闭", 110, 130)
        end
    end)
    
    return { name = "UI Demo", version = "1.0.0" }
end
```

### 持久化数据
```lua
function init(ctx)
    local save_data = {}
    
    -- 加载保存的数据
    local function loadData()
        local save_file = "mod_data_" .. ctx.name .. ".lua"
        if love.filesystem.getInfo(save_file) then
            local content = love.filesystem.read(save_file)
            local chunk = load("return " .. content)
            if chunk then
                save_data = chunk() or {}
            end
        end
    end
    
    -- 保存数据
    local function saveData()
        local save_file = "mod_data_" .. ctx.name .. ".lua"
        local serialized = serialize(save_data)  -- 需要实现序列化函数
        love.filesystem.write(save_file, serialized)
    end
    
    -- 简单的序列化函数
    local function serialize(t)
        local function serializeValue(v)
            if type(v) == "string" then
                return string.format("%q", v)
            elseif type(v) == "table" then
                local parts = {}
                for k, val in pairs(v) do
                    local key = type(k) == "string" and k or "[" .. serializeValue(k) .. "]"
                    table.insert(parts, key .. "=" .. serializeValue(val))
                end
                return "{" .. table.concat(parts, ",") .. "}"
            else
                return tostring(v)
            end
        end
        return serializeValue(t)
    end
    
    return {
        name = "Persistent Data",
        version = "1.0.0",
        
        init = function(context)
            loadData()
            print("加载的数据：", save_data.player_score or 0)
        end,
        
        cleanup = function(context)
            saveData()
            print("数据已保存")
        end
    }
end
```

---

## 调试与测试

### 调试技巧
```lua
function init(ctx)
    -- 调试开关
    local DEBUG = true
    
    local function debugPrint(...)
        if DEBUG then
            print("[DEBUG]", ...)
        end
    end
    
    -- 详细的事件日志
    ctx.event_bus.on("tile_placed", function(data)
        debugPrint("Tile placed:", data.type, "at", data.x, data.y)
    end)
    
    ctx.event_bus.on("tile_removed", function(data)
        debugPrint("Tile removed:", data.type, "from", data.x, data.y)
    end)
    
    -- 性能监控
    local frame_count = 0
    ctx.event_bus.on("update", function(dt)
        frame_count = frame_count + 1
        if frame_count % 60 == 0 then  -- 每60帧
            debugPrint("FPS:", love.timer.getFPS())
        end
    end)
    
    return { name = "Debug Mod", version = "1.0.0" }
end
```

### 错误处理
```lua
function init(ctx)
    -- 安全的tile注册
    local function safeTileRegister(name, definition)
        local success, error = pcall(function()
            ctx.registerTileType(name, definition)
        end)
        
        if not success then
            print("注册tile失败：", name, error)
            return false
        end
        return true
    end
    
    -- 使用pcall保护脚本加载
    local function safeLoadScript(path)
        local success, script = pcall(function()
            return ctx.loadScript(path)
        end)
        
        if success and script and script.loaded then
            return script
        else
            print("脚本加载失败：", path)
            return nil
        end
    end
    
    return { name = "Safe Mod", version = "1.0.0" }
end
```

---

## 最佳实践

### 1. 代码组织
```lua
-- 将复杂逻辑分解为小函数
function init(ctx)
    local mod = {}
    
    -- 分离tile定义
    function mod.registerTiles()
        ctx.registerTileType("my_grass", {
            is_dynamic = false,
            color = {0.3, 0.8, 0.3}
        })
    end
    
    -- 分离事件处理
    function mod.setupEvents()
        ctx.event_bus.on("keypressed", function(key)
            if key == "g" then
                print("切换到草地模式")
            end
        end)
    end
    
    -- 分离生成器
    function mod.setupGenerators()
        ctx.registerChunkGenerator("grass_fields", function(cx, cy, ts)
            -- 生成逻辑...
            return true
        end, 1)
    end
    
    -- 执行初始化
    mod.registerTiles()
    mod.setupEvents()
    mod.setupGenerators()
    
    return { name = "Well Organized Mod", version = "1.0.0" }
end
```

### 2. 性能考虑
```lua
function init(ctx)
    -- 缓存频繁访问的对象
    local tile_system = ctx.tile_system
    local event_bus = ctx.event_bus
    
    -- 避免在update事件中做重复计算
    local last_second = 0
    event_bus.on("update", function(dt)
        local current_second = math.floor(love.timer.getTime())
        if current_second ~= last_second then
            last_second = current_second
            -- 每秒执行一次的逻辑
        end
    end)
    
    -- 使用静态tile而不是动态tile（除非必要）
    ctx.registerTileType("efficient_block", {
        is_dynamic = false,  -- 更高效
        color = {1, 0, 0}
    })
    
    return { name = "Efficient Mod", version = "1.0.0" }
end
```

### 3. 用户体验
```lua
function init(ctx)
    -- 提供清晰的反馈
    ctx.registerTileType("interactive_block", {
        is_dynamic = false,
        color = {0, 1, 1},
        on_place = function(actor, x, y, data)
            print("✓ 互动方块已放置")
        end,
        on_interact = function(actor, x, y)
            print("→ 方块被激活！")
        end
    })
    
    -- 提供帮助信息
    local help_shown = false
    ctx.event_bus.on("keypressed", function(key)
        if key == "h" and not help_shown then
            help_shown = true
            print("=== Mod帮助 ===")
            print("按 T 键放置互动方块")
            print("点击方块进行交互")
            print("================")
        end
    end)
    
    return {
        name = "User Friendly Mod",
        version = "1.0.0",
        
        init = function(context)
            print("用户友好Mod已加载！按 H 键查看帮助")
        end
    }
end
```

### 4. 模块化设计
```lua
function init(ctx)
    -- 创建模块化的功能
    local TileRegistry = {
        tiles = {},
        
        register = function(self, name, def)
            self.tiles[name] = def
            ctx.registerTileType(name, def)
        end,
        
        get = function(self, name)
            return self.tiles[name]
        end
    }
    
    local EventHandler = {
        handlers = {},
        
        register = function(self, event, handler)
            if not self.handlers[event] then
                self.handlers[event] = {}
                ctx.event_bus.on(event, function(...)
                    for _, h in ipairs(self.handlers[event]) do
                        h(...)
                    end
                end)
            end
            table.insert(self.handlers[event], handler)
        end
    }
    
    -- 使用模块
    TileRegistry:register("modular_block", {
        is_dynamic = false,
        color = {1, 0.5, 0}
    })
    
    EventHandler:register("keypressed", function(key)
        if key == "m" then
            print("模块化按键处理")
        end
    end)
    
    return { name = "Modular Mod", version = "1.0.0" }
end
```

---

## 总结

通过这个详细教程，您应该能够：

1. ✅ **创建基本Mod**：理解Mod结构和生命周期
2. ✅ **注册Tile类型**：静态和动态tile的区别和使用
3. ✅ **处理事件**：监听系统事件和创建自定义事件
4. ✅ **开发脚本组件**：为tile添加复杂行为
5. ✅ **创建世界生成器**：程序化生成地形和结构
6. ✅ **管理资源**：加载纹理、脚本和数据文件
7. ✅ **应用高级技巧**：Mod间通信、UI、持久化
8. ✅ **调试和优化**：错误处理和性能优化
9. ✅ **遵循最佳实践**：代码组织和用户体验

现在您可以开始创建自己的Mod了！建议从简单的功能开始，逐步增加复杂度。记住经常测试和使用热重载功能（按R键）来提高开发效率。

---

## 实战练习

### 练习1：创建一个基础农业Mod

**目标**：实现种子、土壤和作物系统

**步骤**：
1. 创建 `mods/farming/mod.lua`
2. 注册以下tile类型：
   - `farmland`（农田，静态）
   - `wheat_seed`（小麦种子，动态，会生长）
   - `wheat_crop`（成熟小麦，静态）

```lua
function init(ctx)
    -- 农田
    ctx.registerTileType("farmland", {
        is_dynamic = false,
        is_solid = false,
        color = {0.4, 0.2, 0.1},
        on_interact = function(actor, x, y)
            -- 在农田上种植种子
            local above_tile = ctx.tile_system:getTile(x, y - 1)
            if not above_tile then
                ctx.tile_system:placeTile(x, y - 1, "wheat_seed")
            end
        end
    })
    
    -- 小麦种子（会生长）
    ctx.registerTileType("wheat_seed", {
        is_dynamic = true,
        is_solid = false,
        color = {0.6, 0.8, 0.3},
        on_place = function(actor, x, y, data)
            actor.tile_data.growth_time = 0
            actor.tile_data.max_growth = 10  -- 10秒生长周期
            
            -- 添加生长脚本
            local growth_script = ctx.loadScript("scripts/crop_growth.lua")
            if growth_script then
                actor:addComponent("growth", growth_script)
            end
        end
    })
    
    -- 成熟小麦
    ctx.registerTileType("wheat_crop", {
        is_dynamic = false,
        is_solid = false,
        color = {1, 1, 0.5},
        on_interact = function(actor, x, y)
            print("收获了小麦！")
            ctx.tile_system:removeTile(x, y)
            -- 这里可以添加物品到背包等逻辑
        end
    })
    
    -- 快捷键
    ctx.event_bus.on("keypressed", function(key)
        if key == "f" then
            current_place_tile = "farmland"
            print("选择：农田")
        end
    end)
    
    return {
        name = "Basic Farming",
        version = "1.0.0",
        description = "基础农业系统"
    }
end
```

创建 `mods/farming/scripts/crop_growth.lua`：
```lua
function update(actor, dt)
    actor.tile_data.growth_time = actor.tile_data.growth_time + dt
    
    if actor.tile_data.growth_time >= actor.tile_data.max_growth then
        -- 生长完成，转换为成熟作物
        local x = math.floor(actor.x / 32)
        local y = math.floor(actor.y / 32)
        
        local tile_system = GAME.tile_system()
        tile_system:removeTile(x, y)
        tile_system:placeTile(x, y, "wheat_crop")
        
        print("小麦成熟了！")
    end
end

function render(actor)
    local x = math.floor(actor.x / 32) * 32
    local y = math.floor(actor.y / 32) * 32
    
    -- 根据生长进度改变大小
    local progress = actor.tile_data.growth_time / actor.tile_data.max_growth
    local size = 16 + progress * 16  -- 从16像素长到32像素
    local offset = (32 - size) / 2
    
    love.graphics.setColor(0.6, 0.8, 0.3)
    love.graphics.rectangle("fill", x + offset, y + offset, size, size)
    
    -- 显示生长进度
    love.graphics.setColor(1, 1, 1, 0.7)
    local progress_text = math.floor(progress * 100) .. "%"
    love.graphics.print(progress_text, x, y - 15, 0, 0.5)
end
```

### 练习2：创建一个简单的魔法系统

**目标**：实现法术书、魔法阵和法术效果

```lua
function init(ctx)
    -- 魔法阵
    ctx.registerTileType("magic_circle", {
        is_dynamic = true,
        is_solid = false,
        color = {0.8, 0.2, 1.0, 0.7},
        on_place = function(actor, x, y, data)
            actor.tile_data.mana = 100
            actor.tile_data.spell_cooldown = 0
            
            local magic_script = ctx.loadScript("scripts/magic_circle.lua")
            if magic_script then
                actor:addComponent("magic", magic_script)
            end
        end,
        on_interact = function(actor, x, y)
            if actor.tile_data.mana >= 10 then
                actor.tile_data.mana = actor.tile_data.mana - 10
                -- 施放火球术
                ctx.event_bus.emit("cast_spell", {
                    spell = "fireball",
                    x = x,
                    y = y,
                    caster = actor
                })
            else
                print("魔力不足！")
            end
        end
    })
    
    -- 火焰方块（法术效果）
    ctx.registerTileType("fire", {
        is_dynamic = true,
        is_solid = false,
        color = {1, 0.3, 0, 0.8},
        on_place = function(actor, x, y, data)
            actor.tile_data.burn_time = 5.0  -- 燃烧5秒
            
            local fire_script = ctx.loadScript("scripts/fire_effect.lua")
            if fire_script then
                actor:addComponent("fire", fire_script)
            end
        end
    })
    
    -- 监听法术事件
    ctx.event_bus.on("cast_spell", function(data)
        if data.spell == "fireball" then
            -- 在附近随机位置创建火焰
            for i = 1, 3 do
                local fire_x = data.x + math.random(-2, 2)
                local fire_y = data.y + math.random(-2, 2)
                ctx.tile_system:placeTile(fire_x, fire_y, "fire")
            end
            print("火球术释放！")
        end
    end)
    
    return {
        name = "Simple Magic",
        version = "1.0.0",
        description = "简单魔法系统"
    }
end
```

### 练习3：创建一个生态系统Mod

**目标**：实现动物、食物链和繁殖系统

```lua
function init(ctx)
    -- 兔子
    ctx.registerTileType("rabbit", {
        is_dynamic = true,
        is_solid = false,
        color = {1, 1, 1},
        on_place = function(actor, x, y, data)
            actor.tile_data.hunger = 100
            actor.tile_data.age = 0
            actor.tile_data.move_timer = 0
            
            local animal_script = ctx.loadScript("scripts/rabbit_ai.lua")
            if animal_script then
                actor:addComponent("ai", animal_script)
            end
        end
    })
    
    -- 胡萝卜
    ctx.registerTileType("carrot", {
        is_dynamic = false,
        is_solid = false,
        color = {1, 0.5, 0},
        on_interact = function(actor, x, y)
            -- 兔子可以吃胡萝卜
            print("胡萝卜被吃掉了！")
            ctx.tile_system:removeTile(x, y)
        end
    })
    
    -- 狼
    ctx.registerTileType("wolf", {
        is_dynamic = true,
        is_solid = false,
        color = {0.3, 0.3, 0.3},
        on_place = function(actor, x, y, data)
            actor.tile_data.hunger = 100
            actor.tile_data.hunt_timer = 0
            
            local predator_script = ctx.loadScript("scripts/wolf_ai.lua")
            if predator_script then
                actor:addComponent("ai", predator_script)
            end
        end
    })
    
    return {
        name = "Ecosystem",
        version = "1.0.0",
        description = "简单生态系统"
    }
end
```

---

## 高级主题

### 1. 多人游戏支持准备

虽然当前框架是单人游戏，但可以为将来的多人扩展做准备：

```lua
function init(ctx)
    -- 网络事件兼容的写法
    ctx.event_bus.on("player_action", function(data)
        local player_id = data.player_id or "local"
        local action = data.action
        
        if action == "place_tile" then
            ctx.tile_system:placeTile(data.x, data.y, data.tile_type)
            -- 广播给其他玩家
            ctx.event_bus.emit("broadcast", {
                event = "tile_placed",
                data = data
            })
        end
    end)
    
    return { name = "Multiplayer Ready", version = "1.0.0" }
end
```

### 2. 插件系统的插件

创建为其他Mod提供服务的"元Mod"：

```lua
function init(ctx)
    -- 创建全局工具API
    _G.ModUtils = {
        -- 简化的tile注册
        registerSimpleTile = function(name, color, solid)
            ctx.registerTileType(name, {
                is_dynamic = false,
                is_solid = solid or false,
                color = color or {1, 1, 1}
            })
        end,
        
        -- 通用的生长系统
        addGrowthBehavior = function(actor, stages, time_per_stage)
            local growth_script = ctx.loadScript("scripts/universal_growth.lua")
            if growth_script then
                actor.tile_data.growth_stages = stages
                actor.tile_data.time_per_stage = time_per_stage
                actor.tile_data.current_stage = 1
                actor:addComponent("growth", growth_script)
            end
        end,
        
        -- 简化的事件处理
        onKeyPress = function(key, callback)
            ctx.event_bus.on("keypressed", function(pressed_key)
                if pressed_key == key then
                    callback()
                end
            end)
        end
    }
    
    return {
        name = "Mod Utils",
        version = "1.0.0",
        description = "为其他Mod提供便利工具",
        provides = {"mod_utils"}
    }
end
```

### 3. 配置文件支持

```lua
function init(ctx)
    local config = {
        -- 默认配置
        generation_frequency = 0.1,
        max_trees_per_chunk = 5,
        tree_growth_time = 10.0
    }
    
    -- 加载配置文件
    local config_path = ctx.path .. "/config.lua"
    if love.filesystem.getInfo(config_path) then
        local user_config = love.filesystem.load(config_path)()
        -- 合并配置
        for k, v in pairs(user_config) do
            config[k] = v
        end
    else
        -- 创建默认配置文件
        local default_config = [[
return {
    generation_frequency = 0.1,  -- 生成频率
    max_trees_per_chunk = 5,     -- 每个chunk最大树木数
    tree_growth_time = 10.0      -- 树木生长时间
}
]]
        love.filesystem.write(config_path, default_config)
    end
    
    -- 使用配置
    ctx.registerChunkGenerator("configurable_trees", function(chunk_x, chunk_y, tile_system)
        local tree_count = 0
        for y = 0, 15 do
            for x = 0, 15 do
                if math.random() < config.generation_frequency and tree_count < config.max_trees_per_chunk then
                    local world_x = chunk_x * 16 + x
                    local world_y = chunk_y * 16 + y
                    tile_system:placeTile(world_x, world_y, "tree", {
                        growth_time = config.tree_growth_time
                    })
                    tree_count = tree_count + 1
                end
            end
        end
        return true
    end, 1)
    
    return {
        name = "Configurable Trees",
        version = "1.0.0",
        description = "可配置的树木生成系统"
    }
end
```

---

## 故障排除

### 常见问题和解决方案

#### 1. Mod无法加载
**症状**：控制台显示"Mod manifest not found"
**解决**：确保文件名是 `mod.lua`，不是 `mod.LUA` 或其他

#### 2. 脚本组件报错
**症状**：`Script compile error` 或 `Script execution error`
**解决**：
- 检查Lua语法错误
- 确保脚本文件路径正确
- 使用 `pcall` 包装可能出错的代码

#### 3. Tile不显示
**症状**：placeTile成功但看不到tile
**解决**：
- 检查color值是否正确（0-1范围）
- 确保tile没有被其他tile覆盖
- 检查相机位置

#### 4. 热重载失效
**症状**：按R键后修改不生效
**解决**：
- 检查文件是否保存
- 某些全局变量可能需要手动清理
- 重启游戏以完全重置

#### 5. 性能问题
**症状**：FPS下降，游戏卡顿
**解决**：
- 减少动态tile数量
- 优化update事件中的逻辑
- 使用定时器而不是每帧检查

---

## 社区和贡献

### 分享你的Mod

1. **文档化**：为你的Mod编写README
2. **版本控制**：使用语义化版本号
3. **测试**：在不同情况下测试你的Mod
4. **开源**：考虑在GitHub等平台分享

### Mod模板

创建一个标准的Mod模板：

```lua
-- mods/your_mod_name/mod.lua
-- 作者：Your Name
-- 版本：1.0.0
-- 描述：Your mod description
-- 许可证：MIT

function init(ctx)
    -- 在这里添加你的初始化代码
    
    -- 示例：注册一个基础方块
    ctx.registerTileType("example_block", {
        is_dynamic = false,
        is_solid = true,
        color = {1, 0, 0}  -- 红色
    })
    
    return {
        name = "Your Mod Name",
        version = "1.0.0",
        description = "Your mod description",
        author = "Your Name",
        dependencies = {},
        
        init = function(context)
            print("Your Mod Name loaded successfully!")
        end,
        
        update = function(context, dt)
            -- 每帧更新逻辑
        end,
        
        cleanup = function(context)
            print("Your Mod Name cleaned up!")
        end
    }
end
```

---

## 结语

恭喜您完成了2D Minecraft-like Framework的Mod开发教程！您现在应该能够：

✅ **理解框架架构**：微内核、ECS、Actor系统的协作方式
✅ **创建功能完整的Mod**：从简单方块到复杂游戏系统
✅ **掌握核心概念**：静态vs动态tile、事件驱动、脚本组件
✅ **应用高级技术**：世界生成、资源管理、Mod间通信
✅ **遵循最佳实践**：代码组织、性能优化、错误处理
✅ **解决常见问题**：调试技巧和故障排除

这个框架的强大之处在于其可扩展性 - 几乎所有的游戏逻辑都可以通过Mod实现。无论是简单的装饰方块，还是复杂的魔法系统、生态模拟、经济系统，都可以在不修改核心代码的情况下实现。

**下一步建议**：
1. 尝试完成文中的练习项目
2. 结合自己的创意创建独特的Mod
3. 探索更复杂的系统设计
4. 考虑为社区贡献你的Mod

记住：最好的学习方式就是实践。开始创建你的第一个Mod吧！🚀