
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
function love.load()
    player = {x = 100, y = 400, w = 32, h = 32, speed = 200, vy = 0, jump = -400}
    gravity = 800
    player.on_ground = true
    platforms = {{x = 0, y = 500, w = 800, h = 100}}
    coins = {{x = 300, y = 400, r = 10}}
end

function love.update(dt)
    -- 玩家移动
    if love.keyboard.isDown("left") then
        player.x = player.x - player.speed * dt
    elseif love.keyboard.isDown("right") then
        player.x = player.x + player.speed * dt
    end
    if love.keyboard.isDown("space") and player.on_ground then
        player.vy = player.jump
        player.on_ground = false
    end
    -- 物理
    player.vy = player.vy + gravity * dt
    player.y = player.y + player.vy * dt
    -- 平台碰撞
    player.on_ground = false
    for _, platform in ipairs(platforms) do
        if player.x + player.w > platform.x and player.x < platform.x + platform.w
            and player.y + player.h > platform.y and player.y < platform.y + platform.h
            and player.vy > 0 then
            player.y = platform.y - player.h
            player.vy = 0
            player.on_ground = true
        end
    end
    -- 金币收集
    for i = #coins, 1, -1 do
        local coin = coins[i]
        if math.sqrt((player.x - coin.x)^2 + (player.y - coin.y)^2) < coin.r + player.w then
            table.remove(coins, i)
        end
    end
end

function love.draw()
    love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)
    for _, platform in ipairs(platforms) do
        love.graphics.rectangle("fill", platform.x, platform.y, platform.w, platform.h)
    end
    for _, coin in ipairs(coins) do
        love.graphics.circle("fill", coin.x, coin.y, coin.r)
    end
end


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