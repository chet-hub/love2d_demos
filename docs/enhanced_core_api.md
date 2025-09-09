# 前言

受minecraft和roblox成功的启发,我要做一个基于tile系统的游戏平台，通过mod实现所有2d游戏玩法, 其中tile系统是关键, 每个tile可以有自己的逻辑属性，可无限扩展，mod可以增加内容或者改变玩法.
LÖVE2D + Fennel 是个绝佳的组合！使用微内核架构


# 微内核架构设计
### 核心只提供基础设施：
```lua
;; src/core.fnl - 最小内核
(local mod-registry {})
(local event-bus {})

;; 核心只负责：
;; 1. Mod加载和管理
;; 2. 事件系统
;; 3. 基础API接口
;; 4. 资源管理

(fn register-mod [mod-id mod-instance]
  "注册mod到系统"
  (tset mod-registry mod-id mod-instance)
  (emit-event "mod-loaded" {:id mod-id}))

(fn emit-event [event-type data]
  "发布事件"
  (let [handlers (. event-bus event-type)]
    (when handlers
      (each [_ handler (pairs handlers)]
        (handler data)))))

(fn subscribe-event [event-type handler]
  "订阅事件"
  (when (not (. event-bus event-type))
    (tset event-bus event-type {}))
  (table.insert (. event-bus event-type) handler))

;; 导出核心API
{: register-mod : emit-event : subscribe-event}
```


### 完全模块化的游戏系统, 基础系统作为mod：
```lua
;; mods/tile-system/init.fnl - Tile系统作为mod
(local core (require "src.core"))
(local tile-registry {})
(local world-data {})

;; Tile系统API
(local tile-api {})

(fn tile-api.register [id properties]
  (tset tile-registry id properties)
  (core.emit-event "tile-registered" {:id id :properties properties}))

(fn tile-api.get [x y]
  (let [key (.. x "," y)]
    (. world-data key)))

(fn tile-api.set [x y tile-id]
  (let [key (.. x "," y)]
    (tset world-data key {:type tile-id :x x :y y})
    (core.emit-event "tile-placed" {:x x :y y :type tile-id})))

;; 注册为全局API
(tset _G "TileAPI" tile-api)

;; 注册mod
(core.register-mod "tile-system" tile-api)
```

```lua
;; mods/render-system/init.fnl - 渲染系统作为mod
(local core (require "src.core"))
(var render-layers {})

(local render-api {})

(fn render-api.add-layer [name priority draw-fn]
  (tset render-layers name {:priority priority :draw draw-fn})
  (table.sort render-layers #(< $1.priority $2.priority)))

(fn render-api.draw-all []
  (each [_ layer (pairs render-layers)]
    (layer.draw)))

;; 监听LÖVE的draw事件
(fn love.draw [] (render-api.draw-all))

;; 注册API和mod
(tset _G "RenderAPI" render-api)
(core.register-mod "render-system" render-api)
```

### 游戏逻辑完全在mod中, 游戏模式mod：

```lua
;; mods/survival-mode/init.fnl - 生存模式
(local core (require "src.core"))

(local survival-state 
  {:hunger 100 
   :health 100 
   :day 1})

;; 游戏规则
(fn update-hunger [dt]
  (tset survival-state :hunger (- survival-state.hunger (* dt 0.1)))
  (when (<= survival-state.hunger 0)
    (core.emit-event "player-starved" {})))

(fn handle-tile-break [data]
  ;; 破坏方块消耗饥饿
  (tset survival-state :hunger (- survival-state.hunger 5)))

(fn handle-night-fall [data]
  ;; 夜晚生成怪物
  (core.emit-event "spawn-monsters" {:count 5}))

;; 订阅事件
(core.subscribe-event "tile-broken" handle-tile-break)
(core.subscribe-event "night-time" handle-night-fall)

;; 注册更新循环
(fn love.update [dt] (update-hunger dt))

(core.register-mod "survival-mode" {:state survival-state})

```

