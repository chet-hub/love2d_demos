# DemoMod for Microkernel 2D Game

## 介绍
该Mod展示了微内核架构中 Mod 开发的全套接口和事件使用方式，支持：
- Actor 创建与脚本组件挂载
- Tile 系统操作（获取/修改）
- 事件总线监听/触发
- Chunk 加载/卸载处理
- 动态脚本逻辑演示

## 文件结构
- `init.lua`：Mod 必需入口文件，注册事件、创建 Actor、挂载脚本组件
- `logic/growth.lua`：动态 Tile 成长逻辑
- `logic/animate.lua`：动态 Tile 动画逻辑
- `README.md`：Mod 文档说明

## 开发规范
1. **Mod入口文件必须为 init.lua**，必须返回 `init(api)` 函数。
2. **脚本组件可以挂载到任意 Actor**，支持多个脚本。
3. **事件使用**：
   - `api:on(event, callback)` 订阅事件
   - `api:emit(event, ...)` 触发事件
   - 可订阅微内核提供的 `chunk-loaded`, `chunk-unloaded`, `tile-updated` 等事件
4. **Tile操作**：
   - `api:set_tile(wx, wy, tile)` / `api:get_tile(wx, wy)`
   - 只有动态Tile才生成Actor，以提升性能
5. **多Mod支持**：每个Mod独立 `init.lua`，微内核可同时加载多个Mod，互不干扰
