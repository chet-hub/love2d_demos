# 2D Minecraft-like Microkernel Framework

## 架构初衷
本框架采用 **微内核 + ECS + Actor + 脚本组件** 的架构：
- 核心负责Tile管理、事件总线、Actor和ECS系统。
- 游戏逻辑全部通过Mod实现，实现高自由度、无限扩展的Tile世界。
- 支持Lua和Fennel Mod，支持热重载。

## 核心模块
1. **main.lua** - Love2D入口，初始化核心系统、TileSystem、ChunkManager、ModManager。
2. **config.lua** - 全局配置（tile大小、chunk大小、视距、保存目录等）。
3. **lib/ecs.lua** - ECS封装（底层使用Concord）。
4. **lib/actor.lua** - Actor对象封装，可挂载组件和逻辑。
5. **lib/script_component.lua** - 脚本组件，Mod可动态扩展逻辑。
6. **lib/event_bus.lua** - 全局事件总线（使用 hump.signal）。
7. **lib/tile_system.lua** - Tile管理系统，管理静态Tile数据和动态TileActor。
8. **lib/chunk_manager.lua** - 按Chunk加载/卸载Tile，支持无限地图。
9. **lib/mod_manager.lua** - Mod加载器，扫描目录加载Mod，支持热重载。
10. **mods/test/** - 示例Mod，展示mod开发流程,以及验证微内核。

## 使用场景
- 无限扩展Tile世界，高自由度Tile逻辑
- 动态Tile才创建Actor，减少性能开销
- Mod可实现地图生成、Tile动态行为、持久化、UI、任务系统等
- 支持热重载Mod，提高开发迭代效率

## 设计目标
- **微内核**：核心仅提供数据和接口，业务逻辑由Mod扩展。
- **高自由度Tile系统**：通过事件和接口扩展动态Tile逻辑。
- **性能优化**：动态Tile才创建Actor，静态Tile直接存储数据。
- **Mod友好**：Mod可完全控制游戏逻辑、地图和事件响应。