### 创造模式mod：
```lua
;; mods/creative-mode/init.fnl - 创造模式
(local core (require "src.core"))

(local creative-inventory 
  ;; 无限物品
  (setmetatable {} {:__index #(or $2 999999)}))

(fn handle-tile-place [data]
  ;; 创造模式不消耗物品
  (print (.. "Placed " data.type " at " data.x "," data.y)))

(fn handle-player-damage [data]
  ;; 创造模式无敌
  (print "No damage in creative mode"))

;; 重写生存模式的行为
(core.subscribe-event "tile-placed" handle-tile-place)
(core.subscribe-event "player-damage" handle-player-damage)

(core.register-mod "creative-mode" {:inventory creative-inventory})
```

### 内容mod示例,方块内容mod：
```lua
;; mods/basic-blocks/init.fnl
(local core (require "src.core"))

;; 等待tile系统加载
(core.subscribe-event "mod-loaded" 
  (fn [data]
    (when (= data.id "tile-system")
      (register-basic-blocks))))

(fn register-basic-blocks []
  (TileAPI.register "grass" 
    {:hardness 2 
     :tool "shovel"
     :drops ["dirt"]
     :on-break grass-break-logic})
  
  (TileAPI.register "stone" 
    {:hardness 8 
     :tool "pickaxe"
     :drops ["cobblestone"]
     :on-break stone-break-logic})
  
  (TileAPI.register "water"
    {:liquid true
     :flow-rate 0.5
     :on-update water-flow-logic}))

(fn grass-break-logic [pos player]
  (core.emit-event "drop-item" {:item "dirt" :pos pos :count 1}))

(core.register-mod "basic-blocks" {})
```

### 复杂机制mod：
```lua
;; mods/redstone-system/init.fnl - 红石系统
(local core (require "src.core"))
(local circuit-network {})

(fn propagate-signal [x y power]
  ;; 信号传播逻辑
  (let [neighbors (get-neighbors x y)]
    (each [_ pos (pairs neighbors)]
      (let [tile (TileAPI.get pos.x pos.y)]
        (when (and tile (tile-conducts-power? tile))
          (set-power pos.x pos.y (max 0 (- power 1))))))))

(fn register-redstone-tiles []
  (TileAPI.register "redstone-wire"
    {:conducts-power true
     :max-power 15
     :on-neighbor-change propagate-signal})
  
  (TileAPI.register "redstone-torch"
    {:power-source true
     :power-level 15
     :on-place #(propagate-signal $1.x $1.y 15)}))

(core.subscribe-event "tile-system" register-redstone-tiles)
(core.register-mod "redstone-system" {})
```

### 核心系统最小化, src/init.fnl (最小主程序)：
```lua
;; 超级简化的主程序
(local core (require "src.core"))
(local mod-loader (require "src.mod-loader"))

(fn love.load []
  (print "Starting game with mod-driven architecture")
  (mod-loader.load-all-mods)
  (core.emit-event "game-started" {}))

(fn love.update [dt]
  (core.emit-event "game-update" {:dt dt}))

(fn love.draw []
  (core.emit-event "game-draw" {}))

;; 其他LÖVE回调也通过事件系统处理
(fn love.mousepressed [x y button]
  (core.emit-event "mouse-pressed" {:x x :y y :button button}))

(fn love.keypressed [key]
  (core.emit-event "key-pressed" {:key key}))
```


### Mod配置驱动, mod manifest系统：
```json
// mods/survival-pack/manifest.json
{
  "id": "survival-pack",
  "version": "1.0",
  "dependencies": ["tile-system", "render-system"],
  "provides": ["survival-mode", "hunger-system", "health-system"],
  "entry": "init.fnl",
  "config": {
    "difficulty": "normal",
    "spawn-monsters": true
  }
}
```

### 这种架构的优势

这种架构的优势
极致的模块化：

核心永远保持最小
所有功能都可以被替换
不同mod组合产生不同游戏体验

开发灵活性：

每个系统独立开发和测试
可以完全重写游戏机制而不碰核心
支持A/B测试不同的游戏设计

