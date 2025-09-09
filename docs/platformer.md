
---

### 案例 2: 平台跳跃游戏

**文件名**: `docs/platformer.md`

```markdown
# 平台跳跃游戏

## 概述
平台跳跃游戏是一个 2D 单人游戏，玩家控制角色移动、跳跃，收集金币，避开障碍。这是 Love2D 的进阶项目，模拟 Roblox 平台跳跃游戏，适合学习物理和关卡设计。

## 学习目标
- 实现 2D 物理（重力、碰撞）。
- 学习精灵渲染和简单关卡设计。
- 熟悉 Lua/Fennel 的模块化设计。
- 为 UGC 平台模块化打基础。

## 代码实现

### Lua 版本（main.lua）
```lua


local love = require('love')
local game = {}

function game.load()
    game.player = {x = 100, y = 400, w = 32, h = 32, speed = 200, vy = 0, jump = -400}
    game.gravity = 800
    game.player.on_ground = true
    game.platforms = {{x = 0, y = 500, w = 800, h = 100}}
    game.coins = {{x = 300, y = 400, r = 10}}
end

function game.update(dt)
    -- 玩家移动
    if love.keyboard.isDown("left") then
        game.player.x = game.player.x - game.player.speed * dt
    elseif love.keyboard.isDown("right") then
        game.player.x = game.player.x + game.player.speed * dt
    end
    if love.keyboard.isDown("space") and game.player.on_ground then
        game.player.vy = game.player.jump
        game.player.on_ground = false
    end
    -- 物理
    game.player.vy = game.player.vy + game.gravity * dt
    game.player.y = game.player.y + game.player.vy * dt
    -- 平台碰撞
    game.player.on_ground = false
    for _, platform in ipairs(game.platforms) do
        if game.player.x + game.player.w > platform.x and game.player.x < platform.x + platform.w
            and game.player.y + game.player.h > platform.y and game.player.y < platform.y + platform.h
            and game.player.vy > 0 then
            game.player.y = platform.y - game.player.h
            game.player.vy = 0
            game.player.on_ground = true
        end
    end
    -- 金币收集
    for i = #game.coins, 1, -1 do
        local coin = game.coins[i]
        if math.sqrt((game.player.x - coin.x)^2 + (game.player.y - coin.y)^2) < coin.r + game.player.w then
            table.remove(game.coins, i)
        end
    end
end

function game.draw()
    love.graphics.rectangle("fill", game.player.x, game.player.y, game.player.w, game.player.h)
    for _, platform in ipairs(game.platforms) do
        love.graphics.rectangle("fill", platform.x, platform.y, platform.w, platform.h)
    end
    for _, coin in ipairs(game.coins) do
        love.graphics.circle("fill", coin.x, coin.y, coin.r)
    end
end

return game


```

### Fennel 版本
```lua 
(fn love.load []
  (set player {:x 100 :y 400 :w 32 :h 32 :speed 200 :vy 0 :jump -400 :on-ground true})
  (set gravity 800)
  (set platforms [{:x 0 :y 500 :w 800 :h 100}])
  (set coins [{:x 300 :y 400 :r 10}]))

(fn love.update [dt]
  ;; 玩家移动
  (when (: love.keyboard :isDown "left")
    (set player.x (- player.x (* player.speed dt))))
  (when (: love.keyboard :isDown "right")
    (set player.x (+ player.x (* player.speed dt))))
  (when (and (: love.keyboard :isDown "space") player.on-ground)
    (set player.vy player.jump)
    (set player.on-ground false))
  ;; 物理
  (set player.vy (+ player.vy (* gravity dt)))
  (set player.y (+ player.y (* player.vy dt)))
  ;; 平台碰撞
  (set player.on-ground false)
  (each [_ platform platforms]
    (when (and (> (+ player.x player.w) platform.x)
               (< player.x (+ platform.x platform.w))
               (> (+ player.y player.h) platform.y)
               (< player.y (+ platform.y platform.h))
               (> player.vy 0))
      (set player.y (- platform.y player.h))
      (set player.vy 0)
      (set player.on-ground true)))
  ;; 金币收集
  (for [i (length coins) 1 -1]
    (let [coin (. coins i)]
      (when (< (math.sqrt (+ (^ (- player.x coin.x) 2) (^ (- player.y coin.y) 2)))
               (+ coin.r player.w))
        (table.remove coins i)))))

(fn love.draw []
  (: love.graphics :rectangle "fill" player.x player.y player.w player.h)
  (each [_ platform platforms]
    (: love.graphics :rectangle "fill" platform.x platform.y platform.w platform.h))
  (each [_ coin coins]
    (: love.graphics :circle "fill" coin.x coin.y coin.r)))

```