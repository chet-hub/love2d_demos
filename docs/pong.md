# Pong（乒乓球游戏）

## 概述
Pong 是一个简单的 2D 双人乒乓球游戏，玩家控制挡板击打小球，率先得分获胜。这是学习 Love2D 和 Lua 的基础项目，适合熟悉渲染、输入处理和简单碰撞检测。

## 学习目标
- 掌握 Love2D 的核心循环（`love.load`、`love.update`、`love.draw`）。
- 理解键盘输入处理。
- 实现基本的 2D 碰撞检测。
- 学习 Lua 和 Fennel 的基本语法。

## 代码实现

### Lua 版本（main.lua）
```lua
function love.load()
    ball = {x = 400, y = 300, radius = 10, dx = 200, dy = 200}
    paddle1 = {x = 50, y = 250, w = 20, h = 100, speed = 300}
    paddle2 = {x = 750, y = 250, w = 20, h = 100, speed = 300}
    score1, score2 = 0, 0
end

function love.update(dt)
    -- 玩家 1 移动
    if love.keyboard.isDown("w") then
        paddle1.y = paddle1.y - paddle1.speed * dt
    elseif love.keyboard.isDown("s") then
        paddle1.y = paddle1.y + paddle1.speed * dt
    end
    -- 玩家 2 移动
    if love.keyboard.isDown("up") then
        paddle2.y = paddle2.y - paddle2.speed * dt
    elseif love.keyboard.isDown("down") then
        paddle2.y = paddle2.y + paddle2.speed * dt
    end
    -- 球移动
    ball.x = ball.x + ball.dx * dt
    ball.y = ball.y + ball.dy * dt
    -- 边界碰撞
    if ball.y < 0 or ball.y > 600 then
        ball.dy = -ball.dy
    end
    -- 挡板碰撞
    if ball.x < paddle1.x + paddle1.w and ball.y > paddle1.y and ball.y < paddle1.y + paddle1.h then
        ball.dx = -ball.dx
    elseif ball.x > paddle2.x - paddle2.w and ball.y > paddle2.y and ball.y < paddle2.y + paddle2.h then
        ball.dx = -ball.dx
    end
    -- 得分
    if ball.x < 0 then
        score2 = score2 + 1
        ball.x, ball.y = 400, 300
    elseif ball.x > 800 then
        score1 = score1 + 1
        ball.x, ball.y = 400, 300
    end
end

function love.draw()
    love.graphics.rectangle("fill", paddle1.x, paddle1.y, paddle1.w, paddle1.h)
    love.graphics.rectangle("fill", paddle2.x, paddle2.y, paddle2.w, paddle2.h)
    love.graphics.circle("fill", ball.x, ball.y, ball.radius)
    love.graphics.print("Score: " .. score1 .. " - " .. score2, 350, 50)
end

```


### Fennel 版本（main.fnl）
```lua
(fn love.load []
  (set ball {:x 400 :y 300 :radius 10 :dx 200 :dy 200})
  (set paddle1 {:x 50 :y 250 :w 20 :h 100 :speed 300})
  (set paddle2 {:x 750 :y 250 :w 20 :h 100 :speed 300})
  (set score1 0)
  (set score2 0))

(fn love.update [dt]
  ;; 玩家 1 移动
  (when (: love.keyboard :isDown "w")
    (set paddle1.y (- paddle1.y (* paddle1.speed dt))))
  (when (: love.keyboard :isDown "s")
    (set paddle1.y (+ paddle1.y (* paddle1.speed dt))))
  ;; 玩家 2 移动
  (when (: love.keyboard :isDown "up")
    (set paddle2.y (- paddle2.y (* paddle2.speed dt))))
  (when (: love.keyboard :isDown "down")
    (set paddle2.y (+ paddle2.y (* paddle2.speed dt))))
  ;; 球移动
  (set ball.x (+ ball.x (* ball.dx dt)))
  (set ball.y (+ ball.y (* ball.dy dt)))
  ;; 边界碰撞
  (when (or (< ball.y 0) (> ball.y 600))
    (set ball.dy (- ball.dy)))
  ;; 挡板碰撞
  (when (and (< ball.x (+ paddle1.x paddle1.w))
             (> ball.y paddle1.y)
             (< ball.y (+ paddle1.y paddle1.h)))
    (set ball.dx (- ball.dx)))
  (when (and (> ball.x (- paddle2.x paddle2.w))
             (> ball.y paddle2.y)
             (< ball.y (+ paddle2.y paddle2.h)))
    (set ball.dx (- ball.dx)))
  ;; 得分
  (when (< ball.x 0)
    (set score2 (+ score2 1))
    (set ball.x 400)
    (set ball.y 300))
  (when (> ball.x 800)
    (set score1 (+ score1 1))
    (set ball.x 400)
    (set ball.y 300)))

(fn love.draw []
  (: love.graphics :rectangle "fill" paddle1.x paddle1.y paddle1.w paddle1.h)
  (: love.graphics :rectangle "fill" paddle2.x paddle2.y paddle2.w paddle2.h)
  (: love.graphics :circle "fill" ball.x ball.y ball.radius)
  (: love.graphics :print (.. "Score: " score1 " - " score2) 350 50))

```