社区创造力：

玩家可以创造全新的游戏模式
不同mod的组合产生意想不到的玩法
真正的"游戏平台"而非单一游戏

迁移友好：

核心逻辑在mod中，迁移时主要是重写基础设施
API保持一致，mod代码大部分可以复用

这样设计确实可以让游戏逻辑100%在mod中实现！








# 核心API架构

```lua 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;事件系统 (EventBus):

;; 核心事件API
(local EventAPI {})

(fn EventAPI.emit [event data]
  "发布事件，支持异步和同步")

(fn EventAPI.subscribe [event handler priority]
  "订阅事件，支持优先级")

(fn EventAPI.unsubscribe [event handler]
  "取消订阅")

(fn EventAPI.once [event handler]
  "一次性事件监听")

(fn EventAPI.create-channel [name]
  "创建命名事件通道")

;; 内置核心事件
;; game-* : 游戏生命周期
;; tick-* : 游戏循环
;; input-* : 输入事件
;; render-* : 渲染事件


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;数据存储系统 (DataAPI)：

(local DataAPI {})

(fn DataAPI.set [key value namespace]
  "设置数据，支持命名空间隔离")

(fn DataAPI.get [key namespace default]
  "获取数据，支持默认值")

(fn DataAPI.watch [key callback namespace]
  "监听数据变化")

(fn DataAPI.delete [key namespace]
  "删除数据")

(fn DataAPI.query [pattern namespace]
  "模式匹配查询")

;; 持久化支持
(fn DataAPI.save [namespace filename]
  "保存命名空间到文件")

(fn DataAPI.load [namespace filename]
  "从文件加载数据")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;空间系统 (SpatialAPI)：

(local SpatialAPI {})

;; 多维度空间支持
(fn SpatialAPI.create-space [name dimensions bounds]
  "创建空间：2D世界、3D世界、抽象空间等")

(fn SpatialAPI.set-cell [space x y ...]
  "设置空间中的单元")

(fn SpatialAPI.get-cell [space x y ...]
  "获取空间中的单元")

(fn SpatialAPI.query-region [space x1 y1 x2 y2]
  "区域查询")

(fn SpatialAPI.find-path [space start end]
  "寻路算法")

(fn SpatialAPI.add-entity [space entity]
  "添加实体到空间")

(fn SpatialAPI.collision-test [space shape position]
  "碰撞检测")



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;渲染系统API, 多层渲染支持：

(local RenderAPI {})

(fn RenderAPI.create-layer [name z-index]
  "创建渲染层")

(fn RenderAPI.draw-sprite [layer texture x y options]
  "精灵渲染")

(fn RenderAPI.draw-text [layer text x y font color]
  "文本渲染")

(fn RenderAPI.draw-shape [layer shape-type points color]
  "形状渲染")

(fn RenderAPI.create-camera [name]
  "创建相机")

(fn RenderAPI.set-camera-viewport [camera x y w h]
  "设置相机视口")

(fn RenderAPI.add-effect [layer effect-type params]
  "添加渲染效果：粒子、着色器等")

;; UI渲染
(fn RenderAPI.create-ui-element [type properties]
  "创建UI元素")

(fn RenderAPI.layout-ui [container children layout-type]
  "UI布局")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;资源管理API：

(local ResourceAPI {})

(fn ResourceAPI.load [type path]
  "加载资源：图片、音频、字体等")

(fn ResourceAPI.preload [resource-list]
  "预加载资源列表")

(fn ResourceAPI.create-atlas [name textures]
  "创建图集")

(fn ResourceAPI.generate-texture [width height generator-fn]
  "程序生成纹理")

(fn ResourceAPI.cache-control [resource ttl]
  "缓存控制")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;输入和交互系统, 统一输入API：
(local InputAPI {})

(fn InputAPI.bind-key [key action context]
  "按键绑定，支持上下文")

(fn InputAPI.bind-mouse [button action]
  "鼠标绑定")

(fn InputAPI.create-gesture [name pattern]
  "手势识别")

(fn InputAPI.get-input-state [action]
  "获取输入状态")

(fn InputAPI.create-input-map [name bindings]
  "创建输入映射")

(fn InputAPI.enable-context [context]
  "启用输入上下文")

;; 虚拟输入支持
(fn InputAPI.create-virtual-stick [position]
  "虚拟摇杆")

(fn InputAPI.create-button-layout [buttons]
  "虚拟按钮布局")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;时间和调度系统,灵活的时间管理：
(local TimeAPI {})

(fn TimeAPI.set-timescale [scale]
  "时间缩放：暂停、慢动作、快进")

(fn TimeAPI.create-timer [duration callback repeat]
  "创建定时器")

(fn TimeAPI.schedule [delay callback]
  "延迟执行")

(fn TimeAPI.create-clock [name tickrate]
  "创建独立时钟")

(fn TimeAPI.tween [object property target duration easing]
  "补间动画")

;; 游戏时间 vs 真实时间
(fn TimeAPI.get-game-time []
  "获取游戏内时间")

(fn TimeAPI.get-real-time []
  "获取真实时间")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;音频系统API, 完整音频支持：

(local AudioAPI {})

(fn AudioAPI.play-sound [sound volume pitch]
  "播放音效")

(fn AudioAPI.play-music [music loop fade-in]
  "播放音乐")

(fn AudioAPI.create-audio-source [type]
  "创建音频源：3D、2D、UI")

(fn AudioAPI.set-listener-position [x y z]
  "设置听者位置")

(fn AudioAPI.create-audio-group [name]
  "音频分组管理")

(fn AudioAPI.apply-effect [source effect-type params]
  "音频效果")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;网络和多人API, 网络抽象层：
(local NetworkAPI {})

(fn NetworkAPI.create-session [type]
  "创建会话：host、client、p2p")

(fn NetworkAPI.send-message [target message reliable]
  "发送消息")

(fn NetworkAPI.sync-data [key value scope]
  "数据同步")

(fn NetworkAPI.register-rpc [name handler]
  "远程过程调用")

(fn NetworkAPI.get-players []
  "获取玩家列表")

;; 状态同步
(fn NetworkAPI.create-sync-group [entities]
  "创建同步组")

(fn NetworkAPI.set-authority [entity player]
  "设置权威性")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;物理系统API, 可选物理支持：
(local PhysicsAPI {})

(fn PhysicsAPI.create-world [gravity]
  "创建物理世界")

(fn PhysicsAPI.create-body [type x y]
  "创建刚体")

(fn PhysicsAPI.add-shape [body shape-type params]
  "添加碰撞形状")

(fn PhysicsAPI.apply-force [body fx fy]
  "施加力")

(fn PhysicsAPI.raycast [world x1 y1 x2 y2]
  "射线检测")

;; 约束和关节
(fn PhysicsAPI.create-joint [type body1 body2 params]
  "创建关节")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;AI和寻路API,智能行为支持：
(local AIAPI {})

(fn AIAPI.create-state-machine [states transitions]
  "状态机")

(fn AIAPI.create-behavior-tree [root-node]
  "行为树")

(fn AIAPI.find-path [start goal obstacles]
  "A*寻路")

(fn AIAPI.create-nav-mesh [polygons]
  "导航网格")

(fn AIAPI.flock-behavior [entities params]
  "群体行为")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;序列化和存档API, 数据持久化：

(local SaveAPI {})

(fn SaveAPI.serialize [data format]
  "序列化：JSON、MessagePack、Binary")

(fn SaveAPI.deserialize [data format]
  "反序列化")

(fn SaveAPI.create-save-slot [name]
  "创建存档槽")

(fn SaveAPI.save-world [slot data]
  "保存世界")

(fn SaveAPI.load-world [slot]
  "加载世界")

(fn SaveAPI.auto-save [interval]
  "自动保存")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;调试和开发工具API,开发支持
(local DebugAPI {})

(fn DebugAPI.log [level message category]
  "日志系统")

(fn DebugAPI.draw-debug-line [x1 y1 x2 y2 color]
  "调试绘制")

(fn DebugAPI.create-inspector [object]
  "对象检视器")

(fn DebugAPI.profile-begin [name]
  "性能分析")

(fn DebugAPI.add-console-command [name handler]
  "控制台命令")

;; 热重载支持
(fn DebugAPI.watch-file [path callback]
  "文件监控")

(fn DebugAPI.reload-mod [mod-name]
  "重载mod")


```

