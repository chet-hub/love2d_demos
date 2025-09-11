# 2d Minecraft

我现在需要使用love2d + fennel 开发一个2d Minecraft，该如何设计API和架构， 具体要求
1. Tile系统和minecraft中的block一样，能无限自由和无限扩展
2. mod系统可以改变游戏内容和玩法， 能加载大量mod， mod开发简单，不冲突兼容性好，整个游戏完全靠mod扩展，使用微内核
3. 需要能支持大型多人同时在线
4. 能实现目前市面上绝大部分2d游戏玩法
5. 同时支持 Lua 和 Fennel 文件，.fnl 文件优先编译
6. 项目目录如下：
2d-minecraft-project/
├── main.lua                # 主入口，加载 Lua/Fennel Mod， 微内核
├── lib/
│   ├── concord/            # Concord ECS 库（从 GitHub 下载）
│   └── fennel.lua         # Fennel 编译器（可选，https://fennel-lang.org/）
├── mods/
│   ├── core/
│   │   ├── init.lua       # 核心 Mod (Lua)
│   ├── rpg/
│   │   ├── init.lua       # RPG Mod (Lua)
│   └── shooter/
│       ├── init.lua       # Shooter Mod (Lua)
└── README.md              # 项目说明

7. 采用 **节点树 + ECS + Actor/消息 + 脚本组件化** 组合，实现 **可扩展、Mod友好、高性能** 的2D Minecraft风格平台
解释如下：

* **节点树**：管理 Tile/Chunk/UI 层次，方便 Mod 挂载。
* **ECS**：处理性能关键逻辑（渲染、物理、AI 批处理）。
* **Actor/消息**：玩家、怪物、Tile 可通过消息系统解耦交互。
* **数据驱动 + 脚本（Fennel）**：Mod 可以动态扩展游戏逻辑。
* **组件化思想**：每个对象通过组合组件实现行为，避免深层继承。

* 可扩展性：脚本组件化+Actor 消息+ECS 完全能支持不同游戏玩法。
* Mod 支持：所有玩法逻辑可以由 Mod 插件实现，核心只提供微内核。
* 性能：ECS 用于批量逻辑计算，Actor 事件用于关键事件触发，节点树管理层次。
* 多人在线：Actor 消息+ECS状态同步，可支持 RTS/MOBA/卡牌等多人模式。