## 完整的核心示例, 统一的核心接口：
```lua
;; src/core-api.fnl
(local CoreAPI {
  :Event EventAPI
  :Data DataAPI
  :Spatial SpatialAPI
  :Render RenderAPI
  :Resource ResourceAPI
  :Input InputAPI
  :Time TimeAPI
  :Audio AudioAPI
  :Network NetworkAPI
  :Physics PhysicsAPI
  :AI AIAPI
  :Save SaveAPI
  :Debug DebugAPI
})

;; 全局暴露
(tset _G "Core" CoreAPI)

;; Mod可以这样使用：
;; (Core.Data.set "player-health" 100 "game-state")
;; (Core.Event.emit "player-damaged" {:damage 10})
;; (Core.Render.draw-sprite "main" player-texture x y)


;;这样的核心API能支持：

;;策略游戏：空间管理 + AI + 回合制时间
;;动作游戏：物理 + 输入 + 实时渲染
;;RPG游戏：存档 + 事件 + UI + 音频
;;多人游戏：网络 + 同步 + 权威性
;;解谜游戏：状态管理 + 序列化
;;模拟游戏：时间 + 复杂数据关系

;;核心保持最小，但API覆盖面广，mod可以组合这些API创造任何类型的游戏！


```


# 扩展微内核API - 支持格斗和实时动作游戏

## 实时物理系统API (PhysicsAPI 增强)

### 高精度碰撞检测
```lua
(local PhysicsAPI {})

;; 基础物理世界
(fn PhysicsAPI.create-world [gravity timestep iterations]
  "创建高精度物理世界，支持子步长")

(fn PhysicsAPI.step-world [world dt max-substeps]
  "固定时间步长物理更新，确保一致性")

;; 碰撞形状系统
(fn PhysicsAPI.create-hitbox [type params]
  "创建攻击判定框：rectangle、circle、polygon、capsule")

(fn PhysicsAPI.create-hurtbox [type params]
  "创建受击判定框")

(fn PhysicsAPI.create-pushbox [type params]  
  "创建推挤判定框")

;; 精确碰撞检测
(fn PhysicsAPI.test-collision [shape1 pos1 shape2 pos2]
  "测试两个形状是否碰撞")

(fn PhysicsAPI.continuous-collision [shape start-pos end-pos obstacles]
  "连续碰撞检测，防止穿透")

(fn PhysicsAPI.overlap-test [shape position query-layers]
  "查询指定层级的重叠对象")

;; 物理属性
(fn PhysicsAPI.set-friction [body surface-friction air-friction]
  "设置摩擦力：地面摩擦和空气阻力")

(fn PhysicsAPI.set-restitution [body bounce-factor]
  "设置弹性系数")

(fn PhysicsAPI.set-mass [body mass]
  "设置质量，影响击退效果")
```

### 运动学系统
```lua
;; 高级运动控制
(fn PhysicsAPI.set-velocity [body vx vy]
  "设置速度")

(fn PhysicsAPI.add-impulse [body ix iy]
  "添加瞬时冲量")

(fn PhysicsAPI.apply-force [body fx fy duration]
  "施加持续力")

(fn PhysicsAPI.set-gravity-scale [body scale]
  "设置重力缩放，支持浮空角色")

;; 约束系统
(fn PhysicsAPI.pin-to-position [body x y stiffness]
  "位置约束，用于平台角色")

(fn PhysicsAPI.limit-velocity [body max-x max-y]
  "速度限制")

(fn PhysicsAPI.create-one-way-platform [x y width]
  "单向平台碰撞")
```

## 动画系统API (AnimationAPI 新增)

### 精确帧动画
```lua
(local AnimationAPI {})

(fn AnimationAPI.create-spritesheet [texture frame-width frame-height]
  "创建精灵表")

(fn AnimationAPI.create-animation [name frames durations looping]
  "创建动画序列，支持每帧不同时长")

(fn AnimationAPI.create-animator [entity]
  "为实体创建动画控制器")

;; 状态机动画
(fn AnimationAPI.add-state [animator name animation]
  "添加动画状态")

(fn AnimationAPI.add-transition [animator from to condition]
  "添加状态转换条件")

(fn AnimationAPI.set-parameter [animator param value]
  "设置动画参数")

;; 混合和插值
(fn AnimationAPI.blend-animations [anim1 anim2 weight]
  "动画混合")

(fn AnimationAPI.crossfade [animator from to duration]
  "交叉淡入淡出")

;; 事件系统
(fn AnimationAPI.add-frame-event [animation frame callback]
  "在特定帧触发事件")

(fn AnimationAPI.add-motion-event [animation progress callback]
  "在动画进度点触发事件")
```

### 高级动画功能
```lua
;; 骨骼动画支持
(fn AnimationAPI.create-skeleton [bones]
  "创建骨骼系统")

(fn AnimationAPI.bind-mesh [skeleton mesh weights]
  "绑定网格到骨骼")

(fn AnimationAPI.apply-ik [skeleton target-bone target-pos]
  "反向运动学")

;; 程序动画
(fn AnimationAPI.create-tween [object property from to duration easing]
  "补间动画")

(fn AnimationAPI.spring-animation [object property target stiffness damping]
  "弹簧动画")

(fn AnimationAPI.shake-effect [object intensity duration decay]
  "震动效果")
```

## 格斗游戏专用API (FightingAPI 新增)

### 输入缓冲和指令识别
```lua
(local FightingAPI {})

;; 输入缓冲系统
(fn FightingAPI.create-input-buffer [size]
  "创建输入缓冲区，记录按键时序")

(fn FightingAPI.add-input [buffer input timestamp]
  "添加输入到缓冲区")

(fn FightingAPI.register-motion [name sequence window]
  "注册搓招指令：波动拳、升龙拳等")

(fn FightingAPI.check-motion [buffer motion-name]
  "检查指令是否成立")

;; 取消系统
(fn FightingAPI.set-cancel-window [action start-frame end-frame]
  "设置招式取消窗口")

(fn FightingAPI.register-cancel [from to conditions]
  "注册取消关系")

(fn FightingAPI.check-cancel [current-action input]
  "检查是否可以取消当前动作")
```

### 攻击系统
```lua
;; 攻击判定
(fn FightingAPI.create-attack [damage knockback hitstun blockstun]
  "创建攻击数据")

(fn FightingAPI.set-attack-properties [attack type priority counter-hit]
  "设置攻击属性：上段、中段、下段等")

(fn FightingAPI.activate-hitbox [entity hitbox attack duration]
  "激活攻击判定")

;; 防御系统
(fn FightingAPI.set-block-state [entity block-type]
  "设置防御状态：立防、蹲防、空防")

(fn FightingAPI.calculate-blockstun [attack defender]
  "计算防御硬直")

(fn FightingAPI.push-back [attacker defender force]
  "计算击退距离")

;; 连击系统
(fn FightingAPI.start-combo [attacker target]
  "开始连击计数")

(fn FightingAPI.add-combo-hit [combo-data attack]
  "添加连击数据")

(fn FightingAPI.calculate-damage-scaling [combo-count base-damage]
  "计算伤害递减")
```

### 角色状态机
```lua
;; 格斗角色状态
(fn FightingAPI.create-fighter-state [name]
  "创建角色状态：站立、蹲下、跳跃、攻击等")

(fn FightingAPI.set-state-properties [state cancellable airborne invincible]
  "设置状态属性")

(fn FightingAPI.add-state-transition [from to input-condition frame-condition]
  "添加状态转换规则")

;; 帧数据系统
(fn FightingAPI.set-frame-data [action startup active recovery]
  "设置招式帧数据")

(fn FightingAPI.set-advantage [action hit-advantage block-advantage]
  "设置有利帧")

(fn FightingAPI.check-punishable [defender attacker]
  "检查是否可以反击")
```

## 实时动作游戏API (ActionAPI 新增)

### 精确时序系统
```lua
(local ActionAPI {})

;; 时间管理
(fn ActionAPI.create-action-timer [entity]
  "为实体创建动作计时器")

(fn ActionAPI.set-frame-rate [fps]
  "设置固定帧率，确保一致性")

(fn ActionAPI.get-frame-count []
  "获取当前帧数")

(fn ActionAPI.schedule-frame-event [frame callback]
  "在特定帧执行事件")

;; I帧系统
(fn ActionAPI.set-invincibility [entity duration types]
  "设置无敌帧，指定无敌类型")

(fn ActionAPI.check-invincible [entity damage-type]
  "检查是否处于无敌状态")

;; 优先级系统
(fn ActionAPI.set-action-priority [action priority]
  "设置动作优先级")

(fn ActionAPI.interrupt-action [entity new-action force]
  "打断当前动作")
```

### 精确碰撞和反馈
```lua
;; 命中反馈
(fn ActionAPI.create-hitstop [duration attacker-freeze target-freeze]
  "创建命中停顿效果")

(fn ActionAPI.screen-shake [intensity duration frequency]
  "屏幕震动")

(fn ActionAPI.hit-spark [position type]
  "命中火花效果")

;; 位移系统
(fn ActionAPI.dash [entity direction distance duration curve]
  "冲刺移动")

(fn ActionAPI.teleport [entity target-pos effect]
  "瞬移")

(fn ActionAPI.slide [entity direction friction]
  "滑行")

;; 弹反系统
(fn ActionAPI.create-parry [entity timing-window]
  "创建弹反窗口")

(fn ActionAPI.perfect-dodge [entity i-frames movement]
  "完美闪避")

(fn ActionAPI.counter-attack [defender attacker counter-data]
  "反击系统")
```

## 音频系统增强 (AudioAPI 扩展)

### 实时音效
```lua
;; 精确音效同步
(fn AudioAPI.play-at-frame [sound frame volume]
  "在指定帧播放音效")

(fn AudioAPI.stop-at-frame [sound-id frame fade-out]
  "在指定帧停止音效")

;; 动态音效
(fn AudioAPI.pitch-shift [sound-id pitch-factor]
  "实时调整音调")

(fn AudioAPI.apply-doppler [sound-id velocity]
  "多普勒效应")

;; 格斗游戏音效
(fn AudioAPI.play-voice-line [character line priority]
  "播放角色语音，支持优先级")

(fn AudioAPI.dynamic-music [situation track crossfade-time]
  "动态音乐切换")
```

## 网络同步增强 (NetworkAPI 扩展)

### 确定性网络
```lua
;; 输入同步
(fn NetworkAPI.sync-inputs [frame inputs]
  "同步所有玩家输入")

(fn NetworkAPI.create-input-delay [delay]
  "设置输入延迟缓解网络延迟")

(fn NetworkAPI.rollback-to-frame [frame]
  "回滚到指定帧")

;; 状态同步
(fn NetworkAPI.create-snapshot [world-state]
  "创建世界状态快照")

(fn NetworkAPI.interpolate-states [state1 state2 factor]
  "状态插值")

(fn NetworkAPI.predict-movement [entity inputs]
  "客户端预测")
```

## 调试工具增强 (DebugAPI 扩展)

### 格斗游戏调试
```lua
;; 可视化调试
(fn DebugAPI.draw-hitboxes [enable colors]
  "显示攻击判定框")

(fn DebugAPI.draw-frame-data [entity show-startup show-active show-recovery]
  "显示帧数据")

(fn DebugAPI.show-input-history [player buffer-size]
  "显示输入历史")

;; 性能分析
(fn DebugAPI.profile-collision [enable]
  "碰撞检测性能分析")

(fn DebugAPI.network-debug [show-latency show-rollbacks]
  "网络调试信息")

(fn DebugAPI.frame-step [enable]
  "单帧步进调试")
```

## 使用示例

### 格斗游戏角色实现
```lua
;; 创建格斗角色
(local ryu {})

(fn ryu.init []
  ;; 创建物理体
  (set ryu.body (PhysicsAPI.create-body "dynamic" 100 300))
  (PhysicsAPI.add-shape ryu.body "capsule" [20 40])
  
  ;; 创建动画器
  (set ryu.animator (AnimationAPI.create-animator ryu))
  (AnimationAPI.add-state ryu.animator "idle" idle-animation)
  (AnimationAPI.add-state ryu.animator "punch" punch-animation)
  
  ;; 创建输入缓冲
  (set ryu.input-buffer (FightingAPI.create-input-buffer 60))
  
  ;; 注册必杀技
  (FightingAPI.register-motion "hadoken" 
    ["down" "down-forward" "forward" "punch"] 20))

(fn ryu.update [dt]
  ;; 更新输入缓冲
  (let [input (InputAPI.get-current-input)]
    (FightingAPI.add-input ryu.input-buffer input (Core.Time.get-frame-count)))
  
  ;; 检查必杀技
  (when (FightingAPI.check-motion ryu.input-buffer "hadoken")
    (ryu.hadoken))
  
  ;; 更新物理和动画
  (PhysicsAPI.update-body ryu.body dt)
  (AnimationAPI.update ryu.animator dt))

(fn ryu.hadoken []
  ;; 播放动画
  (AnimationAPI.set-state ryu.animator "hadoken")
  
  ;; 创建火球
  (let [fireball (create-projectile "hadoken" ryu.position)]
    (PhysicsAPI.set-velocity fireball 300 0)))
```

### 实时动作游戏实现
```lua
;; 动作游戏角色
(local ninja {})

(fn ninja.init []
  (set ninja.body (PhysicsAPI.create-body "kinematic" 100 100))
  (set ninja.dash-timer (ActionAPI.create-action-timer ninja))
  (set ninja.combo-count 0))

(fn ninja.update [dt]
  (let [input (InputAPI.get-current-input)]
    
    ;; 攻击输入
    (when (and input.attack-pressed (= ninja.state "ground"))
      (ninja.attack))
    
    ;; 冲刺输入
    (when (and input.dash-pressed (ninja.can-dash?))
      (ninja.dash input.direction))
    
    ;; 更新状态
    (ActionAPI.update-timer ninja.dash-timer dt)
    (PhysicsAPI.update-body ninja.body dt)))

(fn ninja.attack []
  ;; 设置攻击状态
  (set ninja.state "attacking")
  (set ninja.combo-count (+ ninja.combo-count 1))
  
  ;; 创建攻击判定
  (let [attack (FightingAPI.create-attack 10 [50 20] 8 4)
        hitbox (PhysicsAPI.create-hitbox "rectangle" [30 20])]
    
    (FightingAPI.activate-hitbox ninja hitbox attack 4)
    
    ;; 命中停顿
    (ActionAPI.create-hitstop 3 2 8)))

(fn ninja.dash [direction]
  ;; 设置无敌帧
  (ActionAPI.set-invincibility ninja 10 ["projectile"])
  
  ;; 冲刺移动
  (ActionAPI.dash ninja direction 150 15 "ease-out")
  
  ;; 残影效果
  (RenderAPI.add-effect "dash-trail" ninja.position))
```

这套扩展API现在完全支持：
- **格斗游戏**：精确帧数据、输入缓冲、搓招识别、连击系统
- **实时动作游戏**：高精度碰撞、无敌帧、完美时序、流畅反馈
- **网络对战**：确定性同步、输入延迟、状态回滚
- **调试工具**：可视化判定框、性能分析、网络调试

核心保持模块化设计，这些API都是可选的，只有需要精确动作游戏的mod才会加载使用。